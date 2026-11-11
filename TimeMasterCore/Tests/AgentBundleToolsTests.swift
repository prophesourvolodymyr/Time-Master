import XCTest
@testable import TimeMasterCore

final class AgentBundleToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("bundle-tools-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Wrestling", "workoutType": "Strength"])["id"] as! String
        for (title, duration) in [("Sprawl", 30), ("Shoot", 40), ("Sit-out", 20)] {
            try call("create_exercise_page", ["title": title, "parent": folder, "duration": duration])
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

    private func drills(sets: Int = 3) -> [String: Any] {
        [
            "exercises": [
                ["exercise": "Wrestling/Sprawl", "duration": 20, "restAfter": 5],
                ["exercise": "Wrestling/Shoot", "duration": 1, "restAfter": 0],
                ["exercise": "Wrestling/Sit-out"],
            ],
            "sets": sets, "restBetweenSets": 40, "order": "random", "voice": false, "prepareTime": 3,
        ]
    }

    func testBuildWorkoutCreatesABundleThatPlaysEveryExerciseInEverySet() throws {
        let built = try call("build_workout", ["name": "Drills", "sections": [["bundle": drills()]]])
        XCTAssertEqual(built["bundles"] as? Int, 1)

        let workout = try stored("Drills")
        let section = workout.sections[0]
        XCTAssertEqual(section.mode, .bundle)
        XCTAssertEqual(section.bundleOrder, .random)
        XCTAssertFalse(section.bundleVoiceEnabled)
        XCTAssertEqual(section.slots.count, 3)
        XCTAssertEqual(Set(section.slots.flatMap(\.children).map(\.id)).count, 9)

        let plan = section.playbackSlots()
        XCTAssertEqual(plan.map(\.name), ["Sprawl", "Shoot", "Sit-out", "Sprawl", "Shoot", "Sit-out", "Sprawl", "Shoot", "Sit-out"])
        XCTAssertEqual(plan.map(\.duration), [20, 1, 20, 20, 1, 20, 20, 1, 20])
        XCTAssertEqual(plan[1].playbackRest, 0)
        XCTAssertEqual(plan[2].playbackRest, 40)
        XCTAssertEqual(plan[8].playbackRest, 0)
        XCTAssertEqual(workout.totalDuration, built["totalSeconds"] as? Int)
    }

    func testGetWorkoutDescribesBundlesCompactly() throws {
        try call("build_workout", ["name": "Drills", "sections": [["bundle": drills(sets: 2)], ["exercise": "Wrestling/Sprawl", "sets": 2]]])

        let sections = try call("get_workout", ["workout": "drills"])["sections"] as! [[String: Any]]

        XCTAssertEqual(sections[0]["kind"] as? String, "bundle")
        XCTAssertEqual(sections[0]["sets"] as? Int, 2)
        XCTAssertEqual(sections[0]["order"] as? String, "random")
        XCTAssertEqual(sections[0]["restBetweenSets"] as? Int, 40)
        let exercises = sections[0]["exercises"] as! [[String: Any]]
        XCTAssertEqual(exercises.map { $0["exercise"] as? String }, ["Wrestling/Sprawl", "Wrestling/Shoot", "Wrestling/Sit-out"])
        XCTAssertEqual(exercises.map { $0["duration"] as? Int }, [20, 1, 20])
        XCTAssertEqual(sections[1]["kind"] as? String, "exercise")
        XCTAssertEqual(sections[1]["position"] as? Int, 2)
        XCTAssertEqual((try call("list_workouts", [:])["workouts"] as! [[String: Any]]).first?["bundles"] as? Int, 1)
    }

    func testAnExerciseListWithTwoDifferentSetsIsReportedPerRound() throws {
        try call("build_workout", ["name": "Drills", "sections": [["bundle": drills(sets: 2)]]])
        var workout = try stored("Drills")
        workout.sections[0].slots[1].children.removeLast()
        try database.updateWorkout(id: workout.id, manifest: workout)

        let section = (try call("get_workout", ["workout": "Drills"])["sections"] as! [[String: Any]])[0]

        XCTAssertNil(section["exercises"])
        XCTAssertEqual((section["rounds"] as? [[Any]])?.map(\.count), [3, 2])
    }

    func testAddWorkoutSectionAppendsAndKeepsTheRestBetweenSections() throws {
        try call("build_workout", ["name": "Mat", "restBetweenSections": 25, "sections": [["exercise": "Wrestling/Sprawl"]]])

        let added = try call("add_workout_section", ["workout": "Mat", "bundle": drills(sets: 2), "name": "Drills"])

        XCTAssertEqual(added["position"] as? Int, 2)
        XCTAssertEqual(added["previousSectionRest"] as? Int, 25)
        let workout = try stored("Mat")
        XCTAssertEqual(workout.sections.map(\.name), ["Sprawl", "Drills"])
        XCTAssertEqual(workout.sections[0].bigRestRow?.duration, 25)
        XCTAssertEqual(workout.sections[1].bigRestRow?.duration, 0)

        try call("add_workout_section", ["workout": "Mat", "exercise": "Wrestling/Shoot", "position": 1])
        XCTAssertEqual(try stored("Mat").sections.map(\.name), ["Shoot", "Sprawl", "Drills"])
    }

    func testUpdateBundleChangesExercisesSetsRestsOrderAndVoice() throws {
        try call("build_workout", ["name": "Drills", "sections": [["bundle": drills(sets: 2)]]])

        let changed = try call("update_workout_section", ["workout": "Drills", "section": "1", "bundle": ["sets": 4, "restBetweenSets": 15, "order": "ordered", "voice": true, "prepareTime": 6]])

        XCTAssertEqual(Set(changed["changed"] as! [String]), ["sets", "restBetweenSets", "prepareTime", "order", "voice"])
        var section = try stored("Drills").sections[0]
        XCTAssertEqual(section.slots.count, 4)
        XCTAssertEqual(section.slots.map(\.playbackRest), [15, 15, 15, 0])
        XCTAssertEqual(section.slots.map(\.name), ["Set 1", "Set 2", "Set 3", "Set 4"])
        XCTAssertEqual(section.bundleOrder, .ordered)
        XCTAssertTrue(section.bundleVoiceEnabled)
        XCTAssertEqual(section.playbackSlots().first?.prepareTime, 6)
        XCTAssertEqual(Set(section.slots.flatMap(\.children).map(\.id)).count, 12)

        try call("update_workout_section", ["workout": "Drills", "section": section.name, "bundle": ["exercises": [["exercise": "Wrestling/Sit-out", "duration": 2, "restAfter": 0]], "sets": 2]])
        section = try stored("Drills").sections[0]
        XCTAssertEqual(section.slots.count, 2)
        XCTAssertEqual(section.playbackSlots().map(\.name), ["Sit-out", "Sit-out"])
        XCTAssertEqual(section.exerciseID, section.slots[0].children[0].exerciseID)
    }

    func testUpdateTimedSectionAppliesToExistingSetsAndTopLevelBundleFieldsAreAccepted() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Wrestling/Sprawl", "sets": 2], ["bundle": drills(sets: 2)]]])
        var workout = try stored("Mat")
        workout.sections[0].slots = (0..<2).map { index in
            WorkoutSetSlotManifest(exerciseID: workout.sections[0].exerciseID, name: "Sprawl", duration: 30, restAfter: index == 0 ? 10 : 0, prepareTime: 4)
        }
        try database.updateWorkout(id: workout.id, manifest: workout)

        try call("update_workout_section", ["workout": "Mat", "section": "1", "duration": 45, "sets": 3, "restBetweenSets": 12])
        let timed = try stored("Mat").sections[0]
        XCTAssertEqual(timed.slots.map(\.duration), [45, 45, 45])
        XCTAssertEqual(timed.slots.map(\.playbackRest), [12, 12, 0])
        XCTAssertEqual(timed.sets, 3)

        try call("update_workout_section", ["workout": "Mat", "section": "2", "sets": 1, "prepareTime": 8])
        let bundle = try stored("Mat").sections[1]
        XCTAssertEqual(bundle.slots.count, 1)
        XCTAssertEqual(bundle.prepareTime, 8)
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "2", "duration": 30]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "1", "bundle": ["sets": 2]]) }?.code, "invalid_argument")
    }

    func testMoveRenameRestAfterAndRemoveSections() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Wrestling/Sprawl"], ["bundle": drills(sets: 1)], ["exercise": "Wrestling/Shoot"]]])

        try call("update_workout_section", ["workout": "Mat", "section": "3", "position": 1, "name": "Opener", "restAfter": 50])
        var workout = try stored("Mat")
        XCTAssertEqual(workout.sections.map(\.name).first, "Opener")
        XCTAssertEqual(workout.sections[0].bigRestRow?.duration, 50)

        let dry = try call("remove_workout_section", ["workout": "Mat", "section": "Opener"], dryRun: true)
        XCTAssertEqual(dry["dryRun"] as? Bool, true)
        XCTAssertEqual(try stored("Mat").sections.count, 3)

        let removed = try call("remove_workout_section", ["workout": "Mat", "section": "2"])
        XCTAssertEqual(removed["sections"] as? Int, 2)
        workout = try stored("Mat")
        XCTAssertEqual(workout.sections.count, 2)
        XCTAssertEqual(AgentToolRegistry.tool(named: "remove_workout_section")?.risk, .delete)
    }

    func testAWorkoutKeepsAtLeastOneSectionAndRejectsBadReferences() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Wrestling/Sprawl"]]])

        XCTAssertEqual(failure { _ = try self.call("remove_workout_section", ["workout": "Mat", "section": "1"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "9", "name": "x"]) }?.code, "not_found")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "Nope", "name": "x"]) }?.code, "not_found")
        XCTAssertEqual(failure { _ = try self.call("update_workout_section", ["workout": "Mat", "section": "1"]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["exercise": "Wrestling/Sprawl", "bundle": self.drills()]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["name": "Empty"]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["bundle": ["sets": 2]]]]) }?.code, "invalid_argument")
        XCTAssertEqual(failure { _ = try self.call("build_workout", ["name": "Bad", "sections": [["bundle": ["exercises": [["exercise": "Wrestling"]]]]]]) }?.code, "invalid_argument")
    }

    func testUpdateWorkoutRenamesAndChangesTheTypeAndRest() throws {
        try call("build_workout", ["name": "Mat", "sections": [["exercise": "Wrestling/Sprawl"]]])

        let changed = try call("update_workout", ["workout": "Mat", "name": "Mat day", "type": "HIIT", "restBetweenSections": 45])

        XCTAssertEqual(Set(changed["changed"] as! [String]), ["name", "type", "restBetweenSections"])
        let workout = try stored("Mat day")
        XCTAssertEqual(workout.type.name, "HIIT")
        XCTAssertEqual(workout.restBetweenSections, 45)
        XCTAssertEqual(failure { _ = try self.call("update_workout", ["workout": "Mat day"]) }?.code, "invalid_argument")
    }

    func testBundleToolsAreInTheCatalogForCoachAndExternalAgents() {
        for name in ["add_workout_section", "update_workout_section", "remove_workout_section", "update_workout"] {
            let tool = AgentToolRegistry.tool(named: name)
            XCTAssertNotNil(tool, name)
            XCTAssertTrue(tool?.coach == true, name)
        }
        let build = AgentToolRegistry.tool(named: "build_workout")!
        let section = (build.properties["sections"]?["items"] as? [String: Any])?["properties"] as? [String: [String: Any]]
        XCTAssertNotNil(section?["bundle"])
        XCTAssertEqual(AgentToolRegistry.tool(named: "list_workouts")?.risk, .read)
    }
}
