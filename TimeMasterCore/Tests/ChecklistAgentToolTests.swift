import XCTest
@testable import TimeMasterCore

final class ChecklistAgentToolTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var skillID: String!
    var workoutID: String!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("checklist-agent-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let wrestling = ExercisePageManifest(title: "Wrestling")
        try database.createPage(manifest: wrestling)
        let single = ExercisePageManifest(title: "Single leg", pageType: .skill)
        try database.createPage(manifest: single, parentID: wrestling.id)
        skillID = single.id
        let drill = ExercisePageManifest(title: "Shot drill", pageKind: .leaf, duration: 30)
        try database.createPage(manifest: drill, parentID: wrestling.id)
        workoutID = UUID().uuidString
        try database.createWorkout(id: workoutID, manifest: WorkoutManifest(id: workoutID, name: "Single-leg bundle", sections: [WorkoutSectionManifest(exerciseID: drill.id, name: "Shot drill", duration: 30)]))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    private func picture(_ name: String) throws -> String {
        let url = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try Data(repeating: 7, count: 64).write(to: file)
        return file.path
    }

    func testTheCatalogStaysSmallAndCoachReady() {
        let names = AgentToolRegistry.milestoneTools.map(\.name)
        XCTAssertLessThanOrEqual(names.count, 8)
        XCTAssertTrue(AgentToolRegistry.milestoneTools.allSatisfy(\.coach))
        XCTAssertEqual(AgentToolRegistry.tool(named: "remove_todo")?.risk, .delete)
        XCTAssertEqual(AgentToolRegistry.tool(named: "list_todos")?.risk, .read)
        let coachProperties = AgentToolRegistry.tool(named: "add_todo")?.coachSchema["properties"] as? [String: Any]
        XCTAssertNotNil(coachProperties?["workouts"])
        XCTAssertNil(coachProperties?["coverPath"], "local paths stay off the coach's schema")
        XCTAssertTrue(OnDeviceToolRouting.tools(for: "Add a to-do to my single leg").contains("add_todo"))
        XCTAssertTrue(OnDeviceToolRouting.tools(for: "what milestones are left?").contains("todo_overview"))
        XCTAssertEqual(AgentApproval.summary(tool: "remove_todo", arguments: ["page": "Single leg", "item": "Setups"]), "Delete “Setups” and everything inside it from “Single leg”")
    }

    func testAgentsBuildAListWithSectionsLinksAndPictures() throws {
        let added = try call("add_todo", ["page": "Wrestling/Single leg", "title": "Drill entries", "workouts": ["Single-leg bundle"], "icon": "🥋"])
        let firstID = added["id"] as! String
        try call("add_todo", ["page": "Single leg", "title": "Footwork", "section": true])
        try call("add_todo", ["page": "Single leg", "title": "Penetration step", "pages": ["Wrestling/Shot drill"], "imagePaths": [try picture("step.jpg")], "note": "Knee to the mat"])
        try call("add_todo", ["page": "Single leg", "title": "Level change", "parent": "Penetration step", "color": "#34d399"])
        try call("add_todo", ["page": "Single leg", "title": "Stance", "inSection": "top"])

        let todos = try database.checklist(TodoItem.self, of: skillID)
        XCTAssertEqual(todos.map(\.title), ["Drill entries", "Stance", "Footwork", "Penetration step"])
        XCTAssertEqual(todos[0].visualLink, .workout(id: workoutID))
        XCTAssertEqual(todos[0].iconName, "🥋")
        XCTAssertTrue(todos[2].isSection)
        XCTAssertEqual(todos[3].imageFilenames.count, 1)
        XCTAssertEqual(todos[3].children.first?.colorHex, "34D399")

        let listed = try call("list_todos", ["page": skillID!])
        let lines = listed["lines"] as! [String]
        XCTAssertEqual(lines.count, 5)
        XCTAssertTrue(lines[0].hasPrefix("[ ] Drill entries"))
        XCTAssertTrue(lines[0].contains("▶ “Single-leg bundle”"))
        XCTAssertTrue(lines[0].hasSuffix("#" + firstID.prefix(8)))
        XCTAssertTrue(lines[2].hasPrefix("## Footwork"))
        XCTAssertTrue(lines[3].contains("→ Wrestling/Shot drill"))
        XCTAssertTrue(lines[3].contains("pictures #1"))
        XCTAssertTrue(lines[4].hasPrefix("  [ ] Level change"))
        XCTAssertEqual(listed["open"] as? Int, 4)
        XCTAssertEqual(listed["media"] as? [String], ["1 image"])
    }

    func testCheckMoveUpdateAndRemoveByShortIdOrTitle() throws {
        let parentID = try call("add_todo", ["page": skillID!, "title": "Setups"])["id"] as! String
        try call("add_todo", ["page": skillID!, "title": "Collar tie", "parent": String(parentID.prefix(6))])
        try call("add_todo", ["page": skillID!, "title": "Finish"])

        let checked = try call("check_todo", ["page": skillID!, "item": "setups"])
        XCTAssertEqual(checked["inside"] as? Int, 1)
        XCTAssertEqual(checked["open"] as? Int, 1)
        try call("check_todo", ["page": skillID!, "item": "Collar tie", "done": false])
        XCTAssertFalse(try database.checklist(TodoItem.self, of: skillID).entry(parentID)!.isDone)

        try call("move_todo", ["page": skillID!, "item": "Finish", "before": "Setups"])
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID).map(\.title), ["Finish", "Setups"])
        try call("move_todo", ["page": skillID!, "item": "Collar tie", "outdent": true])
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID).map(\.title), ["Finish", "Setups", "Collar tie"])
        try call("move_todo", ["page": skillID!, "item": "Collar tie", "indent": true])
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID).entry(parentID)?.children.map(\.title), ["Collar tie"])

        try call("update_todo", ["page": skillID!, "item": "Finish", "title": "Finish strong", "links": ["https://youtu.be/abc"], "workouts": [workoutID!]])
        let finish = try database.checklist(TodoItem.self, of: skillID)[0]
        XCTAssertEqual(finish.title, "Finish strong")
        XCTAssertEqual(finish.links.compactMap(\.target), [.workout(id: workoutID), .web("https://youtu.be/abc")])
        try call("update_todo", ["page": skillID!, "item": "Finish strong", "links": [String]()])
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID)[0].links.compactMap(\.target), [.workout(id: workoutID)], "replacing links leaves the workout link alone")

        let preview = try call("remove_todo", ["page": skillID!, "item": "Setups"], dryRun: true)
        XCTAssertEqual(preview["inside"] as? Int, 1)
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID).count, 2)
        try call("remove_todo", ["page": skillID!, "item": "Setups"])
        XCTAssertEqual(try database.checklist(TodoItem.self, of: skillID).map(\.title), ["Finish strong"])
    }

    func testMilestonesUseTheSameToolsAndSectionsRenameAsEntries() throws {
        try call("add_todo", ["page": skillID!, "list": "milestone", "title": "Competition", "section": true])
        let id = try call("add_todo", ["page": skillID!, "list": "milestone", "title": "Hit it live", "inSection": "Competition", "workouts": ["Single-leg bundle"]])["id"] as! String
        try call("update_todo", ["page": skillID!, "list": "milestone", "item": "Competition", "title": "Tournaments"])
        let milestones = try database.checklist(Milestone.self, of: skillID)
        XCTAssertEqual(milestones.map(\.title), ["Tournaments", "Hit it live"])
        XCTAssertTrue(try database.checklist(TodoItem.self, of: skillID).isEmpty)
        try call("check_todo", ["page": skillID!, "list": "milestone", "item": id])
        let page = try call("get_page", ["page": skillID!])
        XCTAssertEqual((page["milestones"] as? [String: Any])?["open"] as? Int, 0)
        XCTAssertEqual((page["milestones"] as? [String: Any])?["total"] as? Int, 1)
        XCTAssertNil(page["todos"])
    }

    func testHelpfulErrors() throws {
        try call("add_todo", ["page": skillID!, "title": "Twice"])
        try call("add_todo", ["page": skillID!, "title": "Twice"])
        XCTAssertEqual(failure { try self.call("check_todo", ["page": self.skillID!, "item": "twice"]) }?.code, "ambiguous")
        XCTAssertEqual(failure { try self.call("check_todo", ["page": self.skillID!, "item": "nothing like it"]) }?.code, "not_found")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": "Wrestling", "title": "x"]) }?.code, "invalid_page")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": self.skillID!, "title": "x", "workouts": ["No such workout"]]) }?.code, "not_found")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": self.skillID!, "title": "x", "cover": "3"]) }?.code, "not_found")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": self.skillID!, "title": "x", "color": "orange"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": self.skillID!, "title": "S", "section": true, "workouts": ["Single-leg bundle"]]) }?.code, "invalid_argument")
        try call("add_todo", ["page": skillID!, "title": "Solo"])
        XCTAssertEqual(failure { try self.call("move_todo", ["page": self.skillID!, "item": "Solo"]) }?.code, "invalid_argument", "a move needs one place")
        let section = try call("add_todo", ["page": skillID!, "title": "Part", "section": true])["id"] as! String
        XCTAssertEqual(failure { try self.call("check_todo", ["page": self.skillID!, "item": section]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { try self.call("add_todo", ["page": self.skillID!, "title": "x", "parent": section]) }?.code, "invalid_argument")
    }

    func testDryRunsChangeNothingAndUndoTakesAddedEntriesAndPicturesBack() throws {
        let preview = try call("add_todo", ["page": skillID!, "title": "Ghost", "coverPath": try picture("g.jpg")], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertTrue(try database.checklist(TodoItem.self, of: skillID).isEmpty)
        let output = try toolbox.call("add_todo", arguments: ["page": skillID!, "title": "Real", "coverPath": try picture("r.jpg")])
        XCTAssertEqual(output.effects.count, 2)
        XCTAssertEqual(try database.getPage(id: skillID).mediaFilenames.count, 1)
        toolbox.revert(output.effects)
        XCTAssertTrue(try database.checklist(TodoItem.self, of: skillID).isEmpty)
        XCTAssertTrue(try database.getPage(id: skillID).mediaFilenames.isEmpty)
    }

    func testTheOverviewCollectsOpenEntriesAndGoneTargets() throws {
        try call("add_todo", ["page": skillID!, "title": "Drill entries", "workouts": ["Single-leg bundle"]])
        try call("add_todo", ["page": skillID!, "list": "milestone", "title": "Hit it live"])
        var overview = try call("todo_overview", [:])
        let row = (overview["pages"] as! [[String: Any]])[0]
        XCTAssertEqual(row["page"] as? String, "Wrestling/Single leg")
        XCTAssertEqual(row["todos"] as? String, "1 open of 1")
        XCTAssertEqual(row["nextMilestone"] as? String, "Hit it live")
        XCTAssertNil(overview["missing"])
        try database.deleteWorkout(id: workoutID)
        overview = try call("todo_overview", ["list": "todo"])
        XCTAssertEqual((overview["pages"] as! [[String: Any]])[0]["missing"] as? Int, 1)
        XCTAssertEqual((overview["missing"] as? [String])?.first, "Wrestling/Single leg · Drill entries: its workout is gone")
        XCTAssertTrue((try call("list_todos", ["page": skillID!])["lines"] as! [String])[0].contains("▶ missing workout"))
    }

    func testTheSkillGuideIsBootstrapped() throws {
        let guide = try String(contentsOf: database.fs.skillsDirectory.appendingPathComponent("manage-todos-and-milestones.md"), encoding: .utf8)
        XCTAssertTrue(guide.contains("tmax add_todo"))
    }
}
