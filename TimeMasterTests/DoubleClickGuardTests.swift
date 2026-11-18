import XCTest
@testable import TimeMaster

/// The Mac's click-through guard: once a click opened something (a page pushed, the cover viewer shown), the rest of
/// that double-click never reaches what opened.
final class DoubleClickGuardTests: XCTestCase {
    private let interval: TimeInterval = 0.5

    /// A guard whose click `clickCount` into its sequence, at `time`, opened something.
    private func opened(byClick clickCount: Int = 1, at time: TimeInterval = 10) -> DoubleClickGuard {
        var rule = DoubleClickGuard()
        rule.noteOpening(clickCount: clickCount, at: time)
        return rule
    }

    func testTheSecondClickOfTheDoubleClickThatOpenedSomethingIsDropped() {
        var rule = opened()
        XCTAssertTrue(rule.drops(.down(clickCount: 2), at: 10.2, interval: interval))
        XCTAssertTrue(rule.drops(.dragged, at: 10.25, interval: interval), "its drags go with it")
        XCTAssertTrue(rule.drops(.up, at: 10.3, interval: interval), "and its release")
    }

    func testATripleClickLosesItsThirdClickToo() {
        var rule = opened()
        XCTAssertTrue(rule.drops(.down(clickCount: 2), at: 10.2, interval: interval))
        XCTAssertTrue(rule.drops(.up, at: 10.25, interval: interval))
        XCTAssertTrue(rule.drops(.down(clickCount: 3), at: 10.6, interval: interval), "within the interval of the second click")
        XCTAssertTrue(rule.drops(.up, at: 10.65, interval: interval))
    }

    func testTheReleaseOfTheOpeningClickGoesThrough() {
        // A list that opens its row on the press: the release of that same click arrives after the push.
        var rule = opened()
        XCTAssertFalse(rule.drops(.up, at: 10.05, interval: interval))
        XCTAssertTrue(rule.drops(.down(clickCount: 2), at: 10.2, interval: interval))
    }

    func testANewClickGoesThroughAndEndsTheGuard() {
        var rule = opened()
        XCTAssertFalse(rule.drops(.down(clickCount: 1), at: 10.2, interval: interval), "a click elsewhere starts its own sequence")
        XCTAssertFalse(rule.drops(.up, at: 10.25, interval: interval))
        XCTAssertFalse(rule.drops(.down(clickCount: 2), at: 10.4, interval: interval), "a double-click on the new screen is its own")
        XCTAssertFalse(rule.drops(.up, at: 10.45, interval: interval))
    }

    func testASecondClickAfterTheDoubleClickIntervalGoesThrough() {
        var rule = opened()
        XCTAssertFalse(rule.drops(.down(clickCount: 2), at: 10.6, interval: interval))
        XCTAssertFalse(rule.drops(.dragged, at: 10.62, interval: interval))
        XCTAssertFalse(rule.drops(.up, at: 10.65, interval: interval))
    }

    func testADoubleClickThatOpenedAGroupKeepsOnlyItsLaterClicksOut() {
        // The root Database opens a group on the second click: that click's release passes, a third click does not.
        var rule = opened(byClick: 2)
        XCTAssertFalse(rule.drops(.up, at: 10.02, interval: interval))
        XCTAssertTrue(rule.drops(.down(clickCount: 3), at: 10.3, interval: interval))
        XCTAssertTrue(rule.drops(.up, at: 10.35, interval: interval))
        XCTAssertFalse(rule.drops(.down(clickCount: 1), at: 12, interval: interval))
    }

    func testAnOpeningLongAfterTheLastClickDropsNothing() {
        // Opened by a key or VoiceOver while the last click (still the current event) is long gone.
        var rule = opened(at: 1)
        XCTAssertFalse(rule.drops(.down(clickCount: 2), at: 30, interval: interval))
    }

    func testNothingIsDroppedBeforeAnythingOpened() {
        var rule = DoubleClickGuard()
        XCTAssertFalse(rule.drops(.down(clickCount: 2), at: 1, interval: interval))
        XCTAssertFalse(rule.drops(.dragged, at: 1.05, interval: interval))
        XCTAssertFalse(rule.drops(.up, at: 1.1, interval: interval))
    }

    func testOnlyALaterClickOfASequenceIsADoubleClick() {
        XCTAssertFalse(DoubleClickGuard.isDoubleClick(clickCount: 1))
        XCTAssertTrue(DoubleClickGuard.isDoubleClick(clickCount: 2))
        XCTAssertTrue(DoubleClickGuard.isDoubleClick(clickCount: 3))
    }
}
