import XCTest
@testable import TimeMasterCore

final class RestExerciseChoicesTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var wristID = ""
    var dipsID = ""
    var rowsID = ""
    var holdID = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("rest-choices-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Calisthenics", "workoutType": "Strength"])["id"] as! String
        for (title, duration) in [("Dips", 40), ("Rows", 40), ("Wrist Circles", 30), ("Long Hold", 90)] {
            let id = try call("create_exercise_page", ["title": title, "parent": folder, "duration": duration])["id"] as! String
            switch title {
            case "Dips": dipsID = id
            case "Rows": rowsID = id
            case "Wrist Circles": wristID = id
            default: holdID = id
            }
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

    private func real(_ id: String, _ name: String, rest: Int = 0) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(exerciseID: id, name: name, duration: 40, restAfter: rest)
    }

    private func filler(_ id: String, rest: Int = 0) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(exerciseID: id, name: "Between sets: Wrist Circles", duration: 30, restAfter: rest)
    }

    private func set(_ kids: [WorkoutSetSlotManifest], rest: Int, isLast: Bool) -> WorkoutSetSlotManifest {
        WorkoutSetSlotManifest(exerciseID: "", name: "Set", duration: 5, restAfter: isLast ? 0 : rest, prepareTime: 4, children: kids)
    }

    private func bundle(_ name: String, sets: [WorkoutSetSlotManifest]) -> WorkoutSectionManifest {
        WorkoutSectionManifest(
            exerciseID: dipsID, name: name, duration: 40, sets: sets.count, restBetweenSets: 45, prepareTime: 4, customRestAfter: 60,
            mode: .bundle, slots: sets, bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 60)
        )
    }

    private func store(_ name: String, _ sections: [WorkoutSectionManifest]) throws -> WorkoutManifest {
        let id = UUID().uuidString
        let manifest = WorkoutManifest(id: id, name: name, sections: sections)
        try database.createWorkout(id: id, manifest: manifest)
        return manifest
    }

    func testSeveralRestExercisesKeepTheFirstAsTheDefaultAndTheRestAsChoices() throws {
        try build("Pull day", dips([
            "restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Dips"],
            "restAfterExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"],
        ]))

        let section = try stored("Pull day").sections[0]
        XCTAssertEqual(section.restExerciseID, wristID)
        XCTAssertEqual(section.restExerciseChoices, [wristID, dipsID])
        XCTAssertEqual(section.playbackSlots().map(\.restExerciseChoices), [[wristID, dipsID], [wristID, dipsID], []])
        XCTAssertEqual(section.bigRestRow?.exerciseChoices, [wristID, rowsID])
    }

    func testEveryChoiceMustFitTheRest() {
        let error = failure { try self.build("Short", self.dips(["restBetweenSets": 60, "restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Long Hold"]])) }

        XCTAssertEqual(error?.code, "invalid_argument")
        XCTAssertTrue(error?.message.contains("Long Hold") == true && error?.message.contains("takes 90 s") == true, error?.message ?? "")
    }

    func testABundleExerciseCanHoldChoicesInTheRestAfterIt() throws {
        let spec: [String: Any] = [
            "exercises": [
                ["exercise": "Calisthenics/Dips", "restAfter": 45, "restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"]],
                ["exercise": "Calisthenics/Rows", "restAfter": 0],
            ],
            "sets": 2, "restBetweenSets": 60,
        ]
        try call("build_workout", ["name": "Circuit", "sections": [["bundle": spec, "restExercise": "Calisthenics/Wrist Circles"], ["exercise": "Calisthenics/Rows"]]])

        let leaves = try stored("Circuit").sections[0].playbackSlots()
        XCTAssertEqual(leaves.map(\.restExerciseChoices), [[wristID, rowsID], [wristID], [wristID, rowsID], []])
        let sections = try XCTUnwrap(try call("get_workout", ["workout": "Circuit"])["sections"] as? [[String: Any]])
        let first = try XCTUnwrap((sections[0]["exercises"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["restExercise"] as? [String], ["Calisthenics/Wrist Circles", "Calisthenics/Rows"])
        XCTAssertEqual(sections[0]["restExercise"] as? String, "Calisthenics/Wrist Circles")
    }

    func testChoicesSurviveSavingAndOlderFilesLoadWithoutThem() throws {
        try build("Pull day", dips(["restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Dips"], "restAfterExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"]]))
        let workout = try stored("Pull day")

        let decoded = try JSONDecoder().decode(WorkoutManifest.self, from: try JSONEncoder().encode(workout))
        XCTAssertEqual(decoded.sections[0].restExerciseChoices, [wristID, dipsID])
        XCTAssertEqual(decoded.sections[0].playbackSlots().map(\.restExerciseChoices), workout.sections[0].playbackSlots().map(\.restExerciseChoices))
        XCTAssertEqual(decoded.sections[0].bigRestRow?.exerciseChoices, [wristID, rowsID])

        let plain = try JSONEncoder().encode(WorkoutSectionManifest(exerciseID: "x", name: "Plain", bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 30, exerciseID: "y")))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        XCTAssertNil(object["restExerciseAlternativeIDs"])
        XCTAssertNil((object["bigRestRow"] as? [String: Any])?["alternativeExerciseIDs"])
        let legacy = try JSONDecoder().decode(WorkoutRestRowManifest.self, from: Data(#"{"id":"r","kind":"big","duration":30,"contents":[],"exerciseID":"y"}"#.utf8))
        XCTAssertEqual(legacy.exerciseChoices, ["y"])
    }

    func testMoreSetsAndANewRestLengthKeepEveryChoice() throws {
        let id = UUID().uuidString
        let slots = (0..<2).map { index in
            WorkoutSetSlotManifest(exerciseID: dipsID, name: "Dips", duration: 40, restAfter: index == 0 ? 90 : 0)
        }
        try database.createWorkout(id: id, manifest: WorkoutManifest(id: id, name: "Stored", sections: [
            WorkoutSectionManifest(exerciseID: dipsID, name: "Dips", duration: 40, sets: 2, restBetweenSets: 90, slots: slots, bigRestRow: WorkoutRestRowManifest(kind: .big, duration: 45)),
            WorkoutSectionManifest(exerciseID: rowsID, name: "Rows"),
        ]))

        try call("update_workout_section", ["workout": "Stored", "section": 1, "restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"], "restAfterExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"]])
        try call("update_workout_section", ["workout": "Stored", "section": 1, "sets": 4, "restAfter": 50])

        let section = try stored("Stored").sections[0]
        XCTAssertEqual(section.slots.map(\.restExerciseChoices), [[wristID, rowsID], [wristID, rowsID], [wristID, rowsID], []])
        XCTAssertEqual(section.bigRestRow?.exerciseChoices, [wristID, rowsID])
        XCTAssertEqual(section.bigRestRow?.duration, 50)
    }

    func testReplacingABundlesExercisesKeepsItsBetweenSetsRestExercises() throws {
        let spec: [String: Any] = ["exercises": [["exercise": "Calisthenics/Dips"], ["exercise": "Calisthenics/Rows"]], "sets": 3, "restBetweenSets": 60]
        try call("build_workout", ["name": "Circuit", "sections": [["bundle": spec, "restExercise": ["Calisthenics/Wrist Circles", "Calisthenics/Rows"]], ["exercise": "Calisthenics/Rows"]]])

        try call("update_workout_section", ["workout": "Circuit", "section": 1, "bundle": ["exercises": [["exercise": "Calisthenics/Rows"]], "sets": 4]])

        let slots = try stored("Circuit").sections[0].slots
        XCTAssertEqual(slots.map(\.restExerciseChoices), [[wristID, rowsID], [wristID, rowsID], [wristID, rowsID], []])
    }

    func testSectionEditsCanBeUndone() throws {
        try build("Pull day", dips())
        let before = try stored("Pull day")

        let output = try toolbox.call("update_workout_section", arguments: ["workout": "Pull day", "section": 1, "sets": 5, "name": "Heavy dips"], dryRun: false)
        XCTAssertEqual(try stored("Pull day").sections[0].sets, 5)
        toolbox.revert(output.effects)

        let restored = try stored("Pull day")
        XCTAssertEqual(restored.sections[0], before.sections[0])
        XCTAssertEqual(restored.name, before.name)
    }

    func testFoldingTurnsFillersIntoRestExercisesAndOneExerciseBundlesIntoTimedSections() throws {
        let single = bundle("Dips 3x40 (wrist circles between, 90 s)", sets: (0..<3).map { index in
            set([real(dipsID, "Dips"), filler(wristID)], rest: 60, isLast: index == 2)
        })
        let circuit = bundle("Mixed 2 rounds (wrist circles between, 75 s)", sets: (0..<2).map { index in
            set([real(dipsID, "Dips"), filler(wristID, rest: 45), real(rowsID, "Rows"), filler(wristID)], rest: 45, isLast: index == 1)
        })
        _ = try store("Camp day", [single, circuit])
        let original = try stored("Camp day")
        let before = original.sections.map(\.calculatedDuration)

        let dry = try toolbox.call("fold_rest_fillers", arguments: ["workout": "Camp day"], dryRun: true)
        XCTAssertEqual(dry.value["sections"] as? Int, 2)
        XCTAssertEqual(try stored("Camp day").sections[0].mode, .bundle)

        let output = try toolbox.call("fold_rest_fillers", arguments: ["workout": "Camp day"], dryRun: false)
        XCTAssertEqual(output.value["fillers"] as? Int, 7)
        XCTAssertEqual(output.value["becameTimed"] as? Int, 1)
        let folded = try stored("Camp day")

        let timed = folded.sections[0]
        XCTAssertEqual(timed.mode, .timed)
        XCTAssertEqual(timed.name, "Dips 3x40")
        XCTAssertEqual(timed.exerciseID, dipsID)
        XCTAssertEqual(timed.sets, 3)
        XCTAssertEqual(timed.duration, 40)
        XCTAssertEqual(timed.restBetweenSets, 90)
        XCTAssertEqual(timed.slots.map(\.playbackRest), [90, 90, 0])
        XCTAssertEqual(timed.slots.map(\.restExerciseID), [wristID, wristID, nil])
        XCTAssertEqual(timed.calculatedDuration, before[0] - 30)

        let circuitAfter = folded.sections[1]
        XCTAssertEqual(circuitAfter.mode, .bundle)
        XCTAssertEqual(circuitAfter.name, "Mixed 2 rounds")
        XCTAssertEqual(circuitAfter.slots.map { $0.children.map(\.exerciseID) }, [[dipsID, rowsID], [dipsID, rowsID]])
        XCTAssertEqual(circuitAfter.slots[0].children.map(\.playbackRest), [75, 0])
        XCTAssertEqual(circuitAfter.slots[0].children.map(\.restExerciseID), [wristID, nil])
        XCTAssertEqual([circuitAfter.slots[0].playbackRest, circuitAfter.slots[1].playbackRest], [75, 0])
        XCTAssertEqual(circuitAfter.slots[0].restExerciseID, wristID)
        XCTAssertNil(circuitAfter.slots[1].restExerciseID)
        XCTAssertEqual(circuitAfter.calculatedDuration, before[1] - 30)

        toolbox.revert(output.effects)
        XCTAssertEqual(try stored("Camp day").sections, original.sections)
    }

    func testFoldingSkipsASectionWhoseRestCannotHoldTheExercise() throws {
        let tight = bundle("Tight", sets: (0..<2).map { index in
            set([real(dipsID, "Dips"), filler(holdID)], rest: 10, isLast: index == 1)
        })
        _ = try store("Tight day", [tight, bundle("Other", sets: [set([real(rowsID, "Rows")], rest: 0, isLast: true)])])
        let original = try stored("Tight day")

        let output = try toolbox.call("fold_rest_fillers", arguments: [:], dryRun: false)

        XCTAssertEqual(output.value["sections"] as? Int, 0)
        XCTAssertEqual((output.value["skipped"] as? [String])?.count, 1)
        XCTAssertEqual(try stored("Tight day").sections, original.sections)
    }

    func testFoldingKeepsNamesWhenAskedAndIgnoresOtherPrefixes() throws {
        let section = bundle("Dips (wrist circles between, 90 s)", sets: (0..<2).map { index in
            set([real(dipsID, "Dips"), WorkoutSetSlotManifest(exerciseID: wristID, name: "Cool down: Wrist Circles", duration: 30, restAfter: 0)], rest: 60, isLast: index == 1)
        })
        _ = try store("Named", [section])
        XCTAssertEqual(try toolbox.call("fold_rest_fillers", arguments: [:], dryRun: false).value["sections"] as? Int, 0)

        let kept = bundle("Dips (wrist circles between, 90 s)", sets: (0..<2).map { index in
            set([real(dipsID, "Dips"), filler(wristID)], rest: 60, isLast: index == 1)
        })
        _ = try store("Kept", [kept])
        _ = try toolbox.call("fold_rest_fillers", arguments: ["workout": "Kept", "keepNames": true], dryRun: false)
        XCTAssertEqual(try stored("Kept").sections[0].name, "Dips (wrist circles between, 90 s)")
        XCTAssertEqual(try stored("Kept").sections[0].mode, .timed)
    }
}
