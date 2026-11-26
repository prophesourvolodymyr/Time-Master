import XCTest
@testable import TimeMasterCore

final class AgentScheduleToolsTests: XCTestCase {
    var root: URL!
    var database: DatabaseManager!
    var toolbox: AgentToolbox!
    var monday: Date!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("schedule-tools-\(UUID().uuidString)", isDirectory: true)
        database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        toolbox = AgentToolbox(database: database)
        let calendar = Calendar.current
        monday = WeeklyWorkoutSchedule.weekStart(calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))!)
        try call("create_exercise_page", ["title": "Jab", "duration": 30])
        try call("build_workout", ["name": "Boxing A", "sections": [["exercise": "Jab"]]])
        try call("build_workout", ["name": "Boxing B", "sections": [["exercise": "Jab", "duration": 60]]])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func call(_ name: String, _ arguments: [String: Any], dryRun: Bool = false) throws -> [String: Any] {
        try toolbox.call(name, arguments: arguments, dryRun: dryRun).value
    }

    private func key(_ offset: Int) -> String {
        WeeklyWorkoutSchedule.dayKey(Calendar.current.date(byAdding: .day, value: offset, to: monday)!)
    }

    private func day(_ offset: Int) throws -> [String: Any] {
        try (call("get_schedule", ["date": key(offset), "days": 1])["days"] as! [[String: Any]])[0]
    }

    private func entries(_ offset: Int) throws -> [[String: Any]] {
        try day(offset)["entries"] as? [[String: Any]] ?? []
    }

    private func titles(_ offset: Int) throws -> [String] {
        try entries(offset).map { $0["title"] as! String }
    }

    private func makePlan(use: Bool = true, entries: [[String: Any]]? = nil) throws {
        let list = entries ?? [
            ["workout": "Boxing A", "weekday": "Mon", "start": "07:30"],
            ["workout": "Boxing B", "weekday": "Wed", "start": "18:00", "minutes": 45],
        ]
        var args: [String: Any] = ["name": "Block", "entries": list]
        if use { args["use"] = true; args["from"] = key(0) }
        try call("create_schedule_plan", args)
    }

    private func expectError(_ code: String, _ name: String, _ arguments: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try call(name, arguments), file: file, line: line) { error in
            XCTAssertEqual((error as? AgentToolError)?.code, code, file: file, line: line)
        }
    }

    func testAPlanFollowedFromAWeekFillsThatWeekAndLaterOnesButNotEarlierOnes() throws {
        try makePlan()
        XCTAssertEqual(try titles(0), ["Boxing A"])
        XCTAssertEqual(try entries(0)[0]["start"] as? String, "07:30")
        XCTAssertEqual(try titles(1), [])
        XCTAssertEqual(try titles(2), ["Boxing B"])
        XCTAssertEqual(try entries(2)[0]["minutes"] as? Int, 45)
        XCTAssertEqual(try entries(2)[0]["done"] as? Bool, false)
        XCTAssertEqual(try titles(7), ["Boxing A"])
        XCTAssertEqual(try titles(-7), [])
        XCTAssertEqual(try titles(-5), [])
    }

    func testHandMarksAndWorkoutHistoryBothMakeAnEntryDone() throws {
        try makePlan()
        try call("complete_schedule_entry", ["entry": "Boxing A", "date": key(0)])
        XCTAssertEqual(try entries(0)[0]["done"] as? Bool, true)
        XCTAssertEqual(try entries(0)[0]["markedByHand"] as? Bool, true)

        try call("complete_schedule_entry", ["entry": "Boxing A", "date": key(0), "done": false])
        XCTAssertEqual(try entries(0)[0]["done"] as? Bool, false)

        try call("complete_schedule_entry", ["entry": "Boxing A", "date": key(0), "clear": true])
        XCTAssertEqual(try entries(0)[0]["done"] as? Bool, false)
        XCTAssertNil(try entries(0)[0]["markedByHand"])

        let workout = try XCTUnwrap(database.listWorkouts().first { $0.name == "Boxing A" })
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!
        try database.appendHistoryEntry(HistoryEntry(workoutId: workout.id, workoutName: workout.name, completedAt: morning, durationCompleted: 60))
        XCTAssertEqual(try entries(0)[0]["done"] as? Bool, true)
        XCTAssertNil(try entries(0)[0]["markedByHand"])
        XCTAssertEqual(try entries(7)[0]["done"] as? Bool, false)
    }

    func testAOneOffEntryStaysOnItsDateAndARepeatingOneJoinsThePlanFromThatWeek() throws {
        try call("add_schedule_entry", ["workout": "Boxing A", "date": key(1), "start": "6:15pm"])
        XCTAssertEqual(try titles(1), ["Boxing A"])
        XCTAssertEqual(try entries(1)[0]["start"] as? String, "18:15")
        XCTAssertEqual(try titles(8), [])

        let added = try call("add_schedule_entry", ["workout": "Boxing B", "date": key(10), "repeat": true])
        XCTAssertEqual(added["plan"] as? String, "My Plan")
        XCTAssertEqual(try titles(10), ["Boxing B"])
        XCTAssertEqual(try titles(17), ["Boxing B"])
        XCTAssertEqual(try titles(3), [])
        let plans = try call("list_schedule_plans", [:])["plans"] as! [[String: Any]]
        XCTAssertEqual(plans.map { $0["name"] as? String }, ["My Plan"])
        XCTAssertEqual((plans[0]["entries"] as! [[String: Any]])[0]["weekday"] as? String, "Thu")
    }

    func testChangingOneDayLeavesThePlanAloneAndChangingThePlanStartsFromThatWeek() throws {
        try makePlan()
        try call("update_schedule_entry", ["entry": "Boxing A", "date": key(0), "start": "09:00"])
        XCTAssertEqual(try entries(0)[0]["start"] as? String, "09:00")
        XCTAssertEqual(try entries(7)[0]["start"] as? String, "07:30")

        let occurrence = try XCTUnwrap(entries(7)[0]["occurrence"] as? String)
        try call("update_schedule_entry", ["entry": occurrence, "scope": "plan", "start": "10:00", "notes": "Heavy bag"])
        XCTAssertEqual(try entries(7)[0]["start"] as? String, "10:00")
        XCTAssertEqual(try entries(14)[0]["start"] as? String, "10:00")
        XCTAssertEqual(try entries(14)[0]["notes"] as? String, "Heavy bag")
        XCTAssertEqual(try entries(0)[0]["start"] as? String, "09:00")
        XCTAssertNil(try entries(0)[0]["notes"])

        let third = try XCTUnwrap(entries(14)[0]["occurrence"] as? String)
        let moved = try call("update_schedule_entry", ["entry": third, "moveTo": key(16)])
        XCTAssertEqual(moved["movedTo"] as? String, key(16))
        XCTAssertEqual(try titles(14), [])
        XCTAssertEqual(try titles(16), ["Boxing A", "Boxing B"])
        XCTAssertEqual(try titles(21), ["Boxing A"])
    }

    func testRemovingAnEntryForOneDayOrFromThePlanOnward() throws {
        try makePlan()
        try call("remove_schedule_entry", ["entry": "Boxing A", "date": key(7)])
        XCTAssertEqual(try titles(7), [])
        XCTAssertEqual(try titles(14), ["Boxing A"])
        XCTAssertEqual(try titles(0), ["Boxing A"])

        let wednesday = try XCTUnwrap(entries(9)[0]["occurrence"] as? String)
        try call("remove_schedule_entry", ["entry": wednesday, "scope": "plan"])
        XCTAssertEqual(try titles(9), [])
        XCTAssertEqual(try titles(16), [])
        XCTAssertEqual(try titles(2), ["Boxing B"])
        XCTAssertEqual(try titles(14), ["Boxing A"])
    }

    func testAVacationWeekHasNoEntriesUntilAPlanIsChosenAgain() throws {
        try makePlan()
        try call("select_schedule_plan", ["vacation": true, "week": key(7)])
        XCTAssertEqual(try titles(7), [])
        XCTAssertEqual(try day(7)["vacation"] as? Bool, true)
        XCTAssertEqual(try titles(14), [])
        XCTAssertEqual(try titles(0), ["Boxing A"])
        expectError("vacation_week", "add_schedule_entry", ["title": "Run", "date": key(9), "repeat": true])

        try call("select_schedule_plan", ["plan": "Block", "week": key(14)])
        XCTAssertEqual(try titles(14), ["Boxing A"])
        XCTAssertEqual(try titles(7), [])
    }

    func testTrainingDaysApplyFromTheirWeekOn() throws {
        try makePlan()
        try call("set_training_days", ["days": ["Tue", "saturday"], "from": key(7)])
        let later = try call("get_schedule", ["date": key(7), "days": 1])
        XCTAssertEqual(later["trainingDays"] as? [String], ["Tue", "Sat"])
        let earlier = try call("get_schedule", ["date": key(0), "days": 1])
        XCTAssertEqual(earlier["trainingDays"] as? [String], ["Mon", "Wed", "Fri"])
    }

    func testDryRunChangesNothingAndUndoPutsTheScheduleBack() throws {
        try call("create_schedule_plan", ["name": "Block", "entries": [["workout": "Boxing A", "weekday": 1]], "use": true, "from": key(0)], dryRun: true)
        XCTAssertNil(try database.loadConfig().workoutSchedule)

        try makePlan()
        let before = try database.loadConfig().workoutSchedule
        let output = try toolbox.call("add_schedule_entry", arguments: ["workout": "Boxing B", "date": key(1), "done": true], dryRun: false)
        XCTAssertNotEqual(try database.loadConfig().workoutSchedule, before)
        toolbox.revert(output.effects)
        XCTAssertEqual(try database.loadConfig().workoutSchedule, before)
    }

    func testPlanEditsKeepEntryIdsAndADeletedPlanLeavesWeeksThatFollowedIt() throws {
        try makePlan()
        let plan = try (call("list_schedule_plans", [:])["plans"] as! [[String: Any]])[0]
        let wednesday = try XCTUnwrap((plan["entries"] as! [[String: Any]]).first { $0["weekday"] as? String == "Wed" })
        let id = try XCTUnwrap(wednesday["id"] as? String)

        try call("update_schedule_plan", ["plan": "Block", "entries": [["id": id, "weekday": "Thu"]], "from": key(7)])
        XCTAssertEqual(try titles(9), [])
        XCTAssertEqual(try titles(10), ["Boxing B"])
        XCTAssertEqual(try entries(10)[0]["id"] as? String, id)
        XCTAssertEqual(try entries(10)[0]["start"] as? String, "18:00")
        XCTAssertEqual(try titles(2), ["Boxing B"])
        XCTAssertEqual(try titles(7), [])

        try call("delete_schedule_plan", ["plan": "Block"])
        XCTAssertEqual((try call("list_schedule_plans", [:])["plans"] as? [[String: Any]])?.count ?? 0, 0)
        XCTAssertEqual(try titles(10), ["Boxing B"])
    }

    func testManyDatedEntriesAreAddedTogetherOrNotAtAllAndUndoneTogether() throws {
        let planned: [[String: Any]] = [
            ["date": key(0), "workout": "Boxing A", "start": "07:00"],
            ["date": key(9), "workout": "Boxing B", "start": "18:00", "minutes": 40],
            ["date": key(20), "title": "Mobility", "done": true],
        ]
        let output = try toolbox.call("add_schedule_entries", arguments: ["entries": planned], dryRun: false)
        XCTAssertEqual(output.value["added"] as? Int, 3)
        XCTAssertEqual(try titles(0), ["Boxing A"])
        XCTAssertEqual(try entries(9)[0]["minutes"] as? Int, 40)
        XCTAssertEqual(try entries(20)[0]["done"] as? Bool, true)
        XCTAssertEqual(try titles(7), [])

        let before = try database.loadConfig().workoutSchedule
        XCTAssertThrowsError(try call("add_schedule_entries", ["entries": [["date": key(1), "title": "Run"], ["date": key(2), "start": "07:00"]]])) { error in
            XCTAssertEqual((error as? AgentToolError)?.code, "entry_failed")
        }
        XCTAssertEqual(try database.loadConfig().workoutSchedule, before)
        XCTAssertEqual(try titles(1), [])

        toolbox.revert(output.effects)
        XCTAssertEqual(try titles(0), [])
        XCTAssertEqual(try titles(9), [])
        XCTAssertEqual(try titles(20), [])
    }

    func testBadInputIsRefusedWithAHintAndAnotherSettingSurvivesScheduleChanges() throws {
        var config = try database.loadConfig()
        config.weeklyGoal = 6
        try database.saveConfig(config)
        try makePlan()
        XCTAssertEqual(try database.loadConfig().weeklyGoal, 6)

        expectError("invalid_date", "add_schedule_entry", ["title": "Run", "date": "2026-02-31"])
        expectError("invalid_time", "add_schedule_entry", ["title": "Run", "date": key(1), "start": "25:00"])
        expectError("invalid_weekday", "create_schedule_plan", ["name": "Odd", "entries": [["title": "Run", "weekday": "Funday"]]])
        expectError("not_found", "complete_schedule_entry", ["entry": "Nothing", "date": key(0)])
        expectError("invalid_argument", "select_schedule_plan", ["plan": "Block", "vacation": true])
        expectError("invalid_argument", "add_schedule_entry", ["date": key(1)])
        expectError("already_exists", "create_schedule_plan", ["name": "block"])
        expectError("invalid_argument", "update_schedule_entry", ["entry": "Boxing A", "date": key(0), "scope": "plan", "moveTo": key(3)])
        expectError("invalid_argument", "update_schedule_entry", ["entry": "Boxing A", "date": key(0), "weekday": "Tue"])

        try call("add_schedule_entry", ["title": "Stretch", "date": key(3)])
        expectError("not_in_plan", "update_schedule_entry", ["entry": "Stretch", "date": key(3), "scope": "plan", "start": "10:00"])
        expectError("not_in_plan", "remove_schedule_entry", ["entry": "Stretch", "date": key(3), "scope": "plan"])
    }

    func testAnOlderConfigWithoutAScheduleReadsAsEmpty() throws {
        let value = try call("get_schedule", [:])
        XCTAssertEqual((value["days"] as? [[String: Any]])?.count, 7)
        XCTAssertNil(value["streak"])
        XCTAssertNil((value["days"] as? [[String: Any]])?.first?["entries"])
    }
}
