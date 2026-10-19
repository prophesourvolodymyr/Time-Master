import XCTest
@testable import TimeMasterCore

final class MediaCommentTests: XCTestCase {
    private var directory: URL!
    private var fileSystem: FileSystemHelper!
    private var database: DatabaseManager!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fileSystem = FileSystemHelper(dataRoot: directory)
        database = DatabaseManager(fs: fileSystem)
        try database.bootstrapIfNeeded()
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testPhotoAndVideoCommentsFollowFilesAfterReorderingAndReloading() throws {
        let page = ExercisePageManifest(title: "Technique", pageKind: .leaf, mediaFilenames: ["photo.jpg", "video.mp4"], duration: 30)
        try database.createPage(manifest: page)
        try database.updateMediaComment(pageID: page.id, filename: "photo.jpg", comment: "**Keep upright**\n[Guide](https://example.com)")
        try database.updateMediaComment(pageID: page.id, filename: "video.mp4", comment: "*Slow descent* and `pause`")
        try database.reorderPageMedia(pageID: page.id, filenames: ["video.mp4", "photo.jpg"])

        let reloaded = DatabaseManager(fs: FileSystemHelper(dataRoot: directory))
        let saved = try reloaded.getPage(id: page.id)
        XCTAssertEqual(saved.mediaFilenames, ["video.mp4", "photo.jpg"])
        XCTAssertEqual(saved.mediaComments["photo.jpg"], "**Keep upright**\n[Guide](https://example.com)")
        XCTAssertEqual(saved.mediaComments["video.mp4"], "*Slow descent* and `pause`")

        try reloaded.updateMediaComment(pageID: page.id, filename: "photo.jpg", comment: "Updated photo cue")
        let edited = try reloaded.getPage(id: page.id)
        XCTAssertEqual(edited.mediaComments["photo.jpg"], "Updated photo cue")
        XCTAssertEqual(edited.mediaComments["video.mp4"], "*Slow descent* and `pause`")
    }

    func testRemovingMediaAndClearingCommentsCannotModifyOtherAttachments() throws {
        let page = ExercisePageManifest(title: "Form", pageKind: .leaf, mediaFilenames: ["photo.jpg", "video.mp4"], duration: 30)
        try database.createPage(manifest: page)
        try database.updateMediaComment(pageID: page.id, filename: "photo.jpg", comment: "Photo cue")
        try database.updateMediaComment(pageID: page.id, filename: "video.mp4", comment: "Video cue")
        try database.removeMediaFromPage(pageID: page.id, filename: "photo.jpg")
        XCTAssertThrowsError(try database.updateMediaComment(pageID: page.id, filename: "photo.jpg", comment: "Stale edit"))
        let removed = try database.getPage(id: page.id)
        XCTAssertNil(removed.mediaComments["photo.jpg"])
        XCTAssertEqual(removed.mediaComments["video.mp4"], "Video cue")

        try database.updateMediaComment(pageID: page.id, filename: "video.mp4", comment: " \n\t ")
        let cleared = try database.getPage(id: page.id)
        XCTAssertNil(cleared.mediaComments["video.mp4"])
        XCTAssertEqual(cleared.mediaFilenames, ["video.mp4"])
    }

    func testOldPageManifestWithoutCommentsRemainsReadable() throws {
        let oldManifest = """
        {"id":"legacy-page","title":"Existing exercise","mediaFilenames":["photo.jpg"],"markdownBody":"Keep this note"}
        """
        let decoded = try JSONDecoder().decode(ExercisePageManifest.self, from: Data(oldManifest.utf8))
        XCTAssertEqual(decoded.mediaFilenames, ["photo.jpg"])
        XCTAssertEqual(decoded.markdownBody, "Keep this note")
        XCTAssertEqual(decoded.mediaComments, [:])
    }
}
