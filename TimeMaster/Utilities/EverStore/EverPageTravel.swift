import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
enum EverViewSnapshot {
#if canImport(UIKit)
    static func image(of view: UIView, rect: CGRect? = nil, afterUpdates: Bool = false) -> CGImage? {
        let region = rect ?? view.bounds
        guard region.width > 0, region.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(view.window?.screen.scale ?? 2, 1.5)
        format.opaque = false
        return UIGraphicsImageRenderer(size: region.size, format: format).image { context in
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: afterUpdates)
            if !view.bounds.contains(region) {
                context.cgContext.saveGState()
                context.cgContext.addRect(region)
                context.cgContext.addRect(view.bounds)
                context.cgContext.clip(using: .evenOdd)
                view.layer.render(in: context.cgContext)
                context.cgContext.restoreGState()
            }
        }.cgImage
    }
#elseif os(macOS)
    static func image(of view: NSView, rect: CGRect? = nil, afterUpdates: Bool = false) -> CGImage? {
        let region = rect ?? view.bounds
        guard region.width > 0, region.height > 0 else { return nil }
        let started = CACurrentMediaTime()
        defer {
            let milliseconds = Int((CACurrentMediaTime() - started) * 1000)
            if milliseconds >= 60 { PerfLog.event("page snapshot took \(milliseconds) ms") }
        }
        if afterUpdates {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
        }
        let scale: CGFloat = 1
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(ceil(region.width * scale)),
            pixelsHigh: Int(ceil(region.height * scale)), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = region.size
        view.cacheDisplay(in: region, to: bitmap)
        return bitmap.cgImage
    }
#endif
}

private struct EverPageTravelActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everPageTravelActive: Bool {
        get { self[EverPageTravelActiveKey.self] }
        set { self[EverPageTravelActiveKey.self] = newValue }
    }
}

/// Which way a page travels, and the hook navigation stacks use to announce a change before it happens.
enum EverPageTravel {
    /// +1 when the page that comes in sits deeper in its stack than the one it replaces (a push, or one page swapped
    /// for another), -1 when it sits higher (a pop).
    static func stackDirection(from depth: Int, to next: Int) -> CGFloat {
        next < depth ? -1 : 1
    }

    /// +1 when the page that comes in sits later on the navigation bar, -1 when earlier, 0 when in the same place.
    static func barDirection(from order: Int, to next: Int) -> CGFloat {
        next == order ? 0 : (next > order ? 1 : -1)
    }

    /// A navigation stack of the main window is about to go from `depth` pages to `next` while the page that leaves is
    /// still on screen: on the Mac the page travel takes a picture of it now, and the page that comes glides in over
    /// it from the side the direction gives. Links, back buttons, Escape and code all move the stacks through here, so
    /// a pop travels exactly like a push, mirrored.
    @MainActor
    static func willNavigate(from depth: Int, to next: Int) {
#if os(macOS)
        EverPageGlide.current?.prepare(direction: stackDirection(from: depth, to: next))
#endif
    }

    /// A navigation stack of the main window is about to swap the page on top for a neighbour of it (Previous and
    /// Next): its depth stays, so the step gives the direction, +1 to the next page (in from the trailing side) and -1
    /// to the previous one. One announcement for the one change of the path, so the swap never glides twice.
    @MainActor
    static func willSwap(direction: CGFloat) {
#if os(macOS)
        EverPageGlide.current?.prepare(direction: direction)
#endif
    }
}

/// What the page travel follows inside one navigation bar page from one pass to the next: the depth of the navigation
/// stack on screen when one reports it (`everPageStack`, `everPushedPage`), and the window title.
struct EverPageRoute: Equatable {
    var depth: Int?
    var title: String
}

/// The titles visited inside one navigation bar page, newest last, for content that reports no stack: going to one of
/// them again is a step back.
struct EverPageTrail: Equatable {
    private(set) var titles: [String] = []

    init() {}

    init(_ route: EverPageRoute) {
        titles = [route.title]
    }

    /// The direction a change from `route` to `next` travels in, or nil when the page stays: a stack that keeps its
    /// depth (a renamed page, a title that arrives late), or a stack that starts or stops reporting.
    func direction(from route: EverPageRoute, to next: EverPageRoute) -> CGFloat? {
        if let depth = route.depth, let nextDepth = next.depth {
            return depth == nextDepth ? nil : EverPageTravel.stackDirection(from: depth, to: nextDepth)
        }
        guard route.depth == nil, next.depth == nil, route.title != next.title else { return nil }
        return titles.contains(next.title) ? -1 : 1
    }

    /// Records arriving at `route`: back to a title already visited drops everything after it.
    mutating func visit(_ route: EverPageRoute) {
        if let index = titles.firstIndex(of: route.title) {
            titles.removeSubrange((index + 1)...)
        } else {
            titles.append(route.title)
        }
    }
}

extension Binding where Value == NavigationPath {
    /// This path of a main-window stack, announcing every change made through it (a link, the stack's own back,
    /// `dismiss`) to the page travel just before it happens (Mac).
    @MainActor
    func everPageTravel() -> Binding<NavigationPath> {
#if os(macOS)
        announcingPageTravel { $0.count }
#else
        self
#endif
    }
}

extension Binding where Value: RandomAccessCollection & Equatable {
    /// This path of a main-window stack, announcing every change made through it to the page travel (Mac).
    @MainActor
    func everPageTravel() -> Binding<Value> {
#if os(macOS)
        announcingPageTravel { $0.count }
#else
        self
#endif
    }
}

extension Binding where Value == Bool {
    /// This `navigationDestination(isPresented:)` flag of a main-window stack, announcing the push or pop it makes to
    /// the page travel (Mac).
    @MainActor
    func everPageTravel() -> Binding<Bool> {
#if os(macOS)
        announcingPageTravel { $0 ? 1 : 0 }
#else
        self
#endif
    }
}

#if os(macOS)
private extension Binding where Value: Equatable {
    @MainActor
    func announcingPageTravel(depth: @escaping @Sendable (Value) -> Int) -> Binding<Value> {
        Binding(get: { wrappedValue }, set: { newValue, transaction in
            let current = wrappedValue
            if newValue != current { EverPageTravel.willNavigate(from: depth(current), to: depth(newValue)) }
            self.transaction(transaction).wrappedValue = newValue
        })
    }
}
#endif

extension View {
    /// The page travel of a navigation bar page's content (`scope`, the page at `order` on the bar). On the Mac a page
    /// pushed or popped in a stack, another bar page, or a change no stack announced slides in a short way from the
    /// side it comes from while fading in; Reduce Motion fades in place. No picture of the page that leaves is taken
    /// and nothing is blurred, so a page change costs no extra render pass. On iPhone the content rises in when the
    /// bar page changes.
    func everPageTravel(scope: String, order: Int) -> some View {
        modifier(EverPageTravelModifier(scope: scope, order: order))
    }
}

private struct EverPageTravelModifier: ViewModifier {
    let scope: String
    let order: Int
#if os(macOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var glide = EverPageGlide()
    @State private var title = ""
    @State private var depth: Int?
    @State private var settledScope: String
    @State private var settledOrder: Int
    @State private var settledRoute: EverPageRoute?
    @State private var trail = EverPageTrail()

    init(scope: String, order: Int) {
        self.scope = scope
        self.order = order
        _settledScope = State(initialValue: scope)
        _settledOrder = State(initialValue: order)
    }
#endif

    func body(content: Content) -> some View {
#if os(macOS)
        // A change the glide has not taken up yet already draws at its start in this pass, never a frame at rest first.
        let route = EverPageRoute(depth: depth, title: title)
        let switching = scope != settledScope && !glide.absorbsScope
        let moving = scope == settledScope && !glide.absorbsRoute
            ? settledRoute.flatMap { trail.direction(from: $0, to: route) } : nil
        let pending = switching || moving != nil
        let reach: EverPageGlideReach = pending ? (switching ? .still : (reduceMotion ? .fade : .nudge)) : glide.reach
        let direction = switching ? EverPageTravel.barDirection(from: settledOrder, to: order) : (moving ?? glide.direction)
        let progress = pending ? 0 : glide.progress
        return content
            .environment(\.everPageTravelActive, true)
            .modifier(EverPageGlideEffect(
                progress: progress, direction: direction, travel: reach.travel, startOpacity: reach.startOpacity
            ))
            .background(EverPageGlideAnchor(glide: glide).allowsHitTesting(false).accessibilityHidden(true))
            .onPreferenceChange(MacWindowTitlePreferenceKey.self) { title = $0 ?? "" }
            .onPreferenceChange(EverPageBackStackKey.self) { depth = $0?.depth }
            .onChange(of: scope) { follow() }
            .onChange(of: order) { if scope == settledScope { settledOrder = order } }
            .onChange(of: route) { follow() }
            .onChange(of: glide.serial) { glide.begin() }
#else
        content.everPageOpening(when: scope, animated: false)
#endif
    }

#if os(macOS)
    /// Settles on the bar page and route on screen, and glides when they changed without an announcement.
    private func follow() {
        let route = EverPageRoute(depth: depth, title: title)
        if scope != settledScope {
            let direction = EverPageTravel.barDirection(from: settledOrder, to: order)
            settledScope = scope
            settledOrder = order
            settledRoute = route
            trail = EverPageTrail(route)
            if glide.absorbsScope {
                glide.takeScope()
            } else {
                glide.travel(direction: direction, switching: true, reduceMotion: reduceMotion)
            }
            return
        }
        guard route != settledRoute else { return }
        glide.takeScope()
        guard let previous = settledRoute, !glide.isSwitching else {
            settledRoute = route
            trail = EverPageTrail(route)
            return
        }
        settledRoute = route
        let direction = glide.absorbsRoute ? nil : trail.direction(from: previous, to: route)
        trail.visit(route)
        if let direction { glide.travel(direction: direction, switching: false, reduceMotion: reduceMotion) }
    }
#endif
}

#if os(macOS)
/// How far a gliding page travels.
enum EverPageGlideReach: Equatable {
    /// A short way, fading in.
    case nudge
    /// In place, fading in (Reduce Motion).
    case fade
    /// In place at once: another bar page takes the window with no slide and no fade.
    case still

    var travel: CGFloat {
        switch self {
        case .nudge: EverPageMotion.nudge
        case .fade, .still: 0
        }
    }

    var startOpacity: CGFloat {
        switch self {
        case .nudge: 0.35
        case .fade: 0
        case .still: 1
        }
    }
}

/// Runs the page travel of the main window's pages: `prepare` before a stack changes, `travel` for a change nothing
/// announced, `begin` once the new page has been laid out at its start.
@MainActor
final class EverPageGlide: ObservableObject {
    enum Phase {
        case idle
        /// A stack announced the change: the route change that follows belongs to this glide.
        case prepared
        /// Another bar page came in; its stack and title report in a pass later.
        case switching
        case travelling
    }

    /// The glide of the window the stacks live in.
    private(set) static weak var current: EverPageGlide?

    @Published private(set) var progress: CGFloat = 1
    @Published private(set) var direction: CGFloat = 0
    @Published private(set) var reach = EverPageGlideReach.nudge
    /// Counts glides: the page starts the animation when it changes, after laying the new page out at its start.
    @Published private(set) var serial = 0
    @Published private(set) var phase = Phase.idle
    /// A prepared glide takes up the bar page change that comes with it (a link to a page of another bar page), once.
    @Published private(set) var awaitsScope = false

    var absorbsScope: Bool { phase == .prepared && awaitsScope }
    var absorbsRoute: Bool { phase == .prepared || phase == .switching }
    var isSwitching: Bool { phase == .switching }

    weak var anchor: NSView? {
        didSet {
            if anchor != nil {
                Self.current = self
            } else if Self.current === self {
                Self.current = nil
            }
        }
    }

    private var preparedAt: CFTimeInterval = 0
    private var settling: Task<Void, Never>?

    /// Call just before a stack changes. Escape and the stack's own hook can both report one change; the second
    /// report is the same glide.
    func prepare(direction: CGFloat) {
        let now = CACurrentMediaTime()
        guard now - preparedAt > 0.05 else { return }
        preparedAt = now
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        start(direction: direction, reach: reduceMotion ? .fade : .nudge, phase: .prepared)
    }

    func travel(direction: CGFloat, switching: Bool, reduceMotion: Bool) {
        start(direction: direction, reach: switching ? .still : (reduceMotion ? .fade : .nudge), phase: switching ? .switching : .travelling)
    }

    func begin() {
        withAnimation(reach == .fade ? .easeOut(duration: 0.15) : EverPageMotion.curve) { progress = 1 }
    }

    /// The prepared change has reached the page: a bar page change after it is the user's own.
    func takeScope() {
        if awaitsScope { awaitsScope = false }
    }

    private func start(direction: CGFloat, reach: EverPageGlideReach, phase: Phase) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.reach = reach
            self.direction = direction
            self.phase = phase
            awaitsScope = phase == .prepared
            progress = 0
            serial &+= 1
        }
        settling?.cancel()
        settling = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((EverPageMotion.duration + 0.12) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    /// Lands a page whose glide never began, once the glide has had time to run.
    private func settle() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            phase = .idle
            awaitsScope = false
            progress = 1
        }
    }
}

/// A page in flight: slid in a short way from one side while fading in, settling as `progress` reaches 1.
private struct EverPageGlideEffect: ViewModifier, Animatable {
    var progress: CGFloat
    var direction: CGFloat
    var travel: CGFloat
    var startOpacity: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let rest = 1 - progress
        content
            .offset(x: direction * travel * rest)
            .opacity(startOpacity + (1 - startOpacity) * progress)
    }
}

/// An empty view with the frame of the bar page's content, so the glide knows which window it belongs to.
private struct EverPageGlideAnchor: NSViewRepresentable {
    let glide: EverPageGlide

    func makeNSView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.glide = glide
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: ()) {
        view.glide = nil
    }

    final class AnchorView: NSView {
        weak var glide: EverPageGlide? {
            willSet { if newValue !== glide, glide?.anchor === self { glide?.anchor = nil } }
            didSet { attach() }
        }

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        private func attach() {
            guard let glide else { return }
            if window != nil {
                if glide.anchor !== self { glide.anchor = self }
            } else if glide.anchor === self {
                glide.anchor = nil
            }
        }
    }
}
#endif
