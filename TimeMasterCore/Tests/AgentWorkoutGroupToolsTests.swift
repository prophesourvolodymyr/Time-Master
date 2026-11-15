import XCTest
@testable import TimeMasterCore

final class AgentWorkoutGroupToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("workout-groups-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        try call("create_exercise_page", ["title": "Sprawl", "duration": 30])
        for name in ["Mon AM", "Mon PM", "Tue AM", "Tue PM"] {
            try call("build_workout", ["name": name, "sections": [["exercise": "Sprawl"]]])
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func groups() throws -> [(title: String, workouts: [String])] {
        try (call("list_workout_groups", [:])["groups"] as! [[String: Any]]).map { ($0["title"] as! String, $0["workouts"] as! [String]) }
    }

    func testGroupsKeepTheOrderTheyWereGivenAndAWorkoutLivesInOneGroup() throws {
        try call("create_workout_group", ["title": "Week 2", "icon": "2.circle.fill", "workouts": ["Tue PM", "Tue AM"]])
        try call("create_workout_group", ["title": "Week 1", "icon": "1.circle.fill", "workouts": ["Mon AM", "Mon PM", "Tue AM"], "position": 1])

        let listed = try groups()
        XCTAssertEqual(listed.map(\.title), ["Week 1", "Week 2"])
        XCTAssertEqual(listed[0].workouts, ["Mon AM", "Mon PM", "Tue AM"])
        XCTAssertEqual(listed[1].workouts, ["Tue PM"])
        XCTAssertEqual(try database.loadConfig().workoutGroups[0].iconType, .system)

        try call("update_workout_group", ["group": "Week 2", "position": 1, "addWorkouts": ["Mon AM"], "workoutOrder": ["Mon AM", "Tue PM"]])
        let moved = try groups()
        XCTAssertEqual(moved.map(\.title), ["Week 2", "Week 1"])
        XCTAssertEqual(moved[0].workouts, ["Mon AM", "Tue PM"])
        XCTAssertEqual(moved[1].workouts, ["Mon PM", "Tue AM"])

        let partialOrder = try? call("update_workout_group", ["group": "Week 1", "workoutOrder": ["Tue AM"]])
        XCTAssertNil(partialOrder)
        XCTAssertEqual(try groups()[1].workouts, ["Mon PM", "Tue AM"])
    }

    func testUndoingACreatedGroupKeepsItsWorkoutsAndDeletedWorkoutsLeaveTheirGroup() throws {
        let batch = toolbox.call
        let output = try batch("create_workout_group", ["title": "Week 1", "workouts": ["Mon AM", "Mon PM"]], false)
        try call("delete_workout", ["workout": "Mon PM"])
        XCTAssertEqual(try groups()[0].workouts, ["Mon AM"])
        XCTAssertEqual(try database.loadConfig().workoutGroups[0].workoutIDs.count, 1)

        toolbox.revert(output.effects)
        XCTAssertTrue(try groups().isEmpty)
        XCTAssertEqual(try call("list_workout_groups", [:])["ungrouped"] as? [String], ["Mon AM", "Tue AM", "Tue PM"])
    }

    func testConfigWithoutGroupsStillDecodesAndOtherSettingsSurviveAGroupChange() throws {
        var config = try database.loadConfig()
        config.weeklyGoal = 6
        try database.saveConfig(config)
        try call("create_workout_group", ["title": "Week 1", "workouts": ["Mon AM"]])

        let reloaded = try database.loadConfig()
        XCTAssertEqual(reloaded.weeklyGoal, 6)
        XCTAssertEqual(reloaded.workoutGroups.map(\.title), ["Week 1"])

        let legacy = try JSONDecoder().decode(ConfigManifest.self, from: Data(#"{"weeklyGoal":3}"#.utf8))
        XCTAssertTrue(legacy.workoutGroups.isEmpty)
    }
}
