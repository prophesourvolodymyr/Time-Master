import XCTest
@testable import TimeMasterCore

final class AgentOrganizeToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("organize-\(UUID().uuidString)", isDirectory: true)
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

    private func run(_ name: String, _ arguments: [String: Any]) throws -> AgentToolOutput {
        try toolbox.call(name, arguments: arguments)
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    private func file(_ name: String) throws -> String {
        let folder = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(repeating: 7, count: 64).write(to: url)
        return url.path
    }

    @discardableResult
    private func folder(_ title: String, in parent: String? = nil, type: String? = nil) throws -> String {
        var arguments: [String: Any] = ["title": title]
        if let parent { arguments["parent"] = parent }
        if let type { arguments["workoutType"] = type }
        return try call("create_container_page", arguments)["id"] as! String
    }

    @discardableResult
    private func exercise(_ title: String, in parent: String) throws -> String {
        try call("create_exercise_page", ["title": title, "parent": parent])["id"] as! String
    }

    @discardableResult
    private func skill(_ title: String, in parent: String, group: String? = nil, status: String? = nil) throws -> String {
        var arguments: [String: Any] = ["title": title, "parent": parent]
        if let group { arguments["group"] = group }
        if let status { arguments["status"] = status }
        return try call("create_skill_page", arguments)["id"] as! String
    }

    private func titles(in parent: String? = nil) throws -> [String] {
        let index = try AgentPageIndex(database: database)
        let id = try parent.map { try index.resolve($0).id }
        return index.children(of: id).map(\.title)
    }

    private func pageID(_ reference: String) throws -> String {
        try AgentPageIndex(database: database).resolve(reference).id
    }

    private func storedState(_ parents: [String]) throws -> [String] {
        var lines: [String] = []
        for parent in parents {
            let id = try pageID(parent)
            let manifest = try database.getPage(id: id)
            let children = try database.storedSiblings(parentID: id).map(\.manifest)
            let names = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0.title) })
            lines.append("\(parent) childIDs \(manifest.childIDs.map { names[$0] ?? "?" })")
            lines += children.map { "\(parent)/\($0.title) order \($0.order)" }.sorted()
        }
        return lines
    }

    private func assertDenseOrder(of parent: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let id = try pageID(parent)
        let children = try database.storedSiblings(parentID: id).map(\.manifest)
        XCTAssertEqual(try database.getPage(id: id).childIDs, children.map(\.id), file: file, line: line)
        XCTAssertEqual(children.map(\.order), Array(children.indices), file: file, line: line)
    }

    private func skillsOf(_ board: String) throws -> [ExercisePageManifest] {
        let children = try database.storedSiblings(parentID: try pageID(board)).map(\.manifest)
        return children.filter { $0.pageType == .skill || $0.pageType == .tutorial }
    }

    private func boardState(_ board: String) throws -> [String] {
        let container = try database.getPage(id: try pageID(board))
        var lines: [String] = []
        for skill in try skillsOf(board) {
            let status = skill.skillStatus?.rawValue ?? "-"
            let group = container.skillBoardSection(skill.skillBoardSectionID ?? "")?.title ?? "none"
            lines.append("\(skill.title) \(status) \(group) \(skill.skillBoardOrder ?? 0)")
        }
        return lines.sorted()
    }

    private func column(_ board: String, group: String?, status: SkillStatus) throws -> [String] {
        let container = try database.getPage(id: try pageID(board))
        let sectionID = container.skillBoardSections.first { $0.title == group }?.id
        var members: [ExercisePageManifest] = []
        for skill in try skillsOf(board) {
            let current = skill.skillStatus ?? .notStarted
            if skill.skillBoardSectionID == sectionID && current == status { members.append(skill) }
        }
        members.sort { ($0.skillBoardOrder ?? 0) < ($1.skillBoardOrder ?? 0) }
        return members.map(\.title)
    }

    func testAPageCanBePutBeforeAfterOrAtAPositionInsideAndAcrossContainers() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross", "Hook", "Uppercut"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        for name in ["Step", "Pivot"] { try exercise(name, in: "Footwork") }

        var moved = try call("move_page", ["page": "Boxing/Uppercut", "before": "Boxing/Jab"])
        XCTAssertEqual(try titles(in: "Boxing"), ["Uppercut", "Jab", "Cross", "Hook"])
        XCTAssertEqual(moved["position"] as? Int, 1)
        XCTAssertEqual(moved["path"] as? String, "Boxing/Uppercut")

        try call("move_page", ["page": "Hook", "after": "Jab", "newParent": "Boxing"])
        XCTAssertEqual(try titles(in: "Boxing"), ["Uppercut", "Jab", "Hook", "Cross"])

        moved = try call("move_page", ["page": "Boxing/Cross", "newParent": "Footwork", "position": 2])
        XCTAssertEqual(moved["path"] as? String, "Footwork/Cross")
        XCTAssertEqual(moved["from"] as? String, "Boxing/Cross")
        XCTAssertEqual(try titles(in: "Boxing"), ["Uppercut", "Jab", "Hook"])
        XCTAssertEqual(try titles(in: "Footwork"), ["Step", "Cross", "Pivot"])
        try assertDenseOrder(of: "Footwork")

        try call("move_page", ["page": "Footwork/Pivot", "newParent": "Boxing", "before": "Hook"])
        XCTAssertEqual(try titles(in: "Boxing"), ["Uppercut", "Jab", "Pivot", "Hook"])

        moved = try call("move_page", ["page": "Boxing/Uppercut", "newParent": "Boxing", "position": 99])
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Pivot", "Hook", "Uppercut"])
        XCTAssertEqual(moved["position"] as? Int, 4)
        try assertDenseOrder(of: "Boxing")
    }

    func testMovingWithoutAPlaceStillGoesToTheEndAndReportsTheOldFields() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        try exercise("Step", in: "Footwork")

        let moved = try call("move_page", ["page": "Boxing/Jab", "newParent": "Footwork"])
        XCTAssertEqual(Set(moved.keys), ["id", "path", "from"])
        XCTAssertEqual(try titles(in: "Footwork"), ["Step", "Jab"])
        try call("move_page", ["page": "Footwork/Step", "newParent": "Footwork"])
        XCTAssertEqual(try titles(in: "Footwork"), ["Jab", "Step"])
        try call("move_page", ["page": "Footwork/Jab"])
        XCTAssertEqual(try titles(), ["Boxing", "Footwork", "Jab"])
    }

    func testMovePageRefusesContradictoryOrImpossiblePlaces() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        try exercise("Step", in: "Footwork")

        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Jab", "before": "Cross", "position": 1]) }?.code, "invalid_argument")
        let flatten = failure { _ = try self.call("move_page", ["page": "Boxing/Jab", "position": 1]) }
        XCTAssertEqual(flatten?.code, "invalid_argument")
        XCTAssertTrue(flatten?.hint?.contains("Boxing") == true)
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Cross"])
        XCTAssertEqual(try titles(), ["Boxing", "Footwork"])
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Boxing/Jab", "before": "Boxing/Jab"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Boxing/Jab", "newParent": "Boxing", "before": "Footwork/Step"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Boxing/Jab", "newParent": "Footwork/Step"]) }?.code, "invalid_parent")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Boxing", "before": "Boxing/Jab"]) }?.code, "invalid_parent")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Jab", "newParent": "Footwork", "position": 0]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": "Jab", "before": "Nonexistent Page"]) }?.code, "not_found")
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Cross"])

        let top = try call("move_page", ["page": "Footwork", "position": 1])
        XCTAssertEqual(top["position"] as? Int, 1)
        XCTAssertEqual(try titles(), ["Footwork", "Boxing"])
        try call("move_page", ["page": "Footwork", "after": "Boxing"])
        XCTAssertEqual(try titles(), ["Boxing", "Footwork"])
    }

    func testUndoPutsMovedAndReorderedPagesExactlyBack() throws {
        try folder("Boxing")
        for name in ["A", "B", "C", "D", "E"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        for name in ["X", "Y", "Z"] { try exercise(name, in: "Footwork") }
        try call("delete_page", ["page": "Boxing/B"])
        let original = try storedState(["Boxing", "Footwork"])

        let operations: [(String, [String: Any])] = [
            ("reorder_pages", ["parent": "Boxing", "order": ["E", "D"]]),
            ("move_page", ["page": "Boxing/C", "newParent": "Footwork", "position": 2]),
            ("move_page", ["page": "Footwork/Y", "before": "Boxing/D"]),
            ("move_page", ["page": "Boxing/A", "newParent": "Footwork"]),
            ("move_page", ["page": "Footwork/X", "newParent": "Footwork", "after": "Footwork/Z"]),
        ]
        for (name, arguments) in operations {
            let output = try run(name, arguments)
            XCTAssertFalse(output.effects.isEmpty, name)
            XCTAssertNotEqual(try storedState(["Boxing", "Footwork"]), original, name)
            let notes = toolbox.revert(output.effects)
            XCTAssertFalse(notes.contains { $0.hasPrefix("Could not") }, "\(name): \(notes)")
            XCTAssertEqual(try storedState(["Boxing", "Footwork"]), original, name)
            XCTAssertEqual(try pageID("Boxing/C"), try pageID("C"))
        }
    }

    func testUndoBringsATopLevelPageBackToItsPlace() throws {
        for name in ["A", "B", "C"] { try folder(name) }
        try folder("Inner", in: "B")
        let before = try titles()
        let moved = try run("move_page", ["page": "A", "newParent": "B", "position": 1])
        XCTAssertEqual(try titles(), ["B", "C"])
        toolbox.revert(moved.effects)
        XCTAssertEqual(try titles(), before)
        XCTAssertEqual(try titles(in: "B"), ["Inner"])
    }

    func testPreviewsChangeNothing() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross", "Hook"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        let original = try storedState(["Boxing", "Footwork"])

        let preview = try call("move_page", ["page": "Boxing/Hook", "newParent": "Footwork", "position": 1], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(preview["position"] as? Int, 1)
        XCTAssertEqual(preview["to"] as? String, "Footwork/Hook")
        let reorder = try call("reorder_pages", ["parent": "Boxing", "order": ["Hook"]], dryRun: true)
        XCTAssertEqual(reorder["dryRun"] as? Bool, true)
        XCTAssertEqual(reorder["order"] as? [String], ["Hook", "Jab", "Cross"])
        XCTAssertEqual(try storedState(["Boxing", "Footwork"]), original)
    }

    func testReorderPagesPutsTheListedPagesFirstAndKeepsTheRestInOrder() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross", "Hook", "Uppercut"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        try exercise("Jab", in: "Footwork")

        let result = try call("reorder_pages", ["parent": "Boxing", "order": ["Hook", "Jab"]])
        XCTAssertEqual(result["order"] as? [String], ["Hook", "Jab", "Cross", "Uppercut"])
        XCTAssertEqual(result["moved"] as? Int, 3)
        XCTAssertEqual(try titles(in: "Boxing"), ["Hook", "Jab", "Cross", "Uppercut"])
        try assertDenseOrder(of: "Boxing")

        let again = try call("reorder_pages", ["parent": "Boxing", "order": ["Hook", "Jab", "Hook"]])
        XCTAssertEqual(again["unchanged"] as? Bool, true)
        XCTAssertTrue(try run("reorder_pages", ["parent": "Boxing", "order": ["Hook"]]).effects.isEmpty)

        let top = try call("reorder_pages", ["order": ["Footwork"]])
        XCTAssertEqual(top["in"] as? String, "top level")
        XCTAssertEqual(try titles(), ["Footwork", "Boxing"])
    }

    func testReorderPagesRefusesPagesThatAreNotChildrenOfTheParent() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        try folder("Drills", in: "Boxing")
        try exercise("Shadow", in: "Boxing/Drills")
        try folder("Footwork")
        try exercise("Jab", in: "Footwork")

        XCTAssertEqual(try call("get_page", ["page": "Boxing/Jab"])["path"] as? String, "Boxing/Jab")
        XCTAssertEqual(failure { _ = try self.call("get_page", ["page": "Jab"]) }?.code, "ambiguous")
        XCTAssertEqual(try call("reorder_pages", ["parent": "Boxing", "order": ["Jab"]])["unchanged"] as? Bool, true)

        let deeper = failure { _ = try self.call("reorder_pages", ["parent": "Boxing", "order": ["Boxing/Drills/Shadow"]]) }
        XCTAssertEqual(deeper?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("reorder_pages", ["parent": "Boxing", "order": ["Footwork"]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("reorder_pages", ["parent": "Boxing", "order": ["Nothing Here"]]) }?.code, "not_found")
        XCTAssertEqual(failure { _ = try self.call("reorder_pages", ["parent": "Boxing", "order": [String]()]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("reorder_pages", ["parent": "Boxing/Jab", "order": ["Jab"]]) }?.code, "invalid_parent")
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Drills"])

        try call("create_exercise_page", ["title": "Jab", "parent": "Boxing", "ifExists": "duplicate"])
        XCTAssertEqual(failure { _ = try self.call("reorder_pages", ["parent": "Boxing", "order": ["Jab"]]) }?.code, "ambiguous")
    }

    private func wrestlingBoard() throws {
        try folder("Wrestling")
        try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting")
        try skill("Snap Down", in: "Wrestling", group: "Hand Fighting")
        try skill("Single Leg", in: "Wrestling", group: "Hand Fighting")
        try skill("Double Leg", in: "Wrestling", group: "Shots")
        try skill("Sprawl", in: "Wrestling")
    }

    func testASkillChangesStatusInTheWordsTheAppShows() throws {
        try wrestlingBoard()
        let learning = try call("update_skill", ["page": "Wrestling/Snap Down", "status": "Learning"])
        XCTAssertEqual(learning["status"] as? String, "learning")
        XCTAssertEqual(learning["changed"] as? [String], ["status"])
        XCTAssertEqual(learning["group"] as? String, "Hand Fighting")
        XCTAssertEqual(try call("get_page", ["page": "Wrestling/Snap Down"])["status"] as? String, "learning")
        XCTAssertEqual(try call("get_page", ["page": "Wrestling/Snap Down"])["group"] as? String, "Hand Fighting")

        for (words, expected) in [("Not Started", "notStarted"), ("in progress", "learning"), ("DONE", "completed"), ("Abandoned", "abandoned"), ("completed", "completed")] {
            XCTAssertEqual(try call("update_skill", ["page": "Wrestling/Snap Down", "status": words])["status"] as? String, expected)
        }
        XCTAssertEqual(try database.getPage(id: try pageID("Wrestling/Snap Down")).skillStatus, .completed)
        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Wrestling/Snap Down", "status": "someday"]) }?.code, "invalid_argument")

        let same = try call("update_skill", ["page": "Wrestling/Snap Down", "status": "completed"])
        XCTAssertEqual(same["unchanged"] as? Bool, true)
        XCTAssertTrue(try run("update_skill", ["page": "Wrestling/Snap Down", "status": "completed"]).effects.isEmpty)
    }

    func testASkillMovesBetweenGroupsByTitleOrIdAndOutOfEveryGroup() throws {
        try wrestlingBoard()
        let board = try database.getPage(id: try pageID("Wrestling"))
        let shots = try XCTUnwrap(board.skillBoardSections.first { $0.title == "Shots" })

        let titled = try call("update_skill", ["page": "Wrestling/Sprawl", "group": "shots"])
        XCTAssertEqual(titled["group"] as? String, "Shots")
        XCTAssertEqual(try call("get_page", ["page": "Wrestling/Sprawl"])["group"] as? String, "Shots")
        XCTAssertEqual(try column("Wrestling", group: "Shots", status: .notStarted), ["Double Leg", "Sprawl"])

        try call("update_skill", ["page": "Wrestling/Sprawl", "group": "none"])
        XCTAssertNil(try call("get_page", ["page": "Wrestling/Sprawl"])["group"])
        XCTAssertNil(try database.getPage(id: try pageID("Wrestling/Sprawl")).skillBoardSectionID)

        let byID = try call("update_skill", ["page": "Wrestling/Sprawl", "group": SkillGroupID.make(containerID: board.id, sectionID: shots.id)])
        XCTAssertEqual(byID["group"] as? String, "Shots")
        try call("update_skill", ["page": "Wrestling/Sprawl", "group": ""])
        XCTAssertNil(try database.getPage(id: try pageID("Wrestling/Sprawl")).skillBoardSectionID)
        try call("update_skill", ["page": "Wrestling/Sprawl", "group": shots.id])
        XCTAssertEqual(try database.getPage(id: try pageID("Wrestling/Sprawl")).skillBoardSectionID, shots.id)

        let missing = failure { _ = try self.call("update_skill", ["page": "Wrestling/Sprawl", "group": "Takedowns"]) }
        XCTAssertEqual(missing?.code, "not_found")
        XCTAssertTrue(missing?.hint?.contains("Hand Fighting") == true)
        XCTAssertEqual(try call("update_skill", ["page": "Wrestling/Sprawl", "group": "Shots"])["unchanged"] as? Bool, true)
    }

    func testASkillTakesAPlaceInsideItsGroupAndStatusColumn() throws {
        try folder("Wrestling")
        for name in ["A", "B", "C"] { try skill(name, in: "Wrestling", group: "Hand Fighting") }
        try skill("D", in: "Wrestling", group: "Hand Fighting", status: "learning")
        try skill("E", in: "Wrestling", group: "Shots")

        var result = try call("update_skill", ["page": "Wrestling/C", "position": 1])
        XCTAssertEqual(result["position"] as? Int, 1)
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .notStarted), ["C", "A", "B"])
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .learning), ["D"])

        result = try call("update_skill", ["page": "Wrestling/D", "status": "notStarted", "position": 2])
        XCTAssertEqual(result["position"] as? Int, 2)
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .notStarted), ["C", "D", "A", "B"])

        result = try call("update_skill", ["page": "Wrestling/C", "position": 99])
        XCTAssertEqual(result["position"] as? Int, 4)
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .notStarted), ["D", "A", "B", "C"])

        try call("update_skill", ["page": "Wrestling/E", "group": "Hand Fighting", "status": "learning", "position": 1])
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .learning), ["E"])
        try call("update_skill", ["page": "Wrestling/A", "status": "learning"])
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .learning), ["E", "A"])
        XCTAssertEqual(try column("Wrestling", group: "Shots", status: .notStarted), [])
    }

    func testSkillChangesPreviewValidateAndUndo() throws {
        try wrestlingBoard()
        try folder("Calisthenics")
        let original = try boardState("Wrestling")

        let preview = try call("update_skill", ["page": "Wrestling/Snap Down", "status": "learning", "group": "Shots", "position": 1], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(preview["wouldChange"] as? [String], ["status", "group", "position"])
        XCTAssertEqual(try boardState("Wrestling"), original)

        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Wrestling/Arm Drag"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Wrestling", "status": "learning"]) }?.code, "invalid_page")
        try exercise("Pushup", in: "Calisthenics")
        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Calisthenics/Pushup", "status": "learning"]) }?.code, "invalid_page")

        let operations: [[String: Any]] = [
            ["page": "Wrestling/Snap Down", "status": "learning", "group": "Shots", "position": 1],
            ["page": "Wrestling/Arm Drag", "position": 99],
            ["page": "Wrestling/Sprawl", "group": "Hand Fighting", "status": "completed"],
            ["page": "Wrestling/Single Leg", "group": "none"],
        ]
        for arguments in operations {
            let output = try run("update_skill", arguments)
            XCTAssertFalse(output.effects.isEmpty, "\(arguments)")
            XCTAssertNotEqual(try boardState("Wrestling"), original, "\(arguments)")
            let notes = toolbox.revert(output.effects)
            XCTAssertFalse(notes.contains { $0.hasPrefix("Could not") }, "\(notes)")
            XCTAssertEqual(try boardState("Wrestling"), original, "\(arguments)")
        }
    }

    func testASkillAtTheTopOfTheLibraryChangesStatusButHasNoGroups() throws {
        let id = try call("create_skill_page", ["title": "Handstand"])["id"] as! String
        let changed = try run("update_skill", ["page": "Handstand", "status": "learning"])
        XCTAssertEqual(try database.getPage(id: id).skillStatus, .learning)
        toolbox.revert(changed.effects)
        XCTAssertEqual(try database.getPage(id: id).skillStatus, .notStarted)
        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Handstand", "group": "Balance"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_skill", ["page": "Handstand", "position": 1]) }?.code, "invalid_argument")
        XCTAssertEqual(try call("update_skill", ["page": "Handstand", "group": "none"])["unchanged"] as? Bool, true)
    }

    func testATutorialPageTakesStatusAndGroupLikeASkill() throws {
        try folder("Wrestling")
        try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting")
        let tutorial = try call("create_skill_page", ["title": "Grip Basics", "parent": "Wrestling", "pageType": "tutorial", "group": "Shots"])["id"] as! String
        let output = try call("update_skill", ["page": tutorial, "status": "completed", "group": "Hand Fighting", "position": 1])
        XCTAssertEqual(output["status"] as? String, "completed")
        XCTAssertEqual(output["group"] as? String, "Hand Fighting")
        XCTAssertEqual(try database.getPage(id: tutorial).skillStatus, .completed)
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .completed), ["Grip Basics"])
        XCTAssertEqual(try column("Wrestling", group: "Shots", status: .notStarted), [])
    }

    func testAGroupIsRenamedNotedRecolouredAndMovedWithoutLosingItsSkills() throws {
        try folder("Boxing")
        for title in ["Punches", "Defense", "Footwork"] { try call("create_skill_group", ["parent": "Boxing", "title": title]) }
        try skill("Jab", in: "Boxing", group: "Punches")
        let boardID = try pageID("Boxing")
        let before = try database.getPage(id: boardID)
        let punches = try XCTUnwrap(before.skillBoardSections.first { $0.title == "Punches" })

        let result = try call("update_skill_group", [
            "container": "Boxing", "group": "punches", "title": "Strikes", "markdownBody": "Snap, do not push.",
            "icon": "figure.boxing", "color": "ff6a00", "position": 3,
        ])
        XCTAssertEqual(result["id"] as? String, SkillGroupID.make(containerID: boardID, sectionID: punches.id))
        XCTAssertEqual(result["group"] as? String, "Strikes")
        XCTAssertEqual(result["position"] as? Int, 3)
        XCTAssertEqual(Set(result["changed"] as? [String] ?? []), ["title", "markdownBody", "icon", "color", "position"])
        let after = try database.getPage(id: boardID)
        XCTAssertEqual(after.orderedSkillBoardSections.map(\.title), ["Defense", "Footwork", "Strikes"])
        let strikes = try XCTUnwrap(after.skillBoardSection(punches.id))
        XCTAssertEqual(strikes.markdownBody, "Snap, do not push.")
        XCTAssertEqual(strikes.icon, "figure.boxing")
        XCTAssertEqual(strikes.iconType, .system)
        XCTAssertEqual(strikes.colorHex, "FF6A00")
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing/Jab")).skillBoardSectionID, punches.id)
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Jab"])["group"] as? String, "Strikes")

        try call("update_skill_group", ["container": "Boxing", "group": SkillGroupID.make(containerID: boardID, sectionID: punches.id), "icon": "🥊", "position": 1])
        let emoji = try XCTUnwrap(try database.getPage(id: boardID).skillBoardSection(punches.id))
        XCTAssertEqual(emoji.iconType, .emoji)
        XCTAssertEqual(try database.getPage(id: boardID).orderedSkillBoardSections.first?.id, punches.id)

        try call("update_skill_group", ["container": "Boxing", "group": punches.id, "icon": "", "color": "", "markdownBody": ""])
        let cleared = try XCTUnwrap(try database.getPage(id: boardID).skillBoardSection(punches.id))
        XCTAssertNil(cleared.icon)
        XCTAssertNil(cleared.iconType)
        XCTAssertNil(cleared.colorHex)
        XCTAssertEqual(cleared.markdownBody, "")
        XCTAssertEqual(cleared.title, "Strikes")
    }

    func testGroupEditsValidatePreviewAndUndo() throws {
        try folder("Boxing")
        for title in ["Punches", "Defense"] { try call("create_skill_group", ["parent": "Boxing", "title": title, "markdownBody": "Notes of \(title)"]) }
        try exercise("Jab", in: "Boxing")
        let boardID = try pageID("Boxing")
        let original = try database.getPage(id: boardID).skillBoardSections

        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": "Punches", "title": " defense "]) }?.code, "already_exists")
        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": "Punches", "color": "orange"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": "Punches", "title": "  "]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": "Punches"]) }?.code, "invalid_argument")
        let unknown = failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": "Counters", "title": "X"]) }
        XCTAssertEqual(unknown?.code, "not_found")
        XCTAssertTrue(unknown?.hint?.contains("Punches") == true)
        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing/Jab", "group": "Punches", "title": "X"]) }?.code, "invalid_parent")
        XCTAssertEqual(failure { _ = try self.call("update_skill_group", ["container": "Boxing", "group": SkillGroupID.make(containerID: "OTHER", sectionID: "x"), "title": "X"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("delete_skill_group", ["container": "Boxing", "group": "Counters"]) }?.code, "not_found")
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections, original)

        let preview = try call("update_skill_group", ["container": "Boxing", "group": "Punches", "title": "Strikes", "position": 2], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections, original)

        let output = try run("update_skill_group", ["container": "Boxing", "group": "Punches", "title": "Strikes", "markdownBody": "New", "color": "00ff00", "icon": "🥊", "position": 2])
        XCTAssertNotEqual(try database.getPage(id: boardID).skillBoardSections, original)
        toolbox.revert(output.effects)
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections, original)
    }

    func testDeletingAGroupKeepsItsSkillsAfterTheOnesAlreadyOutsideAnyGroup() throws {
        try folder("Wrestling")
        try skill("Free One", in: "Wrestling")
        try skill("Free Two", in: "Wrestling")
        try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting", status: "learning")
        try skill("Snap Down", in: "Wrestling", group: "Hand Fighting")
        try skill("Double Leg", in: "Wrestling", group: "Shots")
        let boardID = try pageID("Wrestling")
        let original = try boardState("Wrestling")
        let originalGroups = try database.getPage(id: boardID).skillBoardSections
        XCTAssertEqual(AgentToolRegistry.tool(named: "delete_skill_group")?.risk, .delete)

        let preview = try call("delete_skill_group", ["container": "Wrestling", "group": "Hand Fighting"], dryRun: true)
        XCTAssertEqual(preview["skillsKept"] as? Int, 2)
        XCTAssertEqual(try boardState("Wrestling"), original)

        let output = try run("delete_skill_group", ["container": "Wrestling", "group": "hand fighting"])
        XCTAssertEqual(output.value["removed"] as? String, "Hand Fighting")
        XCTAssertEqual(output.value["skillsKept"] as? Int, 2)
        let board = try database.getPage(id: boardID)
        XCTAssertEqual(board.skillBoardSections.map(\.title), ["Shots"])
        let free = try ["Free One", "Free Two"].map { try database.getPage(id: try pageID("Wrestling/\($0)")) }
        let moved = try ["Arm Drag", "Snap Down"].map { try database.getPage(id: try pageID("Wrestling/\($0)")) }
        for skill in moved {
            XCTAssertNil(skill.skillBoardSectionID)
            XCTAssertGreaterThan(skill.skillBoardOrder ?? 0, free.map { $0.skillBoardOrder ?? 0 }.max() ?? 0)
        }
        XCTAssertEqual(moved[0].skillStatus, .learning)
        XCTAssertEqual(try database.getPage(id: try pageID("Wrestling/Double Leg")).skillBoardSectionID, board.skillBoardSections[0].id)

        let notes = toolbox.revert(output.effects)
        XCTAssertFalse(notes.contains { $0.hasPrefix("Could not") }, "\(notes)")
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections, originalGroups)
        XCTAssertEqual(try boardState("Wrestling"), original)
    }

    func testAGroupWithClipsIsRemovedWithoutAnUndoThatWouldPointAtMissingFiles() throws {
        try folder("Wrestling")
        try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting")
        let boardID = try pageID("Wrestling")
        let section = try XCTUnwrap(try database.getPage(id: boardID).skillBoardSections.first)
        try database.uploadMediaToPage(pageID: SkillGroupID.make(containerID: boardID, sectionID: section.id), sourceURL: URL(fileURLWithPath: try file("clip.mp4")))
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections[0].mediaFilenames.count, 1)

        let output = try run("delete_skill_group", ["container": "Wrestling", "group": "Hand Fighting"])
        XCTAssertTrue(output.effects.isEmpty)
        XCTAssertNotNil(output.value["note"])
        XCTAssertTrue(try database.getPage(id: boardID).skillBoardSections.isEmpty)
        XCTAssertNil(try database.getPage(id: try pageID("Wrestling/Arm Drag")).skillBoardSectionID)
    }

    func testADuplicateCopiesEveryFieldTheClipsAndTheirCommentsAndSitsRightAfterTheOriginal() throws {
        try folder("Boxing")
        try call("create_exercise_page", [
            "title": "Jab", "parent": "Boxing", "markdownBody": "Snap it", "linkURLs": ["https://example.com/jab"], "duration": 45, "sets": 3,
            "media": [["path": try file("front.mp4"), "comment": "front view"], ["path": try file("side.jpg")]],
        ])
        try exercise("Cross", in: "Boxing")
        let original = try database.getPage(id: try pageID("Boxing/Jab"))

        let output = try run("duplicate_page", ["page": "Boxing/Jab"])
        XCTAssertEqual(output.value["path"] as? String, "Boxing/Jab Copy")
        XCTAssertEqual(output.effects, [.createdPage(id: output.value["id"] as! String)])
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Jab Copy", "Cross"])
        try assertDenseOrder(of: "Boxing")

        let copyID = output.value["id"] as! String
        let copy = try database.getPage(id: copyID)
        XCTAssertNotEqual(copyID, original.id)
        XCTAssertEqual(copy.title, "Jab Copy")
        XCTAssertEqual(copy.pageType, .exercise)
        XCTAssertEqual(copy.markdownBody, "Snap it")
        XCTAssertEqual(copy.linkURLs, ["https://example.com/jab"])
        XCTAssertEqual(copy.duration, 45)
        XCTAssertEqual(copy.sets, 3)
        XCTAssertEqual(copy.parentID, original.parentID)
        XCTAssertEqual(copy.childIDs, [])
        XCTAssertGreaterThanOrEqual(copy.createdAt, original.createdAt)
        XCTAssertEqual(copy.mediaFilenames, original.mediaFilenames)
        XCTAssertEqual(copy.mediaComments, original.mediaComments)
        XCTAssertEqual(copy.mediaComments.values.sorted(), ["front view"])
        for name in copy.mediaFilenames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: try database.pageMediaURL(pageID: copyID, filename: name).path), name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try database.pageMediaURL(pageID: original.id, filename: name).path), name)
        }
        XCTAssertEqual((try call("get_page", ["page": copyID])["media"] as? [[String: Any]])?.count, 2)

        XCTAssertEqual(try call("duplicate_page", ["page": "Boxing/Jab"])["path"] as? String, "Boxing/Jab Copy 2")
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Jab Copy 2", "Jab Copy", "Cross"])
        XCTAssertEqual(try call("duplicate_page", ["page": "Boxing/Jab", "title": "Jab Drill"])["path"] as? String, "Boxing/Jab Drill")
        let renamed = try call("duplicate_page", ["page": "Boxing/Jab", "title": "cross"])
        XCTAssertEqual(renamed["path"] as? String, "Boxing/cross 2")
        XCTAssertEqual((renamed["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(failure { _ = try self.call("duplicate_page", ["page": "Boxing/Jab", "title": " "]) }?.code, "invalid_argument")

        let notes = toolbox.revert(output.effects)
        XCTAssertFalse(notes.contains { $0.hasPrefix("Could not") }, "\(notes)")
        XCTAssertFalse(try titles(in: "Boxing").contains("Jab Copy"))
        XCTAssertEqual(try database.getPage(id: original.id).mediaFilenames, original.mediaFilenames)
    }

    func testADuplicatedNoteKeepsItsPicturesAndAPreviewCreatesNothing() throws {
        try folder("Boxing")
        try call("create_note_page", ["title": "Theory", "parent": "Boxing", "markdownBody": "Stack the joints.", "images": [try file("diagram.jpg")]])
        let original = try database.getPage(id: try pageID("Boxing/Theory"))
        let count = try AgentPageIndex(database: database).count

        XCTAssertEqual(try call("duplicate_page", ["page": "Boxing/Theory"], dryRun: true)["wouldCreate"] as? String, "Boxing/Theory Copy")
        XCTAssertEqual(try AgentPageIndex(database: database).count, count)

        let copyID = try call("duplicate_page", ["page": "Boxing/Theory"])["id"] as! String
        let copy = try database.getPage(id: copyID)
        XCTAssertEqual(copy.markdownBody, original.markdownBody)
        let attachments = try database.noteAttachmentNames(pageID: original.id)
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try database.noteAttachmentNames(pageID: copyID), attachments)
        XCTAssertTrue(copy.markdownBody.contains("Attachments/\(attachments[0])"))
        let file = try database.noteAttachmentsURL(pageID: copyID).appendingPathComponent(attachments[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testADeepCopyTakesEverythingInsideAndAShallowOneOnlyThePage() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        try exercise("Cross", in: "Boxing")
        try folder("Drills", in: "Boxing")
        try exercise("Shadow", in: "Boxing/Drills")
        try skill("Footwork", in: "Boxing", group: "Basics")
        let originalIDs = Set(try AgentPageIndex(database: database).pages.map(\.id))

        let output = try run("duplicate_page", ["page": "Boxing", "deep": true])
        XCTAssertEqual(output.value["path"] as? String, "Boxing Copy")
        XCTAssertEqual(output.value["pages"] as? Int, 6)
        XCTAssertEqual(output.effects.count, 6)
        XCTAssertEqual(try titles(), ["Boxing", "Boxing Copy"])
        XCTAssertEqual(try titles(in: "Boxing Copy"), try titles(in: "Boxing"))
        XCTAssertEqual(try titles(in: "Boxing Copy/Drills"), ["Shadow"])
        let created = Set(output.effects.compactMap { effect -> String? in
            if case .createdPage(let id) = effect { return id }
            return nil
        })
        XCTAssertEqual(created.count, 6)
        XCTAssertTrue(created.isDisjoint(with: originalIDs))
        XCTAssertEqual(Set(try AgentPageIndex(database: database).pages.map(\.id)), originalIDs.union(created))

        let copiedBoard = try database.getPage(id: try pageID("Boxing Copy"))
        let originalBoard = try database.getPage(id: try pageID("Boxing"))
        XCTAssertEqual(copiedBoard.skillBoardSections.map(\.title), ["Basics"])
        XCTAssertEqual(copiedBoard.skillBoardSections.map(\.id), originalBoard.skillBoardSections.map(\.id))
        XCTAssertEqual(try call("get_page", ["page": "Boxing Copy/Footwork"])["group"] as? String, "Basics")
        XCTAssertEqual(((try call("get_page", ["page": "Boxing Copy"]))["groups"] as? [[String: Any]])?.first?["skills"] as? Int, 1)
        XCTAssertEqual(copiedBoard.childIDs.count, 4)
        XCTAssertEqual(try titles(in: "Boxing").count, 4)

        let shallow = try call("duplicate_page", ["page": "Boxing"])
        XCTAssertEqual(shallow["path"] as? String, "Boxing Copy 2")
        XCTAssertNil(shallow["pages"])
        XCTAssertEqual(try titles(in: "Boxing Copy 2"), [])
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing Copy 2")).skillBoardSections.map(\.title), ["Basics"])

        let notes = toolbox.revert(output.effects)
        XCTAssertFalse(notes.contains { $0.hasPrefix("Could not") }, "\(notes)")
        XCTAssertEqual(try titles(), ["Boxing", "Boxing Copy 2"])
        XCTAssertEqual(Set(try AgentPageIndex(database: database).pages.map(\.id)).intersection(created), [])
    }

    func testADeepCopyPointsPrerequisitesAtTheCopies() throws {
        try folder("Wrestling")
        let first = try skill("Stance", in: "Wrestling")
        let second = try skill("Shot", in: "Wrestling")
        try database.addSkillDependency(first, to: second)
        try call("duplicate_page", ["page": "Wrestling", "deep": true])
        let copiedFirst = try pageID("Wrestling Copy/Stance")
        let copiedSecond = try database.getPage(id: try pageID("Wrestling Copy/Shot"))
        XCTAssertEqual(copiedSecond.dependencyPageIDs, [copiedFirst])
        XCTAssertEqual(try database.getPage(id: second).dependencyPageIDs, [first])
    }

    func testASkillCopyStaysInItsGroupRightAfterTheOriginalAndLeavesItWhenCopiedToAnotherBoard() throws {
        try folder("Wrestling")
        try skill("A", in: "Wrestling", group: "Hand Fighting", status: "learning")
        try skill("B", in: "Wrestling", group: "Hand Fighting", status: "learning")
        try skill("C", in: "Wrestling", group: "Hand Fighting")
        try skill("D", in: "Wrestling", group: "Shots")
        try folder("Boxing")
        try skill("Jab", in: "Boxing")

        let output = try run("duplicate_page", ["page": "Wrestling/A"])
        XCTAssertEqual(output.value["group"] as? String, "Hand Fighting")
        XCTAssertEqual(try titles(in: "Wrestling"), ["A", "A Copy", "B", "C", "D"])
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .learning), ["A", "A Copy", "B"])
        XCTAssertEqual(try column("Wrestling", group: "Hand Fighting", status: .notStarted), ["C"])
        let boardID = try pageID("Wrestling")
        XCTAssertEqual(try database.getPage(id: boardID).skillBoardSections.count, 2)
        XCTAssertEqual(try call("get_page", ["page": "Wrestling/A Copy"])["status"] as? String, "learning")

        let elsewhere = try call("duplicate_page", ["page": "Wrestling/B", "parent": "Boxing"])
        XCTAssertEqual(elsewhere["path"] as? String, "Boxing/B Copy")
        XCTAssertNil(elsewhere["group"])
        let moved = try database.getPage(id: elsewhere["id"] as! String)
        XCTAssertNil(moved.skillBoardSectionID)
        XCTAssertEqual(moved.skillStatus, .learning)
        XCTAssertGreaterThan(moved.skillBoardOrder ?? 0, try database.getPage(id: try pageID("Boxing/Jab")).skillBoardOrder ?? 0)
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "B Copy"])
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing")).skillBoardSections, [])
    }

    func testACopyKeepsItsTagOnlyWhereTheTreeHasIt() throws {
        try folder("Boxing")
        try folder("Footwork")
        try exercise("Jab", in: "Boxing")
        try call("create_page_tag", ["container": "Boxing", "title": "Morning flow"])
        try call("update_page", ["page": "Boxing/Jab", "tag": "Morning flow"])

        let inPlace = try call("duplicate_page", ["page": "Boxing/Jab"])
        XCTAssertEqual(try call("get_page", ["page": inPlace["id"] as! String])["tag"] as? String, "Morning flow")
        XCTAssertNil(inPlace["warnings"])

        let away = try call("duplicate_page", ["page": "Boxing/Jab", "parent": "Footwork"])
        XCTAssertNil(try call("get_page", ["page": away["id"] as! String])["tag"])
        XCTAssertNil(try database.getPage(id: away["id"] as! String).typeID)
        XCTAssertEqual((away["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Jab"])["tag"] as? String, "Morning flow")
    }

    func testACopyNeverGoesIntoItselfOrAPageThatCannotHoldPagesAndDeepCopiesAreCapped() throws {
        try folder("Boxing")
        try folder("Drills", in: "Boxing")
        try exercise("Jab", in: "Boxing")
        XCTAssertEqual(failure { _ = try self.call("duplicate_page", ["page": "Boxing", "parent": "Boxing"]) }?.code, "invalid_parent")
        XCTAssertEqual(failure { _ = try self.call("duplicate_page", ["page": "Boxing", "parent": "Boxing/Drills", "deep": true]) }?.code, "invalid_parent")
        XCTAssertEqual(failure { _ = try self.call("duplicate_page", ["page": "Boxing/Drills", "parent": "Boxing/Jab"]) }?.code, "invalid_parent")

        let bigID = try folder("Big")
        for number in 0..<14 {
            let sub = ExercisePageManifest(title: "Sub \(number)", pageKind: .container)
            try database.createPage(manifest: sub, parentID: bigID)
            for leaf in 0..<14 {
                try database.createPage(manifest: ExercisePageManifest(title: "Page \(leaf)", pageKind: .leaf, duration: 30), parentID: sub.id)
            }
        }
        let count = try AgentPageIndex(database: database).count
        let capped = failure { _ = try self.call("duplicate_page", ["page": "Big", "deep": true]) }
        XCTAssertEqual(capped?.code, "too_many_pages")
        XCTAssertNotNil(capped?.hint)
        XCTAssertEqual(try AgentPageIndex(database: database).count, count)
        XCTAssertEqual(try call("duplicate_page", ["page": "Big"])["path"] as? String, "Big Copy")
    }

    func testACopyOfARootFolderKeepsItsTypeAtTheTopAndInheritsWhenNested() throws {
        try folder("Yoga Flow", type: "Yoga")
        try folder("Boxing", type: "Strength")

        let inPlace = try call("duplicate_page", ["page": "Yoga Flow"])
        XCTAssertEqual(try titles(), ["Yoga Flow", "Yoga Flow Copy", "Boxing"])
        XCTAssertEqual(try call("get_page", ["page": inPlace["id"] as! String])["type"] as? String, "Yoga")

        let nested = try call("duplicate_page", ["page": "Yoga Flow", "parent": "Boxing"])
        XCTAssertNil(try database.getPage(id: nested["id"] as! String).workoutType)
        XCTAssertEqual(try call("get_page", ["page": nested["id"] as! String])["type"] as? String, "Strength")

        XCTAssertEqual(try titles(in: "Boxing"), ["Yoga Flow Copy"])
    }

    private func trashEntries() throws -> [[String: Any]] {
        try call("list_trash", ["limit": 500])["items"] as! [[String: Any]]
    }

    @discardableResult
    private func age(_ entry: String, seconds: Int) throws -> String {
        let trash = database.fs.trashDirectory
        let stamp = entry.prefix { $0.isNumber }
        let renamed = "\(Int(stamp)! - seconds)" + entry.dropFirst(stamp.count)
        try FileManager.default.moveItem(at: trash.appendingPathComponent(entry), to: trash.appendingPathComponent(renamed))
        return renamed
    }

    func testTheTrashListsDeletedPagesNewestFirstWithWhereTheyCameFrom() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross", "Hook"] { try exercise(name, in: "Boxing") }
        for name in ["Jab", "Cross", "Hook"] { try call("delete_page", ["page": "Boxing/\(name)"]) }
        var items = try trashEntries()
        XCTAssertEqual(items.count, 3)
        let byTitle = Dictionary(uniqueKeysWithValues: items.map { ($0["title"] as! String, $0["id"] as! String) })
        try age(byTitle["Jab"]!, seconds: 300)
        try age(byTitle["Cross"]!, seconds: 200)

        items = try trashEntries()
        XCTAssertEqual(items.map { $0["title"] as? String }, ["Hook", "Cross", "Jab"])
        XCTAssertEqual(items[0]["kind"] as? String, "exercise")
        XCTAssertEqual(items[0]["from"] as? String, "Boxing/Hook")
        XCTAssertNil(items[0]["parentMissing"])
        let formatter = ISO8601DateFormatter()
        let newest = try XCTUnwrap(formatter.date(from: items[0]["deleted"] as! String))
        let oldest = try XCTUnwrap(formatter.date(from: items[2]["deleted"] as! String))
        XCTAssertLessThan(abs(newest.timeIntervalSinceNow), 60)
        XCTAssertEqual(newest.timeIntervalSince(oldest), 300, accuracy: 2)

        let listed = try call("list_trash", ["limit": 2])
        XCTAssertEqual((listed["items"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(listed["more"] as? Int, 1)
        XCTAssertEqual(listed["total"] as? Int, 3)
        XCTAssertNil(try call("list_trash", [:])["more"])
    }

    func testAPageComesBackWithEverythingInsideItAndIsLinkedIntoItsParent() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        try folder("Drills", in: "Boxing")
        try exercise("Shadow", in: "Boxing/Drills")
        try exercise("Bag", in: "Boxing/Drills")
        try exercise("Cross", in: "Boxing")
        try call("delete_page", ["page": "Boxing/Drills"])
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Cross"])

        let listed = try XCTUnwrap(try trashEntries().first)
        XCTAssertEqual(listed["kind"] as? String, "container")
        XCTAssertEqual(listed["inside"] as? Int, 2)
        XCTAssertEqual(listed["from"] as? String, "Boxing/Drills")

        let output = try run("restore_from_trash", ["item": listed["id"] as! String])
        XCTAssertEqual(output.value["path"] as? String, "Boxing/Drills")
        XCTAssertEqual(output.value["restored"] as? Bool, true)
        XCTAssertEqual(output.value["inside"] as? Int, 2)
        XCTAssertNil(output.value["note"])
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Cross", "Drills"])
        XCTAssertEqual(Set(try titles(in: "Boxing/Drills")), ["Shadow", "Bag"])
        try assertDenseOrder(of: "Boxing")
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing")).childIDs.last, try pageID("Boxing/Drills"))
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing/Drills/Shadow")).parentID, try pageID("Boxing/Drills"))
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Drills/Bag"])["path"] as? String, "Boxing/Drills/Bag")
        XCTAssertTrue(try trashEntries().isEmpty)
    }

    func testRestoringByTheDeletedPagesIdWorksAndAnUndoPutsItBackInTheTrash() throws {
        try folder("Boxing")
        let jab = try exercise("Jab", in: "Boxing")
        try call("delete_page", ["page": jab])
        let preview = try call("restore_from_trash", ["item": jab], dryRun: true)
        XCTAssertEqual(preview["wouldRestore"] as? String, "Boxing/Jab")
        XCTAssertEqual(try trashEntries().count, 1)
        XCTAssertEqual(try titles(in: "Boxing"), [])

        let output = try run("restore_from_trash", ["item": jab])
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab"])
        XCTAssertEqual(output.effects, [.createdPage(id: jab)])
        toolbox.revert(output.effects)
        XCTAssertEqual(try titles(in: "Boxing"), [])
        XCTAssertEqual(try trashEntries().map { $0["title"] as? String }, ["Jab"])
        XCTAssertEqual(try database.getPage(id: try pageID("Boxing")).childIDs, [])
    }

    func testAPageWhoseFolderIsGoneReturnsToTheTopLevelAndTheResultSaysSo() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        try folder("Footwork")
        try call("delete_page", ["page": "Boxing/Jab"])
        try call("delete_page", ["page": "Boxing"])

        let jab = try XCTUnwrap(try trashEntries().first { $0["title"] as? String == "Jab" })
        XCTAssertNil(jab["from"])
        XCTAssertEqual(jab["parentMissing"] as? Bool, true)
        let output = try call("restore_from_trash", ["item": jab["id"] as! String])
        XCTAssertEqual(output["path"] as? String, "Jab")
        XCTAssertNotNil(output["note"])
        XCTAssertNil(try database.getPage(id: try pageID("Jab")).parentID)
        XCTAssertEqual(try titles(), ["Footwork", "Jab"])

        let boxing = try XCTUnwrap(try trashEntries().first { $0["title"] as? String == "Boxing" })
        try call("restore_from_trash", ["item": boxing["id"] as! String])
        XCTAssertEqual(try titles(), ["Footwork", "Jab", "Boxing"])
        XCTAssertEqual(try titles(in: "Boxing"), [])
    }

    func testAPageCanBeRestoredIntoAnotherContainerAndKeepsItsSkillStatusButLosesAGroupThatIsGone() throws {
        try folder("Wrestling")
        try folder("Archive")
        try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting", status: "learning")
        try call("delete_page", ["page": "Wrestling/Arm Drag"])
        try call("delete_skill_group", ["container": "Wrestling", "group": "Hand Fighting"])

        let entry = try XCTUnwrap(try trashEntries().first)
        let output = try call("restore_from_trash", ["item": entry["id"] as! String])
        XCTAssertEqual(output["path"] as? String, "Wrestling/Arm Drag")
        let page = try database.getPage(id: try pageID("Wrestling/Arm Drag"))
        XCTAssertNil(page.skillBoardSectionID)
        XCTAssertEqual(page.skillStatus, .learning)

        try call("delete_page", ["page": "Wrestling/Arm Drag"])
        let again = try XCTUnwrap(try trashEntries().first)
        let moved = try call("restore_from_trash", ["item": again["id"] as! String, "parent": "Archive"])
        XCTAssertEqual(moved["path"] as? String, "Archive/Arm Drag")
        XCTAssertEqual(try database.getPage(id: try pageID("Archive")).childIDs, [try pageID("Archive/Arm Drag")])
        XCTAssertEqual(failure { _ = try self.call("restore_from_trash", ["item": "nothing"]) }?.code, "not_found")
    }

    func testRestoringNeverOverwritesAndAnAmbiguousIdAsksForTheEntry() throws {
        try folder("Boxing")
        let jab = try exercise("Jab", in: "Boxing")
        try call("update_page", ["page": jab, "markdownBody": "Keep me"])
        try call("delete_page", ["page": jab])
        let entry = try XCTUnwrap(try trashEntries().first)["id"] as! String
        let trash = database.fs.trashDirectory
        try FileManager.default.copyItem(at: trash.appendingPathComponent(entry), to: trash.appendingPathComponent("2-copy-of-\(entry)"))

        let ambiguous = failure { _ = try self.call("restore_from_trash", ["item": jab]) }
        XCTAssertEqual(ambiguous?.code, "ambiguous")
        XCTAssertTrue(ambiguous?.hint?.contains(entry) == true)

        try call("restore_from_trash", ["item": entry])
        try call("update_page", ["page": jab, "markdownBody": "Edited since"])
        let blocked = failure { _ = try self.call("restore_from_trash", ["item": "2-copy-of-\(entry)"]) }
        XCTAssertEqual(blocked?.code, "already_exists")
        XCTAssertEqual(try database.getPage(id: jab).markdownBody, "Edited since")
        XCTAssertEqual(try trashEntries().count, 1)
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab"])
    }

    func testADeletedWorkoutIsListedAndComesBackIntoTheWorkouts() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        let workout = try call("build_workout", ["name": "Morning", "sections": [["exercise": "Boxing/Jab"]]])["id"] as! String
        try call("delete_workout", ["workout": "Morning"])
        XCTAssertTrue(try database.listWorkouts().isEmpty)

        let item = try XCTUnwrap(try trashEntries().first)
        XCTAssertEqual(item["kind"] as? String, "workout")
        XCTAssertEqual(item["title"] as? String, "Morning")
        XCTAssertNil(item["from"])
        XCTAssertEqual(failure { _ = try self.call("restore_from_trash", ["item": item["id"] as! String, "parent": "Boxing"]) }?.code, "invalid_argument")

        let output = try run("restore_from_trash", ["item": item["id"] as! String])
        XCTAssertEqual(output.value["name"] as? String, "Morning")
        XCTAssertEqual(try database.listWorkouts().map(\.id), [workout])
        XCTAssertEqual(try database.getWorkout(id: workout).name, "Morning")
        XCTAssertTrue(try trashEntries().isEmpty)
        toolbox.revert(output.effects)
        XCTAssertTrue(try database.listWorkouts().isEmpty)
        XCTAssertEqual(try trashEntries().count, 1)

        try call("restore_from_trash", ["item": workout])
        try call("build_workout", ["name": "Evening", "sections": [["exercise": "Boxing/Jab"]]])
        XCTAssertEqual(try database.listWorkouts().count, 2)
    }

    func testTheTrashListsOnlyPagesAndWorkoutsNotTheLeftoversOfEdits() throws {
        try folder("Boxing")
        let jab = try call("create_exercise_page", ["title": "Jab", "parent": "Boxing", "media": [["path": try file("a.mp4")]]])["id"] as! String
        try call("build_workout", ["name": "Morning", "sections": [["exercise": jab]]])
        var workout = try XCTUnwrap(try database.listWorkouts().first)
        workout.name = "Morning Edited"
        try database.updateWorkout(id: workout.id, manifest: workout)
        try database.removeMediaFromPage(pageID: jab, filename: try database.getPage(id: jab).mediaFilenames[0])
        let trash = database.fs.trashDirectory
        let activity = trash.appendingPathComponent("1700000000-ACTIVITY", isDirectory: true)
        try FileManager.default.createDirectory(at: activity, withIntermediateDirectories: true)
        try Data(#"{"id":"ACTIVITY","kind":"run","title":"Run","startedAt":"2026-01-01T00:00:00Z"}"#.utf8).write(to: activity.appendingPathComponent("manifest.json"))
        XCTAssertGreaterThanOrEqual(try FileManager.default.contentsOfDirectory(atPath: trash.path).count, 3)
        XCTAssertEqual(try trashEntries().count, 0)

        try call("delete_page", ["page": jab])
        XCTAssertEqual(try trashEntries().map { $0["title"] as? String }, ["Jab"])
    }

    func testRiskLevelsAndTheSkillDocumentFollowTheContract() throws {
        XCTAssertEqual(AgentToolRegistry.tool(named: "list_trash")?.risk, .read)
        XCTAssertEqual(AgentToolRegistry.tool(named: "delete_skill_group")?.risk, .delete)
        for name in ["reorder_pages", "update_skill", "update_skill_group", "duplicate_page", "restore_from_trash", "move_page"] {
            XCTAssertEqual(AgentToolRegistry.tool(named: name)?.risk, .write, name)
        }
        XCTAssertFalse(AgentToolRegistry.tools.contains { $0.name.contains("empty_trash") || $0.name.contains("purge") })
        let guide = try String(contentsOf: database.fs.skillsDirectory.appendingPathComponent("organize-library.md"), encoding: .utf8)
        for name in ["reorder_pages", "update_skill", "update_skill_group", "delete_skill_group", "duplicate_page", "list_trash", "restore_from_trash"] {
            XCTAssertTrue(guide.contains("tmax \(name)"), name)
        }
    }

    func testACopyKeepsAToDoCoverAndAGroupsFilesBecauseMediaKeepTheirNames() throws {
        try folder("Wrestling")
        let skillID = try skill("Arm Drag", in: "Wrestling", group: "Hand Fighting")
        try call("attach_media", ["page": skillID, "path": try file("cover.jpg"), "comment": "the grip"])
        try call("add_todo", ["page": "Wrestling/Arm Drag", "title": "Drill it", "cover": "1"])
        let boardID = try pageID("Wrestling")
        let section = try XCTUnwrap(try database.getPage(id: boardID).skillBoardSections.first)
        let groupFile = try database.uploadMediaToPage(pageID: SkillGroupID.make(containerID: boardID, sectionID: section.id), sourceURL: URL(fileURLWithPath: try file("group.jpg")))

        let copy = try database.getPage(id: try call("duplicate_page", ["page": "Wrestling/Arm Drag"])["id"] as! String)
        let original = try database.getPage(id: skillID)
        XCTAssertNotNil(copy.todos.first?.coverMediaFilename)
        XCTAssertEqual(copy.todos.first?.coverMediaFilename, original.mediaFilenames.first)
        XCTAssertEqual(copy.mediaComments.values.sorted(), ["the grip"])

        let boardCopy = try call("duplicate_page", ["page": "Wrestling"])["id"] as! String
        let groupMedia = SkillGroupID.mediaFolder(containerFolder: try database.resolvePageFolder(id: boardCopy), sectionID: section.id).appendingPathComponent(groupFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: groupMedia.path))
        XCTAssertEqual(try database.getPage(id: boardCopy).skillBoardSections.first?.mediaFilenames, [groupFile])
    }

    func testNamingTheOriginalsOwnContainerCopiesRightAfterItToo() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross"] { try exercise(name, in: "Boxing") }
        let output = try call("duplicate_page", ["page": "Boxing/Jab", "parent": "Boxing"])
        XCTAssertEqual(output["path"] as? String, "Boxing/Jab Copy")
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Jab Copy", "Cross"])
    }

    func testANoteComesBackFromTheTrashWithItsPictures() throws {
        try folder("Boxing")
        let id = try call("create_note_page", ["title": "Theory", "parent": "Boxing", "images": [try file("diagram.jpg")]])["id"] as! String
        let names = try database.noteAttachmentNames(pageID: id)
        XCTAssertEqual(try call("list_trash", [:])["total"] as? Int, 0)
        try call("delete_page", ["page": id])
        XCTAssertEqual(try trashEntries().first?["kind"] as? String, "note")
        try call("restore_from_trash", ["item": id])
        XCTAssertEqual(try database.noteAttachmentNames(pageID: id), names)
        XCTAssertEqual(try call("get_page", ["page": "Boxing/Theory"])["kind"] as? String, "note")
    }

    func testRestoringIntoAPageThatCannotHoldPagesIsRefusedAndNothingMoves() throws {
        try folder("Boxing")
        try exercise("Jab", in: "Boxing")
        let cross = try exercise("Cross", in: "Boxing")
        try call("delete_page", ["page": cross])
        XCTAssertEqual(failure { _ = try self.call("restore_from_trash", ["item": cross, "parent": "Boxing/Jab"]) }?.code, "invalid_parent")
        XCTAssertEqual(try trashEntries().count, 1)
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab"])
    }

    func testABatchRollsBackACopyAndAMoveWhenALaterStepFails() throws {
        try folder("Boxing")
        for name in ["Jab", "Cross"] { try exercise(name, in: "Boxing") }
        try folder("Footwork")
        try exercise("Step", in: "Footwork")
        let error = failure {
            _ = try self.call("batch", ["operations": [
                ["tool": "duplicate_page", "arguments": ["page": "Boxing/Jab"]],
                ["tool": "move_page", "arguments": ["page": "$0.id", "newParent": "Footwork", "position": 1]],
                ["tool": "update_skill", "arguments": ["page": "Boxing", "status": "learning"]],
            ]])
        }
        XCTAssertEqual(error?.code, "batch_failed")
        XCTAssertEqual(try titles(in: "Boxing"), ["Jab", "Cross"])
        XCTAssertEqual(try titles(in: "Footwork"), ["Step"])
        XCTAssertEqual(try trashEntries().map { $0["title"] as? String }, ["Jab Copy"])
    }
}
