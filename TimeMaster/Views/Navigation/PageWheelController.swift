// PageWheelController.swift
//
// The page wheel's state. Pulling the bar up turns its arc into the wheel in real time; a finger still holding when
// the wheel has formed points at a slice and opens it on release, and the page behind already switches to whatever it
// rests on. Once open the wheel spins under a finger, the slice at the top is the selection, a tap opens a slice (the
// hub opens the top one), and typing turns it to the best match while a thinking bubble lists what was found below the
// pages. The container does not observe this object: only the wheel's own views redraw while it moves.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// The bar's arc as the wheel starts from it, in global coordinates.
struct PageWheelArc: Equatable {
    var peak: CGPoint
    var width: CGFloat
    var sag: CGFloat
    /// Distance between two pages on the bar.
    var pitch: CGFloat
    /// How far below the arc line the pages' icons sit.
    var inset: CGFloat

    static let zero = PageWheelArc(peak: .zero, width: 0, sag: 1, pitch: 80, inset: 18)
}

/// Where the wheel, its search field and its bubble go inside the space the wheel has: the field at the top, the
/// thinking bubble hanging under it (beside the wheel on wide windows) and the wheel below. While typing on a phone the
/// wheel grows and sits right under the field and the bubble, its lower half going under the keyboard.
struct PageWheelLayout: Equatable {
    var bounds: CGRect
    var center: CGPoint
    var radius: CGFloat
    var searchBar: CGRect
    var bubble: CGRect
    var bubbleOnSide: Bool
    var searching: Bool

    static let searchHeight: CGFloat = 54

    /// `bubbleHeight` is the height the thinking bubble takes now, 0 while it is hidden.
    init(bounds: CGRect, searching: Bool, keyboardUp: Bool, bubbleHeight: CGFloat = 0) {
        self.bounds = bounds
        self.searching = searching
        let width = bounds.width
        let wide = width >= 760
        let barWidth = min(width - 32, 560)
        searchBar = CGRect(x: bounds.midX - barWidth / 2, y: bounds.minY + 12, width: barWidth, height: Self.searchHeight)
        let below = searchBar.maxY + 14
        let room = max(0, bounds.maxY - below)
        if wide {
            radius = max(90, min(width * 0.3, room * 0.42, 260))
            center = CGPoint(x: bounds.midX, y: below + room * 0.48)
            let bubbleWidth = min(360, (width - radius * 2) / 2 - 40)
            bubble = CGRect(x: center.x + radius + 28, y: center.y - radius, width: max(0, bubbleWidth), height: radius * 2)
            bubbleOnSide = true
        } else {
            bubble = CGRect(x: bounds.minX + 16, y: below, width: width - 32,
                            height: keyboardUp ? max(120, room - 110) : room * 0.45)
            bubbleOnSide = false
            let top = below + (bubbleHeight > 0 ? min(bubbleHeight, bubble.height) + 10 : 0)
            if searching && keyboardUp {
                radius = min(width * 0.5, 230)
                center = CGPoint(x: bounds.midX, y: top + radius + 4)
            } else {
                let space = max(0, bounds.maxY - top)
                radius = max(90, min(width * 0.43, space * 0.42, 210))
                center = CGPoint(x: bounds.midX, y: max(top + radius + 8, top + space * 0.44))
            }
        }
    }

    func morph(count: Int, arc: PageWheelArc) -> PageWheelMorph {
        let circle = PageWheelMorph.arcCircle(width: max(arc.width, 1), peak: arc.peak, sag: arc.sag)
        return PageWheelMorph(
            count: count, arcCenter: circle.center, arcRadius: circle.radius, arcPitch: arc.pitch, arcInset: arc.inset,
            wheelCenter: center, wheelRadius: radius
        )
    }
}

@MainActor
final class PageWheelController: ObservableObject {
    enum Phase: Equatable {
        case closed
        case pulling
        case open
        case closing
    }

    @Published private(set) var phase: Phase = .closed
    /// 0 is the bar's arc, 1 the formed wheel.
    @Published private(set) var progress: CGFloat = 0
    /// How far a pull went past the formed wheel, which stretches it.
    @Published private(set) var stretch: CGFloat = 0
    @Published private(set) var rotation: CGFloat = 0
    /// The slice a holding finger or the pointer is on.
    @Published private(set) var hovered: Int?
    /// The finger or the pointer over the wheel, in wheel space: it magnifies the slices around it.
    @Published private(set) var touch: CGPoint?
    /// Where the wheel's orange light sits (it stays where the finger lifted while it fades) and how bright it is.
    @Published private(set) var light: CGPoint?
    @Published private(set) var glow: CGFloat = 0
    @Published private(set) var results = NavigationSearchResults.empty
    @Published private(set) var expanded: [String: [NavigationSearchNode]] = [:]
    /// A search is waiting for its pause or its index, or running; the field and the bubble show it.
    @Published private(set) var isSearching = false
    @Published var searchFocused = false
    @Published var query = "" {
        didSet { if query != oldValue { queryChanged() } }
    }

    private(set) var items: [SlotNavigationItem] = []
    var bounds: CGRect = .zero
    /// The top of the on-screen keyboard in the wheel's space while it shows.
    @Published var keyboardTop: CGFloat?
    /// The thinking bubble's height while it shows; the wheel makes room for it under the search field.
    @Published var bubbleHeight: CGFloat = 0
    var arc = PageWheelArc.zero
    var reduceMotion = false
    var search: NavigationSearchModel? {
        didSet {
            search?.onIndexChanged = { [weak self] in
                guard let self, !self.query.isEmpty else { return }
                self.queryChanged()
            }
        }
    }

    /// The page behind the wheel should become `id` (the deck slides to its shell and builds it).
    var onPreview: (String) -> Void = { _ in }
    /// `id` was chosen: select it.
    var onCommit: (String) -> Void = { _ in }
    /// The wheel closed without a choice: the page behind returns to the selection.
    var onCancel: () -> Void = {}
    var onPhaseChange: (Phase) -> Void = { _ in }
    /// A search result below the pages was chosen.
    var onOpenTarget: (NavigationSearchTarget) -> Void = { _ in }

    private var spin = PageWheelSpin()
    private var clock = PageWheelClock()
    private var lastTop: Int?
    private var lastTick: TimeInterval = 0
    private var previewed: String?
    private var previewTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var formedAt: TimeInterval?
    /// Where the finger last came to rest and since when: a page opens behind the wheel, and on release, only once the
    /// finger holds on a slice, never while it only passes over slices on its way.
    private var holdAnchor: CGPoint?
    private var holdSince: TimeInterval = 0
    private var pullDistance: CGFloat = 220
    private var spinStart: CGPoint?
    /// The finger came down on the hub: moving it points at a slice like a marking menu, and lifting opens that slice.
    private var touchOnHub = false

    init() {
        clock.tick = { [weak self] time, step in self?.frame(time: time, step: step) }
    }

    var isActive: Bool { phase != .closed }
    var layout: PageWheelLayout {
        var area = bounds
        if let keyboardTop {
            area.size.height = min(area.height, max(220, keyboardTop - area.minY))
        }
        return PageWheelLayout(bounds: area, searching: searchFocused || !query.isEmpty, keyboardUp: keyboardTop != nil,
                               bubbleHeight: bubbleHeight)
    }

    func geometry(at progress: CGFloat? = nil) -> PageWheelGeometry {
        layout.morph(count: items.count, arc: arc).geometry(at: progress ?? self.progress)
    }

    var top: Int { PageWheelGeometry.wrap(Int(rotation.rounded()), count: items.count) }

    func update(items: [SlotNavigationItem]) {
        guard items.map(\.id) != self.items.map(\.id) else {
            self.items = items
            return
        }
        let current = self.items.indices.contains(top) ? self.items[top].id : nil
        self.items = items
        if let current, let index = items.firstIndex(where: { $0.id == current }) {
            place(at: index)
        }
    }

    // MARK: Opening from the bar

    /// A finger on the bar started pulling up. `selection` is the page on screen, which the wheel opens on.
    func beginPull(selection: Int) {
        guard !items.isEmpty, phase == .closed || phase == .closing else { return }
        closeTask?.cancel()
        pullDistance = min(max((arc.peak.y - layout.center.y) * 0.85, 180), 320)
        place(at: selection)
        formedAt = nil
        holdAnchor = nil
        hovered = nil
        light = nil
        glow = 0
        query = ""
        results = .empty
        expanded = [:]
        search?.prepare(wheelPages: items.map(\.id))
        setPhase(.pulling)
        AppInteractionHaptics.shared.beganReveal()
    }

    /// The pulling finger moved: `translation` from where it started, `location` where it is now (wheel space).
    func pull(translation: CGSize, location: CGPoint, now: TimeInterval = PageWheelClock.now) {
        guard phase == .pulling else { return }
        let raw = -translation.height / pullDistance
        let formed = raw >= 1
        let nextProgress = min(max(raw, 0), 1)
        let nextStretch = formed && !reduceMotion ? (raw - 1) * 0.22 : 0
        if formed, formedAt == nil {
            formedAt = now
            AppInteractionHaptics.shared.crossedThreshold()
            feel(.formed)
        }
        if progress != nextProgress || abs(stretch - nextStretch) > 0.001 {
            withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.2, dampingFraction: 0.88, blendDuration: 0.1)) {
                progress = nextProgress
                stretch = nextStretch
            }
        }
        touch = location
        lightUp(at: location)
        guard formedAt != nil, raw >= 0.92 else {
            setHovered(nil, now: now)
            return
        }
        setHovered(geometry(at: 1).slice(at: location, rotation: rotation), now: now)
        trackHold(at: location, now: now)
    }

    /// The pulling finger lifted. A slice it held on opens; a pull that went far enough leaves the wheel open on the
    /// page that was showing; a short one falls back into the bar.
    func endPull(translation: CGSize, predicted: CGSize, now: TimeInterval = PageWheelClock.now) {
        guard phase == .pulling else { return }
        touch = nil
        dimLight()
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) { stretch = 0 }
        if let hovered, isHeld(now: now) {
            commit(hovered)
            return
        }
        setHovered(nil, now: now)
        let projected = -predicted.height / pullDistance
        if progress >= 0.38 || projected >= 0.85 {
            open()
            schedulePreview(top, dwell: 0)
        } else {
            close(committing: nil)
        }
    }

    /// Opens the wheel at once, for the keyboard command, the accessibility action and the two-finger swipe.
    func present(selection: Int, searching: Bool) {
        guard !items.isEmpty else { return }
        if phase == .closed || phase == .closing {
            beginPull(selection: selection)
        }
        open()
        if searching { searchFocused = true }
    }

    private func open() {
        setPhase(.open)
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.86)) {
            progress = 1
            stretch = 0
        }
        AppInteractionHaptics.shared.opened()
    }

    /// The orange light under the finger: it comes up softly where the finger is and follows it.
    private func lightUp(at location: CGPoint) {
        light = location
        guard glow < 1 else { return }
        withAnimation(reduceMotion ? nil : EverBounceMotion.lightOn) { glow = 1 }
    }

    /// The light fades where the finger left it.
    private func dimLight() {
        guard glow > 0 else { return }
        withAnimation(reduceMotion ? nil : EverBounceMotion.lightOff) { glow = 0 }
    }

    // MARK: Using the open wheel

    /// A finger came down on the open wheel at `location`.
    func touchBegan(at location: CGPoint, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open else { return }
        touch = location
        lightUp(at: location)
        spinStart = location
        let geometry = geometry(at: 1)
        touchOnHub = geometry.distance(to: location) <= geometry.hubRadius
        if spin.phase == .settling {
            spin.grab(at: now)
            clock.stop()
        }
    }

    /// The finger moved: from the hub it points at the slice in its direction; on the ring, past a few points, it turns
    /// the wheel.
    func touchMoved(to location: CGPoint, from start: CGPoint, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open else { return }
        touch = location
        light = location
        let geometry = geometry(at: 1)
        if touchOnHub {
            let slice = geometry.distance(to: location) > geometry.hubRadius
                ? geometry.slice(at: location, rotation: rotation) : nil
            setHovered(slice, now: now)
            trackHold(at: location, now: now)
            return
        }
        guard let previous = spinStart else {
            spinStart = location
            return
        }
        if spin.phase != .tracking {
            guard hypot(location.x - start.x, location.y - start.y) > 6 else { return }
            spin.grab(at: now)
            cancelPreview()
        }
        spin.track(by: Double(geometry.slices(turnedFrom: previous, to: location)), at: now)
        spinStart = location
        publishRotation()
    }

    /// The finger lifted. Without travel it was a tap: a slice opens (turning to the top first), the hub opens the
    /// slice at the top. A drag from the hub opens the slice it points at. A spin coasts on and settles.
    func touchEnded(at location: CGPoint, travelled: CGFloat, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open else { return }
        let fromHub = touchOnHub
        touch = nil
        dimLight()
        spinStart = nil
        touchOnHub = false
        if spin.phase == .tracking {
            spin.release(at: now)
            clock.start()
            return
        }
        if fromHub, travelled >= 10 {
            if let hovered {
                commit(hovered)
            } else {
                setHovered(nil, now: now)
            }
            return
        }
        guard travelled < 10 else { return }
        let geometry = geometry(at: 1)
        let distance = geometry.distance(to: location)
        if distance <= geometry.hubRadius {
            commit(top)
        } else if distance <= geometry.radius * 1.08, let slice = geometry.slice(at: location, rotation: rotation) {
            commit(slice)
        } else {
            close(committing: nil)
        }
    }

    /// The pointer moved over the wheel on the Mac, or left it (nil).
    func hover(at location: CGPoint?, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open else { return }
        touch = location
        guard let location else {
            setHovered(nil, now: now)
            dimLight()
            return
        }
        lightUp(at: location)
        let geometry = geometry(at: 1)
        let slice = geometry.distance(to: location) <= geometry.radius * 1.08
            ? geometry.slice(at: location, rotation: rotation) : nil
        setHovered(slice, now: now)
        trackHold(at: location, now: now)
    }

    /// Two-finger scrolls and arrow keys turn the wheel one or more slices.
    func turn(by slices: Double, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open, slices.isFinite, slices != 0 else { return }
        let base = spin.target ?? Double(rotation)
        spin.settle(on: (base + slices).rounded())
        clock.start()
    }

    /// A continuous two-finger scroll over the wheel on the Mac.
    func scroll(by slices: Double, ended: Bool, now: TimeInterval = PageWheelClock.now) {
        guard phase == .open else { return }
        if ended {
            spin.release(at: now)
            clock.start()
            return
        }
        if spin.phase != .tracking { spin.grab(at: now) }
        spin.track(by: slices, at: now)
        publishRotation()
    }

    /// Opens slice `index`: the wheel turns it to the top, the page is chosen and the wheel falls back into the bar
    /// with that page in the middle.
    func commit(_ index: Int) {
        guard items.indices.contains(index), phase != .closing else { return }
        let id = items[index].id
        cancelPreview()
        hovered = nil
        let target = Double(geometry(at: 1).rotation(bringing: index, near: rotation))
        if abs(target - Double(rotation)) > 0.001 {
            spin.settle(on: target)
            clock.start()
        }
        AppInteractionHaptics.shared.pressed()
        feel(.formed)
        searchFocused = false
        onCommit(id)
        close(committing: id, delay: abs(target - Double(rotation)) > 0.001 ? 0.14 : 0)
    }

    /// Closes without a choice: tap outside, swipe down, Escape.
    func dismiss() {
        guard phase == .open || phase == .pulling else { return }
        close(committing: nil)
    }

    private func close(committing id: String?, delay: Double = 0) {
        cancelPreview()
        searchFocused = false
        touch = nil
        dimLight()
        setHovered(nil, now: PageWheelClock.now)
        setPhase(.closing)
        if id == nil { onCancel() }
        if id == nil { AppInteractionHaptics.shared.dismissed() }
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard let self, !Task.isCancelled else { return }
            let duration = self.reduceMotion ? 0.16 : 0.5
            withAnimation(self.reduceMotion ? .easeOut(duration: duration) : .spring(response: 0.48, dampingFraction: 0.9)) {
                self.progress = 0
                self.stretch = 0
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.query = ""
            self.results = .empty
            self.expanded = [:]
            self.setPhase(.closed)
        }
    }

    // MARK: Search

    func submit() {
        let pending = isSearching && !query.isEmpty ? search?.search(query).best : nil
        guard let best = pending ?? results.best else {
            if query.isEmpty { commit(top) }
            return
        }
        open(best.target)
    }

    /// Opens a search result: a page on the wheel through the wheel, anything else (and pages the bar does not carry)
    /// through the app after the wheel closes.
    func open(_ target: NavigationSearchTarget) {
        if case .page(let destination) = target, let index = items.firstIndex(where: { $0.id == destination.rawValue }) {
            commit(index)
            return
        }
        let destination = target.destination
        if let index = items.firstIndex(where: { $0.id == destination.rawValue }) {
            let rotationTarget = Double(geometry(at: 1).rotation(bringing: index, near: rotation))
            spin.settle(on: rotationTarget)
            clock.start()
        }
        AppInteractionHaptics.shared.pressed()
        searchFocused = false
        onOpenTarget(target)
        close(committing: destination.rawValue, delay: 0.1)
    }

    func toggle(_ node: NavigationSearchNode) {
        if expanded[node.id] != nil {
            expanded[node.id] = nil
        } else {
            expanded[node.id] = search?.children(of: node.target) ?? []
        }
    }

    /// Builds the search index in the background ahead of the first pull.
    func warmUp() {
        search?.prepare(wheelPages: items.map(\.id))
    }

    private func queryChanged() {
        searchTask?.cancel()
        loadingTask?.cancel()
        if !expanded.isEmpty { expanded = [:] }
        guard let search else { return }
        let typed = query
        guard !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            if results != .empty { results = .empty }
            return
        }
        loadingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled, let self else { return }
            self.isSearching = true
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, let self, search.hasIndex else { return }
            let index = search.snapshot()
            let next = await Task.detached(priority: .userInitiated) { index.search(typed) }.value
            guard !Task.isCancelled, self.query == typed else { return }
            self.loadingTask?.cancel()
            self.results = next
            self.isSearching = false
            self.turn(toward: next)
        }
    }

    /// Turns the wheel to the page the best match lives on.
    private func turn(toward next: NavigationSearchResults) {
        guard let destination = next.destination,
              let index = items.firstIndex(where: { $0.id == destination.rawValue }), phase == .open else { return }
        let target = Double(geometry(at: 1).rotation(bringing: index, near: CGFloat(spin.target ?? Double(rotation))))
        if abs(target - (spin.target ?? Double(rotation))) > 0.001 {
            spin.settle(on: target)
            clock.start()
        }
    }

    // MARK: Motion

    private func place(at index: Int) {
        spin.place(Double(index))
        rotation = CGFloat(index)
        lastTop = items.isEmpty ? nil : PageWheelGeometry.wrap(index, count: items.count)
        previewed = items.indices.contains(index) ? items[index].id : nil
    }

    private func frame(time: TimeInterval, step: TimeInterval) {
        let moving = spin.step(by: step)
        publishRotation()
        if !moving {
            clock.stop()
            schedulePreview(top, dwell: restingPreviewDwell)
        }
    }

    private func publishRotation() {
        let next = CGFloat(spin.rotation)
        if rotation != next { rotation = next }
        let current = top
        guard current != lastTop else { return }
        lastTop = current
        tick()
        if spin.phase == .resting { schedulePreview(current, dwell: restingPreviewDwell) }
    }

    /// How long the wheel rests on a slice before the page behind follows it: longer while typing, so building a page
    /// never lands between two keystrokes.
    private var restingPreviewDwell: Double {
        query.isEmpty ? 0.16 : 0.45
    }

    private func setHovered(_ slice: Int?, now: TimeInterval) {
        guard slice != hovered else { return }
        hovered = slice
        holdAnchor = nil
        if slice != nil {
            tick()
            previewTask?.cancel()
        } else {
            schedulePreview(top, dwell: 0.25)
        }
    }

    /// The finger or the pointer is at `location`: moving more than a few points starts a new hold, and holding on a
    /// slice opens its page behind the wheel.
    private func trackHold(at location: CGPoint, now: TimeInterval) {
        if let anchor = holdAnchor, hypot(location.x - anchor.x, location.y - anchor.y) <= 14 { return }
        holdAnchor = location
        holdSince = now
        if let hovered { schedulePreview(hovered, dwell: 0.22) }
    }

    private func isHeld(now: TimeInterval) -> Bool {
        hovered != nil && holdAnchor != nil && now - holdSince >= 0.2
    }

    private func schedulePreview(_ index: Int, dwell: Double) {
        previewTask?.cancel()
        guard items.indices.contains(index), phase == .open || phase == .pulling else { return }
        let id = items[index].id
        guard id != previewed else { return }
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000))
            guard let self, !Task.isCancelled, self.phase == .open || self.phase == .pulling else { return }
            self.previewed = id
            self.onPreview(id)
        }
    }

    private func cancelPreview() {
        previewTask?.cancel()
        previewTask = nil
    }

    private func setPhase(_ next: Phase) {
        guard phase != next else { return }
        phase = next
        if next == .closed {
            previewed = nil
            clock.stop()
        }
        onPhaseChange(next)
    }

    private enum Feel { case crossing, formed }

    private func tick() {
        let now = PageWheelClock.now
        guard now - lastTick >= 0.025 else { return }
        lastTick = now
        AppInteractionHaptics.shared.selectionChanged()
        feel(.crossing)
    }

    private func feel(_ moment: Feel) {
        #if os(macOS)
        guard NSApp.isActive else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(moment == .crossing ? .alignment : .levelChange, performanceTime: .now)
        #endif
    }
}

/// Calls `tick` once per display frame while started.
@MainActor
final class PageWheelClock {
    var tick: (TimeInterval, TimeInterval) -> Void = { _, _ in }
    private var link: CADisplayLink?
    private var last: TimeInterval?

    nonisolated static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func start() {
        guard link == nil else { return }
        last = nil
        #if os(iOS)
        let next = CADisplayLink(target: Target(self), selector: #selector(Target.step(_:)))
        next.add(to: .main, forMode: .common)
        link = next
        #elseif os(macOS)
        guard let next = NSScreen.main?.displayLink(target: Target(self), selector: #selector(Target.step(_:))) else { return }
        next.add(to: .main, forMode: .common)
        link = next
        #endif
    }

    func stop() {
        link?.invalidate()
        link = nil
        last = nil
    }

    fileprivate func step(_ link: CADisplayLink) {
        let time = link.targetTimestamp
        let step = last.map { time - $0 } ?? 1.0 / 60
        last = time
        tick(time, max(0, step))
    }

    /// Holds the clock weakly so the display link, which retains its target, never keeps the wheel alive.
    private final class Target: NSObject {
        weak var clock: PageWheelClock?

        init(_ clock: PageWheelClock) {
            self.clock = clock
        }

        @objc func step(_ link: CADisplayLink) {
            MainActor.assumeIsolated {
                guard let clock else {
                    link.invalidate()
                    return
                }
                clock.step(link)
            }
        }
    }
}
