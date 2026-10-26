import XCTest
@testable import TimeMaster

final class MenuBarActivitySummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 12, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func entry(
        _ day: Int,
        hour: Int = 12,
        month: Int = 10,
        seconds: Int = 1800,
        partial: Bool = false,
        elapsed: Int = 0,
        type: WorkoutType = .strength,
        name: String = "Session"
    ) -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(
            workoutId: UUID(),
            workoutName: name,
            completedAt: date(day, hour, month: month),
            durationCompleted: seconds,
            workoutType: type,
            isPartial: partial,
            elapsedSeconds: elapsed
        )
    }

    private func make(
        _ entries: [WorkoutHistoryEntry],
        now: Date? = nil,
        goal: Int = 4,
        streak: (current: Int, best: Int) = (0, 0)
    ) -> MenuBarActivitySummary {
        MenuBarActivitySummary.make(
            entries: entries,
            now: now ?? date(28),
            calendar: calendar,
            weeklyGoal: goal,
            streak: streak
        )
    }

    func testEmptyHistoryHasZeroedNumbersAndAFullWeekOfEmptyDays() {
        let summary = make([])
        XCTAssertFalse(summary.hasHistory)
        XCTAssertEqual(summary.sessionsThisWeek, 0)
        XCTAssertEqual(summary.weekSeconds, 0)
        XCTAssertEqual(summary.days.count, 7)
        XCTAssertTrue(summary.days.allSatisfy { $0.seconds == 0 })
        XCTAssertEqual(summary.days.last?.isToday, true)
        XCTAssertTrue(summary.monthByType.isEmpty)
        XCTAssertTrue(summary.recent.isEmpty)
        XCTAssertEqual(summary.goalProgress, 0)
    }

    func testTheWeekStartsOnTheCalendarsFirstWeekday() {
        let sunday = entry(25)
        let monday = entry(26)
        let tuesday = entry(27, seconds: 600)
        let summary = make([sunday, monday, tuesday], now: date(28))
        XCTAssertEqual(summary.sessionsThisWeek, 2)
        XCTAssertEqual(summary.weekSeconds, 1800 + 600)
    }

    func testSessionsAfterNowDoNotCount() {
        let future = entry(28, hour: 20)
        let summary = make([future], now: date(28, 9))
        XCTAssertEqual(summary.sessionsThisWeek, 0)
        XCTAssertEqual(summary.days.last?.seconds, 0)
        XCTAssertTrue(summary.monthByType.isEmpty)
        XCTAssertTrue(summary.recent.isEmpty)
        XCTAssertFalse(summary.hasHistory)
    }

    func testPartialSessionsCountTheirElapsedTimeNotThePlannedDuration() {
        let partial = entry(27, seconds: 3000, partial: true, elapsed: 400)
        let summary = make([partial])
        XCTAssertEqual(summary.weekSeconds, 400)
        XCTAssertEqual(summary.recent.first?.seconds, 400)
        XCTAssertEqual(summary.recent.first?.isPartial, true)
    }

    func testTheLastSevenDaysEndTodayAndAddUpPerDay() {
        let summary = make([entry(28, hour: 8, seconds: 600), entry(28, hour: 18, seconds: 300), entry(22, seconds: 900), entry(21, seconds: 999)], now: date(28, 20))
        XCTAssertEqual(summary.days.map { calendar.component(.day, from: $0.date) }, [22, 23, 24, 25, 26, 27, 28])
        XCTAssertEqual(summary.days.first?.seconds, 900)
        XCTAssertEqual(summary.days.last?.seconds, 900)
        XCTAssertEqual(summary.busiestDaySeconds, 900)
    }

    func testMonthTimeIsSplitByTypeAndLimitedToTheTopThree() {
        let legs = WorkoutType(id: "legs", name: "Legs", iconName: "figure.walk", colorHex: "FF0000")
        let core = WorkoutType(id: "core", name: "Core", iconName: "figure.core.training", colorHex: "00FF00")
        let arms = WorkoutType(id: "arms", name: "Arms", iconName: "dumbbell", colorHex: "0000FF")
        let yoga = WorkoutType(id: "yoga", name: "Yoga", iconName: "figure.yoga", colorHex: "FFFF00")
        let entries = [
            entry(2, seconds: 3000, type: legs),
            entry(3, seconds: 1000, type: core),
            entry(4, seconds: 500, type: arms),
            entry(5, seconds: 100, type: yoga),
            entry(30, month: 9, seconds: 9999, type: yoga)
        ]
        let summary = make(entries)
        XCTAssertEqual(summary.monthByType.map(\.typeID), ["legs", "core", "arms"])
        XCTAssertEqual(summary.monthByType.first?.fraction ?? 0, 3000.0 / 4600.0, accuracy: 0.0001)
    }

    func testRecentSessionsAreNewestFirstAndLimited() {
        let entries = (1...12).map { entry($0, name: "Day \($0)") }
        let summary = make(entries)
        XCTAssertEqual(summary.recent.count, MenuBarActivitySummary.recentLimit)
        XCTAssertEqual(summary.recent.first?.name, "Day 12")
        XCTAssertEqual(summary.recent.last?.name, "Day 5")
    }

    func testGoalProgressIsCappedAndIgnoresAnUnsetGoal() {
        let entries = [entry(26), entry(27), entry(28, hour: 9)]
        XCTAssertEqual(make(entries, now: date(28, 20), goal: 6).goalProgress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(make(entries, now: date(28, 20), goal: 2).goalProgress, 1)
        XCTAssertEqual(make(entries, now: date(28, 20), goal: 0).goalProgress, 0)
    }

}
