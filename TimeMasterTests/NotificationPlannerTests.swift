import XCTest
@testable import TimeMaster

final class NotificationPlannerTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func schedule(days: Set<Int>, type: WorkoutType = .strength, endedAt: Date? = nil) -> TypeSchedule {
        var schedule = TypeSchedule(type: type, daysOfWeek: days, startDate: date(1, 0), durationMonths: 0, weeklyGoal: 3)
        schedule.endedAt = endedAt
        return schedule
    }

    private func entry(type: WorkoutType, at completedAt: Date) -> WorkoutHistoryEntry {
        WorkoutHistoryEntry(workoutId: UUID(), workoutName: "Session", completedAt: completedAt, durationCompleted: 600, workoutType: type)
    }

    func testNudgeFiresOneHourAfterWorkoutTimeWhileTheWindowIsStillOpen() {
        let nudges = NotificationPlanner.missedNudges(
            schedules: [schedule(days: [3])], history: [], hour: 9, minute: 0, now: date(21, 9, 30)
        )
        XCTAssertEqual(nudges.map(\.workoutDate), [date(21, 9)])
        XCTAssertEqual(nudges.map(\.fireDate), [date(21, 10)])
    }

    func testNoNudgeIsPlannedInThePastOnceTheWindowHasClosed() {
        let nudges = NotificationPlanner.missedNudges(
            schedules: [schedule(days: [3])], history: [], hour: 9, minute: 0, now: date(21, 10, 30)
        )
        XCTAssertTrue(nudges.isEmpty)
    }

    func testCompletingTheSameTypeThatDayCancelsOnlyThatNudge() {
        let schedules = [schedule(days: [3, 5])]
        let done = [entry(type: .strength, at: date(21, 9, 20))]
        let nudges = NotificationPlanner.missedNudges(schedules: schedules, history: done, hour: 9, minute: 0, now: date(21, 9, 30))
        XCTAssertEqual(nudges.map(\.workoutDate), [date(23, 9)])
        let otherType = [entry(type: .hiit, at: date(21, 9, 20))]
        let unaffected = NotificationPlanner.missedNudges(schedules: schedules, history: otherType, hour: 9, minute: 0, now: date(21, 9, 30))
        XCTAssertEqual(unaffected.map(\.workoutDate), [date(21, 9), date(23, 9)])
    }

    func testEndedScheduleStopsNudgingFromItsEndDay() {
        let ended = schedule(days: [3, 5], endedAt: date(22, 0))
        let nudges = NotificationPlanner.missedNudges(schedules: [ended], history: [], hour: 9, minute: 0, now: date(21, 9, 30))
        XCTAssertEqual(nudges.map(\.workoutDate), [date(21, 9)])
    }

    func testSundayUsesMondayBasedSeven() {
        XCTAssertEqual(NotificationPlanner.mondayBasedWeekday(of: date(25, 12), calendar: calendar), 7)
        XCTAssertEqual(NotificationPlanner.mondayBasedWeekday(of: date(19, 12), calendar: calendar), 1)
        let nudges = NotificationPlanner.missedNudges(
            schedules: [schedule(days: [7])], history: [], hour: 18, minute: 30, now: date(21, 9)
        )
        XCTAssertEqual(nudges.map(\.fireDate), [date(25, 19, 30)])
    }
}
