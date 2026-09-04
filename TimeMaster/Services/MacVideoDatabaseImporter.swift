#if os(macOS)
import AppKit
import AVFoundation
import Foundation
import TimeMasterCore

/// Renders one tray item and persists it to a leaf page.
enum MacVideoDatabaseImporter {
    enum Target {
        case createLeaf(parentID: String)
        case attachToLeaf(pageID: String, originalManifest: ExercisePageManifest)
    }

    enum ImportError: LocalizedError {
        case noMedia
        case stillCaptureFailed
        case clipExportFailed
        case invalidTarget(String)
        case mediaLimitExceeded
        case databaseWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .noMedia:
                return "Add a still or clip before saving."
            case .stillCaptureFailed:
                return "TimeMaster could not capture the selected still."
            case .clipExportFailed:
                return "TimeMaster could not export the selected clip."
            case .invalidTarget(let detail):
                return detail
            case .mediaLimitExceeded:
                return "This page cannot contain more than 20 media items."
            case .databaseWriteFailed(let detail):
                return detail.isEmpty ? "TimeMaster could not save this media item." : detail
            }
        }
    }

    static func save(
        draft: MacVideoDraft,
        asset: AVURLAsset,
        manifest: ExercisePageManifest,
        target: Target,
        additionalMediaURLs: [URL],
        database: DatabaseManager = .shared,
        reloadDatabase: @escaping @MainActor () -> Void
    ) async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster Video Export-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            let renderedURLs = try await render(
                draft: draft,
                asset: asset,
                temporaryDirectory: temporaryDirectory
            )
            let extraURLs = try validatedAdditionalMediaURLs(additionalMediaURLs)

            try await Task.detached(priority: .userInitiated) {
                try persist(
                    renderedURLs: renderedURLs,
                    additionalMediaURLs: extraURLs,
                    manifest: manifest,
                    target: target,
                    database: database
                )
            }.value
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.databaseWriteFailed(error.localizedDescription)
        }

        await reloadDatabase()
    }

    private static func render(
        draft: MacVideoDraft,
        asset: AVURLAsset,
        temporaryDirectory: URL
    ) async throws -> [URL] {
        var renderedURLs: [URL] = []

        for media in draft.mediaItems {
            switch media.kind {
            case .screenshot:
                renderedURLs.append(
                    try await renderStill(
                        from: asset,
                        at: media.startTime,
                        temporaryDirectory: temporaryDirectory
                    )
                )

            case .clip:
                guard let endTime = media.endTime,
                      endTime - media.startTime >= 0.25 else {
                    throw ImportError.clipExportFailed
                }
                guard let exportedURL = await VideoTrimService.export(
                    asset: asset,
                    from: media.startTime,
                    to: endTime
                ) else {
                    throw ImportError.clipExportFailed
                }

                let destinationURL = temporaryDirectory
                    .appendingPathComponent("clip-\(media.id.uuidString).mp4")
                do {
                    try FileManager.default.moveItem(at: exportedURL, to: destinationURL)
                } catch {
                    throw ImportError.clipExportFailed
                }
                renderedURLs.append(destinationURL)
            }
        }

        return renderedURLs
    }

    private static func validatedAdditionalMediaURLs(_ urls: [URL]) throws -> [URL] {
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory
            ), !isDirectory.boolValue else {
                throw ImportError.databaseWriteFailed(
                    "An additional media attachment is no longer available."
                )
            }
        }
        return urls
    }

    private static func persist(
        renderedURLs: [URL],
        additionalMediaURLs: [URL],
        manifest: ExercisePageManifest,
        target: Target,
        database: DatabaseManager
    ) throws {
        switch target {
        case .createLeaf(let parentID):
            let parent = try database.getPage(id: parentID)
            guard parent.pageKind == .container else {
                throw ImportError.invalidTarget(
                    "Choose a container when creating a new exercise page."
                )
            }
            guard renderedURLs.count + additionalMediaURLs.count <= 20 else {
                throw ImportError.mediaLimitExceeded
            }

            var newManifest = manifest
            newManifest.pageKind = .leaf
            newManifest.parentID = parentID
            newManifest.coverImageFilename = nil
            newManifest.workoutType = nil
            newManifest.mediaFilenames = []

            try database.createPage(manifest: newManifest, parentID: parentID)
            do {
                try upload(
                    renderedURLs: renderedURLs,
                    additionalMediaURLs: additionalMediaURLs,
                    to: newManifest.id,
                    database: database
                )
            } catch {
                do {
                    try database.deletePage(id: newManifest.id)
                } catch {
                    throw ImportError.databaseWriteFailed(
                        "The new page could not be saved, and cleanup also failed: \(error.localizedDescription)"
                    )
                }
                throw error
            }


        case .attachToLeaf(let pageID, let originalManifest):
            guard originalManifest.id == pageID,
                  originalManifest.pageKind == .leaf else {
                throw ImportError.invalidTarget(
                    "Media can only be attached to an existing exercise page."
                )
            }

            let persistedManifest = try database.getPage(id: pageID)
            guard persistedManifest.pageKind == .leaf else {
                throw ImportError.invalidTarget(
                    "Media can only be attached to an existing exercise page."
                )
            }
            guard persistedManifest.mediaFilenames == originalManifest.mediaFilenames else {
                throw ImportError.invalidTarget(
                    "This exercise changed while it was open. Reopen the save form and try again."
                )
            }
            guard persistedManifest.mediaFilenames.count + renderedURLs.count + additionalMediaURLs.count <= 20 else {
                throw ImportError.mediaLimitExceeded
            }

            var editedManifest = manifest
            editedManifest.id = pageID
            editedManifest.pageKind = .leaf
            editedManifest.parentID = originalManifest.parentID
            editedManifest.coverImageFilename = nil
            editedManifest.workoutType = nil
            editedManifest.mediaFilenames = originalManifest.mediaFilenames

            try database.updatePage(
                id: pageID,
                manifest: editedManifest,
                newParentID: originalManifest.parentID
            )

            var uploadedFilenames: [String] = []
            do {
                for renderedURL in renderedURLs {
                    let filename = try database.uploadMediaToPage(
                        pageID: pageID,
                        sourceURL: renderedURL
                    )
                    uploadedFilenames.append(filename)
                }

                for url in additionalMediaURLs {
                    let filename = try database.uploadMediaToPage(
                        pageID: pageID,
                        sourceURL: url
                    )
                    uploadedFilenames.append(filename)
                }
            } catch {
                let cleanupError = rollback(
                    pageID: pageID,
                    originalManifest: originalManifest,
                    uploadedFilenames: uploadedFilenames,
                    database: database
                )
                if let cleanupError {
                    throw ImportError.databaseWriteFailed(
                        "\(error.localizedDescription) Cleanup failed: \(cleanupError)"
                    )
                }
                throw error
            }
        }
    }

    private static func upload(
        renderedURLs: [URL],
        additionalMediaURLs: [URL],
        to pageID: String,
        database: DatabaseManager
    ) throws {
        for renderedURL in renderedURLs {
            try database.uploadMediaToPage(pageID: pageID, sourceURL: renderedURL)
        }
        for url in additionalMediaURLs {
            try database.uploadMediaToPage(pageID: pageID, sourceURL: url)
        }
    }

    private static func rollback(
        pageID: String,
        originalManifest: ExercisePageManifest,
        uploadedFilenames: [String],
        database: DatabaseManager
    ) -> String? {
        var cleanupErrors: [String] = []
        for filename in uploadedFilenames {
            do {
                try database.removeMediaFromPage(pageID: pageID, filename: filename)
            } catch {
                cleanupErrors.append(error.localizedDescription)
            }
        }

        do {
            try database.updatePage(
                id: pageID,
                manifest: originalManifest,
                newParentID: originalManifest.parentID
            )
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        return cleanupErrors.isEmpty ? nil : cleanupErrors.joined(separator: " ")
    }

    private static func renderStill(
        from asset: AVURLAsset,
        at time: Double,
        temporaryDirectory: URL
    ) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let captureTime = CMTime(seconds: time, preferredTimescale: 600)
        let cgImage: CGImage
        do {
            (cgImage, _) = try await generator.image(at: captureTime)
        } catch {
            throw ImportError.stillCaptureFailed
        }
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
        do {
            try jpegData.write(to: destinationURL, options: .atomic)
        } catch {
            throw ImportError.stillCaptureFailed
        }
        return destinationURL
    }
}
#endif

#if os(iOS)
import AVFoundation
import Foundation
import TimeMasterCore
import UIKit

enum VideoEditorDatabaseImporter {
    enum Target {
        case createLeaf(parentID: String)
        case attachToLeaf(pageID: String, originalManifest: ExercisePageManifest)
    }

    enum ImportError: LocalizedError {
        case noMedia
        case stillCaptureFailed
        case clipExportFailed
        case invalidTarget(String)
        case mediaLimitExceeded
        case databaseWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .noMedia:
                return "Add a still or clip before saving."
            case .stillCaptureFailed:
                return "TimeMaster could not prepare the selected still."
            case .clipExportFailed:
                return "TimeMaster could not export the selected clip."
            case .invalidTarget(let detail):
                return detail
            case .mediaLimitExceeded:
                return "This page cannot contain more than 20 media items."
            case .databaseWriteFailed(let detail):
                return detail.isEmpty ? "TimeMaster could not save this media item." : detail
            }
        }
    }

    static func save(
        item: TrayItem,
        asset: AVURLAsset,
        manifest: ExercisePageManifest,
        target: Target,
        database: DatabaseManager = .shared,
        reloadDatabase: @escaping @MainActor () -> Void
    ) async throws {
        guard !item.mediaList.isEmpty else {
            throw ImportError.noMedia
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeMaster Video Export-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            let renderedURLs = try await render(
                mediaList: item.mediaList,
                asset: asset,
                temporaryDirectory: temporaryDirectory
            )

            try await Task.detached(priority: .userInitiated) {
                try persist(
                    renderedURLs: renderedURLs,
                    manifest: manifest,
                    target: target,
                    database: database
                )
            }.value
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.databaseWriteFailed(error.localizedDescription)
        }

        await reloadDatabase()
    }

    private static func render(
        mediaList: [TrayMedia],
        asset: AVURLAsset,
        temporaryDirectory: URL
    ) async throws -> [URL] {
        var renderedURLs: [URL] = []

        for (index, media) in mediaList.enumerated() {
            switch media {
            case .screenshot(let image):
                let destinationURL: URL
                if let data = image.jpegData(compressionQuality: 0.92) {
                    destinationURL = temporaryDirectory
                        .appendingPathComponent("still-\(index)-\(UUID().uuidString).jpg")
                    try data.write(to: destinationURL, options: .atomic)
                } else if let data = image.pngData() {
                    destinationURL = temporaryDirectory
                        .appendingPathComponent("still-\(index)-\(UUID().uuidString).png")
                    try data.write(to: destinationURL, options: .atomic)
                } else {
                    throw ImportError.stillCaptureFailed
                }
                renderedURLs.append(destinationURL)

            case .clip(let startTime, let endTime, _):
                guard endTime - startTime >= 0.25 else {
                    throw ImportError.clipExportFailed
                }
                guard let exportedURL = await VideoTrimService.export(
                    asset: asset,
                    from: startTime,
                    to: endTime
                ) else {
                    throw ImportError.clipExportFailed
                }

                let destinationURL = temporaryDirectory
                    .appendingPathComponent("clip-\(index)-\(UUID().uuidString).mp4")
                do {
                    try FileManager.default.moveItem(at: exportedURL, to: destinationURL)
                } catch {
                    throw ImportError.clipExportFailed
                }
                renderedURLs.append(destinationURL)
            }
        }

        return renderedURLs
    }

    private static func persist(
        renderedURLs: [URL],
        manifest: ExercisePageManifest,
        target: Target,
        database: DatabaseManager
    ) throws {
        guard !renderedURLs.isEmpty else {
            throw ImportError.noMedia
        }

        switch target {
        case .createLeaf(let parentID):
            let parent = try database.getPage(id: parentID)
            guard parent.pageKind == .container else {
                throw ImportError.invalidTarget(
                    "Choose a container when creating a new exercise page."
                )
            }
            guard renderedURLs.count <= 20 else {
                throw ImportError.mediaLimitExceeded
            }

            var newManifest = manifest
            newManifest.pageKind = .leaf
            newManifest.parentID = parentID
            newManifest.coverImageFilename = nil
            newManifest.workoutType = nil
            newManifest.mediaFilenames = []

            try database.createPage(manifest: newManifest, parentID: parentID)
            do {
                var uploadedFilenames: [String] = []
                try upload(
                    renderedURLs: renderedURLs,
                    to: newManifest.id,
                    database: database,
                    uploadedFilenames: &uploadedFilenames
                )
            } catch {
                do {
                    try database.deletePage(id: newManifest.id)
                } catch {
                    throw ImportError.databaseWriteFailed(
                        "The new page could not be saved, and cleanup also failed: \(error.localizedDescription)"
                    )
                }
                throw error
            }

        case .attachToLeaf(let pageID, let originalManifest):
            guard originalManifest.id == pageID,
                  originalManifest.pageKind == .leaf else {
                throw ImportError.invalidTarget(
                    "Media can only be attached to an existing exercise page."
                )
            }

            let persistedManifest = try database.getPage(id: pageID)
            guard persistedManifest.pageKind == .leaf else {
                throw ImportError.invalidTarget(
                    "Media can only be attached to an existing exercise page."
                )
            }
            guard persistedManifest.mediaFilenames == originalManifest.mediaFilenames else {
                throw ImportError.invalidTarget(
                    "This exercise changed while it was open. Reopen the save form and try again."
                )
            }
            guard persistedManifest.mediaFilenames.count + renderedURLs.count <= 20 else {
                throw ImportError.mediaLimitExceeded
            }

            var editedManifest = manifest
            editedManifest.id = pageID
            editedManifest.pageKind = .leaf
            editedManifest.parentID = originalManifest.parentID
            editedManifest.coverImageFilename = nil
            editedManifest.workoutType = nil
            editedManifest.mediaFilenames = originalManifest.mediaFilenames

            try database.updatePage(
                id: pageID,
                manifest: editedManifest,
                newParentID: originalManifest.parentID
            )

            var uploadedFilenames: [String] = []
            do {
                try upload(
                    renderedURLs: renderedURLs,
                    to: pageID,
                    database: database,
                    uploadedFilenames: &uploadedFilenames
                )
            } catch {
                let cleanupError = rollback(
                    pageID: pageID,
                    originalManifest: originalManifest,
                    uploadedFilenames: uploadedFilenames,
                    database: database
                )
                if let cleanupError {
                    throw ImportError.databaseWriteFailed(
                        "\(error.localizedDescription) Cleanup failed: \(cleanupError)"
                    )
                }
                throw error
            }
        }
    }

    private static func upload(
        renderedURLs: [URL],
        to pageID: String,
        database: DatabaseManager,
        uploadedFilenames: inout [String]
    ) throws {
        for renderedURL in renderedURLs {
            let filename = try database.uploadMediaToPage(
                pageID: pageID,
                sourceURL: renderedURL
            )
            uploadedFilenames.append(filename)
        }
    }

    private static func rollback(
        pageID: String,
        originalManifest: ExercisePageManifest,
        uploadedFilenames: [String],
        database: DatabaseManager
    ) -> String? {
        var cleanupErrors: [String] = []
        for filename in uploadedFilenames {
            do {
                try database.removeMediaFromPage(pageID: pageID, filename: filename)
            } catch {
                cleanupErrors.append(error.localizedDescription)
            }
        }

        do {
            try database.updatePage(
                id: pageID,
                manifest: originalManifest,
                newParentID: originalManifest.parentID
            )
        } catch {
            cleanupErrors.append(error.localizedDescription)
        }

        return cleanupErrors.isEmpty ? nil : cleanupErrors.joined(separator: " ")
    }
}
#endif
