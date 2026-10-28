import XCTest
@testable import TimeMasterCore

final class AgentToolboxTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("agent-\(UUID().uuidString)", isDirectory: true)
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

    private func media(_ name: String, bytes: Int = 64) throws -> String {
        let url = root.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try Data(repeating: 7, count: bytes).write(to: file)
        return file.path
    }

    private func makeLibrary() throws -> (folder: String, exercise: String) {
        let folder = try call("create_container_page", ["title": "Lower Body", "workoutType": "Strength"])["id"] as! String
        let exercise = try call("create_exercise_page", ["title": "Squat", "parent": folder, "duration": 40])["id"] as! String
        return (folder, exercise)
    }

    private func failure(_ block: () throws -> Void) -> AgentToolError? {
        do { try block(); return nil } catch { return error as? AgentToolError }
    }

    func testCreatedExerciseIsVisibleToSearchAndTheCoachContext() throws {
        let ids = try makeLibrary()
        let found = try call("search_pages", ["query": "squat"])
        XCTAssertEqual((found["results"] as! [[String: Any]]).first?["path"] as? String, "Lower Body/Squat")
        let context = try AISystemPromptBuilder(fs: FileSystemHelper(dataRoot: root)).buildSessionContext(db: database)
        XCTAssertEqual(context.database.totalExercises, 1)
        XCTAssertEqual(context.database.byType["Strength"], 1)
        XCTAssertEqual(context.database.folders, ["Lower Body"])
        XCTAssertEqual(try database.getPage(id: ids.exercise).pageType, .exercise)
    }

    func testReferencesAcceptTitlePathsAndReportAmbiguity() throws {
        let ids = try makeLibrary()
        let page = try call("get_page", ["page": "lower body/SQUAT"])
        XCTAssertEqual(page["id"] as? String, ids.exercise)
        XCTAssertEqual(try call("get_page", ["page": "Squat"])["id"] as? String, ids.exercise)
        let other = try call("create_container_page", ["title": "Upper Body", "workoutType": "Strength"])["id"] as! String
        try call("create_exercise_page", ["title": "Squat", "parent": other])
        let error = failure { _ = try self.call("get_page", ["page": "Squat"]) }
        XCTAssertEqual(error?.code, "ambiguous")
        XCTAssertTrue(error?.hint?.contains("Upper Body/Squat") == true)
        XCTAssertEqual(failure { _ = try self.call("get_page", ["page": "Lunge"]) }?.code, "not_found")
    }

    func testRootPagesOwnTheTypeAndNestedPagesInheritIt() throws {
        let ids = try makeLibrary()
        let nested = try toolbox.call("create_exercise_page", arguments: ["title": "Lunge", "parent": ids.folder, "workoutType": "Yoga"])
        XCTAssertEqual((nested.value["warnings"] as? [String])?.count, 1)
        XCTAssertEqual(try call("get_page", ["page": nested.value["id"] as! String])["type"] as? String, "Strength")
        XCTAssertEqual(failure { _ = try self.call("create_container_page", ["title": "X", "workoutType": "Nonsense"]) }?.code, "unknown_workout_type")
    }

    func testDuplicateTitlesAreRefusedUnlessRequested() throws {
        let ids = try makeLibrary()
        let error = failure { _ = try self.call("create_exercise_page", ["title": " squat ", "parent": ids.folder]) }
        XCTAssertEqual(error?.code, "already_exists")
        XCTAssertEqual(error?.details["existingID"] as? String, ids.exercise)
        let reused = try call("create_exercise_page", ["title": "Squat", "parent": ids.folder, "ifExists": "reuse"])
        XCTAssertEqual(reused["id"] as? String, ids.exercise)
        XCTAssertEqual(reused["reused"] as? Bool, true)
        try call("create_exercise_page", ["title": "Squat", "parent": ids.folder, "ifExists": "duplicate"])
        XCTAssertEqual(try call("search_pages", ["query": "squat", "kind": "exercise"])["total"] as? Int, 2)
    }

    func testExercisePagesCannotContainChildren() throws {
        let ids = try makeLibrary()
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Deep", "parent": ids.exercise]) }?.code, "invalid_parent")
    }

    func testAttachMediaCopiesTheFileAndCoverFollowsOrder() throws {
        let ids = try makeLibrary()
        let first = try call("attach_media", ["page": ids.exercise, "path": try media("a.jpg"), "comment": "Setup"])
        let second = try call("attach_media", ["page": ids.exercise, "path": try media("b.mp4")])
        var page = try database.getPage(id: ids.exercise)
        XCTAssertEqual(page.mediaFilenames.count, 2)
        XCTAssertEqual(first["attached"] as? String, "image")
        XCTAssertEqual(page.mediaComments[page.mediaFilenames[0]], "Setup")
        XCTAssertEqual(second["attached"] as? String, "video")
        try call("attach_media", ["page": ids.exercise, "path": try media("c.png"), "makeCover": true])
        page = try database.getPage(id: ids.exercise)
        XCTAssertEqual(AgentMedia.kind(ofFilename: page.mediaFilenames[0]), "image")
        XCTAssertEqual(page.mediaFilenames.count, 3)
        let stored = try database.pageMediaURL(pageID: ids.exercise, filename: page.mediaFilenames[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
    }

    func testMediaPathsAreValidatedBeforeAnythingIsWritten() throws {
        let ids = try makeLibrary()
        XCTAssertEqual(failure { _ = try self.call("attach_media", ["page": ids.exercise, "path": "relative/a.jpg"]) }?.code, "invalid_path")
        XCTAssertEqual(failure { _ = try self.call("attach_media", ["page": ids.exercise, "path": try self.media("notes.txt")]) }?.code, "unsupported_media")
        XCTAssertEqual(failure { _ = try self.call("attach_media", ["page": ids.exercise, "path": self.root.path + "/missing.jpg"]) }?.code, "file_not_found")
        let before = try AgentPageIndex(database: database).count
        let error = failure {
            _ = try self.call("create_exercise_page", ["title": "Plank", "media": [["path": try self.media("ok.jpg")], ["path": "nope.mp4"]]])
        }
        XCTAssertEqual(error?.code, "invalid_path")
        XCTAssertEqual(try AgentPageIndex(database: database).count, before)
    }

    func testCreateWithMediaAttachesEveryItemWithCaptions() throws {
        let created = try call("create_exercise_page", ["title": "Plank", "media": [["path": try media("p1.mp4"), "comment": "Front"], ["path": try media("p2.jpg")]]])
        let page = try database.getPage(id: created["id"] as! String)
        XCTAssertEqual(page.mediaFilenames.count, 2)
        XCTAssertEqual(page.mediaComments[page.mediaFilenames[0]], "Front")
    }

    func testNotesSurviveLaterPageUpdates() throws {
        let ids = try makeLibrary()
        try call("add_page_note", ["page": ids.exercise, "note": "Keep chest up"])
        try call("update_page", ["page": ids.exercise, "duration": 55])
        let page = try database.getPage(id: ids.exercise)
        XCTAssertTrue(page.markdownBody.contains("Keep chest up"))
        XCTAssertEqual(page.duration, 55)
        let guide = try database.readGuideContent(pageID: ids.exercise)
        XCTAssertTrue(guide.contains("Keep chest up"))
    }

    func testUpdateRejectsInvalidChangesAndEmptyRequests() throws {
        let ids = try makeLibrary()
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": ids.exercise]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": ids.folder, "duration": 30]) }?.code, "invalid_page")
        XCTAssertEqual(failure { _ = try self.call("update_page", ["page": ids.exercise, "workoutType": "Yoga"]) }?.code, "invalid_page")
    }

    func testMoveAndDeleteKeepTheTreeConsistent() throws {
        let ids = try makeLibrary()
        let other = try call("create_container_page", ["title": "Core", "workoutType": "Strength"])["id"] as! String
        try call("move_page", ["page": ids.exercise, "newParent": other])
        XCTAssertEqual(try call("get_page", ["page": ids.exercise])["path"] as? String, "Core/Squat")
        XCTAssertEqual(failure { _ = try self.call("move_page", ["page": other, "newParent": other]) }?.code, "invalid_parent")
        let removed = try call("delete_page", ["page": other])
        XCTAssertEqual(removed["inside"] as? Int, 1)
        XCTAssertEqual(removed["trashed"] as? String, "Core")
        XCTAssertEqual(failure { _ = try self.call("get_page", ["page": ids.exercise]) }?.code, "not_found")
    }

    func testBuildWorkoutResolvesExercisesAndRejectsFolders() throws {
        let ids = try makeLibrary()
        let built = try call("build_workout", ["name": "Legs", "type": "strength", "sections": [["exercise": "Lower Body/Squat", "sets": 3], ["exercise": ids.exercise, "duration": 20]]])
        XCTAssertEqual(built["sections"] as? Int, 2)
        let workout = try database.getWorkout(id: built["id"] as! String)
        XCTAssertEqual(workout.sections.map(\.exerciseID), [ids.exercise, ids.exercise])
        XCTAssertEqual(workout.sections[0].duration, 40)
        XCTAssertEqual(workout.sections[0].sets, 3)
        XCTAssertEqual(workout.sections[1].duration, 20)
        XCTAssertEqual(try call("get_workout", ["workout": "legs"])["id"] as? String, built["id"] as? String)
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["exercise": "Lower Body"]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "None", "sections": [] as [Any]]) }?.code, "invalid_argument")
    }

    func testWorkoutRestsAreExplicitSoReportedTotalsSurviveTheAppReload() throws {
        let ids = try makeLibrary()
        let built = try call("build_workout", ["name": "Legs", "restBetweenSections": 20, "sections": [["exercise": ids.exercise], ["exercise": ids.exercise], ["exercise": ids.exercise]]])
        let stored = try database.getWorkout(id: built["id"] as! String)
        XCTAssertEqual(stored.sections.map { $0.bigRestRow?.duration }, [20, 20, 0])
        XCTAssertEqual(stored.totalDuration, built["totalSeconds"] as? Int)
        let listed = (try call("list_workouts", [:])["workouts"] as! [[String: Any]]).first
        XCTAssertEqual(listed?["totalSeconds"] as? Int, built["totalSeconds"] as? Int)
        XCTAssertNil(listed?["id"])
    }

    func testListingsAreBoundedAndResultsOmitEmptyFields() throws {
        let ids = try makeLibrary()
        let created = try call("create_exercise_page", ["title": "Plain", "parent": ids.folder])
        XCTAssertEqual(Set(created.keys), ["id", "path"])
        for number in 0..<70 { _ = try call("create_exercise_page", ["title": "Move \(number)", "parent": ids.folder]) }
        let listing = try call("list_pages", ["parent": ids.folder])
        XCTAssertEqual((listing["pages"] as! [[String: Any]]).count, 60)
        XCTAssertEqual(listing["more"] as? Int, 12)
        XCTAssertNil((listing["pages"] as! [[String: Any]])[0]["id"])
        XCTAssertNil((listing["pages"] as! [[String: Any]])[0]["media"])
        let search = try call("search_pages", ["query": "move"])
        XCTAssertEqual((search["results"] as! [[String: Any]]).count, 20)
        XCTAssertEqual(search["total"] as? Int, 70)
        XCTAssertEqual(search["more"] as? Int, 50)
        XCTAssertTrue(AgentJSON.string(["path": "Lower Body/Squat"]).contains("Lower Body/Squat"))
    }

    func testListingsShowAnIdOnlyWhenAPathIsAmbiguous() throws {
        let ids = try makeLibrary()
        try call("create_exercise_page", ["title": "Squat", "parent": ids.folder, "ifExists": "duplicate"])
        try call("create_exercise_page", ["title": "Lunge", "parent": ids.folder])
        let rows = try call("list_pages", ["parent": ids.folder])["pages"] as! [[String: Any]]
        XCTAssertTrue(rows.filter { $0["path"] as? String == "Lower Body/Squat" }.allSatisfy { $0["id"] != nil })
        XCTAssertNil(rows.first { $0["path"] as? String == "Lower Body/Lunge" }?["id"])
    }

    func testNotFoundSuggestsTheClosestTitleForATypo() throws {
        let ids = try makeLibrary()
        let error = failure { _ = try self.call("get_page", ["page": "Lower Body/Sqaut"]) }
        XCTAssertEqual(error?.code, "not_found")
        XCTAssertTrue(error?.hint?.contains("Lower Body/Squat (\(ids.exercise))") == true)
    }

    func testDryRunValidatesWithoutWriting() throws {
        let ids = try makeLibrary()
        let before = try AgentPageIndex(database: database).count
        let preview = try call("create_exercise_page", ["title": "Row", "parent": ids.folder], dryRun: true)
        XCTAssertEqual(preview["dryRun"] as? Bool, true)
        XCTAssertEqual(try AgentPageIndex(database: database).count, before)
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Row", "parent": "Missing"], dryRun: true) }?.code, "not_found")
        _ = try call("build_workout", ["name": "W", "sections": [["exercise": ids.exercise]]], dryRun: true)
        XCTAssertTrue(try database.listWorkouts().isEmpty)
    }

    func testArgumentsAreCoercedAndUnknownKeysAreRejected() throws {
        let created = try call("create_exercise_page", ["title": "Dip", "duration": "45", "sets": 3.0])
        let page = try database.getPage(id: created["id"] as! String)
        XCTAssertEqual(page.duration, 45)
        XCTAssertEqual(page.sets, 3)
        let unknown = failure { _ = try self.call("create_exercise_page", ["name": "Dip"]) }
        XCTAssertEqual(unknown?.code, "invalid_argument")
        XCTAssertTrue(unknown?.hint?.contains("title") == true)
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Dip", "duration": "fast"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Dip", "duration": 1]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": "Dip", "ifExists": "maybe"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("create_exercise_page", ["title": true]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("list_workouts", ["extra": 1]) }?.hint, "This tool takes no arguments.")
    }

    func testBatchChainsResultsAndRollsBackOnFailure() throws {
        let result = try call("batch", ["operations": [
            ["tool": "create_container_page", "arguments": ["title": "Mobility", "workoutType": "Stretch"]],
            ["tool": "create_exercise_page", "arguments": ["title": "Cat-Cow", "parent": "$0.id", "media": [["path": try media("cc.mp4")]]]],
            ["tool": "build_workout", "arguments": ["name": "Flow", "sections": [["exercise": "$1.id"]]]],
        ]])
        XCTAssertEqual((result["results"] as! [Any]).count, 3)
        XCTAssertEqual((try call("get_page", ["page": "Mobility/Cat-Cow"])["media"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(try database.listWorkouts().count, 1)

        let before = try AgentPageIndex(database: database).count
        let error = failure {
            _ = try self.call("batch", ["operations": [
                ["tool": "create_container_page", "arguments": ["title": "Temp"]],
                ["tool": "create_exercise_page", "arguments": ["title": "Inner", "parent": "$0.id"]],
                ["tool": "attach_media", "arguments": ["page": "$1.id", "path": "missing.jpg"]],
            ]])
        }
        XCTAssertEqual(error?.code, "batch_failed")
        XCTAssertEqual(error?.details["index"] as? Int, 2)
        XCTAssertEqual(error?.details["cause"] as? String, "invalid_path")
        XCTAssertEqual(try AgentPageIndex(database: database).count, before)
        XCTAssertEqual(failure { _ = try self.call("batch", ["operations": [["tool": "batch"]]]) }?.code, "batch_failed")
    }

    func testBatchDryRunDefersOperationsThatNeedEarlierResults() throws {
        let result = try call("batch", ["operations": [
            ["tool": "create_container_page", "arguments": ["title": "Plan"]],
            ["tool": "create_exercise_page", "arguments": ["title": "Step", "parent": "$0.id", "duration": "$0.duration"]],
        ]], dryRun: true)
        let results = result["results"] as! [[String: Any]]
        XCTAssertEqual(results[1]["deferred"] as? Bool, true)
        XCTAssertEqual(try AgentPageIndex(database: database).count, 0)
    }

    func testBatchRiskIsTheHighestRiskOfItsOperations() {
        let writes: [String: Any] = ["operations": [["tool": "create_container_page"], ["tool": "update_page"], ["tool": "move_page"]]]
        let deleting: [String: Any] = ["operations": [["tool": "create_container_page"], ["tool": "delete_page"]]]
        XCTAssertEqual(AgentToolRegistry.effectiveRisk(of: "batch", arguments: writes), .write)
        XCTAssertEqual(AgentToolRegistry.effectiveRisk(of: "batch", arguments: deleting), .delete)
        XCTAssertEqual(AgentToolRegistry.effectiveRisk(of: "list_pages", arguments: [:]), .read)
        XCTAssertEqual(AgentToolRegistry.effectiveRisk(of: "mystery", arguments: [:]), .delete)
    }

    func testOnlyDeletingToolsRequireApproval() {
        let deleting = AgentToolRegistry.tools.filter { $0.risk == .delete }.map(\.name).sorted()
        XCTAssertEqual(deleting, ["delete_page", "delete_workout"])
        XCTAssertEqual(AgentToolRegistry.tool(named: "update_page")?.risk, .write)
        XCTAssertEqual(AgentToolRegistry.tool(named: "move_page")?.risk, .write)
        XCTAssertEqual(AgentToolRegistry.tool(named: "update_settings")?.risk, .write)
    }

    func testRevertUndoesCreationsAttachmentsAndNotes() throws {
        let ids = try makeLibrary()
        let created = try toolbox.call("create_exercise_page", arguments: ["title": "Row", "parent": ids.folder])
        let attached = try toolbox.call("attach_media", arguments: ["page": ids.exercise, "path": try media("r.jpg")])
        let noted = try toolbox.call("add_page_note", arguments: ["page": ids.exercise, "note": "temp"])
        let workout = try toolbox.call("build_workout", arguments: ["name": "Tmp", "sections": [["exercise": ids.exercise]]])
        toolbox.revert(created.effects + attached.effects + noted.effects + workout.effects)
        XCTAssertEqual(failure { _ = try self.call("get_page", ["page": "Lower Body/Row"]) }?.code, "not_found")
        let page = try database.getPage(id: ids.exercise)
        XCTAssertTrue(page.mediaFilenames.isEmpty)
        XCTAssertFalse(page.markdownBody.contains("temp"))
        XCTAssertTrue(try database.listWorkouts().isEmpty)
    }

    func testContextDescribesTheLibraryAndConventions() throws {
        _ = try makeLibrary()
        let context = try call("context", [:])
        let library = context["library"] as! [String: Any]
        XCTAssertEqual(library["exercises"] as? Int, 1)
        XCTAssertEqual((library["roots"] as! [[String: Any]]).first?["exercises"] as? Int, 1)
        XCTAssertFalse((context["conventions"] as! [String]).isEmpty)
        XCTAssertTrue((context["types"] as! [String]).contains("Stretch"))
    }

    func testListPagesHonorsDepthAndOrder() throws {
        let ids = try makeLibrary()
        try call("create_exercise_page", ["title": "Lunge", "parent": ids.folder])
        let shallow = try call("list_pages", [:])
        XCTAssertNil((shallow["pages"] as! [[String: Any]])[0]["pages"])
        let deep = try call("list_pages", ["depth": 2])
        let children = (deep["pages"] as! [[String: Any]])[0]["pages"] as! [[String: Any]]
        XCTAssertEqual(children.map { $0["path"] as? String }, ["Lower Body/Squat", "Lower Body/Lunge"])
    }

    func testAppOnlyToolsAreNotExecutedByTheLibraryToolbox() {
        XCTAssertEqual(failure { _ = try self.call("import_video", ["source": "https://example.com/v"]) }?.code, "wrong_executor")
        XCTAssertEqual(failure { _ = try self.call("no_such_tool", [:]) }?.code, "unknown_tool")
        XCTAssertTrue(failure { _ = try self.call("create_exercize_page", [:]) }?.hint?.contains("create_exercise_page") == true)
    }
}

final class AgentWireTests: XCTestCase {
    func testOpenAIToolTurnEchoesCallsAndPairsResults() {
        let calls = [AgentToolCall(id: "c1", name: "search_pages", arguments: ["query": "squat"]), AgentToolCall(id: "c2", name: "get_stats", arguments: [:])]
        let assistant = AgentWire.openAIAssistantMessage(text: "", calls: calls)
        let echoed = assistant["tool_calls"] as! [[String: Any]]
        XCTAssertEqual(echoed.map { $0["id"] as? String }, ["c1", "c2"])
        XCTAssertNil(assistant["content"])
        let arguments = (echoed[0]["function"] as! [String: Any])["arguments"] as! String
        XCTAssertEqual(try JSONSerialization.jsonObject(with: Data(arguments.utf8)) as? [String: String], ["query": "squat"])
        XCTAssertEqual(AgentWire.toolMessage(callID: "c1", content: "ok")["tool_call_id"] as? String, "c1")
    }

    func testTruncatedArgumentsNeverBecomeAnEmptyToolCall() {
        let message: [String: Any] = ["tool_calls": [
            ["id": "a", "function": ["name": "build_workout", "arguments": "{\"name\":\"Legs\",\"sections\":[{\"exerc"]],
            ["id": "b", "function": ["name": "get_stats", "arguments": ""]],
            ["id": "c", "function": ["name": "search_pages", "arguments": "{\"query\":\"row\"}"]],
        ]]
        let parsed = AgentWire.parseOpenAI(message: message)
        XCTAssertEqual(parsed.calls[0].argumentError, AgentWire.truncatedArguments)
        XCTAssertNil(parsed.calls[1].argumentError)
        XCTAssertEqual(parsed.calls[2].arguments["query"] as? String, "row")
    }

    func testAnthropicConversionUsesToolUseAndMergesResultsIntoOneTurn() {
        let calls = [AgentToolCall(id: "t1", name: "search_pages", arguments: ["query": "a"]), AgentToolCall(id: "t2", name: "get_stats", arguments: [:])]
        let messages: [[String: Any]] = [
            ["role": "system", "content": "Be brief."],
            ["role": "user", "content": "find"],
            AgentWire.openAIAssistantMessage(text: "Looking.", calls: calls),
            AgentWire.toolMessage(callID: "t1", content: "one"),
            AgentWire.toolMessage(callID: "t2", content: "two"),
        ]
        let request = AgentWire.anthropicRequest(from: messages)
        XCTAssertEqual(request.system, "Be brief.")
        XCTAssertEqual(request.messages.map { $0["role"] as? String }, ["user", "assistant", "user"])
        let blocks = request.messages[1]["content"] as! [[String: Any]]
        XCTAssertEqual(blocks.map { $0["type"] as? String }, ["text", "tool_use", "tool_use"])
        XCTAssertEqual((blocks[1]["input"] as? [String: String]), ["query": "a"])
        let results = request.messages[2]["content"] as! [[String: Any]]
        XCTAssertEqual(results.map { $0["tool_use_id"] as? String }, ["t1", "t2"])
        XCTAssertEqual(results.map { $0["type"] as? String }, ["tool_result", "tool_result"])
    }

    func testAnthropicRequestNeverStartsWithAnAssistantTurn() {
        let request = AgentWire.anthropicRequest(from: [["role": "assistant", "content": "Hi"], ["role": "user", "content": "Hello"]])
        XCTAssertEqual(request.messages.first?["role"] as? String, "user")
    }

    func testParseAnthropicCollectsTextAndToolUse() {
        let parsed = AgentWire.parseAnthropic(content: [["type": "text", "text": "Sure"], ["type": "tool_use", "id": "u", "name": "list_pages", "input": ["depth": 2]]])
        XCTAssertEqual(parsed.text, "Sure")
        XCTAssertEqual(parsed.calls.first?.arguments["depth"] as? Int, 2)
    }

    func testCoachDefinitionsExposeEveryCoachToolWithoutExternalFields() throws {
        let definitions = AgentToolRegistry.openAIDefinitions()
        let names = definitions.compactMap { ($0["function"] as? [String: Any])?["name"] as? String }
        XCTAssertEqual(Set(names), Set(AgentToolRegistry.tools.filter(\.coach).map(\.name)))
        XCTAssertTrue(names.contains("create_exercise_page"))
        XCTAssertTrue(names.contains("create_container_page"))
        XCTAssertFalse(names.contains("attach_media"))
        let data = try JSONSerialization.data(withJSONObject: definitions)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("x-path"))
        XCTAssertFalse(text.contains("x-external"))
        XCTAssertFalse(text.contains("\"media\""))
        XCTAssertEqual(AgentToolRegistry.anthropicDefinitions().count, definitions.count)
    }

    func testCatalogKeepsTheExternalFieldsAndIsStable() throws {
        let create = AgentToolRegistry.tool(named: "create_exercise_page")!
        XCTAssertNotNil(create.properties["media"])
        let item = (create.properties["media"]?["items"] as? [String: Any])?["properties"] as? [String: [String: Any]]
        XCTAssertEqual(item?["path"]?["x-path"] as? Bool, true)
        XCTAssertEqual(AgentToolRegistry.schemaVersion, AgentToolRegistry.schemaVersion)
        XCTAssertEqual(AgentToolRegistry.tools.count, Set(AgentToolRegistry.tools.map(\.name)).count)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: AgentToolRegistry.catalog()))
        for tool in AgentToolRegistry.tools {
            let names = Set(tool.properties.keys)
            XCTAssertTrue(Set(tool.required).isSubset(of: names), tool.name)
        }
    }

    func testApprovalTextNamesWhatWillChange() {
        XCTAssertEqual(AgentApproval.summary(tool: "create_exercise_page", arguments: ["title": "Row", "parent": "Back"]), "Create exercise “Row” in Back")
        XCTAssertEqual(AgentApproval.summary(tool: "delete_page", arguments: ["page": "Core"]), "Move “Core” and everything inside it to the trash")
        XCTAssertEqual(AgentApproval.details(tool: "build_workout", arguments: ["sections": [[:], [:]], "name": "Legs"])["Sections"], "2 items")
    }
}
