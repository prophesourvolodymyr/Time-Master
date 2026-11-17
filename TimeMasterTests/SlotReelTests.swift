import XCTest
@testable import TimeMaster

@MainActor
final class SlotReelTests: XCTestCase {
    // MARK: - Physics

    /// Moves the fingers at `speed` slots per second for `events` scroll events, then lifts them.
    private func swipe(_ reel: inout SlotReelPhysics, speed: Double, events: Int = 8, rate: Double = 120, start: Double = 0) -> Double {
        var time = start
        for _ in 0..<events {
            time += 1 / rate
            reel.track(delta: speed / rate, at: time)
        }
        let released = time + 0.004
        reel.release(at: released)
        return released
    }

    /// Steps display frames until the reel rests; returns how long that took, or `nil` if it never did.
    private func settle(_ reel: inout SlotReelPhysics, from start: Double, frame: Double = 1.0 / 120) -> Double? {
        var time = start
        while time - start < 8 {
            time += frame
            reel.step(to: time)
            if reel.phase == .resting { return time - start }
        }
        return nil
    }

    /// Swipes at `speed`, lifts the fingers and runs frames until the reel rests; returns whether it did.
    private func flick(_ reel: inout SlotReelPhysics, speed: Double) -> Bool {
        let released = swipe(&reel, speed: speed)
        return settle(&reel, from: released) != nil
    }

    func testALightSwipeMovesExactlyOneSlot() {
        for speed in [SlotReelTuning.bar.flickSpeed * 1.5, SlotReelTuning.bar.spinSpeed * 0.5, SlotReelTuning.bar.spinSpeed * 0.95] {
            var forward = SlotReelPhysics(count: 11, slot: 5)
            let forwardRested = flick(&forward, speed: speed)
            XCTAssertTrue(forwardRested)
            XCTAssertEqual(forward.slot, 6, "speed \(speed)")
            var backward = SlotReelPhysics(count: 11, slot: 5)
            let backwardRested = flick(&backward, speed: -speed)
            XCTAssertTrue(backwardRested)
            XCTAssertEqual(backward.slot, 4, "speed \(-speed)")
        }
    }

    func testEveryFlickComesToRestExactlyOnASlotInsideTheBar() {
        for speed in stride(from: -40.0, through: 40.0, by: 3.3) {
            var reel = SlotReelPhysics(count: 11, slot: 5)
            let rested = flick(&reel, speed: speed)
            XCTAssertTrue(rested, "speed \(speed) never rested")
            XCTAssertEqual(reel.position, reel.position.rounded(), accuracy: 0.001, "speed \(speed)")
            XCTAssertTrue((0...10).contains(reel.slot), "speed \(speed) landed on \(reel.slot)")
        }
    }

    func testAFasterFlickNeverLandsShorter() {
        var previous = 5
        for step in 0...40 {
            var reel = SlotReelPhysics(count: 200, slot: 5)
            let rested = flick(&reel, speed: 0.5 + Double(step))
            XCTAssertTrue(rested)
            XCTAssertGreaterThanOrEqual(reel.slot, previous)
            previous = reel.slot
        }
        XCTAssertGreaterThan(previous, 10)
    }

    func testPullingPastTheFirstPageIsResistedAndSettlesBack() {
        var reel = SlotReelPhysics(count: 4, slot: 0)
        var time = 0.0
        for _ in 0..<60 {
            time += 1.0 / 120
            reel.track(delta: -0.05, at: time)
        }
        XCTAssertLessThan(reel.position, 0)
        XCTAssertGreaterThan(reel.position, -SlotReelTuning.bar.overscroll)
        reel.release(at: time + 0.2)
        let rested = settle(&reel, from: time + 0.2)
        XCTAssertNotNil(rested)
        XCTAssertEqual(reel.slot, 0)
        XCTAssertEqual(reel.position, 0)
    }

    func testGrabbingACoastingReelStopsIt() {
        var reel = SlotReelPhysics(count: 200, slot: 5)
        var time = swipe(&reel, speed: 30)
        for _ in 0..<24 {
            time += 1.0 / 120
            reel.step(to: time)
        }
        XCTAssertEqual(reel.phase, .coasting)
        let caught = reel.position
        reel.grab(at: time)
        XCTAssertEqual(reel.phase, .tracking)
        reel.step(to: time + 0.1)
        XCTAssertEqual(reel.position, caught)
    }

    func testReduceMotionStepsOneSlotAndChangesSlotsInstantly() {
        var reel = SlotReelPhysics(count: 11, slot: 5, reduceMotion: true)
        var time = 0.0
        for _ in 0..<20 {
            time += 1.0 / 120
            reel.track(delta: 8.0 / 120, at: time)
            XCTAssertEqual(reel.position, reel.position.rounded())
        }
        reel.release(at: time + 0.004)
        XCTAssertEqual(reel.phase, .resting)
        XCTAssertEqual(reel.slot, 6)
        reel.select(9, at: time + 1)
        XCTAssertEqual(reel.phase, .resting)
        XCTAssertEqual(reel.position, 9)
    }

    func testResizingRestsOnTheNearestSlotThatStillExists() {
        var reel = SlotReelPhysics(count: 6, slot: 5)
        reel.resize(count: 4)
        XCTAssertEqual(reel.count, 4)
        XCTAssertEqual(reel.slot, 3)
        XCTAssertEqual(reel.position, 3)
        reel.resize(count: 8)
        XCTAssertEqual(reel.landing, 3)
    }

    func testAHeldStripGlidesBackFromWhereTheEditorLeftIt() {
        var reel = SlotReelPhysics(count: 6, slot: 2)
        reel.hold(at: -0.8)
        XCTAssertEqual(reel.position, -0.8, accuracy: 0.0001)
        XCTAssertEqual(reel.phase, .resting)
        reel.select(2, at: 0)
        XCTAssertEqual(reel.phase, .settling)
        XCTAssertEqual(reel.landing, 2)
        var lowest = reel.position
        var time = 0.0
        while reel.phase != .resting, time < 3 {
            time += 1.0 / 120
            reel.step(to: time)
            lowest = min(lowest, reel.position)
        }
        XCTAssertEqual(reel.position, 2)
        XCTAssertGreaterThanOrEqual(lowest, -0.8)
        reel.hold(at: 40)
        XCTAssertEqual(reel.position, 6)
    }

    // MARK: - Scroll routing

    private func event(
        _ phase: SlotReelScrollEvent.Phase, dx: CGFloat = 0, dy: CGFloat = 0, at time: TimeInterval,
        inside: Bool = true, momentum: Bool = false, momentumEnded: Bool = false
    ) -> SlotReelScrollEvent {
        SlotReelScrollEvent(phase: phase, isMomentum: momentum, momentumEnded: momentumEnded,
                            deltaX: dx, deltaY: dy, time: time, inside: inside)
    }

    /// Runs the display clock until the reel stops moving on its own.
    private func run(_ reel: SlotReel, from start: TimeInterval) {
        var time = start
        while time - start < 8 {
            time += 1.0 / 120
            if !reel.frame(at: time) { return }
        }
    }

    func testScrollDeltasMoveTheStripLikePageContent() {
        XCTAssertEqual(SlotReelScrollRouter.slots(-90, pitch: 90), 1)
        XCTAssertEqual(SlotReelScrollRouter.slots(45, pitch: 90), -0.5)
        XCTAssertEqual(SlotReelScrollRouter.slots(10, pitch: 0), -10)
    }

    func testASidewaysSwipeOverTheBarLandsOnTheNextPageAndSwallowsItsMomentum() {
        let reel = SlotReel(count: 6, slot: 2)
        var landed: [Int] = []
        reel.landed = { landed.append($0) }
        var router = SlotReelScrollRouter()
        var time: TimeInterval = 100
        XCTAssertFalse(router.route(event(.mayBegin, at: time), reel: reel, pitch: 90))
        time += 0.008
        XCTAssertFalse(router.route(event(.began, dx: -2.25, at: time), reel: reel, pitch: 90))
        time += 1.0 / 120
        XCTAssertFalse(router.route(event(.changed, dx: -2.25, at: time), reel: reel, pitch: 90))
        for _ in 0..<8 {
            time += 1.0 / 120
            XCTAssertTrue(router.route(event(.changed, dx: -2.25, at: time), reel: reel, pitch: 90))
        }
        XCTAssertTrue(reel.isTracking)
        XCTAssertGreaterThan(reel.position, 2)
        XCTAssertTrue(landed.isEmpty)
        time += 0.004
        XCTAssertTrue(router.route(event(.ended, at: time), reel: reel, pitch: 90))
        XCTAssertEqual(landed, [3])
        run(reel, from: time)
        XCTAssertEqual(reel.slot, 3)
        XCTAssertEqual(reel.position, 3)
        XCTAssertTrue(router.route(event(.wheel, dx: -3, at: time + 0.02, momentum: true), reel: reel, pitch: 90))
        XCTAssertTrue(router.route(event(.wheel, at: time + 0.3, momentum: true, momentumEnded: true), reel: reel, pitch: 90))
        XCTAssertFalse(router.route(event(.wheel, dy: -3, at: time + 1, momentum: true), reel: reel, pitch: 90))
        XCTAssertEqual(landed, [3])
    }

    func testAVerticalScrollOverTheBarReachesThePage() {
        let reel = SlotReel(count: 6, slot: 2)
        var router = SlotReelScrollRouter()
        var time: TimeInterval = 10
        XCTAssertFalse(router.route(event(.began, dx: 0.5, dy: -3, at: time), reel: reel, pitch: 90))
        for _ in 0..<10 {
            time += 1.0 / 120
            XCTAssertFalse(router.route(event(.changed, dx: 1, dy: -5, at: time), reel: reel, pitch: 90))
        }
        XCTAssertFalse(router.route(event(.ended, at: time + 0.01), reel: reel, pitch: 90))
        XCTAssertFalse(router.route(event(.wheel, dy: -4, at: time + 0.05, momentum: true), reel: reel, pitch: 90))
        XCTAssertFalse(reel.isTracking)
        XCTAssertEqual(reel.position, 2)
    }

    func testAScrollThatStartedOverThePageNeverMovesTheBar() {
        let reel = SlotReel(count: 6, slot: 2)
        var router = SlotReelScrollRouter()
        var time: TimeInterval = 10
        XCTAssertFalse(router.route(event(.began, dx: -5, at: time, inside: false), reel: reel, pitch: 90))
        for _ in 0..<10 {
            time += 1.0 / 120
            XCTAssertFalse(router.route(event(.changed, dx: -8, at: time), reel: reel, pitch: 90))
        }
        XCTAssertFalse(router.route(event(.ended, at: time), reel: reel, pitch: 90))
        XCTAssertFalse(reel.isTracking)
        XCTAssertEqual(reel.position, 2)
    }

    func testSidewaysWheelNotchesStepOnePageAndVerticalOnesPass() {
        let reel = SlotReel(count: 6, slot: 2)
        var landed: [Int] = []
        reel.landed = { landed.append($0) }
        var router = SlotReelScrollRouter()
        XCTAssertTrue(router.route(event(.wheel, dx: -1, at: 1), reel: reel, pitch: 90))
        XCTAssertTrue(router.route(event(.wheel, dx: -1, at: 1.01), reel: reel, pitch: 90))
        XCTAssertEqual(landed, [3])
        XCTAssertTrue(router.route(event(.wheel, dx: 1, at: 1.2), reel: reel, pitch: 90))
        XCTAssertEqual(landed, [3, 2])
        XCTAssertFalse(router.route(event(.wheel, dy: -1, at: 1.5), reel: reel, pitch: 90))
        XCTAssertFalse(router.route(event(.wheel, dx: -1, at: 2, inside: false), reel: reel, pitch: 90))
        XCTAssertEqual(landed, [3, 2])
    }

    func testRestingFingersCatchAGlidingStrip() {
        let reel = SlotReel(count: 8, slot: 0)
        var router = SlotReelScrollRouter()
        reel.select(6, at: 0)
        reel.frame(at: 0.05)
        XCTAssertTrue(reel.isMoving)
        let caught = reel.position
        XCTAssertFalse(router.route(event(.mayBegin, at: 0.05), reel: reel, pitch: 90))
        XCTAssertTrue(reel.isTracking)
        XCTAssertEqual(reel.position, caught)
        XCTAssertFalse(router.route(event(.ended, at: 0.3), reel: reel, pitch: 90))
        XCTAssertFalse(reel.isTracking)
        run(reel, from: 0.3)
        XCTAssertEqual(CGFloat(reel.slot), caught.rounded())
    }

    // MARK: - Arc hit region

    func testScrollsCountOnlyOnTheSurfaceSideOfTheArcLine() {
        let rect = CGRect(x: 0, y: 40, width: 1000, height: 196)
        let line = SlotArcGeometry.curveY(at: 500, in: rect, curveOffset: 54, expansion: 1)
        XCTAssertTrue(SlotArcGeometry.surfaceContains(CGPoint(x: 500, y: line + 10), in: rect, curveOffset: 54, expansion: 1))
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 500, y: line - 10), in: rect, curveOffset: 54, expansion: 1))
        XCTAssertTrue(SlotArcGeometry.surfaceContains(CGPoint(x: 500, y: line - 10), in: rect, curveOffset: 54, expansion: 1, reach: 16))
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 500, y: line - 30), in: rect, curveOffset: 54, expansion: 1, reach: 16))
        let edge = SlotArcGeometry.curveY(at: 20, in: rect, curveOffset: 54, expansion: 1)
        XCTAssertGreaterThan(edge, line + 10)
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 20, y: line + 10), in: rect, curveOffset: 54, expansion: 1))
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 1001, y: rect.maxY), in: rect, curveOffset: 54, expansion: 1))
    }

    func testTheTopBarMirrorsTheHitRegion() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 196)
        let line = rect.maxY - SlotArcGeometry.curveY(at: 400, in: rect, curveOffset: 54, expansion: 1)
        XCTAssertTrue(SlotArcGeometry.surfaceContains(CGPoint(x: 400, y: line - 10), in: rect, curveOffset: 54, expansion: 1, placement: .top))
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 400, y: line + 30), in: rect, curveOffset: 54, expansion: 1, placement: .top))
    }

    func testTheFlatStripIsSurfaceEdgeToEdge() {
        let rect = CGRect(x: 0, y: 0, width: 600, height: 60)
        XCTAssertTrue(SlotArcGeometry.surfaceContains(CGPoint(x: 5, y: 1), in: rect, curveOffset: 54, expansion: 0))
        XCTAssertTrue(SlotArcGeometry.surfaceContains(CGPoint(x: 595, y: 59), in: rect, curveOffset: 54, expansion: 0))
        XCTAssertFalse(SlotArcGeometry.surfaceContains(CGPoint(x: 5, y: -20), in: rect, curveOffset: 54, expansion: 0))
    }
}
