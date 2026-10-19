import XCTest
@testable import TimeMaster

final class RankedTrackingTests: XCTestCase {
    private func pose(_ time: Double, bottom: Bool = false) -> RankedPose {
        let points: [String: (Double, Double)] = bottom
            ? ["Shoulder": (0.25, 0.4), "Elbow": (0.4, 0.4), "Wrist": (0.25, 0.25), "Hip": (0.5, 0.3375), "Knee": (0.68, 0.2925), "Ankle": (0.85, 0.25)]
            : ["Shoulder": (0.25, 0.55), "Elbow": (0.25, 0.4), "Wrist": (0.25, 0.25), "Hip": (0.5, 0.425), "Knee": (0.68, 0.335), "Ankle": (0.85, 0.25)]
        var joints: [String: RankedJoint] = [:]
        for side in ["left", "right"] {
            for (name, point) in points {
                joints[side + name] = .init(x: point.0, y: point.1 + (side == "right" ? 0.1 : 0), confidence: 0.99)
            }
        }
        joints["nose"] = .init(x: 0.15, y: bottom ? 0.55 : 0.7, confidence: 0.99)
        return .init(time: time, aspect: 1, people: 1, joints: joints, light: 0.5, cameraMoving: false)
    }

    private func calibrated(_ variation: RankedVariation = .standardPushUp) -> RankedMovementTracker {
        var tracker = RankedMovementTracker(variation: variation)
        for i in -30..<0 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertTrue(tracker.state.calibrated)
        tracker.begin(at: 0, end: 60)
        return tracker
    }

    func testHalfRepAtGoDoesNotCountButSubsequentFullCycleDoes() {
        var tracker = calibrated()
        for i in 0..<10 { _ = tracker.consume(pose(Double(i) / 10, bottom: true)) }
        for i in 10..<20 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 0)
        for i in 20..<25 { _ = tracker.consume(pose(Double(i) / 10, bottom: true)) }
        for i in 25..<30 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 1)
        for i in 30..<100 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 1)
    }

    func testTrackingLossDiscardsPartialRepAndRequiresRecalibration() {
        var tracker = calibrated()
        for i in 0..<5 { _ = tracker.consume(pose(Double(i) / 10)) }
        for i in 5..<10 { _ = tracker.consume(pose(Double(i) / 10, bottom: true)) }
        var obscured = pose(1)
        obscured.joints["leftAnkle"]?.confidence = 0.1
        _ = tracker.consume(obscured)
        XCTAssertFalse(tracker.state.calibrated)
        for i in 11..<40 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertTrue(tracker.state.calibrated)
        XCTAssertEqual(tracker.state.score, 0)
    }

    func testHoldUsesLongestContinuousSegmentAndNeverAddsMissingFrames() {
        var tracker = calibrated(.highPlank)
        for i in 0...50 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 5, accuracy: 0.001)
        var bad = pose(5.1); bad.people = 2
        _ = tracker.consume(bad)
        for i in 52..<102 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 5, accuracy: 0.001)
        _ = tracker.consume(pose(20))
        XCTAssertEqual(tracker.state.score, 5, accuracy: 0.001)
        XCTAssertFalse(tracker.state.calibrated)
    }

    func testStationaryAthleteAndFramesOutsideDeadlineCannotScoreRepetitions() {
        var tracker = calibrated()
        for i in 0...600 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 0)
        for i in 601..<610 { _ = tracker.consume(pose(Double(i) / 10, bottom: true)) }
        for i in 610..<620 { _ = tracker.consume(pose(Double(i) / 10)) }
        XCTAssertEqual(tracker.state.score, 0)
    }

    func testPausedMovementNeedsUninterruptedBottomAndTempoNeedsSlowDescent() {
        for variation in [RankedVariation.pausedPushUp, .tempoPushUp] {
            var tracker = calibrated(variation)
            for i in 0..<5 { _ = tracker.consume(pose(Double(i) / 10)) }
            for i in 5..<11 { _ = tracker.consume(pose(Double(i) / 10, bottom: true)) }
            for i in 11..<20 { _ = tracker.consume(pose(Double(i) / 10)) }
            XCTAssertEqual(tracker.state.score, 0)
        }
    }

    func testOneSidedPartialPushUpDepthDoesNotQualify() {
        var partial = pose(0, bottom: true)
        partial.joints["rightElbow"] = .init(x: 0.25, y: 0.375, confidence: 0.99)
        let assessment = RankedMovementRules.assess(partial, variation: .standardPushUp)
        XCTAssertFalse(assessment.bottom)
        XCTAssertTrue(RankedMovementRules.assess(pose(0, bottom: true), variation: .standardPushUp).bottom)
    }
}
