import XCTest
@testable import TimeMaster

final class AppCommandQueueTests: XCTestCase {
    func testDrainReturnsTheQueuedRequestsOnceInArrivalOrder() {
        var queue = AppCommandQueue()
        let id = UUID()
        queue.enqueue(.openPage(destination: "coach", coachPrompt: "Plan my week"))
        queue.enqueue(.startWorkout(id))

        XCTAssertEqual(queue.drain(), [.openPage(destination: "coach", coachPrompt: "Plan my week"), .startWorkout(id)])
        XCTAssertEqual(queue.drain(), [])
    }

    func testANewerRequestOfTheSameKindReplacesTheOlderOne() {
        var queue = AppCommandQueue()
        let first = UUID()
        let second = UUID()
        queue.enqueue(.startWorkout(first))
        queue.enqueue(.openPage(destination: "schedule", coachPrompt: nil))
        queue.enqueue(.startWorkout(second))
        queue.enqueue(.openPage(destination: "analytics", coachPrompt: nil))

        XCTAssertEqual(
            queue.drain(),
            [.startWorkout(second), .openPage(destination: "analytics", coachPrompt: nil)]
        )
    }

    func testRepeatedNewWorkoutRequestsCollapseToOne() {
        var queue = AppCommandQueue()
        queue.enqueue(.newWorkout)
        queue.enqueue(.newWorkout)
        XCTAssertEqual(queue.drain(), [.newWorkout])
    }
}
