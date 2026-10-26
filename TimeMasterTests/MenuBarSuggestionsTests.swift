import XCTest
@testable import TimeMaster

final class MenuBarSuggestionsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: hour, minute: minute))!
    }

    private func input(
        hour: Int = 10,
        scheduled: [MenuBarSuggestionInput.Scheduled] = [],
        sessions: Int = 0,
        goal: Int = 4,
        streak: Int = 0,
        trainedToday: Bool = false,
        rest: Bool = false,
        resumable: MenuBarSuggestionInput.Resumable? = nil,
        running: Bool = false,
        waiting: [MenuBarSuggestionInput.WaitingType] = []
    ) -> MenuBarSuggestionInput {
        MenuBarSuggestionInput(
            now: date(hour),
            calendar: calendar,
            scheduledToday: scheduled,
            sessionsThisWeek: sessions,
            weeklyGoal: goal,
            currentStreak: streak,
            trainedToday: trainedToday,
            isRestDay: rest,
            resumable: resumable,
            isWorkoutRunning: running,
            waitingTypes: waiting
        )
    }

    private func item(
        _ name: String = "Legs",
        start: Date,
        status: ScheduledWorkoutStatus = .pending,
        hasTime: Bool = true,
        canStart: Bool = true
    ) -> MenuBarSuggestionInput.Scheduled {
        MenuBarSuggestionInput.Scheduled(workoutID: UUID(), name: name, start: start, hasTime: hasTime, status: status, canStart: canStart)
    }

    private func kinds(_ input: MenuBarSuggestionInput) -> [MenuBarSuggestion.Kind] {
        MenuBarSuggestionEngine.make(input).map(\.kind)
    }

    func testNothingIsSuggestedWhileAWorkoutRuns() {
        let busy = input(scheduled: [item(start: date(10, 10))], sessions: 3, streak: 5, rest: true, running: true)
        XCTAssertEqual(kinds(busy), [])
    }

    func testAQuietDayHasNoSuggestions() {
        XCTAssertEqual(kinds(input()), [])
    }

    func testResumeComesFirstAndStartsTheSavedWorkout() {
        let id = UUID()
        let result = MenuBarSuggestionEngine.make(
            input(scheduled: [item(start: date(10, 10))], resumable: .init(workoutID: id, name: "Legs"))
        )
        XCTAssertEqual(result.first?.kind, .resume)
        XCTAssertEqual(result.first?.action, .startWorkout(id))
    }

    func testAWorkoutStartingWithinHalfAnHourIsSuggested() {
        let planned = item(start: date(10, 20))
        let result = MenuBarSuggestionEngine.make(input(scheduled: [planned]))
        XCTAssertEqual(result.map(\.kind), [.startSoon])
        XCTAssertEqual(result.first?.action, .startWorkout(planned.workoutID))
    }

    func testAWorkoutLaterThanHalfAnHourIsNotSuggested() {
        XCTAssertEqual(kinds(input(scheduled: [item(start: date(10, 31))])), [])
    }

    func testAWorkoutWithoutATimeOrWithoutExercisesIsNotSuggestedAsComingUp() {
        XCTAssertEqual(kinds(input(scheduled: [item(start: date(10, 10), hasTime: false)])), [])
        XCTAssertEqual(kinds(input(scheduled: [item(start: date(10, 10), canStart: false)])), [])
    }

    func testAMissedWorkoutOffersAShortSession() {
        let missed = item("Core", start: date(7), status: .missed)
        let result = MenuBarSuggestionEngine.make(input(scheduled: [missed]))
        XCTAssertEqual(result.map(\.kind), [.missed])
        XCTAssertEqual(result.first?.action, .startWorkout(missed.workoutID))
    }

    func testTheStreakIsAtRiskOnlyLateInTheDayWithNothingLoggedAndNoRestDay() {
        XCTAssertEqual(kinds(input(hour: 19, streak: 6)), [.streakAtRisk])
        XCTAssertEqual(kinds(input(hour: 17, streak: 6)), [])
        XCTAssertEqual(kinds(input(hour: 19, streak: 6, trainedToday: true)), [])
        XCTAssertEqual(kinds(input(hour: 19, streak: 0)), [])
        XCTAssertEqual(kinds(input(hour: 19, streak: 6, rest: true)), [.restDay])
    }

    func testWeeklyGoalMessages() {
        XCTAssertEqual(kinds(input(sessions: 3, goal: 4)), [.goalAlmostMet])
        XCTAssertEqual(kinds(input(sessions: 4, goal: 4)), [.goalMet])
        XCTAssertEqual(kinds(input(sessions: 6, goal: 4)), [.goalMet])
        XCTAssertEqual(kinds(input(sessions: 1, goal: 4)), [])
        XCTAssertEqual(kinds(input(sessions: 3, goal: 0)), [])
    }

    func testTheMostNeglectedTypeIsSuggestedAfterAWeek() {
        let legs = MenuBarSuggestionInput.WaitingType(typeName: "Legs", daysSinceLast: 9, workoutID: UUID())
        let core = MenuBarSuggestionInput.WaitingType(typeName: "Core", daysSinceLast: 12, workoutID: UUID())
        let fresh = MenuBarSuggestionInput.WaitingType(typeName: "Arms", daysSinceLast: 6, workoutID: UUID())
        let result = MenuBarSuggestionEngine.make(input(waiting: [legs, core, fresh]))
        XCTAssertEqual(result.map(\.kind), [.typeWaiting])
        XCTAssertEqual(result.first?.action, .startWorkout(core.workoutID))
        XCTAssertEqual(kinds(input(waiting: [fresh])), [])
    }

    func testRestDayOffersTheCoach() {
        let result = MenuBarSuggestionEngine.make(input(rest: true))
        XCTAssertEqual(result.map(\.kind), [.restDay])
        XCTAssertEqual(result.first?.action, .openPage(.coach))
    }

    func testSuggestionsAreOrderedByUrgency() {
        let planned = item(start: date(19, 10))
        let missed = item("Core", start: date(7), status: .missed)
        let result = kinds(
            input(
                hour: 19,
                scheduled: [planned, missed],
                sessions: 3,
                streak: 4,
                resumable: .init(workoutID: UUID(), name: "Legs"),
                waiting: [.init(typeName: "Arms", daysSinceLast: 8, workoutID: UUID())]
            )
        )
        XCTAssertEqual(result, [.resume, .startSoon, .missed, .streakAtRisk, .goalAlmostMet, .typeWaiting])
    }
}
