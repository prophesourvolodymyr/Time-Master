import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DatabaseSyncTransport {
    static let chunkSize = 4 * 1_024 * 1_024
    static let maximumChunks = 1_024
    static let maximumFileSize = Int64(chunkSize) * Int64(maximumChunks)
    static let maximumCommitBytes = 2 * 1_024 * 1_024
    private static let maximumMetadataBytes = 48 * 1_024 * 1_024

    let serviceURL: URL
    let session: URLSession
    let accessToken: String

    enum CommitResult {
        case committed([DatabaseSyncFile])
        case conflict([DatabaseSyncFile])
    }

    func manifest(cursor: Int64) async throws -> DatabaseSyncManifestResponse {
        var components = URLComponents(url: try endpoint("sync/manifest"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "cursor", value: String(cursor)), URLQueryItem(name: "limit", value: "500")]
        let data = try await perform(request(url: components.url!, method: "GET"), maximumBytes: Self.maximumMetadataBytes)
        do {
            return try JSONDecoder().decode(DatabaseSyncManifestResponse.self, from: data)
        } catch {
            throw DatabaseSyncError.invalidResponse("Unreadable file manifest.")
        }
    }

    func commit(deviceID: String, mutations: [DatabaseSyncMutation]) async throws -> CommitResult {
        let body = try JSONEncoder().encode(DatabaseSyncCommitRequest(deviceID: deviceID, mutations: mutations))
        guard body.count <= Self.maximumCommitBytes else {
            throw DatabaseSyncError.invalidResponse("The commit exceeds the service's metadata limit.")
        }
        var request = try request(url: endpoint("sync/commit"), method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, status) = try await response(request, maximumBytes: Self.maximumMetadataBytes)
        if status == 409 {
            guard let conflict = try? JSONDecoder().decode(DatabaseSyncConflictResponse.self, from: data), !conflict.conflicts.isEmpty else {
                throw DatabaseSyncError.invalidResponse("The service did not identify the conflicting revisions.")
            }
            return .conflict(conflict.conflicts)
        }
        try checkStatus(status, body: data)
        guard let result = try? JSONDecoder().decode(DatabaseSyncCommitResponse.self, from: data) else {
            throw DatabaseSyncError.invalidResponse("Unreadable commit result.")
        }
        return .committed(result.files)
    }

    func uploadChunk(hash: String, file: URL) async throws {
        try Task.checkCancellation()
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        guard size > 0, size <= Self.chunkSize else {
            throw DatabaseSyncError.invalidResponse("Invalid upload chunk size.")
        }
        var request = try request(url: endpoint("sync/blobs/\(hash)"), method: "PUT")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(String(size), forHTTPHeaderField: "Content-Length")
        let delegate = DatabaseSyncUploadDelegate()
        let (body, response) = try await delegate.upload(session: session, request: request, file: file)
        try Task.checkCancellation()
        try checkStatus(response.statusCode, body: body)
    }

    func downloadChunk(hash: String, destination: URL) async throws {
        let request = try request(url: endpoint("sync/blobs/\(hash)"), method: "GET")
        let (temporary, response) = try await session.download(for: request, delegate: DatabaseSyncRequestDelegate(maximumBytes: Self.chunkSize))
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw DatabaseSyncError.invalidResponse("Missing HTTP response.")
        }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        guard size >= 0, size <= Self.chunkSize else {
            throw DatabaseSyncError.invalidResponse("The service returned an oversized chunk.")
        }
        if !(200..<300).contains(response.statusCode) {
            try checkStatus(response.statusCode, body: Data(contentsOf: temporary))
        }
        guard size > 0 else { throw DatabaseSyncError.invalidResponse("The service returned an empty chunk.") }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let scheme = serviceURL.scheme?.lowercased(), let host = serviceURL.host,
              serviceURL.user == nil, serviceURL.password == nil, serviceURL.query == nil, serviceURL.fragment == nil,
              scheme == "https" || (scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host)) else {
            throw DatabaseSyncError.invalidServiceURL
        }
        return serviceURL.appendingPathComponent("v1").appendingPathComponent(path)
    }

    private func request(url: URL, method: String) throws -> URLRequest {
        guard !accessToken.isEmpty, !accessToken.contains("\r"), !accessToken.contains("\n") else {
            throw DatabaseSyncError.unauthorized
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest, maximumBytes: Int) async throws -> Data {
        let (data, status) = try await response(request, maximumBytes: maximumBytes)
        try checkStatus(status, body: data)
        return data
    }

    private func response(_ request: URLRequest, maximumBytes: Int) async throws -> (Data, Int) {
        try Task.checkCancellation()
        let (temporary, response) = try await session.download(for: request, delegate: DatabaseSyncRequestDelegate(maximumBytes: maximumBytes))
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw DatabaseSyncError.invalidResponse("Missing HTTP response.")
        }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        guard size >= 0, size <= maximumBytes else {
            throw DatabaseSyncError.invalidResponse("The service returned oversized metadata.")
        }
        return (try Data(contentsOf: temporary), response.statusCode)
    }

    private func checkStatus(_ status: Int, body: Data) throws {
        if status == 401 { throw DatabaseSyncError.unauthorized }
        guard (200..<300).contains(status) else {
            struct Detail: Decodable { let detail: String }
            let detail = (try? JSONDecoder().decode(Detail.self, from: body).detail)
                ?? "The cloud service is unavailable. Your exercise files remain local."
            throw DatabaseSyncError.server(status: status, detail: String(detail.prefix(1_024)))
        }
    }
}

private final class DatabaseSyncRequestDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let maximumBytes: Int64

    init(maximumBytes: Int) {
        self.maximumBytes = Int64(maximumBytes)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > maximumBytes || totalBytesExpectedToWrite > maximumBytes {
            downloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

private final class DatabaseSyncUploadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionUploadTask?
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var cancelled = false
    private var body = Data()
    private var response: HTTPURLResponse?
    private var responseError: Error?
    private let maximumBytes = 64 * 1_024

    func upload(session: URLSession, request: URLRequest, file: URL) async throws -> (Data, HTTPURLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.uploadTask(with: request, fromFile: file)
                task.delegate = self
                lock.lock()
                self.continuation = continuation
                self.task = task
                let cancelled = self.cancelled
                lock.unlock()
                if cancelled { task.cancel() }
                task.resume()
            }
        } onCancel: {
            self.lock.lock()
            self.cancelled = true
            let task = self.task
            self.lock.unlock()
            task?.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        self.response = response as? HTTPURLResponse
        let reject = response.expectedContentLength > maximumBytes || self.response == nil
        if reject { responseError = DatabaseSyncError.invalidResponse("Invalid or oversized blob upload response.") }
        lock.unlock()
        completionHandler(reject ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let reject = data.count > maximumBytes - body.count
        if reject { responseError = DatabaseSyncError.invalidResponse("Oversized blob upload response.") }
        else { body.append(data) }
        lock.unlock()
        if reject { dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.task = nil
        let result: Result<(Data, HTTPURLResponse), Error>
        if let error = responseError ?? error { result = .failure(error) }
        else if let response { result = .success((body, response)) }
        else { result = .failure(DatabaseSyncError.invalidResponse("Missing blob upload response.")) }
        lock.unlock()
        continuation?.resume(with: result)
    }
}
