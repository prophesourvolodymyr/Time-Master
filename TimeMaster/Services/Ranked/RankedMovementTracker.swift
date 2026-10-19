import Foundation

struct RankedJoint: Codable, Equatable {
    var x: Double
    var y: Double
    var confidence: Double
}

struct RankedPose: Codable, Equatable {
    var time: Double
    var aspect: Double
    var people: Int
    var joints: [String: RankedJoint]
    var light: Double
    var cameraMoving: Bool
    var diamondContact: Bool?

    func point(_ name: String) -> RankedVector? {
        guard let p = joints[name], p.confidence >= 0.45,
              p.x.isFinite, p.y.isFinite, (0.025...0.975).contains(p.x),
              (0.025...0.975).contains(p.y) else { return nil }
        return RankedVector(x: p.x * aspect, y: p.y)
    }
}

struct RankedVector: Equatable {
    var x: Double
    var y: Double
    func distance(to b: Self) -> Double { hypot(x - b.x, y - b.y) }
    static func angle(_ a: Self, _ b: Self, _ c: Self) -> Double {
        let u = Self(x: a.x - b.x, y: a.y - b.y)
        let v = Self(x: c.x - b.x, y: c.y - b.y)
        let length = hypot(u.x, u.y) * hypot(v.x, v.y)
        guard length > 0.0001 else { return 0 }
        return acos(min(1, max(-1, (u.x * v.x + u.y * v.y) / length))) * 180 / .pi
    }
}

struct RankedPoseAssessment: Equatable {
    var valid: Bool
    var top: Bool = false
    var bottom: Bool = false
    var reason: String
    var scale: Double = 0
}

enum RankedMovementRules {
    static let version = "pose-1"
    static let maximumGap = 0.25
    static let stablePhase = 0.18

    static func assess(_ pose: RankedPose, variation: RankedVariation) -> RankedPoseAssessment {
        func invalid(_ reason: String) -> RankedPoseAssessment { .init(valid: false, reason: reason) }
        guard pose.people == 1 else { return invalid(pose.people == 0 ? "Step into view" : "One athlete only") }
        guard pose.light >= 0.12 else { return invalid("Find brighter, even light") }
        guard !pose.cameraMoving else { return invalid("Keep the camera steady · Recalibrate") }
        let names = ["nose", "leftShoulder", "rightShoulder", "leftElbow", "rightElbow", "leftWrist", "rightWrist", "leftHip", "rightHip", "leftKnee", "rightKnee", "leftAnkle", "rightAnkle"]
        guard names.allSatisfy({ pose.point($0) != nil }) else { return invalid("Keep head, hands and feet visible") }
        let p = Dictionary(uniqueKeysWithValues: names.map { ($0, pose.point($0)!) })
        let ls = p["leftShoulder"]!, rs = p["rightShoulder"]!
        let lh = p["leftHip"]!, rh = p["rightHip"]!
        let torso = (ls.distance(to: lh) + rs.distance(to: rh)) / 2
        guard torso > 0.07 else { return invalid("Move closer · Full body in view") }
        let extentX = p.values.map(\.x).max()! - p.values.map(\.x).min()!
        let extentY = p.values.map(\.y).max()! - p.values.map(\.y).min()!
        guard max(extentX / pose.aspect, extentY) >= 0.35 else { return invalid("Move closer · Full body in view") }
        var elbows: [Double] = [], knees: [Double] = [], hips: [Double] = []
        for side in ["left", "right"] {
            let s = p[side + "Shoulder"]!, e = p[side + "Elbow"]!, w = p[side + "Wrist"]!
            let h = p[side + "Hip"]!, k = p[side + "Knee"]!, a = p[side + "Ankle"]!
            elbows.append(RankedVector.angle(s, e, w))
            knees.append(RankedVector.angle(h, k, a))
            hips.append(RankedVector.angle(s, h, variation == .kneePushUp ? k : a))
        }
        let shoulderSpan = ls.distance(to: rs)
        let handSpan = p["leftWrist"]!.distance(to: p["rightWrist"]!)
        let footSpan = p["leftAnkle"]!.distance(to: p["rightAnkle"]!)
        let stance = footSpan / max(shoulderSpan, 0.001)
        let grip = handSpan / max(shoulderSpan, 0.001)
        let meanShoulderY = (ls.y + rs.y) / 2
        let meanHipY = (lh.y + rh.y) / 2
        let meanAnkleY = (p["leftAnkle"]!.y + p["rightAnkle"]!.y) / 2
        let meanWristY = (p["leftWrist"]!.y + p["rightWrist"]!.y) / 2
        let elbow = elbows.min()!, knee = knees.min()!
        let deepestElbow = elbows.max()!, deepestKnee = knees.max()!
        let hip = hips.min()!
        let isSide = variation == .leftSidePlank || variation == .rightSidePlank
        if variation.family == .squats {
            guard shoulderSpan > torso * 0.3 else { return invalid("Turn to a three-quarter view · Show both feet") }
            let range: ClosedRange<Double> = variation == .wideSquat ? 1.4...2.8 : variation == .narrowSquat ? 0.2...0.85 : 0.85...1.5
            guard range.contains(stance) else { return invalid("Reset the selected stance") }
            guard meanShoulderY > meanHipY, meanHipY > meanAnkleY else { return invalid("Keep your torso upright") }
            let kneeY = (p["leftKnee"]!.y + p["rightKnee"]!.y) / 2
            return .init(valid: true, top: knee >= 160 && hip >= 155,
                         bottom: deepestKnee <= 100 && meanHipY <= kneeY + torso * 0.15,
                         reason: "Stand tall → Lower fully → Stand tall", scale: torso)
        }
        if isSide {
            let side = variation == .leftSidePlank ? "left" : "right"
            let other = side == "left" ? "right" : "left"
            let s = p[side + "Shoulder"]!, e = p[side + "Elbow"]!, w = p[side + "Wrist"]!
            guard s.y < p[other + "Shoulder"]!.y - torso * 0.12,
                  abs(ls.x - rs.x) < torso * 0.4,
                  footSpan < torso * 0.4,
                  abs(s.x - e.x) < torso * 0.35,
                  RankedVector.angle(s, e, w) < 125,
                  hip >= 160, knee >= 155 else { return invalid("Stack shoulders and feet · Support the selected side") }
            return .init(valid: true, top: true, reason: "Hold your line", scale: torso)
        }
        if variation == .wallHandstandPushUp || variation == .freestandingHandstandPushUp {
            guard meanAnkleY > meanHipY, meanHipY > meanShoulderY, meanShoulderY > meanWristY,
                  abs((lh.x + rh.x - ls.x - rs.x) / 2) < torso * 0.4,
                  hip >= 155, knee >= 155 else { return invalid("Show a straight, fully inverted body") }
        } else {
            guard abs(meanShoulderY - meanHipY) < torso * 0.65, hip >= 160 else { return invalid("Align shoulders, hips and legs") }
            if variation == .kneePushUp {
                let kneeY = (p["leftKnee"]!.y + p["rightKnee"]!.y) / 2
                guard deepestKnee < 155, abs(kneeY - meanWristY) < torso * 0.4 else { return invalid("Use knee support · Keep hips straight") }
            } else {
                guard knee >= 155 else { return invalid("Keep knees extended") }
                if variation == .planchePushUp {
                    guard meanAnkleY > meanWristY + torso * 0.18 else { return invalid("Both feet must remain above hand support") }
                } else {
                    guard abs(meanAnkleY - meanWristY) < torso * 0.45 else { return invalid("Keep toes and hands at floor level") }
                }
            }
        }
        if [.widePushUp, .closePushUp, .diamondPushUp, .standardPushUp, .pausedPushUp, .tempoPushUp].contains(variation) {
            guard shoulderSpan > torso * 0.3 else { return invalid("Turn slightly · Show both hands and shoulders") }
            let range: ClosedRange<Double> = variation == .widePushUp ? 1.4...2.8 : variation == .closePushUp ? 0.35...0.85 : variation == .diamondPushUp ? 0...0.55 : 0.85...1.5
            guard range.contains(grip) else { return invalid("Reset the selected hand placement") }
            if variation == .diamondPushUp, pose.diamondContact != true { return invalid("Show both thumbs and index fingertips together") }
        }
        if variation == .forearmPlank {
            guard elbow >= 65 && deepestElbow <= 115,
                  abs(ls.x - p["leftElbow"]!.x) < torso * 0.35,
                  abs(rs.x - p["rightElbow"]!.x) < torso * 0.35 else { return invalid("Elbows under shoulders · Forearms down") }
            return .init(valid: true, top: true, reason: "Hold your line", scale: torso)
        }
        if variation == .highPlank {
            guard elbow >= 155,
                  abs(ls.x - p["leftWrist"]!.x) < torso * 0.4,
                  abs(rs.x - p["rightWrist"]!.x) < torso * 0.4 else { return invalid("Straight arms · Hands beneath shoulders") }
            return .init(valid: true, top: true, reason: "Hold your line", scale: torso)
        }
        return .init(valid: true, top: elbow >= 160, bottom: deepestElbow <= 95,
                     reason: "Straight arms → Full depth → Straight arms", scale: torso)
    }
}

struct RankedTrackingState: Equatable {
    var score: Double = 0
    var currentHold: Double = 0
    var phase = "Set position"
    var reason = "Step into view"
    var usable = false
    var calibrated = false
    var accepted = false
}

struct RankedMovementTracker {
    let variation: RankedVariation
    private(set) var state = RankedTrackingState()
    private var lastTime: Double?
    private var stableSince: Double?
    private var calibrationSince: Double?
    private var calibratedScale: Double?
    private var holdSince: Double?
    private var descendingSince: Double?
    private var bottomSince: Double?
    private var phase = 0
    private var start: Double?
    private var end: Double?

    init(variation: RankedVariation) { self.variation = variation }

    mutating func begin(at start: Double, end: Double) {
        self.start = start
        self.end = end
        state.score = 0
        state.currentHold = 0
        resetSegment()
        lastTime = nil
    }

    mutating func interrupt(_ reason: String) {
        resetSegment()
        calibrationSince = nil
        calibratedScale = nil
        state.usable = false
        state.calibrated = false
        state.reason = reason
    }

    mutating func consume(_ pose: RankedPose) -> RankedTrackingState {
        state.accepted = false
        guard pose.time.isFinite, lastTime.map({ pose.time > $0 }) ?? true else { return state }
        let gap = lastTime.map { pose.time - $0 } ?? 0
        lastTime = pose.time
        let assessment = RankedMovementRules.assess(pose, variation: variation)
        if gap > RankedMovementRules.maximumGap || !assessment.valid {
            interrupt(gap > RankedMovementRules.maximumGap ? "Tracking interrupted · Reset position" : assessment.reason)
            return state
        }
        if let scale = calibratedScale, abs(assessment.scale / scale - 1) > 0.22 {
            interrupt("Viewpoint changed · Recalibrate")
            return state
        }
        state.usable = true
        state.reason = assessment.reason
        if !state.calibrated {
            if assessment.top {
                if calibrationSince == nil { calibrationSince = pose.time }
                if pose.time - calibrationSince! >= 1.5 {
                    state.calibrated = true
                    calibratedScale = assessment.scale
                }
            } else { calibrationSince = nil }
        }
        guard let start, let end, pose.time >= start, pose.time <= end else { return state }
        guard state.calibrated else { resetSegment(); state.reason = "Hold the starting position to calibrate"; return state }
        if variation.isTimedHold {
            if holdSince == nil { holdSince = pose.time }
            state.currentHold = pose.time - holdSince!
            state.score = max(state.score, state.currentHold)
            state.phase = "Holding"
            return state
        }
        switch phase {
        case 0:
            state.phase = "Start with full extension"
            if assessment.top {
                if stableSince == nil { stableSince = pose.time }
                if pose.time - stableSince! >= RankedMovementRules.stablePhase { phase = 1; stableSince = nil }
            } else { stableSince = nil }
        case 1:
            state.phase = "Lower"
            if !assessment.top, descendingSince == nil { descendingSince = pose.time }
            if assessment.bottom {
                if bottomSince == nil { bottomSince = pose.time }
                let pause = variation == .pausedPushUp || variation == .pausedSquat ? 1.0 : RankedMovementRules.stablePhase
                if pose.time - bottomSince! >= pause { phase = 2; stableSince = nil }
            } else {
                bottomSince = nil
                if assessment.top { descendingSince = nil }
            }
        default:
            state.phase = "Return to full extension"
            if assessment.top {
                if stableSince == nil { stableSince = pose.time }
                if pose.time - stableSince! >= RankedMovementRules.stablePhase {
                    let descent = (bottomSince ?? pose.time) - (descendingSince ?? pose.time)
                    if variation != .tempoPushUp || descent >= 3 {
                        state.score += 1
                        state.accepted = true
                        state.reason = "Complete repetition accepted"
                    } else { state.reason = "Lower for at least 3 seconds" }
                    phase = 1
                    stableSince = nil
                    descendingSince = nil
                    bottomSince = nil
                }
            } else { stableSince = nil }
        }
        return state
    }

    private mutating func resetSegment() {
        phase = 0
        stableSince = nil
        descendingSince = nil
        bottomSince = nil
        holdSince = nil
        state.currentHold = 0
        state.phase = "Reset position"
    }
}
