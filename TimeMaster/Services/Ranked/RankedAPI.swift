import Foundation
import CryptoKit
import TimeMasterCore

enum RankedServiceError: LocalizedError {
    case unconfigured, insecureEndpoint, signedOut, message(String)
    var errorDescription: String? {
        switch self {
        case .unconfigured: return "The Ranked service is not configured. Camera-tracked Practice and the local library are available."
        case .insecureEndpoint: return "Ranked requires a secure HTTPS service address."
        case .signedOut: return "Sign in to your TimeMaster account to compete."
        case .message(let value): return value
        }
    }
}

actor RankedAPI {
    static let shared = RankedAPI()
    private var accountID: String?
    private var generation: UInt64 = 0
    private let session: URLSession
    let baseURL: URL?
    private struct Problem: Decodable { let detail: String }

    init() {
        baseURL = CloudServices.serviceURL(key: "TMRankedServiceURL", fallback: "TMSyncServiceURL")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: RankedTransportDelegate(), delegateQueue: nil)
    }

    var configured: Bool { baseURL != nil }

    func activateAccount(_ id: String?) {
        generation &+= 1
        accountID = id
    }

    func restore() throws -> String? {
        guard let key = matchPreferenceKey else { return nil }
        return UserDefaults.standard.string(forKey: key)
    }

    func hasSession() async throws -> Bool {
        guard let accountID else { return false }
        let current = try await CloudServices.auth.get().restore()
        return current?.userID == accountID
    }

    func rememberMatch(_ id: String?, accountID expectedAccountID: String?) throws {
        guard expectedAccountID == accountID else { throw CloudAuthError.superseded }
        guard let key = matchPreferenceKey else { return }
        if let id { UserDefaults.standard.set(id, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let accountID else { throw RankedServiceError.signedOut }
        let version = generation
        let client = try CloudServices.auth.get()
        var current = try await client.validSession()
        guard version == generation, current.userID == accountID else { throw CloudAuthError.superseded }
        let result: T
        do {
            result = try await send(path: path, method: method, body: body, token: current.accessToken)
        } catch RankedHTTPError.unauthorized {
            guard version == generation else { throw CloudAuthError.superseded }
            current = try await client.refreshSession()
            guard version == generation, current.userID == accountID else { throw CloudAuthError.superseded }
            result = try await send(path: path, method: method, body: body, token: current.accessToken)
        }
        guard version == generation else { throw CloudAuthError.superseded }
        try Task.checkCancellation()
        return result
    }

    private var matchPreferenceKey: String? {
        guard let accountID, let baseURL else { return nil }
        let endpoint = SHA256.hash(data: Data(baseURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return "tm.ranked.activeMatch.\(endpoint).\(accountID)"
    }

    private func send<T: Decodable>(path: String, method: String, body: Data?, token: String) async throws -> T {
        guard let baseURL else { throw RankedServiceError.unconfigured }
        guard let url = URL(string: path, relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL,
              url.host == baseURL.host, url.scheme == baseURL.scheme,
              url.port == baseURL.port, url.user == nil, url.password == nil else { throw RankedServiceError.insecureEndpoint }
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw RankedServiceError.message("Invalid service response") }
        if http.statusCode == 401 { throw RankedHTTPError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(Problem.self, from: data).detail) ?? "Ranked service rejected this request (\(http.statusCode))."
            throw RankedServiceError.message(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private enum RankedHTTPError: LocalizedError {
    case unauthorized
    var errorDescription: String? { "The shared account session was not accepted. Sign in again; local changes remain on this device." }
}

struct RankedOK: Decodable { let ok: Bool }

private final class RankedTransportDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
