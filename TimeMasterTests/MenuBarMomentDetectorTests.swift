import XCTest
@testable import TimeMaster

final class MenuBarMomentDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let workoutID = UUID()

    private func state(
        phase: WorkoutPhase = .active,
        title: String = "Squat",
        remaining: Int = 30,
        section: Int = 0,
        elapsed: Int = 100,
        total: Int = 1200,
        paused: Bool = false,
        next: String? = "Lunge",
        id: UUID? = nil
    ) -> WorkoutLiveState {
        WorkoutLiveState(
            workoutID: id ?? workoutID,
            workoutName: "Legs",
            colorHex: "FF6A00",
            phase: phase,
            title: title,
            subtitle: "",
            isPaused: paused,
            remainingSeconds: remaining,
            phaseDuration: 60,
            sectionIndex: section,
            sectionCount: 3,
            elapsedSeconds: elapsed,
            totalSeconds: total,
            nextTitle: next,
            startedAt: start
        )
    }

    private func kinds(_ moments: [MenuBarMoment]) -> [MenuBarMomentKind] {
        moments.map(\.kind)
    }

    func testCountdownFiresOnceWhenFiveSecondsRemainBeforeTheNextExercise() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(phase: .setRest, remaining: 7), finish: nil)
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, remaining: 6), finish: nil), [])
        let five = detector.ingest(state: state(phase: .setRest, remaining: 5), finish: nil)
        XCTAssertEqual(kinds(five), [.countdown])
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, remaining: 4), finish: nil), [])
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, remaining: 3), finish: nil), [])
    }

    func testCountdownIsNotRepeatedWhenGetReadyFollowsTheRest() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(phase: .setRest, remaining: 6), finish: nil)
        XCTAssertEqual(kinds(detector.ingest(state: state(phase: .setRest, remaining: 5), finish: nil)), [.countdown])
        XCTAssertEqual(detector.ingest(state: state(phase: .prepare, title: "Get ready", remaining: 4), finish: nil), [])
    }

    func testCountdownRearmsAfterTheNextExerciseRuns() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(phase: .setRest, remaining: 5), finish: nil)
        _ = detector.ingest(state: state(phase: .active, remaining: 40), finish: nil)
        let second = detector.ingest(state: state(phase: .setRest, remaining: 3), finish: nil)
        XCTAssertEqual(kinds(second), [.restStarted, .countdown])
    }

    func testNoCountdownWhilePausedOrWithoutANextExercise() {
        var detector = MenuBarMomentDetector()
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, remaining: 4, paused: true), finish: nil), [])
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, remaining: 4, next: nil), finish: nil), [])
    }

    func testRestStartedFiresOnTheTransitionIntoRest() {
        var detector = MenuBarMomentDetector()
        XCTAssertEqual(detector.ingest(state: state(phase: .active, remaining: 1), finish: nil), [])
        let rest = detector.ingest(state: state(phase: .setRest, title: "Rest", remaining: 60), finish: nil)
        XCTAssertEqual(kinds(rest), [.restStarted])
        XCTAssertEqual(detector.ingest(state: state(phase: .setRest, title: "Rest", remaining: 59), finish: nil), [])
    }

    func testJoiningMidRestDoesNotAnnounceTheRestStart() {
        var detector = MenuBarMomentDetector()
        XCTAssertEqual(detector.ingest(state: state(phase: .sectionRest, remaining: 40), finish: nil), [])
    }

    func testSectionChangeFiresWhenTheSectionIndexGrows() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(section: 0), finish: nil)
        let changed = detector.ingest(state: state(title: "Press", section: 1), finish: nil)
        XCTAssertEqual(kinds(changed), [.sectionChanged])
        XCTAssertEqual(detector.ingest(state: state(title: "Press", section: 1), finish: nil), [])
    }

    func testHalfwayFiresOnceWhenProgressCrossesOneHalf() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(elapsed: 598), finish: nil)
        let half = detector.ingest(state: state(elapsed: 600), finish: nil)
        XCTAssertEqual(kinds(half), [.halfway])
        XCTAssertEqual(detector.ingest(state: state(elapsed: 601), finish: nil), [])
    }

    func testHalfwayIsSkippedForShortWorkoutsAndWhenJoinedAfterIt() {
        var short = MenuBarMomentDetector()
        _ = short.ingest(state: state(elapsed: 50, total: 100), finish: nil)
        XCTAssertEqual(short.ingest(state: state(elapsed: 51, total: 100), finish: nil), [])

        var late = MenuBarMomentDetector()
        XCTAssertEqual(late.ingest(state: state(elapsed: 900), finish: nil), [])
    }

    func testLastMinuteFiresOnceWhenAMinuteRemains() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(elapsed: 1139), finish: nil)
        let last = detector.ingest(state: state(elapsed: 1140), finish: nil)
        XCTAssertEqual(kinds(last), [.lastMinute])
        XCTAssertEqual(detector.ingest(state: state(elapsed: 1141), finish: nil), [])
    }

    func testLastMinuteIsSkippedForVeryShortWorkouts() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(elapsed: 100, total: 170), finish: nil)
        XCTAssertEqual(detector.ingest(state: state(elapsed: 111, total: 170), finish: nil), [])
    }

    func testFinishedFiresOncePerFinish() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(), finish: nil)
        let finish = WorkoutLiveFinish(workoutName: "Legs", elapsedSeconds: 1500, finishedAt: start)
        let done = detector.ingest(state: nil, finish: finish)
        XCTAssertEqual(kinds(done), [.finished])
        XCTAssertEqual(detector.ingest(state: nil, finish: finish), [])

        let next = WorkoutLiveFinish(workoutName: "Legs", elapsedSeconds: 900, finishedAt: start.addingTimeInterval(3600))
        XCTAssertEqual(kinds(detector.ingest(state: nil, finish: next)), [.finished])
    }

    func testANewWorkoutResetsEveryMoment() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(elapsed: 598), finish: nil)
        XCTAssertEqual(kinds(detector.ingest(state: state(elapsed: 600), finish: nil)), [.halfway])

        let other = UUID()
        _ = detector.ingest(state: state(elapsed: 598, id: other), finish: nil)
        XCTAssertEqual(kinds(detector.ingest(state: state(elapsed: 600, id: other), finish: nil)), [.halfway])
    }
    func testRestartingTheSameWorkoutRearmsItsMilestones() {
        var detector = MenuBarMomentDetector()
        _ = detector.ingest(state: state(elapsed: 598), finish: nil)
        XCTAssertEqual(kinds(detector.ingest(state: state(elapsed: 600), finish: nil)), [.halfway])
        _ = detector.ingest(state: nil, finish: nil)

        var restarted = state(elapsed: 598)
        restarted.startedAt = start.addingTimeInterval(3600)
        _ = detector.ingest(state: restarted, finish: nil)
        restarted.elapsedSeconds = 600
        XCTAssertEqual(kinds(detector.ingest(state: restarted, finish: nil)), [.halfway])
    }
}
