import Combine
import XCTest
@testable import TimeMaster

@MainActor
final class WorkoutLiveSessionTests: XCTestCase {
    private var session: WorkoutLiveSession { .shared }
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        session.finish(completed: false, elapsedSeconds: 0)
        cancellables.removeAll()
    }

    override func tearDown() {
        session.finish(completed: false, elapsedSeconds: 0)
        cancellables.removeAll()
        super.tearDown()
    }

    private func state(name: String = "Legs", remaining: Int = 30, paused: Bool = false) -> WorkoutLiveState {
        WorkoutLiveState(
            workoutID: UUID(),
            workoutName: name,
            colorHex: "FF6A00",
            phase: .active,
            title: "Squat",
            subtitle: "",
            isPaused: paused,
            remainingSeconds: remaining,
            phaseDuration: 40,
            sectionIndex: 0,
            sectionCount: 1,
            elapsedSeconds: 10,
            totalSeconds: 600,
            nextTitle: nil,
            startedAt: Date()
        )
    }

    func testCompletingClearsTheStateAndRemembersTheFinish() {
        session.publish(state(name: "Core"))
        session.finish(completed: true, elapsedSeconds: 1500)
        XCTAssertFalse(session.isActive)
        XCTAssertEqual(session.lastFinish?.workoutName, "Core")
        XCTAssertEqual(session.lastFinish?.elapsedSeconds, 1500)
    }

    func testStoppingClearsTheStateWithoutAFinish() {
        session.publish(state())
        session.finish(completed: false, elapsedSeconds: 90)
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.lastFinish)
    }

    func testFinishingWithNothingRunningChangesNothing() {
        session.publish(state())
        session.finish(completed: true, elapsedSeconds: 600)
        let first = session.lastFinish
        session.finish(completed: true, elapsedSeconds: 999)
        XCTAssertEqual(session.lastFinish, first)
    }

    func testAnotherWorkoutStartingClearsThePreviousFinish() {
        session.publish(state())
        session.finish(completed: true, elapsedSeconds: 600)
        XCTAssertNotNil(session.lastFinish)
        session.publish(state(name: "Arms"))
        XCTAssertNil(session.lastFinish)
    }

    func testRepeatedPublishesOfTheSameStateDoNotChangeIt() {
        let value = state()
        session.publish(value)
        var changes = 0
        session.$state.dropFirst().sink { _ in changes += 1 }.store(in: &cancellables)
        session.publish(value)
        session.publish(value)
        XCTAssertEqual(changes, 0)
        session.publish(state(remaining: 29))
        XCTAssertEqual(changes, 1)
    }

}
