import XCTest
@testable import TimeMaster

final class EarlyDoneGuardTests: XCTestCase {
    func testTheThresholdIsTwentySeconds() {
        XCTAssertEqual(EarlyDoneGuard.threshold, 20)
        var lastEarlySecond = EarlyDoneGuard()
        XCTAssertEqual(lastEarlySecond.pressDone(elapsed: EarlyDoneGuard.threshold - 1), .superhuman)
        var firstLateSecond = EarlyDoneGuard()
        XCTAssertEqual(firstLateSecond.pressDone(elapsed: EarlyDoneGuard.threshold), .complete)
    }

    func testDoneAfterTheThresholdCompletesWithoutAskingAnything() {
        var doneGuard = EarlyDoneGuard()
        XCTAssertEqual(doneGuard.pressDone(elapsed: 45), .complete)
        XCTAssertEqual(doneGuard.stage, .fresh)
    }

    func testEarlyTapsTeaseThenAskThenSkipWithoutAskingAgain() {
        var doneGuard = EarlyDoneGuard()
        XCTAssertEqual(doneGuard.pressDone(elapsed: 3), .superhuman)
        XCTAssertEqual(doneGuard.pressDone(elapsed: 8), .confirm)
        XCTAssertEqual(doneGuard.pressDone(elapsed: 12), .skip)
        XCTAssertEqual(doneGuard.pressDone(elapsed: 13), .skip)
    }

    func testATapAfterTheThresholdCompletesEvenAfterATease() {
        var doneGuard = EarlyDoneGuard()
        XCTAssertEqual(doneGuard.pressDone(elapsed: 5), .superhuman)
        XCTAssertEqual(doneGuard.pressDone(elapsed: 21), .complete)
    }

    func testEverySetStartsWithAFreshGuard() {
        var firstSet = EarlyDoneGuard()
        _ = firstSet.pressDone(elapsed: 2)
        _ = firstSet.pressDone(elapsed: 4)
        var nextSet = EarlyDoneGuard()
        XCTAssertEqual(nextSet.pressDone(elapsed: 2), .superhuman)
    }
}
