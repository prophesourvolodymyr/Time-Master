import AVFoundation
import UIKit

// MARK: - VideoTrimService

/// Stateless service for exporting video clips and generating thumbnails.
struct VideoTrimService {

    /// Export a sub-clip of the given asset to a temp .mp4 file.
    /// - Returns: A URL to the exported file, or nil on failure.
    static func export(asset: AVURLAsset, from startTime: Double, to endTime: Double) async -> URL? {
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else { return nil }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end:   CMTime(seconds: endTime,   preferredTimescale: 600)
        )

        // AVAssetExportSession.export() async — iOS 16+, does not throw
        await session.export()

        guard session.status == .completed else {
            print("VideoTrimService export failed: \(session.error?.localizedDescription ?? "unknown")")
            return nil
        }
        return outputURL
    }

    /// Generate a thumbnail for the asset at the given time (seconds).
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
}
