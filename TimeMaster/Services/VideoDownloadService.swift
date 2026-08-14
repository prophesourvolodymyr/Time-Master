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

/// Downloads a social-media video for the current platform.
struct VideoDownloadService {
    enum DownloadError: LocalizedError {
        case invalidServerURL
        case httpError(Int)
        case noFile
        case localDownloaderUnavailable
        case localDownloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidServerURL:
                return "Invalid server URL — check Server Settings."
            case .httpError(let code):
                return "Server returned HTTP \(code)."
            case .noFile:
                return "Downloaded file could not be saved."
            case .localDownloaderUnavailable:
                return "yt-dlp was not found. Install it with `pip3 install yt-dlp`."
            case .localDownloadFailed(let message):
                return message.isEmpty ? "yt-dlp could not download this video." : message
            }
        }
    }

    /// A dedicated URLSession with generous timeouts so yt-dlp processing
    /// doesn't cause the connection to be considered idle and timed out.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 300
        cfg.timeoutIntervalForResource = 1800
        return URLSession(configuration: cfg)
    }()

    /// Uses the local yt-dlp executable on macOS and the companion server on iOS.
    static func download(socialURL: String, settings: ServerSettings) async throws -> URL {
        #if os(macOS)
        return try await downloadLocally(socialURL: socialURL)
        #else
        return try await downloadFromServer(socialURL: socialURL, settings: settings)
        #endif
    }

    #if os(macOS)
    private static func downloadLocally(socialURL: String) async throws -> URL {
        guard !socialURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DownloadError.localDownloadFailed("Enter a video URL first.")
        }
        guard let executableURL = localDownloaderURL() else {
            throw DownloadError.localDownloaderUnavailable
        }

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("TimeMasterDownload-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        let outputTemplate = workDirectory.appendingPathComponent("video.%(ext)s").path
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "-f",
            "hd/sd/best[ext=mp4][acodec!=none]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best",
            "--merge-output-format", "mp4",
            "-o", outputTemplate,
            "--no-playlist",
            "--quiet",
            "--no-warnings",
            socialURL,
        ]

        var environment = ProcessInfo.processInfo.environment
        let toolDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        environment["PATH"] = toolDirectories.joined(separator: ":")
            + ":" + (environment["PATH"] ?? "")
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let result: (status: Int32, output: String)
        do {
            result = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<(status: Int32, output: String), Error>) in
                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(
                        data: outputData + errorData,
                        encoding: .utf8
                    ) ?? ""
                    continuation.resume(returning: (process.terminationStatus, output))
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw DownloadError.localDownloadFailed(error.localizedDescription)
        }

        guard result.status == 0 else {
            let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DownloadError.localDownloadFailed(message)
        }

        guard let downloadedURL = try? fileManager.contentsOfDirectory(
            at: workDirectory,
            includingPropertiesForKeys: nil
        ).first(where: { $0.pathExtension.lowercased() == "mp4" }) else {
            throw DownloadError.noFile
        }

        let destinationURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mp4")
        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: downloadedURL, to: destinationURL)
        return destinationURL
    }

    private static func localDownloaderURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pythonVersions = ["3.13", "3.12", "3.11", "3.10", "3.9"]
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "\(home)/.local/bin/yt-dlp",
            "\(home)/Library/Python/3.13/bin/yt-dlp",
            "\(home)/Library/Python/3.12/bin/yt-dlp",
            "\(home)/Library/Python/3.11/bin/yt-dlp",
            "\(home)/Library/Python/3.10/bin/yt-dlp",
            "\(home)/Library/Python/3.9/bin/yt-dlp",
            "/usr/bin/yt-dlp",
        ] + pythonVersions.map { "\(home)/Library/Python/\($0)/bin/yt-dlp" }
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0) }
    }
    #endif

    #if os(iOS)
    private static func downloadFromServer(
        socialURL: String,
        settings: ServerSettings
    ) async throws -> URL {
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

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: localURL, to: destinationURL)
        return destinationURL
    }
    #endif

    /// GET /health — returns true if the server responds with 200.
    static func healthCheck(settings: ServerSettings) async -> Bool {
        #if os(macOS)
        return localDownloaderURL() != nil
        #else
        guard let base = settings.baseURL else { return false }
        let endpoint = base.appendingPathComponent("health")
        let request = URLRequest(url: endpoint)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
        #endif
    }
}
