import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The navigation stack on screen as the Mac's Escape key and page travel see it: how many pages sit above its root
/// and how to step back one, exactly like the page's back button. Stacks report it up the view tree with
/// `everPageStack(depth:pop:)` (a stack with a path) or `everPushedPage()` (a page pushed without a path entry).
struct EverPageBackStack: Equatable {
    /// Pages above the root.
    var depth: Int
    /// Who answers `pop`; a new owner is a new answer, so the window takes it up.
    var owner: UUID?
    /// Steps back one page; nil at the root.
    var pop: (() -> Void)?

    var canPop: Bool { depth > 0 && pop != nil }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.depth == rhs.depth && lhs.owner == rhs.owner && lhs.canPop == rhs.canPop
    }

    /// A stack whose path holds `depth` pages, around what its pages report: a stack inside one of them steps back
    /// first.
    static func stack(owner: UUID, depth: Int, pop: @escaping () -> Void, around inner: Self?) -> Self {
        let total = depth + (inner?.depth ?? 0)
        if let inner, inner.canPop { return Self(depth: total, owner: inner.owner, pop: inner.pop) }
        return Self(depth: total, owner: owner, pop: depth > 0 ? pop : nil)
    }

    /// A page pushed without a path entry, `depth` pages above its stack's root, around what it reports itself.
    static func page(owner: UUID, depth: Int, pop: @escaping () -> Void, around inner: Self?) -> Self {
        if let inner, inner.canPop { return Self(depth: depth + inner.depth, owner: inner.owner, pop: inner.pop) }
        return Self(depth: depth, owner: owner, pop: pop)
    }

    /// Two reports side by side, as a stack shows its pages one after another: the deepest one is the page on top and
    /// steps back (the later one when they are as deep).
    static func merging(_ earlier: Self?, _ later: Self?) -> Self? {
        guard let earlier else { return later }
        guard let later else { return earlier }
        return later.depth >= earlier.depth ? later : earlier
    }
}

struct EverPageBackStackKey: PreferenceKey {
    static var defaultValue: EverPageBackStack? { nil }

    static func reduce(value: inout EverPageBackStack?, nextValue: () -> EverPageBackStack?) {
        value = EverPageBackStack.merging(value, nextValue())
    }
}

/// Something more open than the page that answers Escape before it: an edit mode, a panel over the page.
struct EverEscapeClaim: Equatable {
    let id: String
    var action: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct EverEscapeClaimKey: PreferenceKey {
    static var defaultValue: EverEscapeClaim? { nil }

    static func reduce(value: inout EverEscapeClaim?, nextValue: () -> EverEscapeClaim?) {
        if let next = nextValue() { value = next }
    }
}

/// What Escape does in the Mac's main window once nothing more open has taken it.
enum EverEscapeOutcome: Equatable {
    /// The key goes on to the content, which answers Escape itself.
    case passThrough
    /// Nothing to step back from: the key stops here, without a beep.
    case swallow
    /// The claim runs.
    case claim
    /// The stack steps back one page.
    case pop
}

/// The rules of the Mac's Escape key for pages, free of AppKit so they can be tested anywhere; `everEscapeStepsBack`
/// feeds them the real window.
enum EverEscapeRoute {
    /// Escape is the window's to consider at all: a plain key press in the key window, with no sheet, alert, menu,
    /// popover, modal or drag in progress, and a first responder that does not use Escape itself (a text field or text
    /// view, a player, a map, a web view).
    static func isCandidate(plainKey: Bool, windowIsKey: Bool, windowIsBusy: Bool, responderUsesEscape: Bool) -> Bool {
        plainKey && windowIsKey && !windowIsBusy && !responderUsesEscape
    }

    /// What Escape does after keyboard navigation and the window's key equivalents (a viewer's or a popup's close
    /// button) declined it. `holds` is true while the content presents something immersive over its page
    /// (`slotNavigationInteractionDisabled`); `quietAtRoot` swallows the key where no stack reports in.
    static func outcome(claim: EverEscapeClaim?, holds: Bool, stack: EverPageBackStack?, quietAtRoot: Bool) -> EverEscapeOutcome {
        if claim != nil { return .claim }
        if holds { return .passThrough }
        if let stack { return stack.canPop ? .pop : .swallow }
        return quietAtRoot ? .swallow : .passThrough
    }
}

extension View {
    /// Reports the navigation stack this is applied to, whose path holds `depth` pages: on the Mac, Escape steps back
    /// with `pop` when nothing more open takes the key, and the page travel tells a push from a pop.
    @ViewBuilder
    func everPageStack(depth: Int, pop: @escaping () -> Void) -> some View {
#if os(macOS)
        modifier(EverPageStackModifier(depth: depth, pop: pop))
#else
        self
#endif
    }

    /// Reports a page pushed without a path entry (a link with a destination view, `navigationDestination(isPresented:)`)
    /// as one page of its stack: on the Mac, Escape dismisses it like its back button.
    @ViewBuilder
    func everPushedPage() -> some View {
#if os(macOS)
        modifier(EverPushedPageModifier())
#else
        self
#endif
    }

    /// While `isActive`, Escape in the Mac window runs `action` instead of stepping back a page.
    @ViewBuilder
    func everEscapeClaim(_ id: String, isActive: Bool, perform action: @escaping () -> Void) -> some View {
#if os(macOS)
        transformPreference(EverEscapeClaimKey.self) { claim in
            if isActive { claim = EverEscapeClaim(id: id, action: action) }
        }
#else
        self
#endif
    }

    /// The Mac window's Escape key steps back a page of the stack on screen, like its back button, once nothing more
    /// open takes it: a sheet or alert, a text field, keyboard navigation inside a group, a close button that answers
    /// Escape, a claim (`everEscapeClaim`) or something immersive over the page. Where no stack reports in,
    /// `quietAtRoot` swallows the key (no beep); false leaves it to content that answers Escape itself.
    @ViewBuilder
    func everEscapeStepsBack(quietAtRoot: Bool) -> some View {
#if os(macOS)
        modifier(EverEscapeStepsBackModifier(quietAtRoot: quietAtRoot))
#else
        self
#endif
    }
}

#if os(macOS)
private struct EverPageStackModifier: ViewModifier {
    let depth: Int
    let pop: () -> Void
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        let owner = owner
        let depth = depth
        let pop = pop
        return content.transformPreference(EverPageBackStackKey.self) { stack in
            stack = .stack(owner: owner, depth: depth, pop: pop, around: stack)
        }
    }
}

private struct EverPushedPageDepthKey: EnvironmentKey {
    static let defaultValue = 0
}

private extension EnvironmentValues {
    /// How many pages above its stack's root the page around this view sits; a link here pushes one more.
    var everPushedPageDepth: Int {
        get { self[EverPushedPageDepthKey.self] }
        set { self[EverPushedPageDepthKey.self] = newValue }
    }
}

private struct EverPushedPageModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.everPushedPageDepth) private var parentDepth
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        let owner = owner
        let dismiss = dismiss
        let depth = parentDepth + 1
        return content
            .environment(\.everPushedPageDepth, depth)
            .transformPreference(EverPageBackStackKey.self) { stack in
                stack = .page(owner: owner, depth: depth, pop: { dismiss() }, around: stack)
            }
    }
}

/// What the window's content last reported; read by the key monitor, never drawn.
@MainActor
private final class EverEscapeCenter {
    var stack: EverPageBackStack?
    var claim: EverEscapeClaim?
    var holds = false
}

private struct EverEscapeStepsBackModifier: ViewModifier {
    let quietAtRoot: Bool
    @State private var center = EverEscapeCenter()

    func body(content: Content) -> some View {
        let center = center
        return content
            .onPreferenceChange(EverPageBackStackKey.self) { center.stack = $0 }
            .onPreferenceChange(EverEscapeClaimKey.self) { center.claim = $0 }
            .onPreferenceChange(SlotNavigationInteractionDisabledPreferenceKey.self) { center.holds = $0 }
            .background(
                EverEscapeCatcher(center: center, quietAtRoot: quietAtRoot)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
    }
}

/// Watches Escape in its own window. Local monitors see a key before the window does, so this one asks everything
/// that could answer Escape first (keyboard navigation, the window's key equivalents) and only then steps back.
private struct EverEscapeCatcher: NSViewRepresentable {
    let center: EverEscapeCenter
    let quietAtRoot: Bool

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.center = center
        view.quietAtRoot = quietAtRoot
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.center = center
        view.quietAtRoot = quietAtRoot
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class CatcherView: NSView {
        var center: EverEscapeCenter?
        var quietAtRoot = true
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let taken = MainActor.assumeIsolated { self?.handle(event) ?? false }
                return taken ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard event.keyCode == KeyNavKey.escape, let window, event.window === window, let center else { return false }
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard EverEscapeRoute.isCandidate(
                plainKey: modifiers.isEmpty,
                windowIsKey: window.isKeyWindow,
                windowIsBusy: Self.isBusy(window),
                responderUsesEscape: Self.usesEscape(window.firstResponder)
            ) else { return false }
            if event.isARepeat { return true }
            if KeyNavRouter.router(for: window)?.handleKey(event) == true { return true }
            if window.performKeyEquivalent(with: event) { return true }
            switch EverEscapeRoute.outcome(claim: center.claim, holds: center.holds, stack: center.stack, quietAtRoot: quietAtRoot) {
            case .passThrough:
                return false
            case .swallow:
                return true
            case .claim:
                center.claim?.action()
                return true
            case .pop:
                guard let stack = center.stack, let pop = stack.pop else { return true }
                EverPageTravel.willNavigate(from: stack.depth, to: stack.depth - 1)
                pop()
                return true
            }
        }

        /// A menu, sheet, alert, modal, popover or drag owns the keys for now.
        private static func isBusy(_ window: NSWindow) -> Bool {
            if KeyNavMonitor.shared.isTrackingMenu || window.attachedSheet != nil || NSEvent.pressedMouseButtons != 0 {
                return true
            }
            if let modal = NSApp.modalWindow, modal !== window { return true }
            return NSApp.windows.contains { other in
                other !== window && other.isVisible && NSStringFromClass(type(of: other)).contains("Popover")
            }
        }

        /// Text fields and text views clear, end editing or complete with Escape; players, maps and web views use it too.
        private static func usesEscape(_ responder: NSResponder?) -> Bool {
            if responder is NSText || responder is NSTextField { return true }
            var view = responder as? NSView
            while let current = view {
                let name = NSStringFromClass(type(of: current))
                if KeyNavPolicy.keyOwningClassNames.contains(where: { name.contains($0) }) { return true }
                view = current.superview
            }
            return false
        }
    }
}
#endif
