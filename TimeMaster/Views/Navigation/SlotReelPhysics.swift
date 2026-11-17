// SlotReelPhysics.swift
//
// The motion model behind the navigation strip on the Mac. Two-finger scrolls and pointer drags move it with
// the fingers, a flick coasts against friction and detents, and every gesture comes to rest exactly on a slot.
// Ported from EverAhent's reel, which the bar shares its component with, so both bars feel the same.
// Positions are in slots (0 is the first page), velocities in slots per second, times in seconds.

import Foundation

struct SlotReelTuning: Equatable, Sendable {
    /// Release speed below which the reel falls back to the nearest slot.
    var flickSpeed: Double
    /// Release speed from which the reel coasts instead of stepping one slot.
    var spinSpeed: Double
    /// Coasting speed at which the reel picks the slot it will land on.
    var captureSpeed: Double
    /// How far ahead of the coasting position, in seconds of travel, the landing slot is picked.
    var reach: Double
    var maximumSpeed: Double
    var drag: Double
    var friction: Double
    /// Pull of each slot while coasting slowly, fading out with speed.
    var detent: Double
    var detentFade: Double
    var stiffness: Double
    var damping: Double
    /// Furthest the strip can be pulled past either end, in slots.
    var overscroll: Double
    var rubber: Double
    /// Travel a Reduce Motion gesture needs before it steps one slot.
    var stepDistance: Double
    /// Window of recent samples the release speed is fitted to.
    var sampleWindow: Double
    /// Pause before release after which the fingers count as stopped.
    var pause: Double

    static let bar = SlotReelTuning(
        flickSpeed: 0.45, spinSpeed: 5, captureSpeed: 2.4, reach: 0.08, maximumSpeed: 42,
        drag: 1.7, friction: 3.6, detent: 5, detentFade: 7,
        stiffness: 400, damping: 26, overscroll: 0.6, rubber: 0.55,
        stepDistance: 0.3, sampleWindow: 0.1, pause: 0.075
    )
}

struct SlotReelPhysics: Sendable {
    enum Phase: Equatable, Sendable {
        case resting
        case tracking
        case coasting
        case settling
    }

    private struct Sample: Sendable {
        var time: Double
        var finger: Double
    }

    static let substep = 1.0 / 600
    static let longestFrame = 0.25
    static let restDistance = 0.003
    static let restSpeed = 0.06
    static let aheadTolerance = 0.04

    let tuning: SlotReelTuning
    var reduceMotion: Bool
    private(set) var count: Int
    private(set) var position: Double
    private(set) var velocity: Double = 0
    private(set) var phase: Phase = .resting
    private(set) var target: Int?
    private(set) var slot: Int
    private var minimumLanding: Int?
    private var springStiffness = 0.0
    private var springDamping = 0.0
    private var finger = 0.0
    private var origin = 0
    private var stepped = false
    private var samples: [Sample] = []
    private var clock = 0.0

    init(count: Int, slot: Int = 0, tuning: SlotReelTuning = .bar, reduceMotion: Bool = false) {
        self.tuning = tuning
        self.reduceMotion = reduceMotion
        self.count = max(count, 0)
        let start = min(max(slot, 0), max(count - 1, 0))
        self.slot = start
        position = Double(start)
    }

    var upper: Double { Double(max(count - 1, 0)) }

    var isMoving: Bool { phase == .coasting || phase == .settling }

    /// The slot the reel rests on or is settling onto; `nil` while the fingers or momentum still decide.
    var landing: Int? {
        switch phase {
        case .resting: slot
        case .settling: target
        case .tracking, .coasting: nil
        }
    }

    mutating func place(at index: Int) {
        let next = clamped(index)
        position = Double(next)
        velocity = 0
        phase = .resting
        target = nil
        minimumLanding = nil
        samples.removeAll()
        slot = next
    }

    /// Changes how many slots there are after a page joined or left the bar, resting on the nearest one left.
    mutating func resize(count newCount: Int) {
        let next = max(newCount, 0)
        guard next != count else { return }
        count = next
        place(at: Int(position.rounded()))
    }

    /// Rests the reel where the strip is drawn, between slots or up to one slot past either end, so the next
    /// `select` glides from there instead of jumping.
    mutating func hold(at value: Double) {
        guard value.isFinite else { return }
        position = min(max(value, -1), upper + 1)
        velocity = 0
        phase = .resting
        target = nil
        minimumLanding = nil
        samples.removeAll()
        slot = clamped(Int(position.rounded()))
    }

    mutating func grab(at time: Double) {
        guard count > 0 else { return }
        phase = .tracking
        velocity = 0
        target = nil
        minimumLanding = nil
        stepped = false
        // A held strip can sit further past an end than the rubber band reaches; catch it inside the band.
        let reach = tuning.overscroll * 0.8
        position = min(max(position, -reach), upper + reach)
        finger = unbanded(position)
        origin = clamped(Int(position.rounded()))
        clock = time
        samples = [Sample(time: time, finger: finger)]
    }

    /// Moves the reel by `delta` slots under the fingers; returns how many slots it crossed.
    @discardableResult
    mutating func track(delta: Double, at time: Double) -> Int {
        guard count > 0, delta.isFinite, time.isFinite else { return 0 }
        if phase != .tracking { grab(at: time) }
        finger += delta
        clock = max(clock, time)
        if reduceMotion {
            guard !stepped, abs(finger - Double(origin)) >= tuning.stepDistance else { return 0 }
            stepped = true
            position = Double(clamped(origin + (finger > Double(origin) ? 1 : -1)))
            return noteSlot()
        }
        record(Sample(time: time, finger: finger))
        position = banded(finger)
        return noteSlot()
    }

    mutating func release(at time: Double) {
        guard phase == .tracking else { return }
        clock = max(clock, time)
        if reduceMotion {
            place(at: Int(position.rounded()))
            return
        }
        let speed = min(max(estimatedVelocity(at: time), -tuning.maximumSpeed), tuning.maximumSpeed)
        velocity = speed
        samples.removeAll()
        if position < 0 || position > upper {
            settle(on: position < 0 ? 0 : count - 1, stopping: abs(speed))
            return
        }
        let magnitude = abs(speed)
        if magnitude < tuning.flickSpeed {
            settle(on: Int(position.rounded()))
            return
        }
        let forward = speed > 0
        let flick = clamped(forward
            ? max(origin + 1, Int((position - Self.aheadTolerance).rounded(.up)))
            : min(origin - 1, Int((position + Self.aheadTolerance).rounded(.down))))
        if magnitude < tuning.spinSpeed {
            settle(on: flick)
            return
        }
        minimumLanding = flick
        target = nil
        phase = .coasting
    }

    mutating func select(_ index: Int, at time: Double) {
        guard count > 0 else { return }
        if reduceMotion || phase == .resting && Double(clamped(index)) == position {
            place(at: index)
            return
        }
        if phase == .tracking || phase == .resting { clock = time }
        samples.removeAll()
        settle(on: index, glide: true)
    }

    /// Advances the motion to `time` in fixed substeps; returns how many slots it crossed.
    @discardableResult
    mutating func step(to time: Double) -> Int {
        guard isMoving, time.isFinite else {
            if time.isFinite, phase == .resting { clock = time }
            return 0
        }
        if time - clock > Self.longestFrame { clock = time - Self.longestFrame }
        var crossings = 0
        while clock + Self.substep <= time {
            integrate(Self.substep)
            clock += Self.substep
            crossings += noteSlot()
            if phase == .resting {
                clock = time
                break
            }
        }
        return crossings
    }

    /// Least-squares speed of the recent samples, so one duplicated or late event can't spike a flick.
    func estimatedVelocity(at time: Double) -> Double {
        guard let last = samples.last, time - last.time <= tuning.pause else { return 0 }
        let recent = samples.filter { last.time - $0.time <= tuning.sampleWindow }
        guard recent.count >= 2, let first = recent.first, last.time - first.time > 0.004 else { return 0 }
        let meanTime = recent.reduce(0) { $0 + $1.time } / Double(recent.count)
        let meanFinger = recent.reduce(0) { $0 + $1.finger } / Double(recent.count)
        var covariance = 0.0
        var variance = 0.0
        for sample in recent {
            let dt = sample.time - meanTime
            covariance += dt * (sample.finger - meanFinger)
            variance += dt * dt
        }
        guard variance > 0 else { return 0 }
        let slope = covariance / variance
        return slope.isFinite ? slope : 0
    }

    private mutating func record(_ sample: Sample) {
        if let last = samples.last, sample.time - last.time < 0.002 {
            samples[samples.count - 1] = Sample(time: max(last.time, sample.time), finger: sample.finger)
        } else {
            samples.append(sample)
        }
        let horizon = sample.time - tuning.sampleWindow * 2
        if let stale = samples.firstIndex(where: { $0.time >= horizon }), stale > 0 {
            samples.removeFirst(stale)
        }
    }

    private mutating func settle(on index: Int, stopping speed: Double = 0, glide: Bool = false) {
        let next = clamped(index)
        target = next
        minimumLanding = nil
        phase = .settling
        let natural = tuning.stiffness.squareRoot()
        let stop = max(natural, speed * 1.5)
        springStiffness = stop * stop
        springDamping = stop > natural ? 2 * stop : (glide ? natural * 1.72 : tuning.damping)
        if isRested(on: next) { place(at: next) }
    }

    private mutating func integrate(_ dt: Double) {
        switch phase {
        case .coasting:
            let magnitude = abs(velocity)
            let direction: Double = velocity >= 0 ? 1 : -1
            let fade = max(0, 1 - magnitude / tuning.detentFade)
            let pull = -tuning.detent * fade * fade * sin(2 * Double.pi * position)
            velocity += (pull - direction * (tuning.friction + tuning.drag * magnitude)) * dt
            position += velocity * dt
            if position > upper && velocity > 0 || position < 0 && velocity < 0 {
                settle(on: position < 0 ? 0 : count - 1, stopping: abs(velocity))
            } else if abs(velocity) < tuning.captureSpeed {
                let forward = direction > 0
                let reached = position + velocity * tuning.reach
                let ahead = forward
                    ? Int((reached - Self.aheadTolerance).rounded(.up))
                    : Int((reached + Self.aheadTolerance).rounded(.down))
                let floor = minimumLanding ?? ahead
                settle(on: forward ? max(ahead, floor) : min(ahead, floor))
            }
        case .settling:
            guard let target else {
                phase = .resting
                return
            }
            let goal = Double(target)
            velocity += (-springStiffness * (position - goal) - springDamping * velocity) * dt
            position += velocity * dt
            if isRested(on: target) { place(at: target) }
        case .resting, .tracking:
            break
        }
    }

    private func isRested(on index: Int) -> Bool {
        abs(position - Double(index)) < Self.restDistance && abs(velocity) < Self.restSpeed
    }

    private mutating func noteSlot() -> Int {
        let next = clamped(Int(position.rounded()))
        let crossed = abs(next - slot)
        slot = next
        return crossed
    }

    private func clamped(_ index: Int) -> Int {
        min(max(index, 0), max(count - 1, 0))
    }

    private func banded(_ value: Double) -> Double {
        if value < 0 { return -band(-value) }
        if value > upper { return upper + band(value - upper) }
        return value
    }

    private func unbanded(_ value: Double) -> Double {
        if value < 0 { return -unband(-value) }
        if value > upper { return upper + unband(value - upper) }
        return value
    }

    private func band(_ overshoot: Double) -> Double {
        let limit = tuning.overscroll
        return limit * (1 - 1 / (overshoot * tuning.rubber / limit + 1))
    }

    private func unband(_ shown: Double) -> Double {
        let limit = tuning.overscroll
        let fraction = min(shown / limit, 0.999)
        return limit / tuning.rubber * (1 / (1 - fraction) - 1)
    }
}
