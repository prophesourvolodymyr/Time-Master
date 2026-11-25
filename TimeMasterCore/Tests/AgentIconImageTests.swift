import XCTest
@testable import TimeMasterCore

final class AgentIconImageTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var dipsID = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("icon-image-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Calisthenics", "workoutType": "Strength"])["id"] as! String
        dipsID = try call("create_exercise_page", ["title": "Dips", "parent": folder, "duration": 40])["id"] as! String
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func picture(_ name: String = "dips.png") throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]).write(to: url)
        return url
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    func testUpdatePageOffersTheIconImageOptionOnlyToTheCli() throws {
        let tool = try XCTUnwrap(AgentToolRegistry.tool(named: "update_page"))
        XCTAssertEqual(tool.properties["iconImage"]?["type"] as? String, "string")
        XCTAssertEqual(tool.properties["iconImage"]?["x-path"] as? Bool, true)
        XCTAssertEqual(tool.properties["iconImage"]?["x-external"] as? Bool, true)
    }

    func testCopiesTheFileIntoThePageAndUsesItAsTheIconPicture() throws {
        let source = try picture()
        let value = try call("update_page", ["page": "Calisthenics/Dips", "iconImage": source.path])
        XCTAssertEqual(value["changed"] as? [String], ["iconImage"])
        let page = try database.getPage(id: dipsID)
        let filename = try XCTUnwrap(page.iconImage)
        XCTAssertEqual(page.mediaFilenames, [filename])
        XCTAssertTrue(filename.hasSuffix(".png"))
        let stored = try database.resolvePageFolder(id: dipsID).appendingPathComponent("media").appendingPathComponent(filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testKeepsExistingMediaAndOtherFieldsPassedWithIt() throws {
        let first = try picture("one.png")
        try call("attach_media", ["page": "Calisthenics/Dips", "path": first.path])
        let second = try picture("two.png")
        try call("update_page", ["page": "Calisthenics/Dips", "iconImage": second.path, "duration": 55])
        let page = try database.getPage(id: dipsID)
        XCTAssertEqual(page.mediaFilenames.count, 2)
        XCTAssertEqual(page.iconImage, page.mediaFilenames.last)
        XCTAssertEqual(page.duration, 55)
    }

    func testEmptyTextClearsThePictureAndKeepsTheFile() throws {
        try call("update_page", ["page": "Calisthenics/Dips", "iconImage": try picture().path])
        let before = try database.getPage(id: dipsID)
        try call("update_page", ["page": "Calisthenics/Dips", "iconImage": ""])
        let page = try database.getPage(id: dipsID)
        XCTAssertNil(page.iconImage)
        XCTAssertEqual(page.mediaFilenames, before.mediaFilenames)
    }

    func testDryRunChangesNothing() throws {
        let value = try call("update_page", ["page": "Calisthenics/Dips", "iconImage": try picture().path], dryRun: true)
        XCTAssertEqual(value["wouldChange"] as? [String], ["iconImage"])
        let page = try database.getPage(id: dipsID)
        XCTAssertNil(page.iconImage)
        XCTAssertTrue(page.mediaFilenames.isEmpty)
    }

    func testRevertingPutsTheEarlierIconBackAndRemovesTheCopy() throws {
        try call("update_page", ["page": "Calisthenics/Dips", "iconImage": try picture("first.png").path])
        let first = try XCTUnwrap(try database.getPage(id: dipsID).iconImage)
        let output = try toolbox.call("update_page", arguments: ["page": "Calisthenics/Dips", "iconImage": try picture("second.png").path], dryRun: false)
        XCTAssertNotEqual(try database.getPage(id: dipsID).iconImage, first)
        toolbox.revert(output.effects)
        let page = try database.getPage(id: dipsID)
        XCTAssertEqual(page.iconImage, first)
        XCTAssertEqual(page.mediaFilenames, [first])
    }

    func testRefusesMissingFilesNonImagesAndNotes() throws {
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": "Calisthenics/Dips", "iconImage": "/nowhere/missing.png"]) }?.code, "file_not_found")
        let clip = root.appendingPathComponent("clip.mp4")
        try Data([0, 0, 0, 1]).write(to: clip)
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": "Calisthenics/Dips", "iconImage": clip.path]) }?.code, "unsupported_media")
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": "Calisthenics/Dips", "iconImage": "relative.png"]) }?.code, "invalid_path")
        try call("create_note_page", ["title": "Plan"])
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": "Plan", "iconImage": try self.picture().path]) }?.code, "invalid_page")
        XCTAssertNil(try database.getPage(id: dipsID).iconImage)
    }

    func testBatchSetsManyIconsAndRollsEveryOneBackWhenALaterStepFails() throws {
        let source = try picture()
        let ok = try call("batch", ["operations": [
            ["tool": "update_page", "arguments": ["page": "Calisthenics/Dips", "iconImage": source.path]],
        ]])
        XCTAssertEqual((ok["results"] as! [Any]).count, 1)
        XCTAssertNotNil(try database.getPage(id: dipsID).iconImage)

        try call("update_page", ["page": "Calisthenics/Dips", "iconImage": ""])
        let before = try database.getPage(id: dipsID).mediaFilenames
        let error = failure {
            _ = try self.call("batch", ["operations": [
                ["tool": "update_page", "arguments": ["page": "Calisthenics/Dips", "iconImage": source.path]],
                ["tool": "update_page", "arguments": ["page": "Calisthenics/Dips", "iconImage": "/nowhere/missing.png"]],
            ]])
        }
        XCTAssertEqual(error?.code, "batch_failed")
        let page = try database.getPage(id: dipsID)
        XCTAssertNil(page.iconImage)
        XCTAssertEqual(page.mediaFilenames, before)
    }
}
