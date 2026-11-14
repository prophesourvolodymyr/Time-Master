import XCTest
@testable import TimeMasterCore

final class SkillPageToolTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("skillpage-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func failure(_ block: () throws -> Void) -> Error? {
        do { try block(); return nil } catch { return error }
    }

    private func clip(_ name: String) throws -> URL {
        let folder = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(name)
        try Data(repeating: 7, count: 64).write(to: file)
        return file
    }

    func testASkillLandsInAGroupOfItsParentsBoardAndKeepsItsClipsWithComments() throws {
        try call("create_container_page", ["title": "Wrestling"])
        let first = try call("create_skill_page", [
            "title": "Arm Drag", "parent": "Wrestling", "group": "Hand Fighting",
            "markdownBody": "# Arm drag", "linkURLs": ["https://example.com/a"],
            "media": [["path": try clip("a.mp4").path, "comment": "Source: coach A"], ["path": try clip("b.mp4").path]],
        ])
        XCTAssertEqual(first["path"] as? String, "Wrestling/Arm Drag")
        XCTAssertEqual(first["media"] as? Int, 2)
        let second = try call("create_skill_page", ["title": "Snap Down", "parent": "Wrestling", "group": "hand fighting"])
        XCTAssertEqual(second["group"] as? String, "hand fighting")

        let board = try database.getPage(id: try database.getPage(id: first["id"] as! String).parentID!)
        XCTAssertEqual(board.skillBoardSections.count, 1)
        XCTAssertEqual(board.skillBoardSections[0].title, "Hand Fighting")

        let arm = try database.getPage(id: first["id"] as! String)
        XCTAssertEqual(arm.pageType, .skill)
        XCTAssertEqual(arm.skillBoardSectionID, board.skillBoardSections[0].id)
        XCTAssertEqual(arm.mediaFilenames.count, 2)
        XCTAssertEqual(arm.mediaComments[arm.mediaFilenames[0]], "Source: coach A")
        XCTAssertEqual(arm.skillBoardOrder, 0)
        let snap = try database.getPage(id: second["id"] as! String)
        XCTAssertEqual(snap.skillBoardSectionID, board.skillBoardSections[0].id)
        XCTAssertEqual(snap.skillBoardOrder, 1)

        let shown = try call("get_page", ["page": "Wrestling/Arm Drag"])
        XCTAssertEqual(shown["group"] as? String, "Hand Fighting")
        XCTAssertEqual(shown["status"] as? String, "notStarted")
        XCTAssertEqual((shown["media"] as? [[String: Any]])?.first?["comment"] as? String, "Source: coach A")
        let boardShown = try call("get_page", ["page": "Wrestling"])
        XCTAssertEqual((boardShown["groups"] as? [[String: Any]])?.first?["skills"] as? Int, 2)
    }

    func testASkillCanHoldExercisesNotesAndSubSkillsAsSubPages() throws {
        try call("create_container_page", ["title": "Calisthenics"])
        try call("create_skill_page", ["title": "Handstand", "parent": "Calisthenics", "group": "Balance"])
        try call("create_exercise_page", ["title": "Wall Walk", "parent": "Calisthenics/Handstand"])
        try call("create_note_page", ["title": "Handstand Theory", "parent": "Calisthenics/Handstand", "markdownBody": "Stack the joints."])
        try call("create_skill_page", ["title": "Press To Handstand", "parent": "Calisthenics/Handstand", "group": "Advanced"])

        let listing = try call("list_pages", ["parent": "Calisthenics/Handstand"])
        let paths = (listing["pages"] as? [[String: Any]])?.compactMap { $0["path"] as? String } ?? []
        XCTAssertEqual(Set(paths), ["Calisthenics/Handstand/Wall Walk", "Calisthenics/Handstand/Handstand Theory", "Calisthenics/Handstand/Press To Handstand"])

        let shown = try call("get_page", ["page": "Calisthenics/Handstand"])
        XCTAssertEqual((shown["pages"] as? [[String: Any]])?.count, 3)
        XCTAssertEqual((shown["groups"] as? [[String: Any]])?.first?["title"] as? String, "Advanced")
        XCTAssertEqual(try call("get_page", ["page": "Calisthenics"])["pages"] != nil, true)
        XCTAssertEqual((failure { _ = try self.call("create_skill_page", ["title": "Nope", "parent": "Calisthenics/Handstand/Wall Walk"]) } as? AgentToolError)?.code, "invalid_parent")
        XCTAssertEqual((failure { _ = try self.call("create_skill_page", ["title": "Loose", "group": "Orphans"]) } as? AgentToolError)?.code, "invalid_argument")
    }

    func testSkillsRefuseDuplicatesAndPreviewAndReuse() throws {
        try call("create_container_page", ["title": "Boxing"])
        try call("create_skill_page", ["title": "Jab", "parent": "Boxing", "group": "Punches"])
        XCTAssertEqual((failure { _ = try self.call("create_skill_page", ["title": "jab", "parent": "Boxing"]) } as? AgentToolError)?.code, "already_exists")
        XCTAssertEqual(try call("create_skill_page", ["title": "Jab", "parent": "Boxing", "ifExists": "reuse"])["reused"] as? Bool, true)
        let preview = try call("create_skill_page", ["title": "Cross", "parent": "Boxing", "group": "New Group"], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(try database.getPage(id: try AgentPageIndex(database: database).resolve("Boxing").id).skillBoardSections.count, 1)
        XCTAssertEqual(try AgentPageIndex(database: database).pages.count, 2)
    }

    func testAGroupTakesNotesOnceAndCanBeReused() throws {
        try call("create_container_page", ["title": "Boxing"])
        let made = try call("create_skill_group", ["parent": "Boxing", "title": "Footwork", "markdownBody": "Move first.", "color": "ff6a00"])
        XCTAssertEqual(made["group"] as? String, "Footwork")
        let board = try database.getPage(id: try AgentPageIndex(database: database).resolve("Boxing").id)
        XCTAssertEqual(board.skillBoardSections[0].markdownBody, "Move first.")
        XCTAssertEqual(board.skillBoardSections[0].colorHex, "FF6A00")
        XCTAssertEqual((failure { _ = try self.call("create_skill_group", ["parent": "Boxing", "title": "footwork"]) } as? AgentToolError)?.code, "already_exists")
        XCTAssertEqual(try call("create_skill_group", ["parent": "Boxing", "title": "footwork", "ifExists": "reuse"])["reused"] as? Bool, true)
        try call("create_skill_page", ["title": "L Step", "parent": "Boxing", "group": "Footwork"])
        XCTAssertEqual(try database.getPage(id: board.id).skillBoardSections.count, 1)
    }

    func testSkillPagesHoldMoreClipsThanOtherPagesAndSearchFindsClipComments() throws {
        try call("create_container_page", ["title": "Wrestling"])
        let id = try call("create_skill_page", ["title": "Single Leg", "parent": "Wrestling"])["id"] as! String
        for index in 0..<21 {
            try call("attach_media", ["page": id, "path": try clip("s\(index).mp4").path, "comment": index == 20 ? "finish with a high crotch" : "clip \(index)"])
        }
        XCTAssertEqual(try database.getPage(id: id).mediaFilenames.count, 21)
        let exercise = try call("create_exercise_page", ["title": "Shot Reps", "parent": "Wrestling"])["id"] as! String
        for index in 0..<20 { try call("attach_media", ["page": exercise, "path": try clip("e\(index).mp4").path]) }
        XCTAssertEqual((failure { _ = try self.call("attach_media", ["page": exercise, "path": try self.clip("e20.mp4").path]) } as? AgentToolError)?.code, "media_limit")

        let found = try call("search_pages", ["query": "crotch finish"])
        XCTAssertEqual((found["results"] as? [[String: Any]])?.first?["path"] as? String, "Wrestling/Single Leg")
    }
}
