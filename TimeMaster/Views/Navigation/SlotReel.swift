// SlotReel.swift
//
// The navigation strip's motion on the Mac: two-finger scrolls, pointer drags, clicks and keyboard steps all
// move one reel, which publishes the position the bar draws and announces the page each gesture lands on.
// `SlotReelScrollRouter` decides which scroll events belong to the bar. Both are free of AppKit so the rules
// can be tested anywhere; `SlotReelScroll` feeds them real events and display frames on the Mac.

import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class SlotReel: ObservableObject {
    @Published private(set) var position: CGFloat
    @Published private(set) var isTracking = false
    @Published private(set) var isMoving = false
    private(set) var lastInput: TimeInterval = 0

    /// Called once with each slot a gesture or a selection comes to rest on.
    var landed: (Int) -> Void = { _ in }
    /// Asks whoever steps the reel once per display frame to start doing so.
    var wake: () -> Void = {}

    private var physics: SlotReelPhysics
    private var announced: Int?
    private var lastTick: TimeInterval = 0

    static let tickSpacing: TimeInterval = 0.025

    nonisolated static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    init(count: Int, slot: Int, tuning: SlotReelTuning = .bar) {
        physics = SlotReelPhysics(count: count, slot: slot, tuning: tuning)
        position = CGFloat(physics.position)
        announced = physics.slot
    }

    var reduceMotion: Bool {
        get { physics.reduceMotion }
        set { physics.reduceMotion = newValue }
    }

    var count: Int { physics.count }
    var slot: Int { physics.slot }
    var landing: Int? { physics.landing }

    /// Moves straight to `index` without announcing it.
    func place(at index: Int) {
        physics.place(at: index)
        announced = physics.slot
        publish(crossings: 0)
    }

    /// Follows the bar gaining or losing a page without announcing a landing.
    func resize(count: Int) {
        guard count != physics.count else { return }
        physics.resize(count: count)
        announced = physics.slot
        publish(crossings: 0)
    }

    /// Rests where the strip is currently drawn, so the next `select` glides from there.
    func hold(at position: CGFloat) {
        physics.hold(at: Double(position))
        announced = physics.slot
        publish(crossings: 0)
    }

    func grab(at time: TimeInterval) {
        lastInput = time
        physics.grab(at: time)
        publish(crossings: 0)
    }

    func track(_ slots: CGFloat, at time: TimeInterval = SlotReel.now) {
        lastInput = time
        let crossed = physics.track(delta: Double(slots), at: time)
        publish(crossings: crossed)
        wake()
    }

    func release(at time: TimeInterval = SlotReel.now) {
        physics.release(at: time)
        publish(crossings: 0)
        wake()
    }

    func select(_ index: Int, at time: TimeInterval = SlotReel.now) {
        physics.select(index, at: time)
        publish(crossings: 0)
        wake()
    }

    /// Glides to a selection made elsewhere, unless the fingers hold the reel or it already lands there.
    func show(_ index: Int) {
        guard !isTracking, physics.landing != index else { return }
        select(index)
    }

    /// Steps the motion to `time`; returns whether the reel still moves on its own.
    @discardableResult
    func frame(at time: TimeInterval) -> Bool {
        let wasMoving = physics.isMoving
        publish(crossings: physics.step(to: time))
        if wasMoving, physics.phase == .resting { Self.feel(.rest) }
        return physics.isMoving
    }

    private func publish(crossings: Int) {
        let next = CGFloat(physics.position)
        if position != next { position = next }
        let tracking = physics.phase == .tracking
        if isTracking != tracking { isTracking = tracking }
        let moving = physics.isMoving
        if isMoving != moving { isMoving = moving }
        if crossings > 0 { tick() }
        guard let landing = physics.landing else {
            announced = nil
            return
        }
        guard landing != announced else { return }
        announced = landing
        landed(landing)
    }

    private func tick() {
        let now = Self.now
        guard now - lastTick >= Self.tickSpacing else { return }
        lastTick = now
        Self.feel(.crossing)
    }

    private enum Feel { case crossing, rest }

    /// A light tick on a Force Touch trackpad for every page passed and when the strip comes to rest.
    private static func feel(_ moment: Feel) {
        #if os(macOS)
        guard NSApp.isActive else { return }
        let pattern: NSHapticFeedbackManager.FeedbackPattern = moment == .crossing ? .alignment : .levelChange
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        #endif
    }
}

/// One scroll event as the router sees it.
struct SlotReelScrollEvent: Equatable {
    enum Phase: Equatable {
        /// A mouse wheel notch, or any device that reports no gesture phases.
        case wheel
        /// Fingers rest on the trackpad; a scroll may follow.
        case mayBegin
        case began
        case changed
        /// The fingers lifted, or the system cancelled the gesture.
        case ended
    }

    var phase: Phase
    /// Set on the momentum events the system sends after the fingers lift.
    var isMomentum = false
    var momentumEnded = false
    /// `scrollingDeltaX` and `scrollingDeltaY`, already oriented by the person's scroll-direction setting.
    var deltaX: CGFloat
    var deltaY: CGFloat
    var time: TimeInterval
    /// Whether the pointer is over the bar's surface.
    var inside: Bool
}

/// Decides which scroll gestures belong to the bar. A gesture is the bar's only when it starts over the surface
/// and its first points travel mostly sideways; vertical scrolls, gestures that started over the page and the
/// momentum of a page scroll pass through untouched. Momentum after the bar's own gesture is swallowed, so the
/// page beneath doesn't drift when the fingers lift.
@MainActor
struct SlotReelScrollRouter {
    static let lockDistance: CGFloat = 6
    static let axisBias: CGFloat = 1.15
    static let wheelSpacing: TimeInterval = 0.06

    private enum Claim { case pending, bar, page }

    private var claim: Claim?
    private var along: CGFloat = 0
    private var across: CGFloat = 0
    private var grabbed = false
    private var swallowsMomentum = false
    private var lastWheel = -TimeInterval.infinity

    /// Scroll deltas move the strip the way they move any Mac scroll view's content. They already carry the
    /// person's scroll-direction setting (`isDirectionInvertedFromDevice` reports it), so with natural scrolling
    /// the strip follows the fingers and nothing is inverted a second time.
    static func slots(_ delta: CGFloat, pitch: CGFloat) -> CGFloat {
        -delta / max(pitch, 1)
    }

    /// Feeds one event to the reel; returns `true` when the bar consumed it and the page must not see it.
    mutating func route(_ event: SlotReelScrollEvent, reel: SlotReel, pitch: CGFloat) -> Bool {
        if event.isMomentum {
            guard swallowsMomentum else { return false }
            if event.momentumEnded { swallowsMomentum = false }
            return true
        }
        let time = event.time
        switch event.phase {
        case .wheel:
            return event.inside && wheel(event, reel: reel)
        case .mayBegin:
            reset(reel: reel, at: time)
            if event.inside, reel.isMoving {
                reel.grab(at: time)
                grabbed = true
            }
            return false
        case .began:
            if !grabbed { reset(reel: reel, at: time) }
            along = 0
            across = 0
            claim = event.inside ? .pending : .page
        case .changed, .ended:
            break
        }
        let ended = event.phase == .ended
        guard let current = claim else {
            if ended, grabbed {
                reel.release(at: time)
                grabbed = false
            }
            return false
        }
        switch current {
        case .page:
            if ended { finish(reel: reel, at: time) }
            return false
        case .pending:
            along += event.deltaX
            across += event.deltaY
            if ended {
                finish(reel: reel, at: time)
                return false
            }
            guard (along * along + across * across).squareRoot() >= Self.lockDistance else { return false }
            guard abs(along) > abs(across) * Self.axisBias else {
                if grabbed {
                    reel.release(at: time)
                    grabbed = false
                }
                claim = .page
                return false
            }
            claim = .bar
            if !reel.isTracking { reel.grab(at: time) }
            reel.track(Self.slots(along, pitch: pitch), at: time)
            return true
        case .bar:
            if ended {
                reel.release(at: time)
                claim = nil
                grabbed = false
                swallowsMomentum = true
                return true
            }
            reel.track(Self.slots(event.deltaX, pitch: pitch), at: time)
            return true
        }
    }

    /// Lets go of the gesture in progress, for example when the bar leaves the window or editing starts.
    mutating func reset(reel: SlotReel, at time: TimeInterval) {
        if reel.isTracking, claim == .bar || grabbed { reel.release(at: time) }
        claim = nil
        grabbed = false
        swallowsMomentum = false
        along = 0
        across = 0
    }

    private mutating func finish(reel: SlotReel, at time: TimeInterval) {
        if grabbed { reel.release(at: time) }
        claim = nil
        grabbed = false
    }

    /// A sideways wheel notch steps one page; notches closer together than `wheelSpacing` are absorbed so one
    /// flick of a free-spinning wheel can't race through the whole bar.
    private mutating func wheel(_ event: SlotReelScrollEvent, reel: SlotReel) -> Bool {
        guard event.deltaX != 0, abs(event.deltaX) > abs(event.deltaY) else { return false }
        if event.time - lastWheel >= Self.wheelSpacing {
            lastWheel = event.time
            reel.select((reel.landing ?? reel.slot) + (event.deltaX > 0 ? -1 : 1), at: event.time)
        }
        return true
    }
}
