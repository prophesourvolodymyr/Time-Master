import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - VideoTrimService

/// Stateless service for exporting video clips and generating thumbnails.
struct VideoTrimService {

    /// Why an export could not produce a clip.
    enum ExportError: LocalizedError {
        case unsupported
        case failed

        var errorDescription: String? {
            switch self {
            case .unsupported: return "This video can’t be exported on this device."
            case .failed: return "The clip could not be exported."
            }
        }
    }

    /// Export a sub-clip of the given asset to a temp .mp4 file.
    /// - Returns: A URL to the exported file, or nil on failure.
    static func export(asset: AVURLAsset, from startTime: Double, to endTime: Double) async -> URL? {
        do {
            return try await export(asset: asset, from: startTime, to: endTime, fileType: .mp4)
        } catch {
            print("VideoTrimService export failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Exports `startTime...endTime` of the asset to a temporary file of `fileType` (`.mp4` when the export cannot
    /// write that type). `progress` (0...1) runs on the main actor about ten times a second. Cancelling the calling
    /// task cancels the export and throws `CancellationError`.
    static func export(
        asset: AVURLAsset,
        from startTime: Double,
        to endTime: Double,
        fileType: AVFileType,
        progress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard let created = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.unsupported
        }
        let box = ExportSessionBox(created)
        let session = box.session
        let type = session.supportedFileTypes.contains(fileType) ? fileType : .mp4
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension(for: type))

        session.outputURL = outputURL
        session.outputFileType = type
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end:   CMTime(seconds: endTime,   preferredTimescale: 600)
        )

        let monitor = progress.map { report in
            Task { @MainActor in
                while !Task.isCancelled {
                    report(Double(box.session.progress))
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
        // AVAssetExportSession.export() async — iOS 16+, does not throw
        await withTaskCancellationHandler {
            await box.session.export()
        } onCancel: {
            box.session.cancelExport()
        }
        monitor?.cancel()

        switch session.status {
        case .completed:
            return outputURL
        case .cancelled:
            try? FileManager.default.removeItem(at: outputURL)
            throw CancellationError()
        default:
            try? FileManager.default.removeItem(at: outputURL)
            throw session.error ?? ExportError.failed
        }
    }

    /// The file type an export of `url` keeps: the source's own container where AVFoundation writes it.
    static func fileType(matching url: URL) -> AVFileType {
        switch url.pathExtension.lowercased() {
        case "mov", "qt": return .mov
        case "m4v": return .m4v
        default: return .mp4
        }
    }

    private static func fileExtension(for type: AVFileType) -> String {
        switch type {
        case .mov: return "mov"
        case .m4v: return "m4v"
        default: return "mp4"
        }
    }

    /// Generate a thumbnail for the asset at the given time (seconds).
    #if os(iOS)
    static func thumbnail(asset: AVURLAsset, at time: Double) async -> UIImage? {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await gen.image(at: cmTime)
            return UIImage(cgImage: cgImage)
        } catch {
            print("VideoTrimService thumbnail error: \(error)")
            return nil
        }
    }
    #elseif os(macOS)
    static func thumbnail(asset: AVURLAsset, at time: Double) async -> NSImage? {
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await gen.image(at: cmTime)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("VideoTrimService thumbnail error: \(error)")
            return nil
        }
    }
    #endif
}

/// Lets the progress poll and the cancellation handler reach the session the export awaits.
private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
