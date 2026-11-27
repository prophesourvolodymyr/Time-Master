import SwiftUI
#if os(iOS)
import UIKit
typealias TmaxMarqueeHostView = UIView
private typealias TmaxScrollContainer = UIScrollView
#else
import AppKit
typealias TmaxMarqueeHostView = NSView
private typealias TmaxScrollContainer = NSScrollView
#endif

extension Notification.Name {
    static let tmaxTouchBegan = Notification.Name("TmaxTouchBegan")
}

enum TmaxMarqueeKind {
    case row
    case title

    fileprivate var speed: Double { self == .title ? 30 : 40 }
    fileprivate var fade: CGFloat { self == .title ? 28 : 22 }
}

/// One line of text that is wider than the room it has. At rest it ends in a soft fade. It scrolls only while it is
/// the one the person is dealing with: under the finger or pointer, being dragged, or the one nearest the middle of
/// the visible page once scrolling has stopped. Everything else stays still, so a page of long names draws nothing.
struct TmaxMarquee<Content: View>: View {
    let text: String
    var kind: TmaxMarqueeKind = .row
    var forceActive = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            TmaxMarqueeScroller(kind: kind, text: text, forceActive: forceActive, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TmaxMarqueeText: View {
    let text: String
    let font: Font
    var color: Color?
    var kind: TmaxMarqueeKind = .row
    var forceActive = false
    var kerning: CGFloat = 0

    init(
        _ text: String,
        font: Font,
        color: Color? = nil,
        kind: TmaxMarqueeKind = .row,
        forceActive: Bool = false,
        kerning: CGFloat = 0
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.kind = kind
        self.forceActive = forceActive
        self.kerning = kerning
    }

    var body: some View {
        TmaxMarquee(text: text, kind: kind, forceActive: forceActive) {
            if let color {
                Text(text).font(font).kerning(kerning).foregroundStyle(color)
            } else {
                Text(text).font(font).kerning(kerning)
            }
        }
    }
}

/// A name that may take up to `lines` lines. When it needs more, or the room it is given is too short for the lines it
/// needs, it becomes one scrolling line instead of ending in three dots.
struct TmaxFittingTitle: View {
    let text: String
    let font: Font
    var color: Color?
    var lines = 2
    var forceActive = false
    var kerning: CGFloat = 0

    @State private var width: CGFloat = 0
    @State private var idealHeight: CGFloat = 0
    @State private var lineHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @State private var squeezed = false

    private var needsScrolling: Bool {
        width > 1 && lineHeight > 0 && idealHeight > 0
            && (squeezed || idealHeight > lineHeight * CGFloat(lines) + 2)
    }

    var body: some View {
        Group {
            if needsScrolling {
                TmaxMarqueeText(text, font: font, color: color, forceActive: forceActive, kerning: kerning)
            } else {
                wrapped
                    .background(TmaxHeightReader {
                        visibleHeight = $0
                        checkSqueeze()
                    })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TmaxWidthReader { width = $0 })
        .background(alignment: .topLeading) { measurement }
        .onChange(of: width) { _ in squeezed = false }
        .onChange(of: text) { _ in squeezed = false }
        .onChange(of: idealHeight) { _ in checkSqueeze() }
        .onChange(of: lineHeight) { _ in checkSqueeze() }
    }

    @ViewBuilder
    private var wrapped: some View {
        if let color {
            Text(text).font(font).kerning(kerning).foregroundStyle(color).lineLimit(lines)
        } else {
            Text(text).font(font).kerning(kerning).lineLimit(lines)
        }
    }

    private var measurement: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Text(text).font(font).kerning(kerning)
                    .frame(width: max(1, proxy.size.width), alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(TmaxHeightReader { idealHeight = $0 })
                Text("Ag").font(font).kerning(kerning)
                    .lineLimit(1)
                    .fixedSize()
                    .background(TmaxHeightReader { lineHeight = $0 })
            }
            .hidden()
            .accessibilityHidden(true)
        }
    }

    private func checkSqueeze() {
        guard !needsScrolling, width > 1, lineHeight > 0, idealHeight > 0, visibleHeight > 0 else { return }
        if visibleHeight + 1 < min(idealHeight, lineHeight * CGFloat(lines) + 2) { squeezed = true }
    }
}

private struct TmaxHeightReader: View {
    let update: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.height) }
                .onChange(of: proxy.size.height) { update($0) }
        }
    }
}

@MainActor
final class TmaxMarqueeHandle: ObservableObject {
    nonisolated let kind: TmaxMarqueeKind
    @Published fileprivate(set) var active = false
    fileprivate(set) var held = false
    var forced = false

    nonisolated init(kind: TmaxMarqueeKind) {
        self.kind = kind
    }

    fileprivate func set(active: Bool, held: Bool) {
        self.held = held
        if self.active != active { self.active = active }
    }
}

private struct TmaxMarqueeMotion: Equatable {
    var active: Bool
    var overflow: Int
    var text: String
    var reduceMotion: Bool
}

private struct TmaxMarqueeScroller<Content: View>: View {
    let kind: TmaxMarqueeKind
    let text: String
    let forceActive: Bool
    let content: () -> Content

    @StateObject private var handle: TmaxMarqueeHandle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    init(kind: TmaxMarqueeKind, text: String, forceActive: Bool, content: @escaping () -> Content) {
        self.kind = kind
        self.text = text
        self.forceActive = forceActive
        self.content = content
        _handle = StateObject(wrappedValue: TmaxMarqueeHandle(kind: kind))
    }

    private var overflow: CGFloat { max(0, textWidth - boxWidth) }
    private var fadeWidth: CGFloat { min(kind.fade, max(8, boxWidth * 0.22)) }

    var body: some View {
        TmaxClipLayout {
            content()
                .lineLimit(1)
                .fixedSize()
                .background(TmaxWidthReader { textWidth = $0 })
                .offset(x: offset)
        }
        .background(TmaxWidthReader { boxWidth = $0 })
        .background { TmaxMarqueeProbe(handle: handle).allowsHitTesting(false) }
        .clipped()
        .mask {
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: overflow > 1 ? fadeWidth : 0)
            }
        }
        .onAppear { handle.forced = forceActive }
        .onChange(of: forceActive) { value in
            handle.forced = value
            TmaxMarqueeCoordinator.shared.refresh(after: 0.02)
        }
        .task(id: TmaxMarqueeMotion(active: handle.active, overflow: Int(overflow), text: text, reduceMotion: reduceMotion)) {
            await run()
        }
    }

    private func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }

    private func run() async {
        let distance = overflow + fadeWidth
        guard overflow > 1, handle.active, !reduceMotion else {
            if offset != 0 { withAnimation(.easeOut(duration: 0.25)) { offset = 0 } }
            return
        }
        let travel = min(9, max(1.4, Double(distance) / kind.speed))
        var cycles = 0
        try? await Task.sleep(nanoseconds: nanoseconds(kind == .title ? 1.2 : 0.7))
        while !Task.isCancelled {
            withAnimation(.linear(duration: travel)) { offset = -distance }
            try? await Task.sleep(nanoseconds: nanoseconds(travel + 1.1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: min(travel, 2.2))) { offset = 0 }
            try? await Task.sleep(nanoseconds: nanoseconds(min(travel, 2.2) + (kind == .title ? 9 : 0.8)))
            cycles += 1
            if kind == .row, cycles >= 2, !handle.held { return }
        }
    }
}

/// Sizes itself to the width it is offered, whatever the width of its one child, and keeps the child at the leading
/// edge. A frame cannot do this: a flexible frame still grows to a child that ignores the offer.
private struct TmaxClipLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let natural = content.sizeThatFits(.unspecified)
        let width: CGFloat
        if let proposed = proposal.width, proposed.isFinite {
            width = proposed
        } else {
            width = natural.width
        }
        return CGSize(width: width, height: natural.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let content = subviews.first else { return }
        let natural = content.sizeThatFits(.unspecified)
        content.place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: natural.width, height: natural.height)
        )
    }
}

private struct TmaxWidthReader: View {
    let update: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.width) }
                .onChange(of: proxy.size.width) { update($0) }
        }
    }
}

#if os(iOS)
private struct TmaxMarqueeProbe: UIViewRepresentable {
    let handle: TmaxMarqueeHandle

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.handle = handle
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.handle = handle
    }

    static func dismantleUIView(_ view: ProbeView, coordinator: ()) {
        view.leave()
    }

    final class ProbeView: UIView {
        weak var handle: TmaxMarqueeHandle?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil, let handle {
                TmaxMarqueeCoordinator.shared.register(handle, view: self)
            } else {
                leave()
            }
        }

        func leave() {
            guard let handle else { return }
            TmaxMarqueeCoordinator.shared.unregister(handle)
        }
    }
}
#else
private struct TmaxMarqueeProbe: NSViewRepresentable {
    let handle: TmaxMarqueeHandle

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.handle = handle
        return view
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        view.handle = handle
    }

    static func dismantleNSView(_ view: ProbeView, coordinator: ()) {
        view.leave()
    }

    final class ProbeView: NSView {
        weak var handle: TmaxMarqueeHandle?
        private var area: NSTrackingArea?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, let handle {
                TmaxMarqueeCoordinator.shared.register(handle, view: self)
            } else {
                leave()
            }
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let next = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(next)
            area = next
        }

        override func mouseEntered(with event: NSEvent) {
            guard let handle else { return }
            TmaxMarqueeCoordinator.shared.pointerEntered(handle)
        }

        override func mouseExited(with event: NSEvent) {
            guard let handle else { return }
            TmaxMarqueeCoordinator.shared.pointerLeft(handle)
        }

        func leave() {
            guard let handle else { return }
            TmaxMarqueeCoordinator.shared.unregister(handle)
        }
    }
}
#endif

@MainActor
final class TmaxMarqueeCoordinator {
    static let shared = TmaxMarqueeCoordinator()

    private struct Entry {
        weak var handle: TmaxMarqueeHandle?
        weak var view: TmaxMarqueeHostView?
    }

    private final class Watcher {
        #if os(iOS)
        private var observation: NSKeyValueObservation?

        init(_ scroll: UIScrollView, onChange: @escaping () -> Void) {
            observation = scroll.observe(\.contentOffset, options: []) { _, _ in onChange() }
        }
        #else
        private var token: NSObjectProtocol?

        init(_ scroll: NSScrollView, onChange: @escaping () -> Void) {
            scroll.contentView.postsBoundsChangedNotifications = true
            token = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main
            ) { _ in onChange() }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
        #endif
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private var watchers: [ObjectIdentifier: Watcher] = [:]
    private var scrolling: Set<ObjectIdentifier> = []
    private var lastScroll: [ObjectIdentifier: TimeInterval] = [:]
    private var touched: ObjectIdentifier?
    private var refreshTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var touchTask: Task<Void, Never>?
    private var observing = false
    private var appActive = true

    private init() {}

    func register(_ handle: TmaxMarqueeHandle, view: TmaxMarqueeHostView) {
        entries[ObjectIdentifier(handle)] = Entry(handle: handle, view: view)
        observeGlobalsIfNeeded()
        let containers = Self.containers(of: view)
        if let outermost = containers.last {
            let scope = ObjectIdentifier(outermost)
            for container in containers {
                let key = ObjectIdentifier(container)
                if watchers[key] == nil {
                    watchers[key] = Watcher(container) { [weak self] in
                        MainActor.assumeIsolated { self?.scrollMoved(scope) }
                    }
                }
            }
        }
        #if os(iOS)
        EverTouchTracker.shared.install(in: view.window)
        #endif
        refresh(after: 0.5)
    }

    func unregister(_ handle: TmaxMarqueeHandle) {
        let id = ObjectIdentifier(handle)
        guard entries.removeValue(forKey: id) != nil else { return }
        if touched == id { touched = nil }
        handle.set(active: false, held: false)
        purgeWatchers()
    }

    func refresh(after delay: Double) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.recompute()
        }
    }

    func pointerEntered(_ handle: TmaxMarqueeHandle) {
        touch(ObjectIdentifier(handle), linger: nil)
    }

    func pointerLeft(_ handle: TmaxMarqueeHandle) {
        guard touched == ObjectIdentifier(handle) else { return }
        touched = nil
        refresh(after: 0.05)
    }

    private func touch(_ id: ObjectIdentifier, linger: Double?) {
        touched = id
        touchTask?.cancel()
        if let linger {
            touchTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(linger * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.touched = nil
                self?.recompute()
            }
        }
        recompute()
    }

    private func scrollMoved(_ scope: ObjectIdentifier) {
        if scrolling.insert(scope).inserted { recompute() }
        lastScroll[scope] = ProcessInfo.processInfo.systemUptime
        guard settleTask == nil else { return }
        settleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let settled = self.scrolling.filter { now - (self.lastScroll[$0] ?? 0) > 0.35 }
                if !settled.isEmpty {
                    self.scrolling.subtract(settled)
                    self.recompute()
                }
                if self.scrolling.isEmpty { break }
            }
            self?.settleTask = nil
        }
    }

    private func observeGlobalsIfNeeded() {
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        let wake: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(after: 0.05) }
        }
        #if os(iOS)
        center.addObserver(forName: .tmaxTouchBegan, object: nil, queue: .main) { [weak self] note in
            guard let x = note.userInfo?["x"] as? CGFloat, let y = note.userInfo?["y"] as? CGFloat else { return }
            MainActor.assumeIsolated { self?.touchBegan(at: CGPoint(x: x, y: y)) }
        }
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appActive = false; self?.recompute() }
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appActive = true; self?.refresh(after: 0.4) }
        }
        center.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main, using: wake)
        #else
        center.addObserver(forName: NSApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appActive = false; self?.recompute() }
        }
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appActive = true; self?.refresh(after: 0.4) }
        }
        #endif
        center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main, using: wake)
    }

    private func touchBegan(at point: CGPoint) {
        for (id, entry) in entries {
            guard let view = entry.view, view.window != nil, Self.isVisible(view) else { continue }
            if Self.windowFrame(of: view).insetBy(dx: -8, dy: -10).contains(point) {
                touch(id, linger: 2.4)
                return
            }
        }
    }

    private func purgeWatchers() {
        var live = Set<ObjectIdentifier>()
        for entry in entries.values {
            guard let view = entry.view else { continue }
            for container in Self.containers(of: view) { live.insert(ObjectIdentifier(container)) }
        }
        watchers = watchers.filter { live.contains($0.key) }
    }

    private func recompute() {
        entries = entries.filter { $0.value.handle != nil && $0.value.view != nil }
        let autoAllowed = appActive && !ProcessInfo.processInfo.isLowPowerModeEnabled && !Self.systemReducesMotion
        var groups: [ObjectIdentifier?: [(id: ObjectIdentifier, handle: TmaxMarqueeHandle, view: TmaxMarqueeHostView)]] = [:]
        for (id, entry) in entries {
            guard let handle = entry.handle, let view = entry.view, view.window != nil else { continue }
            groups[Self.containers(of: view).last.map(ObjectIdentifier.init), default: []].append((id, handle, view))
        }
        for (scope, members) in groups {
            let paused = scope.map { scrolling.contains($0) } ?? false
            let visible = members.filter { Self.isVisible($0.view) }
            var winner: ObjectIdentifier?
            if let forced = visible.first(where: { $0.handle.forced }) {
                winner = forced.id
            } else if !paused {
                if let touched, visible.contains(where: { $0.id == touched }) {
                    winner = touched
                } else if autoAllowed {
                    let rows = visible.filter { $0.handle.kind == .row }
                    if let first = rows.first {
                        let line = Self.readingLine(for: first.view)
                        winner = rows.min {
                            abs(Self.windowFrame(of: $0.view).midY - line) < abs(Self.windowFrame(of: $1.view).midY - line)
                        }?.id
                    }
                }
            }
            for member in members {
                let isVisible = visible.contains { $0.id == member.id }
                let held = member.handle.forced || member.id == touched
                switch member.handle.kind {
                case .title:
                    member.handle.set(active: isVisible && !paused && autoAllowed, held: held)
                case .row:
                    member.handle.set(active: member.id == winner, held: held)
                }
            }
        }
    }

    private static var systemReducesMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    private static func containers(of view: TmaxMarqueeHostView) -> [TmaxScrollContainer] {
        var result: [TmaxScrollContainer] = []
        var current = view.superview
        while let candidate = current {
            if let scroll = candidate as? TmaxScrollContainer { result.append(scroll) }
            current = candidate.superview
        }
        return result
    }

    private static func windowFrame(of view: TmaxMarqueeHostView) -> CGRect {
        view.convert(view.bounds, to: nil)
    }

    private static func windowBounds(of view: TmaxMarqueeHostView) -> CGRect {
        guard let window = view.window else { return .zero }
        #if os(iOS)
        return window.bounds
        #else
        return CGRect(origin: .zero, size: window.frame.size)
        #endif
    }

    private static func isHidden(_ view: TmaxMarqueeHostView) -> Bool {
        var current: TmaxMarqueeHostView? = view
        while let candidate = current {
            #if os(iOS)
            if candidate.isHidden || candidate.alpha < 0.01 { return true }
            #else
            if candidate.isHidden || candidate.alphaValue < 0.01 { return true }
            #endif
            current = candidate.superview
        }
        return false
    }

    private static func isVisible(_ view: TmaxMarqueeHostView) -> Bool {
        guard view.window != nil, !isHidden(view) else { return false }
        let frame = windowFrame(of: view)
        guard frame.width > 1, frame.height > 1, frame.intersects(windowBounds(of: view)) else { return false }
        for scroll in containers(of: view) {
            let area = scroll.convert(scroll.bounds, to: nil).insetBy(dx: -1, dy: -1)
            if !area.contains(frame) { return false }
        }
        return true
    }

    private static func readingLine(for view: TmaxMarqueeHostView) -> CGFloat {
        if let outermost = containers(of: view).last {
            let area = outermost.convert(outermost.bounds, to: nil)
            #if os(iOS)
            return area.minY + area.height * 0.42
            #else
            return area.maxY - area.height * 0.42
            #endif
        }
        return windowBounds(of: view).midY
    }
}
