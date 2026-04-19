import Foundation

// MARK: - ServerSettings

/// UserDefaults-backed singleton holding the companion server connection info.
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

    var baseURL: URL? {
        URL(string: "http://\(host):\(port)")
    }
}

// MARK: - VideoDownloadService

/// Downloads a social-media video via the companion Python server.
struct VideoDownloadService {

    enum DownloadError: LocalizedError {
        case invalidServerURL
        case httpError(Int)
        case noFile

        var errorDescription: String? {
            switch self {
            case .invalidServerURL: return "Invalid server URL — check Server Settings."
            case .httpError(let code): return "Server returned HTTP \(code)."
            case .noFile: return "Downloaded file could not be saved."
            }
        }
    }

    /// A dedicated URLSession with generous timeouts so yt-dlp processing
    /// doesn't cause the connection to be considered idle and timed out.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        // Allow up to 5 minutes waiting for the first byte (yt-dlp + ffmpeg merge)
        cfg.timeoutIntervalForRequest  = 300
        // Allow up to 30 minutes for the full resource transfer
        cfg.timeoutIntervalForResource = 1800
        return URLSession(configuration: cfg)
    }()

    /// POST /download with the given social URL.
    /// Returns a local temp URL pointing to the downloaded .mp4.
    static func download(socialURL: String, settings: ServerSettings) async throws -> URL {
        guard let base = settings.baseURL else {
            throw DownloadError.invalidServerURL
        }
        let endpoint = base.appendingPathComponent("download")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["url": socialURL])
        request.timeoutInterval = 300

        let (localURL, response) = try await session.download(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DownloadError.httpError(http.statusCode)
        }

        // Move temp download to a stable named path
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: localURL, to: dest)
        return dest
    }

    /// GET /health — returns true if the server responds with 200.
    static func healthCheck(settings: ServerSettings) async -> Bool {
        guard let base = settings.baseURL else { return false }
        let endpoint = base.appendingPathComponent("health")
        let request = URLRequest(url: endpoint)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
