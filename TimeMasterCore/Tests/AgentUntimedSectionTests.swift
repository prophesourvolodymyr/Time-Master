import XCTest
@testable import TimeMasterCore

final class AgentUntimedSectionTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("untimed-tools-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let folder = try call("create_container_page", ["title": "Calisthenics", "workoutType": "Strength"])["id"] as! String
        for (title, duration) in [("Push-up", 30), ("Squat", 40)] {
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

    func testEverySectionInputOffersAnUntimedSwitch() throws {
        for name in ["add_workout_section", "update_workout_section"] {
            let tool = try XCTUnwrap(AgentToolRegistry.tool(named: name))
            XCTAssertEqual(tool.properties["untimed"]?["type"] as? String, "boolean", name)
        }
        let build = try XCTUnwrap(AgentToolRegistry.tool(named: "build_workout"))
        let item = try XCTUnwrap(build.properties["sections"]?["items"] as? [String: Any])
        let properties = try XCTUnwrap(item["properties"] as? [String: [String: Any]])
        XCTAssertEqual(properties["untimed"]?["type"] as? String, "boolean")
    }

    func testAnUntimedSectionKeepsItsDurationAsTheEstimate() throws {
        let built = try call("build_workout", ["name": "Reps", "sections": [
            ["exercise": "Calisthenics/Push-up", "untimed": true, "duration": 45, "sets": 3, "repCount": 12],
            ["exercise": "Calisthenics/Squat"],
        ]])

        let workout = try stored("Reps")
        XCTAssertFalse(workout.sections[0].isTimerEnabled)
        XCTAssertEqual(workout.sections[0].duration, 45)
        XCTAssertEqual(workout.sections[0].repCount, 12)
        XCTAssertEqual(workout.sections[0].playbackSlots().map(\.duration), [45, 45, 45])
        XCTAssertTrue(workout.sections[1].isTimerEnabled)
        XCTAssertEqual(built["totalSeconds"] as? Int, workout.totalDuration)
    }

    func testTheEstimateKeepsTheFiveSecondMinimum() {
        let error = failure {
            _ = try self.call("build_workout", ["name": "Reps", "sections": [["exercise": "Calisthenics/Push-up", "untimed": true, "duration": 3]]])
        }
        XCTAssertEqual(error?.code, "invalid_argument")
    }

    func testGetWorkoutReportsOnlyUntimedSections() throws {
        try call("build_workout", ["name": "Reps", "sections": [
            ["exercise": "Calisthenics/Push-up", "untimed": true],
            ["exercise": "Calisthenics/Squat", "untimed": false],
        ]])

        let sections = try call("get_workout", ["workout": "Reps"])["sections"] as! [[String: Any]]

        XCTAssertEqual(sections[0]["untimed"] as? Bool, true)
        XCTAssertNil(sections[1]["untimed"])
    }

    func testABundleSectionCanRunUntilDone() throws {
        try call("build_workout", ["name": "Circuit", "sections": [["exercise": "Calisthenics/Squat"]]])
        let bundle: [String: Any] = ["exercises": [["exercise": "Calisthenics/Push-up", "repCount": 10], ["exercise": "Calisthenics/Squat"]], "sets": 2]

        try call("add_workout_section", ["workout": "Circuit", "bundle": bundle, "untimed": true])

        let section = try stored("Circuit").sections[1]
        XCTAssertEqual(section.mode, .bundle)
        XCTAssertFalse(section.isTimerEnabled)
        let sections = try call("get_workout", ["workout": "Circuit"])["sections"] as! [[String: Any]]
        XCTAssertEqual(sections[1]["untimed"] as? Bool, true)
    }

    func testUpdateSectionSwitchesBetweenTimerAndUntilDone() throws {
        try call("build_workout", ["name": "Reps", "sections": [["exercise": "Calisthenics/Push-up", "duration": 30]]])

        let changed = try call("update_workout_section", ["workout": "Reps", "section": "1", "untimed": true])
        XCTAssertEqual(changed["changed"] as? [String], ["untimed"])
        XCTAssertFalse(try stored("Reps").sections[0].isTimerEnabled)
        XCTAssertEqual(try stored("Reps").sections[0].duration, 30)

        try call("update_workout_section", ["workout": "Reps", "section": "1", "untimed": false])
        XCTAssertTrue(try stored("Reps").sections[0].isTimerEnabled)
    }
}
