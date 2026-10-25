#if os(macOS)
import Foundation

enum MacVideoDownloadService {
    enum DownloadError: LocalizedError {
        case invalidURL
        case downloaderUnavailable
        case downloaderFailed(String)
        case noVideoFile
        case liveVideo

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Enter a valid http or https video link."
            case .downloaderUnavailable:
                return "yt-dlp was not found. Run brew install yt-dlp ffmpeg, then retry."
            case .downloaderFailed(let detail):
                return detail.isEmpty ? "yt-dlp could not download this video. Open the original link or retry." : detail
            case .noVideoFile:
                return "yt-dlp finished without a video file. Open the original link to check availability."
            case .liveVideo:
                return "This video is live. Import it after the broadcast ends."
            }
        }
    }

    struct Metadata: Decodable {
        let title: String?
        let duration: Double?
        let isLive: Bool?

        enum CodingKeys: String, CodingKey {
            case title, duration
            case isLive = "is_live"
        }
    }

    private struct CommandResult {
        let status: Int32
        let output: String
        let errors: String
    }

    private static var importsDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("TimeMaster/Video Imports", isDirectory: true)
    }

    private static var toolDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let inherited = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.deno/bin"]
            + inherited + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        var seen = Set<String>()
        return candidates.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func executableURL(named name: String) -> URL? {
        var paths = toolDirectories.map { "\($0)/\(name)" }
        if name == "yt-dlp" {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            paths += ["3.15", "3.14", "3.13", "3.12", "3.11", "3.10", "3.9"]
                .map { "\(home)/Library/Python/\($0)/bin/yt-dlp" }
        }
        return paths.first(where: FileManager.default.isExecutableFile(atPath:)).map { URL(fileURLWithPath: $0) }
    }

    private static var extractorArguments: [String] {
        var arguments = ["--no-playlist", "--no-progress", "--socket-timeout", "30"]
        if let ffmpeg = executableURL(named: "ffmpeg") {
            arguments += ["--ffmpeg-location", ffmpeg.deletingLastPathComponent().path]
        }
        if let deno = executableURL(named: "deno") {
            arguments += ["--js-runtimes", "deno:\(deno.path)"]
        } else if let node = executableURL(named: "node") {
            arguments += ["--js-runtimes", "node:\(node.path)"]
        }
        return arguments
    }

    static func installedVersion() async -> String? {
        guard let executable = executableURL(named: "yt-dlp") else { return nil }
        do {
            let directory = try makeWorkingDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let result = try await run(executableURL: executable, arguments: ["--version"], workingDirectory: directory)
            guard result.status == 0 else { return nil }
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    static func validate(from sourceURL: URL) async throws -> Metadata {
        let executable = try requireDownloader(for: sourceURL)
        let directory = try makeWorkingDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await run(
            executableURL: executable,
            arguments: extractorArguments + ["--skip-download", "--dump-single-json", "--", sourceURL.absoluteString],
            workingDirectory: directory
        )
        guard result.status == 0 else { throw DownloadError.downloaderFailed(failureMessage(from: result)) }
        guard let data = result.output.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(Metadata.self, from: data) else {
            throw DownloadError.downloaderFailed("yt-dlp returned unreadable video information. Retry or open the original link.")
        }
        guard metadata.isLive != true else { throw DownloadError.liveVideo }
        return metadata
    }

    static func download(from sourceURL: URL) async throws -> MacVideoSource {
        let executable = try requireDownloader(for: sourceURL)
        let directory = try makeWorkingDirectory()
        do {
            let result = try await run(
                executableURL: executable,
                arguments: extractorArguments + [
                    "--format", "bv*[vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b",
                    "--merge-output-format", "mp4",
                    "--recode-video", "mp4",
                    "--paths", directory.path,
                    "--output", "video.%(ext)s",
                    "--print", "after_move:filepath",
                    "--", sourceURL.absoluteString,
                ],
                workingDirectory: directory
            )
            guard result.status == 0 else { throw DownloadError.downloaderFailed(failureMessage(from: result)) }
            try Task.checkCancellation()
            guard let videoURL = downloadedVideo(from: result.output, in: directory) else { throw DownloadError.noVideoFile }
            return MacVideoSource(url: videoURL, managedDirectory: directory)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    static func removeManagedDownload(at directory: URL) {
        let target = directory.standardizedFileURL
        guard target.path.hasPrefix(importsDirectory.standardizedFileURL.path + "/") else { return }
        try? FileManager.default.removeItem(at: target)
    }

    private static func requireDownloader(for url: URL) throws -> URL {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { throw DownloadError.invalidURL }
        guard let executable = executableURL(named: "yt-dlp") else { throw DownloadError.downloaderUnavailable }
        return executable
    }

    private static func makeWorkingDirectory() throws -> URL {
        let directory = importsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func run(executableURL: URL, arguments: [String], workingDirectory: URL) async throws -> CommandResult {
        let identifier = UUID().uuidString
        let outputURL = workingDirectory.appendingPathComponent("\(identifier).stdout")
        let errorURL = workingDirectory.appendingPathComponent("\(identifier).stderr")
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = toolDirectories.joined(separator: ":")
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        let cancellation = CommandCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { completed in
                    try? outputHandle.close()
                    try? errorHandle.close()
                    if cancellation.wasCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(returning: CommandResult(
                            status: completed.terminationStatus,
                            output: (try? String(contentsOf: outputURL, encoding: .utf8)) ?? "",
                            errors: (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
                        ))
                    }
                }
                do {
                    try cancellation.launch(process)
                } catch {
                    process.terminationHandler = nil
                    try? outputHandle.close()
                    try? errorHandle.close()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func downloadedVideo(from output: String, in directory: URL) -> URL? {
        let prefix = directory.standardizedFileURL.path + "/"
        return output.split(whereSeparator: \.isNewline).reversed().compactMap { line in
            let url = URL(fileURLWithPath: String(line)).standardizedFileURL
            guard url.path.hasPrefix(prefix),
                  ["mp4", "m4v", "mov", "webm", "mkv"].contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { return nil }
            return url
        }.first
    }

    private static func failureMessage(from result: CommandResult) -> String {
        let text = result.errors.isEmpty ? result.output : result.errors
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .suffix(12)
            .joined(separator: "\n")
    }

    private final class CommandCancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        var wasCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func launch(_ process: Process) throws {
            lock.lock()
            defer { lock.unlock() }
            guard !cancelled else { throw CancellationError() }
            self.process = process
            try process.run()
        }

        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            cancelled = true
            if let process, process.isRunning { process.interrupt() }
        }
    }
}
#endif
