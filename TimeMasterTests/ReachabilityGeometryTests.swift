import XCTest
@testable import TimeMaster

final class ReachabilityGeometryTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 390, height: 700)

    func testShallowLeftSwipesAcceptBothVerticalDirections() {
        for dy in [-20.0, 20.0] {
            XCTAssertTrue(ReachabilityGeometry.accepts(start: CGPoint(x: 320, y: 400),
                translation: CGSize(width: -80, height: dy), in: bounds))
        }
    }

    func testScrollingAndMusicEdgeKeepOwnership() {
        for translation in [CGSize(width: -10, height: -80), CGSize(width: -80, height: 0),
                            CGSize(width: 80, height: 20)] {
            XCTAssertFalse(ReachabilityGeometry.accepts(start: CGPoint(x: 320, y: 400),
                translation: translation, in: bounds))
        }
        for start in [CGPoint(x: 380, y: 400), CGPoint(x: 20, y: 400),
                      CGPoint(x: 320, y: 30), CGPoint(x: 320, y: 680)] {
            XCTAssertFalse(ReachabilityGeometry.accepts(start: start,
                translation: CGSize(width: -80, height: 20), in: bounds))
        }
    }

    func testShortPullCancelsEvenWithHighVelocity() {
        XCTAssertFalse(ReachabilityGeometry.shouldOpen(translation: CGSize(width: -18, height: 5),
                                                       velocity: CGPoint(x: -900, y: 0)))
        XCTAssertFalse(ReachabilityGeometry.shouldOpen(translation: CGSize(width: 10, height: 5),
                                                       velocity: .zero))
        XCTAssertTrue(ReachabilityGeometry.shouldOpen(translation: CGSize(width: -65, height: 15),
                                                      velocity: .zero))
        XCTAssertTrue(ReachabilityGeometry.shouldOpen(translation: CGSize(width: -35, height: 10),
                                                      velocity: CGPoint(x: -600, y: 0)))
    }

    func testShelfStaysInsideShortAndTallViewports() {
        for height in [100.0, 320.0, 700.0] {
            let half = min(ReachabilityGeometry.shelfHeight / 2, height / 2)
            for requested in [-100.0, 0, 180, 900] {
                let y = ReachabilityGeometry.anchorY(requested, height: height)
                XCTAssertGreaterThanOrEqual(y, half)
                XCTAssertLessThanOrEqual(y, height - half)
            }
        }
    }

    func testOverflowReelClampsBothEndsAndReverses() {
        XCTAssertEqual(ReachabilityGeometry.settledIndex(current: 0, translation: 500, step: 80, count: 6), 0)
        XCTAssertEqual(ReachabilityGeometry.settledIndex(current: 2, translation: -900, step: 80, count: 6), 5)
        XCTAssertEqual(ReachabilityGeometry.settledIndex(current: 4, translation: 160, step: 80, count: 6), 2)
        XCTAssertEqual(ReachabilityGeometry.settledIndex(current: 0, translation: -100, step: 80, count: 0), 0)
    }

    func testLeftwardSwipesNeverMovePages() {
        let translation = CGSize(width: -160, height: 20)
        for x in [10.0, 380.0] {
            XCTAssertNil(SlotPageSwipeGeometry.progress(index: 2, start: CGPoint(x: x, y: 400),
                                                        translation: translation, width: 390))
        }
        XCTAssertNil(SlotPageSwipeGeometry.destination(index: 2, translation: translation,
                                                       projectedWidth: -300, width: 390))
        XCTAssertNil(SlotPageSwipeGeometry.destination(index: 2, translation: translation,
                                                       projectedWidth: 300, width: 390))
    }

    func testRightwardSwipeOnlyReachesPreviousPage() {
        let translation = CGSize(width: 120, height: 10)
        XCTAssertEqual(SlotPageSwipeGeometry.destination(index: 2, translation: translation,
                                                         projectedWidth: 200, width: 390), 1)
        XCTAssertNil(SlotPageSwipeGeometry.destination(index: 0, translation: translation,
                                                       projectedWidth: 200, width: 390))
        XCTAssertNil(SlotPageSwipeGeometry.progress(index: 0, start: CGPoint(x: 10, y: 400),
                                                    translation: translation, width: 390))
        XCTAssertEqual(SlotPageSwipeGeometry.progress(index: 2, start: CGPoint(x: 10, y: 400),
                                                      translation: CGSize(width: 900, height: 10), width: 390), 1)
    }

    func testPageSwipeCancelsReversalAndLeavesContentScrollingAlone() {
        let translation = CGSize(width: 120, height: 10)
        XCTAssertNil(SlotPageSwipeGeometry.destination(index: 2, translation: translation,
                                                       projectedWidth: -100, width: 390))
        XCTAssertNil(SlotPageSwipeGeometry.destination(index: 2, translation: translation,
                                                       projectedWidth: 80, width: 390))
        XCTAssertNil(SlotPageSwipeGeometry.progress(index: 2, start: CGPoint(x: 200, y: 400),
                                                    translation: translation, width: 390))
        XCTAssertNil(SlotPageSwipeGeometry.progress(index: 2, start: CGPoint(x: 10, y: 400),
                                                    translation: CGSize(width: 10, height: 120), width: 390))
    }

    func testHiddenMenuRemainsVisibleForTwoIdleSeconds() {
        let start = ContinuousClock.now
        var overlay = SlotNavigationOverlayState()
        overlay.reveal(at: start, interacting: false)
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .milliseconds(1999))))
        XCTAssertTrue(overlay.isVisible)
        XCTAssertTrue(overlay.dismissIfExpired(at: start.advanced(by: .seconds(2))))
        XCTAssertFalse(overlay.isVisible)
    }

    func testMenuInteractionPausesDismissalAndRestartsGraceAfterRelease() {
        let start = ContinuousClock.now
        var overlay = SlotNavigationOverlayState()
        overlay.reveal(at: start, interacting: false)
        overlay.interactionChanged(true, at: start.advanced(by: .seconds(1)))
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .seconds(8))))
        XCTAssertTrue(overlay.isVisible)
        overlay.interactionChanged(false, at: start.advanced(by: .seconds(8)))
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .milliseconds(9999))))
        XCTAssertTrue(overlay.dismissIfExpired(at: start.advanced(by: .seconds(10))))
    }

    func testLeavingAndReenteringMapCannotReuseTheOldDeadline() {
        let start = ContinuousClock.now
        var overlay = SlotNavigationOverlayState()
        overlay.reveal(at: start, interacting: false)
        overlay.dismiss()
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .seconds(2))))
        overlay.reveal(at: start.advanced(by: .seconds(3)), interacting: false)
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .seconds(4))))
        XCTAssertTrue(overlay.isVisible)
        XCTAssertTrue(overlay.dismissIfExpired(at: start.advanced(by: .seconds(5))))
    }

    func testMapEntryWhileReelingWaitsForReleaseBeforeStartingTheTimer() {
        let start = ContinuousClock.now
        var overlay = SlotNavigationOverlayState()
        overlay.reveal(at: start, interacting: true)
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .seconds(20))))
        XCTAssertTrue(overlay.isVisible)
        overlay.interactionChanged(false, at: start.advanced(by: .seconds(20)))
        XCTAssertFalse(overlay.dismissIfExpired(at: start.advanced(by: .seconds(21))))
        XCTAssertTrue(overlay.dismissIfExpired(at: start.advanced(by: .seconds(22))))
    }

    func testBottomEdgeRevealRejectsPaneScrollsHorizontalReelingAndShortPulls() {
        XCTAssertTrue(SlotNavigationOverlayState.acceptsReveal(
            start: CGPoint(x: 195, y: 680), translation: CGSize(width: 10, height: -60), viewportHeight: 700))
        for (startY, translation) in [
            (600.0, CGSize(width: 0, height: -100)),
            (680.0, CGSize(width: 80, height: -50)),
            (680.0, CGSize(width: 0, height: -47)),
            (680.0, CGSize(width: 0, height: 80))
        ] {
            XCTAssertFalse(SlotNavigationOverlayState.acceptsReveal(
                start: CGPoint(x: 195, y: startY), translation: translation, viewportHeight: 700))
        }
    }
}
