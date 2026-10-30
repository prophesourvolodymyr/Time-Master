import SwiftUI

// MARK: - Keyboard navigation (macOS)
//
// A TUI-style keyboard layer: arrows move an accent focus ring between the things you can click, spatially.
// Self-contained (no app models; `KeyNavStyle.swift` is the only file naming the app's design tokens), so the
// folder can be copied into another SwiftUI app. Every modifier compiles to nothing on iOS.
//
// Targets come in two levels:
// - primary: the big squares the arrows move between (buttons, tab pills, cards, rows, tiles, widgets);
// - secondary: the small controls inside a primary one (a card's done circle, play button, link chips, menu).
//   Arrows never reach them directly: Space enters the primary, arrows then move between its secondaries,
//   Return presses one, Escape (or Space) leaves.
//
// Keys (only while no text field, list, menu, popover or sheet owns them):
//   ← ↑ → ↓            nearest target in that direction      ⇧ + arrow   three targets
//   Space               enter / leave the focused primary      Return      activate the focused target, or
//   Escape              leave the entered primary                          the one under a pointer that moved
//   ⌘← / ⌘→             previous / next page (`keyNavHost(onPageStep:)`)
// The engine follows the pointer: when nothing is focused, or the pointer moved since the last key, navigation
// starts from the target under the pointer (else the nearest one in the pressed direction). A click hides the ring.
// Return runs the target's `action`, or clicks its centre exactly like the pointer would (buttons, menus, links,
// tap gestures all work unchanged); a primary without an action that holds secondaries is entered instead. With
// nothing focused and a resting pointer, Return passes through (a sheet's default button still answers it).
// An Escape that nothing else used (no sheet closed, no search dismissed) lets go of a text field or picker, so the
// arrows navigate again. Scrolling is instant: a focused target scrolls into view, clear of `keyNavObstruction()`s.
//
// Wiring:
//   1. `.keyNavHost()` once at the root of every container: a window's content, a sheet, a popover, an in-window
//      overlay. The topmost container of a window owns the keys; a nested host takes over from its ancestors.
//      `.keyNavAccessoryHost()` joins content drawn outside the container's tree (window toolbar items).
//   2. Buttons (and menus) drawn by a navigation-aware `ButtonStyle` are targets on their own: the style calls
//      `keyNavButtonSurface(_:)` on its visible face (the app's shared styles do). For any other style use
//      `.keyNavButtonStyle(_:)`, or `.keyNavPlainButtonStyle()` instead of `.plain`; an unstyled button or menu
//      needs `.keyNavTarget(shape:)`. A target inside a primary target is automatically secondary.
//   3. Anything else clickable: `.keyNavTarget(role:shape:action:)`. Give primary containers an `action` when they
//      open something.
//   4. `.keyNavRole(_:)` sets the role of the targets below (`.secondary`, `.primary`, `.excluded` opts out);
//      `.keyNavObstruction()` marks chrome drawn over content (focus scrolls clear of it);
//      `.keyNavYield(_:)` hands every key to a view that handles its own (a focused media player).

/// How a view takes part in keyboard navigation.
enum KeyNavRole: Hashable {
    /// Primary, unless it sits inside a primary target: then secondary. The default for every button.
    case automatic
    /// A big square the arrows move between.
    case primary
    /// A small control inside a primary target, reached with Space (a secondary outside any primary is primary).
    case secondary
    /// Not a target, and nothing inside it is either (chrome such as a navigation bar).
    case excluded
}

/// The outline of a target; the focus ring follows it.
enum KeyNavShape: Hashable {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle

    static let standard = KeyNavShape.roundedRectangle(cornerRadius: 12)
}

private struct KeyNavRoleKey: EnvironmentKey {
    static var defaultValue: KeyNavRole { .automatic }
}

private struct KeyNavShapeKey: EnvironmentKey {
    static var defaultValue: KeyNavShape? { nil }
}

extension EnvironmentValues {
    /// Role of the next targets down the tree. Each target resets it to `.automatic` for what it contains
    /// (`.excluded` stays excluded all the way down).
    var keyNavRole: KeyNavRole {
        get { self[KeyNavRoleKey.self] }
        set { self[KeyNavRoleKey.self] = newValue }
    }

    /// Ring outline for the next targets down the tree that do not name one (a button style's own outline otherwise).
    var keyNavShape: KeyNavShape? {
        get { self[KeyNavShapeKey.self] }
        set { self[KeyNavShapeKey.self] = newValue }
    }
}

extension View {
    /// Root of a navigable container (window content, sheet, popover, in-window overlay). Apply once per container.
    /// `onPageStep(-1 / +1)` answers ⌘← / ⌘→ (only while this container owns the window's keys).
    @ViewBuilder
    func keyNavHost(onPageStep: ((Int) -> Void)? = nil) -> some View {
        #if os(macOS)
        modifier(KeyNavHostModifier(kind: .container, onPageStep: onPageStep))
        #else
        self
        #endif
    }

    /// Content drawn outside its container's view tree but in the same window (window toolbar items): its targets
    /// join the container's while that container owns the window's keys.
    @ViewBuilder
    func keyNavAccessoryHost() -> some View {
        #if os(macOS)
        modifier(KeyNavHostModifier(kind: .accessory, onPageStep: nil))
        #else
        self
        #endif
    }

    /// Makes this view a target. `role` `.automatic` takes the role set by `keyNavRole(_:)` above (by default:
    /// primary, or secondary inside a primary target). `action` runs on Return; without one Return enters a
    /// primary that holds secondaries, or clicks the target's centre. `id` (optional, need not be unique) brings
    /// the focus back to the target carrying it after a rebuild. Apply it before (inside) `.disabled(_:)`, so a
    /// disabled target is skipped.
    @ViewBuilder
    func keyNavTarget(
        id: AnyHashable? = nil,
        role: KeyNavRole = .automatic,
        shape: KeyNavShape = .standard,
        action: (() -> Void)? = nil
    ) -> some View {
        #if os(macOS)
        modifier(KeyNavTargetModifier(id: id, role: role, shape: shape, fallbackShape: shape, action: action))
        #else
        self
        #endif
    }

    /// Sets the role of the targets below (buttons included): `.secondary` for small controls laid over a card,
    /// `.primary` for buttons that must stay top-level inside a primary container, `.excluded` to opt out.
    @ViewBuilder
    func keyNavRole(_ role: KeyNavRole) -> some View {
        #if os(macOS)
        environment(\.keyNavRole, role)
        #else
        self
        #endif
    }

    /// Ring outline for the buttons below (their style's outline otherwise).
    @ViewBuilder
    func keyNavShape(_ shape: KeyNavShape) -> some View {
        #if os(macOS)
        environment(\.keyNavShape, shape)
        #else
        self
        #endif
    }

    /// Chrome drawn over scrolling content (a floating bar): a focused target is scrolled clear of it, and the
    /// pointer over it is not over the content underneath.
    @ViewBuilder
    func keyNavObstruction() -> some View {
        #if os(macOS)
        modifier(KeyNavObstructionModifier())
        #else
        self
        #endif
    }

    /// While `active`, the engine leaves every key (but ⌘← / ⌘→) to this view, e.g. a focused media player
    /// that handles Space and arrows itself.
    @ViewBuilder
    func keyNavYield(_ active: Bool = true) -> some View {
        #if os(macOS)
        modifier(KeyNavYieldModifier(active: active))
        #else
        self
        #endif
    }

    /// For `ButtonStyle` bodies: registers the drawn face as the button's target (Return clicks it, so the
    /// button's own action, menu or link runs). Put it on the visible face, before any enlarged hit area, so the
    /// ring hugs what you see. `.keyNavShape(_:)` from a call site overrides `shape`.
    @ViewBuilder
    func keyNavButtonSurface(_ shape: KeyNavShape) -> some View {
        #if os(macOS)
        modifier(KeyNavTargetModifier(id: nil, role: .automatic, shape: nil, fallbackShape: shape, action: nil))
        #else
        self
        #endif
    }

    /// `.buttonStyle(style)` plus a target around the whole button, for styles that do not call
    /// `keyNavButtonSurface(_:)` themselves. Works for menus too.
    @ViewBuilder
    func keyNavButtonStyle<S: ButtonStyle>(_ style: S, shape: KeyNavShape = .standard) -> some View {
        #if os(macOS)
        buttonStyle(style).modifier(KeyNavTargetModifier(id: nil, role: .automatic, shape: nil, fallbackShape: shape, action: nil))
        #else
        buttonStyle(style)
        #endif
    }

    /// `.buttonStyle(.plain)` plus a target around the whole button (or menu).
    @ViewBuilder
    func keyNavPlainButtonStyle(shape: KeyNavShape = .standard) -> some View {
        #if os(macOS)
        buttonStyle(.plain).modifier(KeyNavTargetModifier(id: nil, role: .automatic, shape: nil, fallbackShape: shape, action: nil))
        #else
        buttonStyle(.plain)
        #endif
    }
}
