#if os(macOS)
import AppKit
import AVFoundation
import Foundation
import TimeMasterCore

/// Converts edited video selections into a V2 exercise page and copies every
/// generated asset into that page's managed `media/` directory.
enum MacVideoDatabaseImporter {
    enum ImportError: LocalizedError {
        case noMedia
        case stillCaptureFailed
        case clipExportFailed
        case databaseWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .noMedia:
                return "Add a still or clip before saving."
            case .stillCaptureFailed:
                return "TimeMaster could not capture one of the selected stills."
            case .clipExportFailed:
                return "TimeMaster could not export one of the selected clips."
            case .databaseWriteFailed(let detail):
                return detail.isEmpty ? "TimeMaster could not save this exercise page." : detail
            }
        }
    }

    static func save(
        asset: AVURLAsset,
        drafts: [MacVideoDraft],
        title: String,
        notes: String,
        parentID: String,
        duration: Int,
        restAfter: Int,
        database: DatabaseManager = .shared,
        reloadDatabase: @escaping @MainActor () -> Void
    ) async throws {
        guard !drafts.isEmpty else { throw ImportError.noMedia }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster Video Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let mediaURLs = try await renderMedia(
            from: drafts,
            asset: asset,
            temporaryDirectory: temporaryDirectory
        )
        let manifest = ExercisePageManifest(
            title: title,
            pageKind: .leaf,
            markdownBody: notes,
            duration: duration,
            restAfter: restAfter,
            sets: 1,
            restBetweenSets: 0,
            parentID: parentID
        )

        do {
            try await Task.detached(priority: .userInitiated) {
                try database.createPage(manifest: manifest, parentID: parentID)

                do {
                    for mediaURL in mediaURLs {
                        try database.uploadMediaToPage(
                            pageID: manifest.id,
                            sourceURL: mediaURL
                        )
                    }
                } catch {
                    try? database.deletePage(id: manifest.id)
                    throw error
                }
            }.value
        } catch {
            throw ImportError.databaseWriteFailed(error.localizedDescription)
        }

        await reloadDatabase()
    }

    private static func renderMedia(
        from drafts: [MacVideoDraft],
        asset: AVURLAsset,
        temporaryDirectory: URL
    ) async throws -> [URL] {
        var mediaURLs: [URL] = []

        for draft in drafts {
            switch draft.kind {
            case .screenshot:
                mediaURLs.append(try await renderStill(
                    from: asset,
                    at: draft.startTime,
                    temporaryDirectory: temporaryDirectory
                ))
            case .clip:
                guard let endTime = draft.endTime,
                      let exportedURL = await VideoTrimService.export(
                        asset: asset,
                        from: draft.startTime,
                        to: endTime
                      ) else {
                    throw ImportError.clipExportFailed
                }

                let destinationURL = temporaryDirectory
                    .appendingPathComponent("clip-\(draft.id.uuidString).mp4")
                try FileManager.default.moveItem(at: exportedURL, to: destinationURL)
                mediaURLs.append(destinationURL)
            }
        }

        return mediaURLs
    }

    private static func renderStill(
        from asset: AVURLAsset,
        at time: Double,
        temporaryDirectory: URL
    ) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let captureTime = CMTime(seconds: time, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: captureTime)
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.92]
              ) else {
            throw ImportError.stillCaptureFailed
        }

        let destinationURL = temporaryDirectory
            .appendingPathComponent("still-\(UUID().uuidString).jpg")
        try jpegData.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
}
#endif
