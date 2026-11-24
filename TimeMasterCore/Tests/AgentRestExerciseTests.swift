import XCTest
@testable import TimeMasterCore

final class AgentRestExerciseTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var wristID = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("rest-exercise-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Calisthenics", "workoutType": "Strength"])["id"] as! String
        for (title, duration) in [("Dips", 40), ("Rows", 40), ("Wrist Circles", 30), ("Long Hold", 90)] {
            let id = try call("create_exercise_page", ["title": title, "parent": folder, "duration": duration])["id"] as! String
            if title == "Wrist Circles" { wristID = id }
        }
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

    private func stored(_ name: String) throws -> WorkoutManifest {
        let id = try call("get_workout", ["workout": name])["id"] as! String
        return try database.getWorkout(id: id)
    }

    private func dips(_ extra: [String: Any] = [:]) -> [String: Any] {
        var section: [String: Any] = ["exercise": "Calisthenics/Dips", "sets": 3, "restBetweenSets": 90, "restAfter": 45]
        for (key, value) in extra { section[key] = value }
        return section
    }

    private func build(_ name: String, _ first: [String: Any]) throws {
        try call("build_workout", ["name": name, "sections": [first, ["exercise": "Calisthenics/Rows"]]])
    }

    func testSectionToolsOfferBothRestExerciseArguments() throws {
        for name in ["add_workout_section", "update_workout_section"] {
            let tool = try XCTUnwrap(AgentToolRegistry.tool(named: name))
            XCTAssertEqual(tool.properties["restExercise"]?["type"] as? String, "array", name)
            XCTAssertEqual(tool.properties["restAfterExercise"]?["type"] as? String, "array", name)
        }
        let build = try XCTUnwrap(AgentToolRegistry.tool(named: "build_workout"))
        let item = try XCTUnwrap(build.properties["sections"]?["items"] as? [String: Any])
        let properties = try XCTUnwrap(item["properties"] as? [String: [String: Any]])
        XCTAssertNotNil(properties["restExercise"])
        XCTAssertNotNil(properties["restAfterExercise"])
    }

    func testARestExerciseFillsEveryRestBetweenSetsButTheLastSet() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))

        let section = try stored("Pull day").sections[0]
        XCTAssertEqual(section.restExerciseID, wristID)
        XCTAssertEqual(section.bigRestRow?.exerciseID, wristID)
        XCTAssertEqual(section.bigRestRow?.duration, 45)
        XCTAssertEqual(section.playbackSlots().map(\.restExerciseID), [wristID, wristID, nil])
    }

    func testARestExerciseDoesNotChangeHowLongTheWorkoutTakes() throws {
        try build("With", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))
        try build("Without", dips())

        XCTAssertEqual(try stored("With").totalDuration, try stored("Without").totalDuration)
    }

    func testGetWorkoutNamesTheRestExercises() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))

        let sections = try XCTUnwrap(try call("get_workout", ["workout": "Pull day"])["sections"] as? [[String: Any]])
        XCTAssertEqual(sections[0]["restExercise"] as? String, "Calisthenics/Wrist Circles")
        XCTAssertEqual(sections[0]["restAfterExercise"] as? String, "Calisthenics/Wrist Circles")
        XCTAssertNil(sections[1]["restExercise"])
    }

    func testTheManifestKeepsRestExercisesAndReadsOlderFilesWithoutThem() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))
        let workout = try stored("Pull day")

        let data = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(WorkoutManifest.self, from: data)
        XCTAssertEqual(decoded.sections[0].restExerciseID, wristID)
        XCTAssertEqual(decoded.sections[0].bigRestRow?.exerciseID, wristID)

        let plain = try JSONEncoder().encode(WorkoutSectionManifest(exerciseID: "x", name: "Plain", bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 30)))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        XCTAssertNil(object["restExerciseID"])
        XCTAssertNil((object["bigRestRow"] as? [String: Any])?["exerciseID"])
        let old = try JSONDecoder().decode(WorkoutSectionManifest.self, from: plain)
        XCTAssertNil(old.restExerciseID)
        XCTAssertNil(old.bigRestRow?.exerciseID)
    }

    func testASingleSetHasNoRestToHoldAnExercise() {
        let error = failure { try self.build("One set", self.dips(["sets": 1, "restExercise": "Calisthenics/Wrist Circles"])) }
        XCTAssertEqual(error?.code, "invalid_argument")
        XCTAssertTrue(error?.message.contains("only one set") == true, error?.message ?? "")
    }

    func testARestOfZeroCannotHoldAnExercise() {
        let between = failure { try self.build("Zero", self.dips(["restBetweenSets": 0, "restExercise": "Calisthenics/Wrist Circles"])) }
        XCTAssertEqual(between?.code, "invalid_argument")
        let after = failure { try self.build("Zero", self.dips(["restAfter": 0, "restAfterExercise": "Calisthenics/Wrist Circles"])) }
        XCTAssertEqual(after?.code, "invalid_argument")
    }

    func testTheLastSectionHasNoRestAfterIt() {
        let error = failure {
            try self.call("build_workout", ["name": "Last", "sections": [["exercise": "Calisthenics/Dips", "restAfterExercise": "Calisthenics/Wrist Circles"]]])
        }
        XCTAssertEqual(error?.code, "invalid_argument")
        XCTAssertTrue(error?.message.contains("no rest after it") == true, error?.message ?? "")
    }

    func testABundleTakesARestBetweenSetsExerciseInEveryRestButTheLast() throws {
        let bundle: [String: Any] = ["exercises": [["exercise": "Calisthenics/Dips"], ["exercise": "Calisthenics/Rows"]], "sets": 3, "restBetweenSets": 60]
        try call("build_workout", ["name": "Bundle", "sections": [["bundle": bundle, "restExercise": "Calisthenics/Wrist Circles"], ["exercise": "Calisthenics/Rows"]]])

        let section = try stored("Bundle").sections[0]
        XCTAssertEqual(section.slots.map(\.restExerciseID), [wristID, wristID, nil])
        XCTAssertEqual(section.playbackSlots().filter { $0.restExerciseID != nil }.count, 2)
    }

    func testABundleCanTakeAnExerciseInItsBigRest() throws {
        let bundle: [String: Any] = ["exercises": [["exercise": "Calisthenics/Dips"], ["exercise": "Calisthenics/Rows"]], "sets": 2, "restBetweenSets": 60]
        try call("build_workout", ["name": "Bundle", "sections": [
            ["bundle": bundle, "restAfter": 60, "restAfterExercise": "Calisthenics/Wrist Circles"], ["exercise": "Calisthenics/Rows"],
        ]])

        XCTAssertEqual(try stored("Bundle").sections[0].bigRestRow?.exerciseID, wristID)
    }

    func testARestShorterThanTheExerciseCannotHoldIt() {
        let error = failure { try self.build("Short", self.dips(["restBetweenSets": 60, "restExercise": "Calisthenics/Long Hold"])) }
        XCTAssertEqual(error?.code, "invalid_argument")
        XCTAssertTrue(error?.message.contains("takes 90 s but the rest is 60 s") == true, error?.message ?? "")
        let after = failure { try self.build("Short", self.dips(["restAfter": 60, "restAfterExercise": "Calisthenics/Long Hold"])) }
        XCTAssertEqual(after?.code, "invalid_argument")
    }

    func testARestExactlyAsLongAsTheExerciseCanHoldIt() throws {
        try build("Exact", dips(["restBetweenSets": 90, "restExercise": "Calisthenics/Long Hold"]))

        XCTAssertNotNil(try stored("Exact").sections[0].restExerciseID)
    }

    func testShorteningARestBelowItsExerciseIsRefusedAndNothingIsSaved() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))
        let before = try stored("Pull day")

        let between = failure { try self.call("update_workout_section", ["workout": "Pull day", "section": 1, "restBetweenSets": 20]) }
        let after = failure { try self.call("update_workout_section", ["workout": "Pull day", "section": 1, "restAfter": 20]) }

        XCTAssertEqual(between?.code, "invalid_argument")
        XCTAssertEqual(after?.code, "invalid_argument")
        XCTAssertEqual(try stored("Pull day").sections[0], before.sections[0])
    }

    func testGoingDownToOneSetOrNoRestDropsTheExerciseThatNoLongerFits() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))

        try call("update_workout_section", ["workout": "Pull day", "section": 1, "sets": 1, "restAfter": 0])

        let section = try stored("Pull day").sections[0]
        XCTAssertNil(section.restExerciseID)
        XCTAssertNil(section.bigRestRow?.exerciseID)
        XCTAssertTrue(section.playbackSlots().allSatisfy { $0.restExerciseID == nil })
    }

    func testAnEmptyValueRemovesARestExercise() throws {
        try build("Pull day", dips(["restExercise": "Calisthenics/Wrist Circles", "restAfterExercise": "Calisthenics/Wrist Circles"]))

        try call("update_workout_section", ["workout": "Pull day", "section": 1, "restExercise": "", "restAfterExercise": ""])

        let section = try stored("Pull day").sections[0]
        XCTAssertNil(section.restExerciseID)
        XCTAssertNil(section.bigRestRow?.exerciseID)
    }

    func testMoreSetsKeepTheRestExerciseInEveryRestBetweenSets() throws {
        let id = UUID().uuidString
        let slots = (0..<2).map { index in
            WorkoutSetSlotManifest(exerciseID: "page", name: "Dips", duration: 40, restAfter: index == 0 ? 90 : 0)
        }
        try database.createWorkout(id: id, manifest: WorkoutManifest(id: id, name: "Stored", sections: [
            WorkoutSectionManifest(exerciseID: "page", name: "Dips", duration: 40, sets: 2, restBetweenSets: 90, slots: slots, bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 30)),
            WorkoutSectionManifest(exerciseID: "page", name: "Rows"),
        ]))

        try call("update_workout_section", ["workout": "Stored", "section": 1, "restExercise": "Calisthenics/Wrist Circles"])
        XCTAssertEqual(try stored("Stored").sections[0].slots.map(\.restExerciseID), [wristID, nil])

        try call("update_workout_section", ["workout": "Stored", "section": 1, "sets": 4])
        let grown = try stored("Stored").sections[0]
        XCTAssertEqual(grown.slots.map(\.restExerciseID), [wristID, wristID, wristID, nil])
        XCTAssertEqual(grown.slots.map(\.playbackRest), [90, 90, 90, 0])
    }
}
