import XCTest
@testable import TimeMaster

final class MenuBarItemPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(
        phase: WorkoutPhase = .active,
        title: String = "Squat",
        remaining: Int = 30,
        duration: Int = 40,
        paused: Bool = false,
        next: String? = "Lunge"
    ) -> WorkoutLiveState {
        WorkoutLiveState(
            workoutID: UUID(),
            workoutName: "Legs",
            colorHex: "FF6A00",
            phase: phase,
            title: title,
            subtitle: "Set 1 of 3",
            isPaused: paused,
            remainingSeconds: remaining,
            phaseDuration: duration,
            sectionIndex: 0,
            sectionCount: 2,
            elapsedSeconds: 100,
            totalSeconds: 1200,
            nextTitle: next,
            startedAt: now
        )
    }

    private func make(
        state: WorkoutLiveState? = nil,
        finish: WorkoutLiveFinish? = nil,
        upcoming: MenuBarUpcoming? = nil,
        showsLabel: Bool = true
    ) -> MenuBarItemPresentation {
        MenuBarItemPresentation.make(state: state, finish: finish, upcoming: upcoming, now: now, showsLabel: showsLabel)
    }

    func testNothingHappeningShowsTheIdleMark() {
        let result = make()
        XCTAssertEqual(result.glyph, .idle)
        XCTAssertNil(result.label)
    }

    func testActiveExerciseShowsRingAndShortLabel() {
        let result = make(state: state(remaining: 32, duration: 40))
        XCTAssertEqual(result.glyph, .exercise)
        XCTAssertEqual(result.progress ?? 0, 0.2, accuracy: 0.001)
    }

    func testRestShowsTheRestClock() {
        let result = make(state: state(phase: .setRest, title: "Rest", remaining: 25, duration: 60))
        XCTAssertEqual(result.glyph, .rest)
    }

    func testLastFiveSecondsBeforeTheNextExerciseCountDown() {
        let rest = make(state: state(phase: .setRest, title: "Rest", remaining: 5, duration: 60, next: "Lunge"))
        XCTAssertEqual(rest.glyph, .countdown(5))

        let warmUp = make(state: state(phase: .warmUp, title: "Warm up", remaining: 1, duration: 120, next: "Squat"))
        XCTAssertEqual(warmUp.glyph, .countdown(1))
    }

    func testSixSecondsLeftIsStillTheNormalRest() {
        let rest = make(state: state(phase: .setRest, title: "Rest", remaining: 6, duration: 60))
        XCTAssertEqual(rest.glyph, .rest)
    }

    func testNoCountdownWithoutANextExercise() {
        let rest = make(state: state(phase: .setRest, title: "Rest", remaining: 3, duration: 60, next: nil))
        XCTAssertEqual(rest.glyph, .rest)
        let blank = make(state: state(phase: .setRest, title: "Rest", remaining: 3, duration: 60, next: ""))
        XCTAssertEqual(blank.glyph, .rest)
    }

    func testTheLastSecondsOfAnExerciseStayAnExercise() {
        let result = make(state: state(phase: .active, remaining: 4, duration: 40, next: "Lunge"))
        XCTAssertEqual(result.glyph, .exercise)
    }

    func testPausedWinsOverTheCountdown() {
        let result = make(state: state(phase: .setRest, title: "Rest", remaining: 3, duration: 60, paused: true))
        XCTAssertEqual(result.glyph, .paused)
    }

    func testLongNamesAreTruncatedToTheLabelLimitKeepingTheTime() {
        let result = make(state: state(title: "Bulgarian Split Squat With Dumbbells", remaining: 75, duration: 90))
        let label = result.label ?? ""
        XCTAssertLessThanOrEqual(label.count, MenuBarItemPresentation.labelLimit)
        XCTAssertTrue(label.hasSuffix(" 1:15"))
        XCTAssertTrue(label.contains("…"))

        let countdown = make(state: state(phase: .setRest, title: "Rest", remaining: 2, duration: 60, next: "Bulgarian Split Squat"))
        let countdownLabel = countdown.label ?? ""
        XCTAssertLessThanOrEqual(countdownLabel.count, MenuBarItemPresentation.labelLimit)
        XCTAssertTrue(countdownLabel.hasSuffix(" in 2"))
    }

    func testHoursAreShownInTheClock() {
        let result = make(state: state(title: "Run", remaining: 3725, duration: 4000))
        XCTAssertEqual(result.label, "Run 1:02:05")
    }

    func testHidingTheLabelKeepsTheIconAndAccessibilityText() {
        let result = make(state: state(), showsLabel: false)
        XCTAssertNil(result.label)
        XCTAssertEqual(result.glyph, .exercise)
        XCTAssertFalse(result.accessibilityLabel.isEmpty)
        XCTAssertFalse(result.tooltip.isEmpty)
    }

    func testFinishShowsDoneForTenSecondsOnly() {
        let finish = WorkoutLiveFinish(workoutName: "Legs", elapsedSeconds: 1500, finishedAt: now.addingTimeInterval(-9))
        XCTAssertEqual(make(finish: finish).glyph, .finished)

        let old = WorkoutLiveFinish(workoutName: "Legs", elapsedSeconds: 1500, finishedAt: now.addingTimeInterval(-10))
        XCTAssertEqual(make(finish: old).glyph, .idle)
    }

    func testUpcomingWorkoutShowsOnlyInsideTheFifteenMinuteWindow() {
        let soon = MenuBarUpcoming(name: "Legs", startsAt: now.addingTimeInterval(14 * 60))
        XCTAssertEqual(make(upcoming: soon).glyph, .upcoming)

        let edge = MenuBarUpcoming(name: "Legs", startsAt: now.addingTimeInterval(15 * 60))
        XCTAssertEqual(make(upcoming: edge).glyph, .upcoming)

        let later = MenuBarUpcoming(name: "Legs", startsAt: now.addingTimeInterval(15 * 60 + 1))
        XCTAssertEqual(make(upcoming: later).glyph, .idle)

        let started = MenuBarUpcoming(name: "Legs", startsAt: now)
        XCTAssertEqual(make(upcoming: started).glyph, .idle)
    }

    func testPriorityIsLiveThenFinishThenUpcoming() {
        let finish = WorkoutLiveFinish(workoutName: "Legs", elapsedSeconds: 600, finishedAt: now.addingTimeInterval(-1))
        let upcoming = MenuBarUpcoming(name: "Core", startsAt: now.addingTimeInterval(300))
        XCTAssertEqual(make(state: state(), finish: finish, upcoming: upcoming).glyph, .exercise)
        XCTAssertEqual(make(finish: finish, upcoming: upcoming).glyph, .finished)
        XCTAssertEqual(make(upcoming: upcoming).glyph, .upcoming)
    }
}
