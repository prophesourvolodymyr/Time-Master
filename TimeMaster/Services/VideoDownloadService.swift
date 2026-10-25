import Foundation

final class ServerSettings: ObservableObject {
    static let shared = ServerSettings()

    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "server_host") }
    }
    @Published var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: "server_port") }
    }

    private init() {
        let savedHost = UserDefaults.standard.string(forKey: "server_host") ?? ""
        host = savedHost.isEmpty ? "localhost" : savedHost
        let savedPort = UserDefaults.standard.integer(forKey: "server_port")
        port = savedPort > 0 ? savedPort : 8888
    }

    var baseURL: URL? { URL(string: "http://\(host):\(port)") }
}

struct VideoDownloadService {
    enum DownloadError: LocalizedError {
        case invalidURL
        case invalidServerURL
        case serverError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Enter a valid http or https video link."
            case .invalidServerURL: return "Check the companion server address in Server Settings."
            case .serverError(let status, let message):
                return message.isEmpty ? "Companion server returned HTTP \(status)." : message
            case .invalidResponse: return "The companion server returned an unreadable response."
            }
        }
    }

    struct Metadata: Decodable {
        let title: String?
        let duration: Double?
    }

    private struct ServerError: Decodable { let error: String }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 1800
        return URLSession(configuration: configuration)
    }()

    static func validate(socialURL: String, settings: ServerSettings) async throws -> Metadata {
        let url = try validatedURL(socialURL)
        #if os(macOS)
        let metadata = try await MacVideoDownloadService.validate(from: url)
        return Metadata(title: metadata.title, duration: metadata.duration)
        #else
        let request = try request(path: "validate", socialURL: url.absoluteString, settings: settings)
        let (data, response) = try await session.data(for: request)
        try check(response, errorData: data)
        return try JSONDecoder().decode(Metadata.self, from: data)
        #endif
    }

    static func download(socialURL: String, settings: ServerSettings) async throws -> URL {
        let url = try validatedURL(socialURL)
        #if os(macOS)
        let source = try await MacVideoDownloadService.download(from: url)
        defer { source.discardManagedFiles() }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.url.pathExtension)
        try FileManager.default.moveItem(at: source.url, to: destination)
        return destination
        #else
        let request = try request(path: "download", socialURL: url.absoluteString, settings: settings)
        let (temporaryURL, response) = try await session.download(for: request)
        do {
            if (response as? HTTPURLResponse)?.statusCode != 200 {
                let errorData = try Data(contentsOf: temporaryURL)
                try check(response, errorData: errorData)
            }
            try check(response, errorData: Data())
            try Task.checkCancellation()
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
        #endif
    }

    private static func validatedURL(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { throw DownloadError.invalidURL }
        return url
    }

    #if os(iOS)
    private static func request(path: String, socialURL: String, settings: ServerSettings) throws -> URLRequest {
        guard let base = settings.baseURL, let host = base.host, !host.isEmpty,
              base.port.map({ (1...65535).contains($0) }) ?? true else { throw DownloadError.invalidServerURL }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["url": socialURL])
        request.timeoutInterval = 300
        return request
    }

    private static func check(_ response: URLResponse, errorData: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw DownloadError.invalidResponse }
        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(ServerError.self, from: errorData))?.error ?? ""
            throw DownloadError.serverError(http.statusCode, message)
        }
    }
    #endif

    static func healthCheck(settings: ServerSettings) async -> Bool {
        #if os(macOS)
        return await MacVideoDownloadService.installedVersion() != nil
        #else
        guard let base = settings.baseURL else { return false }
        do {
            let (_, response) = try await session.data(from: base.appendingPathComponent("health"))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
        #endif
    }
}
