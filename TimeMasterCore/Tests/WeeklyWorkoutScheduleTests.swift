import XCTest
@testable import TimeMasterCore

final class WeeklyWorkoutScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ key: String) -> Date { WeeklyWorkoutSchedule.date(for: key, calendar: calendar)! }

    private func plan(days: [Int] = [1], workoutID: UUID = UUID()) -> WeeklyWorkoutSchedule.Plan {
        WeeklyWorkoutSchedule.Plan(name: "Strength", entries: days.map {
            WeeklyWorkoutSchedule.Entry(workoutID: workoutID, title: "Strength", weekday: $0, startMinute: 1080, durationSeconds: 1800)
        })
    }

    private func equipped(_ plan: WeeklyWorkoutSchedule.Plan, start: String = "2026-01-05") -> WeeklyWorkoutSchedule {
        var schedule = WeeklyWorkoutSchedule()
        schedule.savePlan(plan)
        schedule.equip(plan, from: date(start), now: date(start), calendar: calendar)
        return schedule
    }

    func testRepeatsUntilAnotherPlanAndPreservesPastSnapshot() {
        let first = plan()
        var schedule = equipped(first)
        XCTAssertEqual(schedule.entries(on: date("2026-01-12"), calendar: calendar), first.entries)
        var edited = first
        edited.entries[0].title = "New month"
        schedule.savePlan(edited)
        XCTAssertEqual(schedule.entries(on: date("2026-01-05"), calendar: calendar)[0].title, "Strength")
        schedule.equip(edited, from: date("2026-02-02"), now: date("2026-01-05"), calendar: calendar)
        XCTAssertEqual(schedule.entries(on: date("2026-01-26"), calendar: calendar)[0].title, "Strength")
        XCTAssertEqual(schedule.entries(on: date("2026-02-09"), calendar: calendar)[0].title, "New month")
    }

    func testVacationFreezesEmptyWeeksAndResumeContinuesCounter() {
        let first = plan()
        var schedule = equipped(first)
        schedule.setChallenge(weekdays: [1], from: date("2026-01-05"), calendar: calendar)
        schedule.setComplete(true, entryID: first.entries[0].id, on: date("2026-01-05"), calendar: calendar)
        schedule.equip(nil, from: date("2026-01-12"), now: date("2026-01-05"), calendar: calendar)
        let vacation = schedule.progress(through: date("2026-02-02"), now: date("2026-02-02"), activity: .init(), calendar: calendar)
        XCTAssertEqual(vacation.weekNumber, 1)
        XCTAssertTrue(vacation.isVacation)
        XCTAssertEqual(schedule.entries(on: date("2026-02-02"), calendar: calendar), [])
        schedule.equip(first, from: date("2026-02-09"), now: date("2026-02-09"), calendar: calendar)
        let resumed = schedule.progress(through: date("2026-02-09"), now: date("2026-02-09"), activity: .init(), calendar: calendar)
        XCTAssertEqual(resumed.weekNumber, 2)
        XCTAssertFalse(resumed.isVacation)
        XCTAssertEqual(schedule.entries(on: date("2026-02-09"), calendar: calendar), first.entries)
    }

    func testOneSessionCannotCompleteTwoOccurrencesAndOverridesWin() {
        let workoutID = UUID()
        var first = plan(workoutID: workoutID)
        var second = first.entries[0]
        second.id = UUID()
        second.startMinute = 1200
        first.entries.append(second)
        var schedule = equipped(first)
        let activity = WeeklyWorkoutSchedule.Activity(sessions: [
            .init(id: UUID(), workoutID: workoutID, date: date("2026-01-05").addingTimeInterval(70000))
        ], calendar: calendar)
        var rows = schedule.occurrences(on: date("2026-01-05"), activity: activity, calendar: calendar)
        XCTAssertEqual(rows.map(\.isComplete), [true, false])
        schedule.setComplete(false, entryID: first.entries[0].id, on: date("2026-01-05"), calendar: calendar)
        rows = schedule.occurrences(on: date("2026-01-05"), activity: activity, calendar: calendar)
        XCTAssertEqual(rows.map(\.isComplete), [false, false])
        schedule.setComplete(nil, entryID: first.entries[0].id, on: date("2026-01-05"), calendar: calendar)
        schedule.setComplete(true, entryID: second.id, on: date("2026-01-05"), calendar: calendar)
        XCTAssertEqual(schedule.occurrences(on: date("2026-01-05"), activity: activity, calendar: calendar).map(\.isComplete), [true, true])
        XCTAssertEqual(schedule.activityCount(on: date("2026-01-05"), activity: activity, calendar: calendar), 2)
    }

    func testSelectedDaysRequireAllWorkoutsButDoNotFailBeforeMidnight() {
        let first = plan(days: [1, 3])
        var schedule = equipped(first)
        schedule.setChallenge(weekdays: [1, 3], from: date("2026-01-05"), calendar: calendar)
        let mondayEvening = date("2026-01-05").addingTimeInterval(86399)
        XCTAssertFalse(schedule.progress(through: mondayEvening, now: mondayEvening, activity: .init(), calendar: calendar).isBroken)
        XCTAssertTrue(schedule.progress(through: date("2026-01-06"), now: date("2026-01-06"), activity: .init(), calendar: calendar).isBroken)
        schedule.setComplete(true, entryID: first.entries[0].id, on: date("2026-01-05"), calendar: calendar)
        let tuesday = schedule.progress(through: date("2026-01-06"), now: date("2026-01-06"), activity: .init(), calendar: calendar)
        XCTAssertFalse(tuesday.isBroken)
        XCTAssertEqual(tuesday.completedDays, 1)
        XCTAssertEqual(tuesday.requiredDays, 2)
        let thursday = schedule.progress(through: date("2026-01-08"), now: date("2026-01-08"), activity: .init(), calendar: calendar)
        XCTAssertTrue(thursday.isBroken)
        XCTAssertEqual(thursday.weekNumber, 0)
    }

    func testCustomTitleOnlyLogDoesNotRepeatOrRewritePlan() {
        let first = plan()
        var schedule = equipped(first)
        let custom = WeeklyWorkoutSchedule.Entry(title: "Walk with friends", weekday: 1)
        schedule.setEntry(custom, on: date("2026-01-05"), calendar: calendar)
        schedule.setComplete(true, entryID: custom.id, on: date("2026-01-05"), calendar: calendar)
        let rows = schedule.occurrences(on: date("2026-01-05"), activity: .init(), calendar: calendar)
        XCTAssertEqual(rows.map(\.entry.title), ["Strength", "Walk with friends"])
        XCTAssertNil(rows[1].start)
        XCTAssertNil(rows[1].entry.durationSeconds)
        XCTAssertTrue(rows[1].isComplete)
        XCTAssertEqual(schedule.entries(on: date("2026-01-12"), calendar: calendar), first.entries)
        XCTAssertEqual(schedule.plans[0], first)
    }

    func testDatedEditsDoNotEraseOtherDaysOrCustomLogs() {
        let first = plan()
        var schedule = equipped(first)
        let custom = WeeklyWorkoutSchedule.Entry(title: "Yoga", weekday: 1)
        schedule.setEntry(custom, on: date("2026-01-05"), calendar: calendar)
        var moved = first.entries[0]
        moved.startMinute = 600
        schedule.setEntry(moved, on: date("2026-01-05"), calendar: calendar)
        XCTAssertEqual(schedule.entries(on: date("2026-01-05"), calendar: calendar).map(\.startMinute), [600, nil])
        schedule.removeEntry(moved, on: date("2026-01-05"), calendar: calendar)
        XCTAssertEqual(schedule.entries(on: date("2026-01-05"), calendar: calendar), [custom])
        XCTAssertEqual(schedule.entries(on: date("2026-01-12"), calendar: calendar), first.entries)
    }

    func testMidweekStartAndChallengeChangesDoNotRewriteEarlierWeeks() {
        let first = plan(days: [1, 3, 5])
        var schedule = equipped(first, start: "2026-01-07")
        schedule.setChallenge(weekdays: [1, 3, 5], from: date("2026-01-07"), calendar: calendar)
        let start = schedule.progress(through: date("2026-01-07"), now: date("2026-01-07"), activity: .init(), calendar: calendar)
        XCTAssertFalse(start.isBroken)
        XCTAssertEqual(start.requiredDays, 2)
        XCTAssertEqual(schedule.entries(on: date("2026-01-05"), calendar: calendar), [])
        schedule.setChallenge(weekdays: [2], from: date("2026-01-12"), calendar: calendar)
        XCTAssertEqual(schedule.challenge(for: date("2026-01-07"), calendar: calendar).weekdays, [1, 3, 5])
        XCTAssertEqual(schedule.challenge(for: date("2026-01-19"), calendar: calendar).weekdays, [2])
    }

    func testCalendarWeekAndWallClockSurviveDaylightSavingAndYearBoundary() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = WeeklyWorkoutSchedule.date(for: "2026-03-02", calendar: local)!
        let sunday = WeeklyWorkoutSchedule.date(for: "2026-03-08", calendar: local)!
        let next = WeeklyWorkoutSchedule.date(for: "2026-03-09", calendar: local)!
        let entry = WeeklyWorkoutSchedule.Entry(title: "Morning", weekday: 7, startMinute: 9 * 60)
        let first = WeeklyWorkoutSchedule.Plan(name: "DST", entries: [entry])
        var schedule = WeeklyWorkoutSchedule()
        schedule.equip(first, from: start, now: start, calendar: local)
        let occurrence = schedule.occurrences(on: sunday, activity: .init(), calendar: local)[0]
        XCTAssertEqual(local.component(.hour, from: occurrence.start!), 9)
        XCTAssertEqual(next.timeIntervalSince(start), 167 * 3600)
        XCTAssertEqual(WeeklyWorkoutSchedule.weekStart(sunday, calendar: local), start)
        XCTAssertEqual(WeeklyWorkoutSchedule.dayKey(WeeklyWorkoutSchedule.weekStart(date("2026-01-01"), calendar: calendar), calendar: calendar), "2025-12-29")
    }

    func testEmptyPlanDoesNotStartStreakAndFuturePlanDoesNotBackdateIt() {
        var schedule = WeeklyWorkoutSchedule()
        let today = date("2026-01-05")
        schedule.equip(.init(name: "Draft"), from: today, now: today, calendar: calendar)
        XCTAssertEqual(schedule.progress(through: today, now: today, activity: .init(), calendar: calendar).weekNumber, 0)
        XCTAssertNil(schedule.startedOn)
        schedule.equip(plan(), from: date("2026-02-02"), now: today, calendar: calendar)
        XCTAssertEqual(schedule.startedOn, "2026-02-02")
        XCTAssertEqual(schedule.entries(on: today, calendar: calendar), [])
        XCTAssertEqual(schedule.progress(through: today, now: today, activity: .init(), calendar: calendar).weekNumber, 0)
    }

    func testIncompleteSecondWorkoutBreaksChosenDayAndFutureLogsCannotEarnProgress() {
        var first = plan()
        var second = first.entries[0]
        second.id = UUID()
        first.entries.append(second)
        var schedule = equipped(first)
        schedule.setChallenge(weekdays: [1], from: date("2026-01-05"), calendar: calendar)
        schedule.setComplete(true, entryID: first.entries[0].id, on: date("2026-01-05"), calendar: calendar)
        let missed = schedule.progress(through: date("2026-01-06"), now: date("2026-01-06"), activity: .init(), calendar: calendar)
        XCTAssertTrue(missed.isBroken)
        XCTAssertEqual(missed.completedDays, 0)
        schedule.setComplete(true, entryID: second.id, on: date("2026-01-05"), calendar: calendar)
        for entry in first.entries {
            schedule.setComplete(true, entryID: entry.id, on: date("2026-01-12"), calendar: calendar)
        }
        let current = schedule.progress(through: date("2026-01-12"), now: date("2026-01-06"), activity: .init(), calendar: calendar)
        XCTAssertEqual(current.weekNumber, 1)
        XCTAssertEqual(current.completedDays, 1)
    }

    func testConfigPersistenceRetainsScheduleAndUnrelatedPreferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try database.bootstrapIfNeeded()
        var config = try database.loadConfig()
        config.weeklyGoal = 6
        config.restDays = ["2026-01-01"]
        config.workoutSchedule = equipped(plan())
        try database.saveConfig(config)
        let reopened = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        let restored = try reopened.loadConfig()
        XCTAssertEqual(restored.workoutSchedule, config.workoutSchedule)
        XCTAssertEqual(restored.weeklyGoal, 6)
        XCTAssertEqual(restored.restDays, ["2026-01-01"])
        let legacy = try JSONDecoder().decode(ConfigManifest.self, from: Data("{\"weeklyGoal\":2}".utf8))
        XCTAssertNil(legacy.workoutSchedule)
        XCTAssertEqual(legacy.weeklyGoal, 2)
    }
}
