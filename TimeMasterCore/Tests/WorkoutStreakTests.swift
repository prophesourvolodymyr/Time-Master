import XCTest
@testable import TimeMasterCore

final class WorkoutStreakTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 18))!
    }

    private func streak(workouts: [Int], rest: Set<Int> = []) -> Int {
        let workoutDays = Set(workouts.map { day($0, from: today) })
        let restDays = Set(rest.map { day($0, from: today) })
        return WorkoutStreak.current(
            workoutDays: workoutDays,
            isRestDay: { restDays.contains(self.calendar.startOfDay(for: $0)) },
            today: today,
            calendar: calendar
        )
    }

    func testNoWorkoutsIsZero() {
        XCTAssertEqual(streak(workouts: []), 0)
    }

    func testRestDaysAloneNeverMakeAStreak() {
        XCTAssertEqual(streak(workouts: [], rest: [0, -1, -2]), 0)
        XCTAssertEqual(streak(workouts: [-20], rest: [0, -1, -2]), 0)
    }

    func testTodayCounts() {
        XCTAssertEqual(streak(workouts: [0]), 1)
        XCTAssertEqual(streak(workouts: [0, -1, -2]), 3)
    }

    func testTheStreakStaysAliveUntilTheDayIsMissed() {
        XCTAssertEqual(streak(workouts: [-1, -2, -3]), 3)
        XCTAssertEqual(streak(workouts: [-2, -3]), 0)
    }

    func testAGapEndsTheStreak() {
        XCTAssertEqual(streak(workouts: [0, -1, -3, -4]), 2)
    }

    func testRestDaysKeepTheStreakGoing() {
        XCTAssertEqual(streak(workouts: [0, -2, -3], rest: [-1]), 4)
        XCTAssertEqual(streak(workouts: [-1, -3], rest: [0, -2]), 4)
        XCTAssertEqual(streak(workouts: [-2], rest: [-1]), 2)
    }

    func testRestDaysBeforeTheFirstWorkoutAreNotCounted() {
        XCTAssertEqual(streak(workouts: [0], rest: Set(-30...(-1))), 1)
    }

    func testAnEndlessRestPeriodDoesNotLoopForever() {
        XCTAssertEqual(WorkoutStreak.current(
            workoutDays: [day(-3, from: today)],
            isRestDay: { _ in true },
            today: today,
            calendar: calendar
        ), 4)
    }
}
