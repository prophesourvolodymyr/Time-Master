// PageWheelSpin.swift
//
// The page wheel's turning. A finger turns it directly; let go and it keeps the speed it had, eases out and comes to
// rest with a slice exactly at the top. Rotations count slices and are not wrapped, velocities are slices per second
// and times seconds.

import Foundation

struct PageWheelSpin: Equatable {
    enum Phase: Equatable {
        case resting
        case tracking
        case settling
    }

    private struct Sample: Equatable {
        var time: Double
        var rotation: Double
    }

    static let stiffness = 190.0
    static let damping = 25.0
    /// Seconds of travel at release speed a flick carries the wheel on before it settles.
    static let reach = 0.3
    static let maximumSpeed = 36.0
    static let sampleWindow = 0.1
    static let pause = 0.08
    static let substep = 1.0 / 480
    static let longestFrame = 0.25
    static let restDistance = 0.002
    static let restSpeed = 0.05

    private(set) var rotation: Double
    private(set) var velocity: Double = 0
    private(set) var phase: Phase = .resting
    private(set) var target: Double?
    private var samples: [Sample] = []

    init(rotation: Double = 0) {
        self.rotation = rotation.isFinite ? rotation : 0
    }

    var isMoving: Bool { phase == .settling }

    /// Puts the wheel at `rotation` at once, at rest.
    mutating func place(_ rotation: Double) {
        guard rotation.isFinite else { return }
        self.rotation = rotation
        velocity = 0
        target = nil
        phase = .resting
        samples.removeAll()
    }

    /// A finger takes hold, stopping any motion where it is.
    mutating func grab(at time: Double) {
        velocity = 0
        target = nil
        phase = .tracking
        samples = [Sample(time: time, rotation: rotation)]
    }

    mutating func track(by delta: Double, at time: Double) {
        guard delta.isFinite, time.isFinite else { return }
        if phase != .tracking { grab(at: time) }
        rotation += delta
        samples.append(Sample(time: time, rotation: rotation))
        samples.removeAll { time - $0.time > Self.sampleWindow * 1.5 }
    }

    /// The finger lets go: the wheel carries on with the speed of its last moments and picks the slice it will rest on.
    mutating func release(at time: Double) {
        guard phase == .tracking else { return }
        let speed = Self.releaseSpeed(samples, at: time)
        samples.removeAll()
        let landing = (rotation + speed * Self.reach).rounded()
        settle(on: landing, velocity: speed)
    }

    /// Turns to `rotation` (a whole slice) from wherever the wheel is, keeping its current speed unless one is given.
    mutating func settle(on rotation: Double, velocity: Double? = nil) {
        guard rotation.isFinite else { return }
        target = rotation
        if let velocity, velocity.isFinite {
            self.velocity = min(max(velocity, -Self.maximumSpeed), Self.maximumSpeed)
        }
        phase = .settling
        samples.removeAll()
        if abs(self.rotation - rotation) < Self.restDistance, abs(self.velocity) < Self.restSpeed {
            self.rotation = rotation
            self.velocity = 0
            phase = .resting
        }
    }

    /// Advances the motion by `duration` seconds; returns whether the wheel still moves on its own.
    @discardableResult
    mutating func step(by duration: Double) -> Bool {
        guard phase == .settling, let target, duration.isFinite, duration > 0 else { return phase == .settling }
        var remaining = min(duration, Self.longestFrame)
        while remaining > 0 {
            let dt = min(Self.substep, remaining)
            let force = -Self.stiffness * (rotation - target) - Self.damping * velocity
            velocity += force * dt
            rotation += velocity * dt
            remaining -= dt
        }
        if abs(rotation - target) < Self.restDistance, abs(velocity) < Self.restSpeed {
            rotation = target
            velocity = 0
            phase = .resting
            self.target = nil
        }
        return phase == .settling
    }

    private static func releaseSpeed(_ samples: [Sample], at time: Double) -> Double {
        guard let last = samples.last, time - last.time <= pause else { return 0 }
        let recent = samples.filter { last.time - $0.time <= sampleWindow }
        guard let first = recent.first, last.time - first.time > 0.008 else { return 0 }
        let speed = (last.rotation - first.rotation) / (last.time - first.time)
        guard speed.isFinite else { return 0 }
        return min(max(speed, -maximumSpeed), maximumSpeed)
    }
}
