#if os(macOS)
import Foundation

/// Runs yt-dlp directly on the Mac. No companion server or network service is involved.
enum MacVideoDownloadService {
    enum DownloadError: LocalizedError {
        case invalidURL
        case downloaderUnavailable
        case downloaderFailed(String)
        case noVideoFile

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Enter a valid http or https video link."
            case .downloaderUnavailable:
                return "yt-dlp was not found. Install it with `brew install yt-dlp ffmpeg`, then reopen this sheet."
            case .downloaderFailed(let detail):
                return detail.isEmpty ? "yt-dlp could not download this video." : detail
            case .noVideoFile:
                return "yt-dlp finished without producing a playable video file."
            }
        }
    }

    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private static var importsDirectory: URL {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return cachesDirectory
            .appendingPathComponent("TimeMaster", isDirectory: true)
            .appendingPathComponent("Video Imports", isDirectory: true)
    }

    static func installedVersion() async -> String? {
        guard let executableURL = executableURL() else { return nil }

        let workingDirectory = importsDirectory
            .appendingPathComponent("Tool Check-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: workingDirectory,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: workingDirectory) }

            let result = try await run(
                executableURL: executableURL,
                arguments: ["--version"],
                workingDirectory: workingDirectory
            )
            guard result.status == 0 else { return nil }
            return result.output
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .last(where: { !$0.isEmpty })
        } catch {
            return nil
        }
    }

    static func download(from sourceURL: URL) async throws -> MacVideoSource {
        guard let scheme = sourceURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              sourceURL.host != nil else {
            throw DownloadError.invalidURL
        }
        guard let executableURL = executableURL() else {
            throw DownloadError.downloaderUnavailable
        }

        let workingDirectory = importsDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        do {
            let result = try await run(
                executableURL: executableURL,
                arguments: [
                    "--no-playlist",
                    "--no-progress",
                    "--no-warnings",
                    "--format", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b",
                    "--merge-output-format", "mp4",
                    "--paths", workingDirectory.path,
                    "--output", "video.%(ext)s",
                    sourceURL.absoluteString,
                ],
                workingDirectory: workingDirectory
            )

            guard result.status == 0 else {
                throw DownloadError.downloaderFailed(failureMessage(from: result.output))
            }
            guard let videoURL = downloadedVideo(in: workingDirectory) else {
                throw DownloadError.noVideoFile
            }
            return MacVideoSource(url: videoURL, managedDirectory: workingDirectory)
        } catch {
            try? fileManager.removeItem(at: workingDirectory)
            throw error
        }
    }

    static func removeManagedDownload(at directory: URL) {
        let standardizedDirectory = directory.standardizedFileURL
        let standardizedImports = importsDirectory.standardizedFileURL
        guard standardizedDirectory.path.hasPrefix(standardizedImports.path + "/") else { return }
        try? FileManager.default.removeItem(at: standardizedDirectory)
    }

    private static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let knownPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "\(home)/.local/bin/yt-dlp",
            "\(home)/.pyenv/shims/yt-dlp",
            "\(home)/Library/Python/3.13/bin/yt-dlp",
            "\(home)/Library/Python/3.12/bin/yt-dlp",
            "\(home)/Library/Python/3.11/bin/yt-dlp",
            "\(home)/Library/Python/3.10/bin/yt-dlp",
            "\(home)/Library/Python/3.9/bin/yt-dlp",
        ]
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) }
        let candidates = knownPaths + pathEntries.map { "\($0)/yt-dlp" }

        var visited = Set<String>()
        for path in candidates where visited.insert(path).inserted {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func run(
        executableURL: URL,
        arguments: [String],
        workingDirectory: URL
    ) async throws -> CommandResult {
        let logURL = workingDirectory.appendingPathComponent("yt-dlp.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle

        var environment = ProcessInfo.processInfo.environment
        let toolDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        environment["PATH"] = (toolDirectories + [environment["PATH"] ?? ""])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        process.environment = environment

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completedProcess in
                try? logHandle.close()
                let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
                continuation.resume(returning: CommandResult(
                    status: completedProcess.terminationStatus,
                    output: output
                ))
            }

            do {
                try process.run()
            } catch {
                try? logHandle.close()
                continuation.resume(throwing: error)
            }
        }
    }

    private static func downloadedVideo(in directory: URL) -> URL? {
        let supportedExtensions: Set<String> = ["mp4", "m4v", "mov", "webm", "mkv"]
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        return candidates
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .filter { (try? $0.resourceValues(forKeys: keys).isRegularFile) ?? false }
            .max {
                let leftSize = (try? $0.resourceValues(forKeys: keys).fileSize) ?? 0
                let rightSize = (try? $1.resourceValues(forKeys: keys).fileSize) ?? 0
                return leftSize < rightSize
            }
    }

    private static func failureMessage(from output: String) -> String {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.suffix(3).joined(separator: "\n")
    }
}
#endif
