import XCTest
import ZIPFoundation
import TimeMasterCore
@testable import TimeMaster

final class ExerciseLibraryBackupTests: XCTestCase {
    func testNestedPagesAndBinaryAssetsSurviveZIPRestoreWithoutReplacingLocalEdits() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let source = DatabaseManager(fs: FileSystemHelper(dataRoot: temporary.appendingPathComponent("source")))
        try source.bootstrapIfNeeded()
        let parent = ExercisePageManifest(title: "Training")
        try source.createPage(manifest: parent)
        let exercise = ExercisePageManifest(title: "Push-up", pageKind: .leaf, markdownBody: "Keep the body straight.", duration: 45, parentID: parent.id)
        try source.createPage(manifest: exercise, parentID: parent.id)
        let second = ExercisePageManifest(title: "Squat", pageKind: .leaf, duration: 30, parentID: parent.id)
        try source.createPage(manifest: second, parentID: parent.id)
        let bytes = Data((0..<8192).map { UInt8($0 % 251) })
        let video = temporary.appendingPathComponent("exercise.mp4")
        try bytes.write(to: video)
        let filename = try source.uploadMediaToPage(pageID: exercise.id, sourceURL: video)
        let cover = temporary.appendingPathComponent("cover.jpg")
        try Data("Library cover".utf8).write(to: cover)
        let coverFilename = try source.uploadCoverImage(pageID: parent.id, sourceURL: cover)
        let legacy = source.dataRoot.appendingPathComponent("Media/shared.jpg")
        try Data("Referenced legacy image".utf8).write(to: legacy)
        var updated = try source.getPage(id: exercise.id)
        updated.mediaFilenames.append("shared.jpg")
        updated.mediaComments["shared.jpg"] = "Use this reference angle."
        try source.updatePage(id: exercise.id, manifest: updated)
        let zip = temporary.appendingPathComponent("library.zip")
        try makeArchive(at: zip, source: source)
        let extracted = temporary.appendingPathComponent("extracted")
        try FileManager.default.unzipItem(at: zip, to: extracted)
        let restored = DatabaseManager(fs: FileSystemHelper(dataRoot: temporary.appendingPathComponent("restored")))
        try restored.bootstrapIfNeeded()
        let existingImage = Data("Keep my existing image".utf8)
        try existingImage.write(to: restored.dataRoot.appendingPathComponent("Media/shared.jpg"))
        let result = try ExerciseLibraryBackup.restore(from: extracted, database: restored)
        XCTAssertEqual(result.pages, 3)
        XCTAssertEqual(try restored.getPage(id: exercise.id).parentID, parent.id)
        XCTAssertEqual(try restored.getPage(id: exercise.id).markdownBody, "Keep the body straight.")
        XCTAssertEqual(try Data(contentsOf: restored.pageMediaURL(pageID: exercise.id, filename: filename)), bytes)
        let restoredPage = try restored.getPage(id: exercise.id)
        let restoredLegacy = try XCTUnwrap(restoredPage.mediaFilenames.first { $0 != filename })
        XCTAssertNotEqual(restoredLegacy, "shared.jpg")
        XCTAssertEqual(try Data(contentsOf: restored.dataRoot.appendingPathComponent("Media/" + restoredLegacy)), Data("Referenced legacy image".utf8))
        XCTAssertEqual(restoredPage.mediaComments[restoredLegacy], "Use this reference angle.")
        XCTAssertEqual(try Data(contentsOf: restored.dataRoot.appendingPathComponent("Media/shared.jpg")), existingImage)
        XCTAssertEqual(try Data(contentsOf: restored.pageCoverURL(pageID: parent.id, filename: coverFilename)), Data("Library cover".utf8))
        let pageFolder = try restored.pageMediaURL(pageID: exercise.id, filename: filename)
            .deletingLastPathComponent().deletingLastPathComponent()
        let displayed = ExercisePage(from: restoredPage, baseURL: pageFolder, legacyMediaDirectory: restored.dataRoot.appendingPathComponent("Media", isDirectory: true))
        let displayedLegacy = try XCTUnwrap(displayed.mediaURLs.first { $0.lastPathComponent == restoredLegacy })
        XCTAssertEqual(try Data(contentsOf: displayedLegacy), Data("Referenced legacy image".utf8))
        var local = try restored.getPage(id: exercise.id)
        local.title = "My newer local name"
        try restored.updatePage(id: exercise.id, manifest: local)
        let repeated = try ExerciseLibraryBackup.restore(from: extracted, database: restored)
        XCTAssertEqual(repeated.pages, 0)
        XCTAssertEqual(repeated.duplicates, 3)
        XCTAssertEqual(repeated.media, 0)
        XCTAssertEqual(try restored.getPage(id: exercise.id).title, "My newer local name")
        XCTAssertEqual(try restored.getPage(id: parent.id).childIDs, [exercise.id, second.id])
    }

    func testZIPTraversalIsRejectedBeforeExtraction() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let archive = Archive(url: temporary.appendingPathComponent("unsafe.zip"), accessMode: .create) else { return XCTFail("Could not create fixture archive") }
        let data = Data("must not escape".utf8)
        try archive.addEntry(with: "database/Exercises Database/../../Config/credentials", type: .file, uncompressedSize: UInt32(data.count), provider: { position, count in
            data.subdata(in: Int(position)..<(Int(position) + count))
        })
        XCTAssertThrowsError(try ExerciseLibraryBackup.validate(archive))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("Config/credentials").path))
    }

    func testExerciseSymlinkCannotExportFilesOutsideTheLibrary() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let source = DatabaseManager(fs: FileSystemHelper(dataRoot: temporary.appendingPathComponent("source")))
        try source.bootstrapIfNeeded()
        let page = ExercisePageManifest(title: "Local exercise")
        try source.createPage(manifest: page)
        let privateFile = temporary.appendingPathComponent("private-key")
        try Data("Not exercise data".utf8).write(to: privateFile)
        let link = source.exercisesDatabaseURL.appendingPathComponent(page.id + "/linked-key")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: privateFile)
        guard let archive = Archive(url: temporary.appendingPathComponent("blocked.zip"), accessMode: .create) else { return XCTFail("Could not create fixture archive") }
        XCTAssertThrowsError(try ExerciseLibraryBackup.add(to: archive, database: source))
        XCTAssertNil(archive["database/Exercises Database/" + page.id + "/linked-key"])
        XCTAssertEqual(try Data(contentsOf: privateFile), Data("Not exercise data".utf8))
    }

    private func makeArchive(at url: URL, source: DatabaseManager) throws {
        guard let archive = Archive(url: url, accessMode: .create) else { throw BackupError.archiveCreationFailed }
        try ExerciseLibraryBackup.add(to: archive, database: source)
        try ExerciseLibraryBackup.validate(archive)
    }
}
