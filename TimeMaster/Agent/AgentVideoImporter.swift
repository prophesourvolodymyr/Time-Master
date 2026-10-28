import Foundation
import AVFoundation
import TimeMasterCore

enum AgentVideoImporter {
    static func run(arguments: [String: Any], dryRun: Bool, router: AgentToolRouter) async throws -> AgentToolOutput {
#if os(macOS)
        let args = try AgentToolRegistry.validate("import_video", arguments: arguments)
        let source = (args["source"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = source.lowercased()
        let isLink = lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
        let clips = args["clips"] as? [[String: Any]] ?? []
        let wholeTitle = (args["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clips.isEmpty || !wholeTitle.isEmpty else {
            throw AgentToolError("invalid_argument", "Pass clips, or a title to save the whole video as one page.")
        }
        for (index, clip) in clips.enumerated() {
            let start = clip["start"] as? Double ?? 0
            let end = clip["end"] as? Double ?? 0
            guard start >= 0, end - start >= 0.25 else {
                throw AgentToolError("invalid_argument", "clips[\(index)]: end must be at least 0.25 seconds after start.")
            }
        }
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "source": source, "downloads": isLink, "pages": max(clips.count, 1)])
        }

        var fileURL: URL
        var downloaded: URL?
        if isLink {
            do {
                fileURL = try await VideoDownloadService.download(socialURL: source, settings: ServerSettings.shared)
                downloaded = fileURL
            } catch {
                throw AgentToolError("download_failed", error.localizedDescription, hint: "Check the link, or download the video yourself and pass its local path.")
            }
        } else {
            fileURL = try AgentFiles.validateMedia(path: source)
            guard AgentFiles.isVideo(fileURL) else {
                throw AgentToolError("unsupported_media", "import_video needs a video (mp4, mov or m4v).")
            }
        }
        defer { if let downloaded { try? FileManager.default.removeItem(at: downloaded) } }

        let asset = AVURLAsset(url: fileURL)
        let duration: Double
        do {
            duration = try await asset.load(.duration).seconds
        } catch {
            throw AgentToolError("unreadable_video", "The video could not be read: \(error.localizedDescription)", hint: "Convert it to mp4 with ffmpeg first.")
        }
        guard duration.isFinite, duration > 0 else {
            throw AgentToolError("unreadable_video", "The video has no readable duration.", hint: "Convert it to mp4 with ffmpeg first.")
        }
        guard AgentFiles.isVideo(fileURL) else {
            throw AgentToolError("unsupported_media", "'.\(fileURL.pathExtension)' video cannot be attached.", hint: "Convert it to mp4 with ffmpeg first.")
        }

        let plan: [[String: Any]] = clips.isEmpty
            ? [["title": wholeTitle, "start": 0.0, "end": duration, "whole": true]]
            : clips
        var effects: [AgentEffect] = []
        var pages: [[String: Any]] = []
        var temporary: [URL] = []
        defer { temporary.forEach { try? FileManager.default.removeItem(at: $0) } }

        do {
            for clip in plan {
                let title = clip["title"] as? String ?? wholeTitle
                let start = clip["start"] as? Double ?? 0
                let end = min(clip["end"] as? Double ?? duration, duration)
                guard end - start >= 0.25 else {
                    throw AgentToolError("invalid_argument", "'\(title)' starts after the end of the video (\(String(format: "%.1f", duration)) s).")
                }
                let mediaURL: URL
                if clip["whole"] as? Bool == true {
                    mediaURL = fileURL
                } else {
                    guard let trimmed = await VideoTrimService.export(asset: asset, from: start, to: end) else {
                        throw AgentToolError("clip_failed", "Cutting '\(title)' failed.", hint: "Check the start and end times.")
                    }
                    temporary.append(trimmed)
                    mediaURL = trimmed
                }
                var body = clip["markdownBody"] as? String ?? ""
                if body.isEmpty {
                    body = clip["whole"] as? Bool == true ? "Source: \(source)" : "Clip \(String(format: "%.2f", start))–\(String(format: "%.2f", end)) s of \(source)"
                }
                var page: [String: Any] = [
                    "title": title,
                    "markdownBody": body,
                    "media": [["path": mediaURL.path, "comment": clip["comment"] as? String ?? title]],
                ]
                var links = clip["linkURLs"] as? [String] ?? []
                if isLink { links.insert(source, at: 0) }
                if !links.isEmpty { page["linkURLs"] = links }
                if let parent = args["parent"] as? String { page["parent"] = parent }
                if let type = args["workoutType"] as? String { page["workoutType"] = type }
                if let exists = args["ifExists"] as? String { page["ifExists"] = exists }
                if let seconds = clip["duration"] as? Int { page["duration"] = seconds }
                let output = try await router.runCore("create_exercise_page", arguments: page)
                effects.append(contentsOf: output.effects)
                var entry: [String: Any] = [
                    "path": output.value["path"] as Any,
                    "id": output.value["id"] as Any,
                    "range": "\(String(format: "%g", start))-\(String(format: "%g", end))",
                ]
                if output.value["reused"] as? Bool == true { entry["reused"] = true }
                pages.append(entry)
            }
        } catch {
            if !effects.isEmpty { _ = try? await router.revertCore(effects) }
            throw error
        }
        return AgentToolOutput(value: ["pages": pages, "videoSeconds": duration], effects: effects)
#else
        throw AgentToolError("unsupported_platform", "import_video is available in the Mac app.")
#endif
    }
}
