// SlotReelScroll.swift
//
// The Mac bar's scroll input and clock: a hit-test transparent view behind the bar that watches the window's
// scroll events, hands the ones that start over the bar's surface to `SlotReelScrollRouter`, and steps the
// reel once per display frame while it moves. Clicks, drags and every scroll elsewhere are left alone.

#if os(macOS)
import AppKit
import SwiftUI

struct SlotReelScroll: NSViewRepresentable {
    let reel: SlotReel
    /// Off while the bar is being edited: every scroll then passes through to the page.
    let isEnabled: Bool
    /// Points of scroll per slot.
    let pitch: CGFloat
    /// Whether a point, in the view's top-left coordinates, lies over the bar's surface.
    let contains: (CGPoint, CGSize) -> Bool
    /// Receives each slot the reel lands on.
    let onLand: (Int) -> Void

    func makeNSView(context: Context) -> SlotReelScrollView {
        let view = SlotReelScrollView()
        update(view)
        return view
    }

    func updateNSView(_ view: SlotReelScrollView, context: Context) {
        update(view)
    }

    static func dismantleNSView(_ view: SlotReelScrollView, coordinator: ()) {
        view.stop()
    }

    private func update(_ view: SlotReelScrollView) {
        view.attach(reel)
        view.pitch = pitch
        view.contains = contains
        view.isEnabled = isEnabled
        reel.landed = onLand
    }
}

final class SlotReelScrollView: NSView {
    /// A tracked gesture whose end event never arrived is let go after this long without input.
    static let stalledTracking: TimeInterval = 1

    var pitch: CGFloat = 1
    var contains: (CGPoint, CGSize) -> Bool = { _, _ in false }
    /// While off (the bar is being edited) every scroll reaches the page; a gesture the bar held is let go on
    /// the next event rather than during the view update that turned it off.
    var isEnabled = true

    private weak var reel: SlotReel?
    private var router = SlotReelScrollRouter()
    private var monitor: Any?
    private var link: CADisplayLink?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func attach(_ next: SlotReel) {
        guard reel !== next else { return }
        reel = next
        next.wake = { [weak self] in self?.startLink() }
        if next.isMoving || next.isTracking { startLink() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.receive(event) ?? false }
            return consumed ? nil : event
        }
        if let reel, reel.isMoving || reel.isTracking { startLink() }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        link?.invalidate()
        link = nil
        if let reel { router.reset(reel: reel, at: SlotReel.now) }
    }

    private func receive(_ event: NSEvent) -> Bool {
        guard let window, event.window === window, let reel else { return false }
        guard isEnabled else {
            router.reset(reel: reel, at: event.timestamp)
            return false
        }
        let local = convert(event.locationInWindow, from: nil)
        let point = CGPoint(x: local.x, y: isFlipped ? local.y : bounds.height - local.y)
        let inside = bounds.contains(local) && contains(point, bounds.size)
        return router.route(SlotReelScrollEvent(event, inside: inside), reel: reel, pitch: pitch)
    }

    private func startLink() {
        guard link == nil, window != nil else { return }
        let next = displayLink(target: self, selector: #selector(step(_:)))
        next.add(to: .main, forMode: .common)
        link = next
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let reel else {
            link.invalidate()
            self.link = nil
            return
        }
        let time = link.targetTimestamp
        if reel.isTracking, time - reel.lastInput > Self.stalledTracking {
            reel.release(at: time)
        }
        let moving = reel.frame(at: time)
        guard !moving, !reel.isTracking else { return }
        link.invalidate()
        self.link = nil
    }
}

private extension SlotReelScrollEvent {
    init(_ event: NSEvent, inside: Bool) {
        let phases = event.phase
        let phase: Phase
        if phases.isEmpty {
            phase = .wheel
        } else if phases.contains(.mayBegin) {
            phase = .mayBegin
        } else if phases.contains(.began) {
            phase = .began
        } else if phases.contains(.ended) || phases.contains(.cancelled) {
            phase = .ended
        } else {
            phase = .changed
        }
        let momentum = event.momentumPhase
        self.init(
            phase: phase,
            isMomentum: !momentum.isEmpty,
            momentumEnded: momentum.contains(.ended) || momentum.contains(.cancelled),
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            time: event.timestamp,
            inside: inside
        )
    }
}
#endif
