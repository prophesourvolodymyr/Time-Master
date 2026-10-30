#if os(macOS)
import AppKit
import SwiftUI

/// The ring a target shows: none, focused (full ring) or entered (dim ring while the user is inside it).
enum KeyNavRing: Equatable {
    case none, focused, entered
}

/// One target's ring, published on its own so only that target redraws when the focus moves.
@MainActor
final class KeyNavRingModel: ObservableObject {
    @Published var ring: KeyNavRing = .none
}

/// A target's frame plus the visible areas of the scroll views around it (nearest vertical and horizontal ones),
/// all in SwiftUI's `.global` space. The viewports tell what is on screen and which scroll view to move.
struct KeyNavPlacement: Equatable {
    var frame: CGRect = .zero
    var verticalViewport: CGRect?
    var horizontalViewport: CGRect?

    init() {}

    init(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: CoordinateSpace.global)
        // Local sizes are before any scale effect; global ones after.
        let scale = proxy.size.width > 0 ? frame.width / proxy.size.width : 1
        func viewport(_ axis: Axis) -> CGRect? {
            guard let local = proxy.bounds(of: .scrollView(axis: axis)) else { return nil }
            return CGRect(
                x: frame.minX + local.minX * scale,
                y: frame.minY + local.minY * scale,
                width: local.width * scale,
                height: local.height * scale
            )
        }
        self.frame = frame
        verticalViewport = viewport(.vertical)
        horizontalViewport = viewport(.horizontal)
    }

    func offsetBy(_ offset: CGVector) -> KeyNavPlacement {
        var moved = self
        moved.frame = frame.offsetBy(dx: offset.dx, dy: offset.dy)
        moved.verticalViewport = verticalViewport?.offsetBy(dx: offset.dx, dy: offset.dy)
        moved.horizontalViewport = horizontalViewport?.offsetBy(dx: offset.dx, dy: offset.dy)
        return moved
    }

    /// The viewports to scroll, horizontal first (a strip usually sits inside a vertical page).
    var viewports: [CGRect] {
        [horizontalViewport, verticalViewport].compactMap { $0 }
    }

    /// Shown through its scroll views and the window, with its visible centre clear of `obstructions`.
    func isVisible(in bounds: CGRect, obstructions: [CGRect]) -> Bool {
        let visible = viewports.reduce(bounds) { $0.intersection($1) }
        let shown = frame.intersection(visible)
        guard !shown.isNull, shown.width >= 1, shown.height >= 1 else { return false }
        let centre = CGPoint(x: shown.midX, y: shown.midY)
        return !obstructions.contains { $0.contains(centre) }
    }

    /// Scrolls inside one of `other`'s scroll views (the same viewport on either axis).
    func sharesScrollView(with other: KeyNavPlacement) -> Bool {
        func same(_ a: CGRect?, _ b: CGRect?) -> Bool {
            guard let a, let b else { return false }
            return abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1
                && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
        }
        return same(verticalViewport, other.verticalViewport) || same(horizontalViewport, other.horizontalViewport)
    }
}

/// A registered target, owned by its view (`KeyNavTargetModifier`). Plain storage: frame updates during
/// scrolling never invalidate a view.
@MainActor
final class KeyNavTargetBox: ObservableObject {
    let ringModel = KeyNavRingModel()
    /// Registry key, unique per target; the secondaries inside a primary name it by this key.
    let key = AnyHashable(UUID())
    /// The call site's `id:`: after a rebuild, focus returns to the target that carries the same id.
    var explicitID: AnyHashable?
    /// The key of the primary target this one sits in (`nil` = primary).
    var parentKey: AnyHashable?
    var isEnabled = true
    /// Runs on Return; `nil` clicks the target's centre.
    var action: (() -> Void)?
    /// Where the target is, in SwiftUI's `.global` space; `nil` until measured.
    var placement: KeyNavPlacement?
    /// Between the view's `onAppear` and `onDisappear`.
    var isOnScreen = false
    private(set) weak var controller: KeyNavController?

    /// Registers with `controller` (or unregisters with `nil`).
    func attach(to controller: KeyNavController?) {
        guard controller !== self.controller else { return }
        self.controller?.remove(self)
        self.controller = controller
        controller?.add(self)
    }

    func setRing(_ ring: KeyNavRing) {
        if ringModel.ring != ring { ringModel.ring = ring }
    }
}

/// The registry of one container (`keyNavHost()`) or accessory (`keyNavAccessoryHost()`): its targets,
/// obstructions and yields, plus the window it lives in. Routing happens in `KeyNavRouter`, per window.
@MainActor
final class KeyNavController: ObservableObject {
    enum Kind {
        case container, accessory
    }

    var kind = Kind.container
    /// The host this one sits in (from the environment); a container covers its ancestors.
    weak var parent: KeyNavController?
    var onPageStep: ((Int) -> Void)?

    private(set) var targets: [AnyHashable: KeyNavTargetBox] = [:]
    private(set) var obstructions: [UUID: CGRect] = [:]
    private(set) var yields: Set<UUID> = []
    private(set) weak var window: NSWindow?
    /// The AppKit view covering the host: where the host's `.global` frame sits in the window.
    private(set) weak var anchor: NSView?
    /// The host's own frame in SwiftUI's `.global` space.
    var hostFrame: CGRect?
    /// Attach order inside the window; the latest uncovered container owns the keys.
    var serial = 0

    func add(_ box: KeyNavTargetBox) {
        targets[box.key] = box
    }

    func remove(_ box: KeyNavTargetBox) {
        guard targets[box.key] === box else { return }
        targets[box.key] = nil
        KeyNavRouter.router(for: window)?.targetDidDisappear(box, in: self)
    }

    func setObstruction(_ token: UUID, frame: CGRect?) {
        obstructions[token] = frame
    }

    func setYield(_ token: UUID, active: Bool) {
        if active {
            yields.insert(token)
        } else {
            yields.remove(token)
        }
    }

    /// Called by the host's anchor view when it moves between windows.
    func attach(window: NSWindow?, anchor: NSView?) {
        if let old = self.window, old !== window {
            KeyNavRouter.router(for: old)?.detach(self)
        }
        self.window = window
        self.anchor = anchor
        if let window {
            KeyNavRouter.attach(self, to: window)
        }
    }

    /// Maps this host's `.global` frames into the window space (top-left origin): the anchor's AppKit frame
    /// minus the host's SwiftUI frame. Calibrating per host keeps it right whatever `.global` is relative to.
    func windowOffset(in space: KeyNavWindowSpace) -> CGVector? {
        guard let anchor, anchor.window === space.window else { return nil }
        let anchored = space.unified(anchor.bounds, from: anchor)
        guard let hostFrame else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: anchored.minX - hostFrame.minX, dy: anchored.minY - hostFrame.minY)
    }

    func isDescendant(of other: KeyNavController) -> Bool {
        var current = parent
        while let host = current {
            if host === other { return true }
            current = host.parent
        }
        return false
    }
}

private struct KeyNavControllerKey: EnvironmentKey {
    static var defaultValue: KeyNavController? { nil }
}

private struct KeyNavParentKey: EnvironmentKey {
    static var defaultValue: AnyHashable? { nil }
}

extension EnvironmentValues {
    /// The registry targets below register with (set by the nearest host).
    var keyNavController: KeyNavController? {
        get { self[KeyNavControllerKey.self] }
        set { self[KeyNavControllerKey.self] = newValue }
    }

    /// The primary target the views below sit in.
    var keyNavParent: AnyHashable? {
        get { self[KeyNavParentKey.self] }
        set { self[KeyNavParentKey.self] = newValue }
    }
}

#endif
