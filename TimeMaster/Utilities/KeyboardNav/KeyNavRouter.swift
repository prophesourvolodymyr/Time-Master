#if os(macOS)
import AppKit

/// Routes one window's keys to the container that owns them and keeps that window's focus.
///
/// The owner is the most recently attached container host of the window that no other attached container sits
/// inside (an overlay or a nested host takes over from its ancestors); accessory hosts whose parent is that
/// container join it. Frames from every host are mapped into one window space (top-left origin) per key press,
/// so nothing is computed while the user scrolls or types.
@MainActor
final class KeyNavRouter {
    private struct NodeID: Hashable {
        let host: ObjectIdentifier
        let id: AnyHashable
    }

    private struct Snapshot {
        var nodes: [KeyNavNode<NodeID>] = []
        var boxes: [NodeID: KeyNavTargetBox] = [:]
        var obstructions: [CGRect] = []
        var container: KeyNavController?
        var yields = false
        /// Targets showing on screen (not scrolled away, clipped or under an obstruction).
        var visible: Set<NodeID> = []
        /// Each target's frame and scroll viewports, in window space.
        var placements: [NodeID: KeyNavPlacement] = [:]
    }

    private final class WeakHost {
        weak var value: KeyNavController?
        init(_ value: KeyNavController) { self.value = value }
    }

    private final class WeakBox {
        weak var value: KeyNavTargetBox?
        init(_ value: KeyNavTargetBox) { self.value = value }
    }

    /// The pointer must move further than this between two keys to take the lead again.
    private static let pointerSlop: CGFloat = 3
    private static var routers: [ObjectIdentifier: KeyNavRouter] = [:]
    private static var attachCount = 0

    private weak var window: NSWindow?
    private var hosts: [WeakHost] = []
    private var focus = KeyNavFocus<NodeID>.none
    private var lit: [WeakBox] = []
    private var lastPointer: CGPoint?
    /// The `id:` of a focused target that went away; a target carrying it in the same host takes the focus back.
    private var restore: (host: ObjectIdentifier, id: AnyHashable)?

    private init(window: NSWindow) {
        self.window = window
    }

    // MARK: Hosts

    static func attach(_ host: KeyNavController, to window: NSWindow) {
        KeyNavMonitor.shared.installIfNeeded()
        routers = routers.filter { $0.value.window != nil }
        let key = ObjectIdentifier(window)
        let router: KeyNavRouter
        if let existing = routers[key], existing.window === window {
            router = existing
        } else {
            router = KeyNavRouter(window: window)
            routers[key] = router
        }
        attachCount += 1
        host.serial = attachCount
        router.hosts.removeAll { $0.value == nil || $0.value === host }
        router.hosts.append(WeakHost(host))
        if host.kind == .container {
            // A container that just appeared (a sheet under a resting pointer) does not count as "pointed at".
            router.lastPointer = KeyNavWindowSpace(window: window).pointer
        }
    }

    static func router(for window: NSWindow?) -> KeyNavRouter? {
        guard let window, let router = routers[ObjectIdentifier(window)], router.window === window else { return nil }
        return router
    }

    func detach(_ host: KeyNavController) {
        hosts.removeAll { $0.value == nil || $0.value === host }
        let key = ObjectIdentifier(host)
        if focus.focused?.host == key || focus.entered?.host == key {
            reset()
        }
    }

    func targetDidDisappear(_ box: KeyNavTargetBox, in host: KeyNavController) {
        box.setRing(.none)
        let node = NodeID(host: ObjectIdentifier(host), id: box.key)
        guard focus.entered == node || focus.focused == node else { return }
        let leaving = focus.entered == node
        if leaving {
            reset()
        } else {
            focus.focused = nil
        }
        restore = box.explicitID.map { (host: ObjectIdentifier(host), id: $0) }
    }

    /// After a rebuild: the target carrying the `id:` of the focused one that went away takes the focus back.
    private func restoreFocus(_ snapshot: Snapshot) {
        guard let pending = restore else { return }
        restore = nil
        guard focus.focused == nil, let node = snapshot.nodes.first(where: { node in
            node.id.host == pending.host && snapshot.boxes[node.id]?.explicitID == pending.id
        }) else { return }
        let entered = node.parent.flatMap { parent in snapshot.nodes.contains { $0.id == parent } ? parent : nil }
        focus = KeyNavFocus(focused: node.id, entered: entered)
    }

    /// A real click: the pointer leads again and the ring hides until the next key.
    func pointerDidClick() {
        restore = nil
        reset()
    }

    // MARK: Keys

    /// Handles a key-down in this router's window; `false` passes it on untouched.
    func handleKey(_ event: NSEvent) -> Bool {
        guard KeyNavKey.isNavigationKey(event.keyCode), let window, window.isKeyWindow,
              KeyNavPolicy.keysAreFree(in: window), let snapshot = snapshot(in: window) else { return false }
        restoreFocus(snapshot)
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let hasTargets = !snapshot.nodes.isEmpty && !snapshot.yields

        if let direction = KeyNavKey.direction(event.keyCode) {
            if flags == .command {
                guard direction.isHorizontal, let pageStep = snapshot.container?.onPageStep else { return false }
                reset()
                pageStep(direction == .left ? -1 : 1)
                return true
            }
            guard flags.isEmpty || flags == .shift, hasTargets else { return false }
            move(direction, count: flags == .shift ? KeyNavGeometry.bigStep : 1, snapshot: snapshot, window: window)
            return true
        }

        switch event.keyCode {
        case KeyNavKey.space:
            guard flags.isEmpty, hasTargets else { return false }
            return toggleEntry(snapshot: snapshot, window: window, isRepeat: event.isARepeat)
        case KeyNavKey.return, KeyNavKey.enter:
            guard flags.isEmpty, hasTargets else { return false }
            return activate(snapshot: snapshot, window: window, isRepeat: event.isARepeat)
        case KeyNavKey.escape:
            guard flags.isEmpty else { return false }
            if let exited = KeyNavGeometry.exit(KeyNavGeometry.sanitized(focus, in: snapshot.nodes)) {
                apply(exited, snapshot: snapshot, window: window, reveal: true)
                return true
            }
            reset()
            return false
        default:
            return false
        }
    }

    private func move(_ direction: KeyNavDirection, count: Int, snapshot: Snapshot, window: NSWindow) {
        let start = followPointer(snapshot, window: window, primaryOnly: false)
        let next = KeyNavGeometry.move(focus, direction: direction, count: count, in: reachable(snapshot), pointer: start)
        apply(next, snapshot: snapshot, window: window, reveal: true)
    }

    /// The targets an arrow may land on: those on screen, plus hidden ones scrolling inside a scroll view that holds
    /// the focused target (moving down a list scrolls it; a header above the list never jumps into rows scrolled
    /// away under it). Navigation that starts without a focus only sees what is on screen.
    private func reachable(_ snapshot: Snapshot) -> [KeyNavNode<NodeID>] {
        let focused = focus.focused.flatMap { snapshot.placements[$0] }
        return snapshot.nodes.map { node in
            guard !snapshot.visible.contains(node.id) else { return node }
            var hidden = node
            if let focused, let placement = snapshot.placements[node.id], placement.sharesScrollView(with: focused) {
                return hidden
            }
            hidden.isEnabled = false
            return hidden
        }
    }

    private func toggleEntry(snapshot: Snapshot, window: NSWindow, isRepeat: Bool) -> Bool {
        _ = followPointer(snapshot, window: window, primaryOnly: true)
        guard focus.focused != nil else {
            apply(focus, snapshot: snapshot, window: window, reveal: false)
            return false
        }
        guard !isRepeat else { return true }
        let pointer = KeyNavWindowSpace(window: window).pointer
        let next = KeyNavGeometry.toggleEntry(focus, in: snapshot.nodes, pointer: pointer)
        apply(next, snapshot: snapshot, window: window, reveal: true)
        return true
    }

    private func activate(snapshot: Snapshot, window: NSWindow, isRepeat: Bool) -> Bool {
        // Return only presses what the user engaged: the focused target, or the one under a pointer that moved.
        // With neither, it passes through (a sheet's default button keeps working).
        _ = followPointer(snapshot, window: window, primaryOnly: false, leadsWhenStill: false)
        guard let id = focus.focused, let box = snapshot.boxes[id],
              let node = snapshot.nodes.first(where: { $0.id == id }) else {
            apply(focus, snapshot: snapshot, window: window, reveal: false)
            return false
        }
        guard !isRepeat else { return true }
        if let action = box.action {
            apply(focus, snapshot: snapshot, window: window, reveal: false)
            action()
        } else if focus.entered == nil, KeyNavGeometry.hasChildren(id, in: snapshot.nodes) {
            let next = KeyNavGeometry.toggleEntry(focus, in: snapshot.nodes, pointer: nil)
            apply(next, snapshot: snapshot, window: window, reveal: true)
        } else {
            apply(focus, snapshot: snapshot, window: window, reveal: false)
            // Bring it clear of edges and chrome first, so the click lands on it.
            let moved = reveal(id, snapshot: snapshot, window: window)
            KeyNavClicker.click(at: CGPoint(x: node.frame.midX - moved.dx, y: node.frame.midY - moved.dy), in: window)
        }
        return true
    }

    /// The pointer leads when it moved since the last key, or (with `leadsWhenStill`) when nothing visible is
    /// focused: focus jumps to the target under it (`primaryOnly`: to that target's primary). Over no target, the
    /// focus clears and the pointer is returned as the point navigation starts from.
    private func followPointer(_ snapshot: Snapshot, window: NSWindow, primaryOnly: Bool, leadsWhenStill: Bool = true) -> CGPoint? {
        let pointer = KeyNavWindowSpace(window: window).pointer
        defer { lastPointer = pointer }
        let current = KeyNavGeometry.sanitized(focus, in: snapshot.nodes)
        var moved = false
        if let pointer {
            if let last = lastPointer {
                moved = hypot(pointer.x - last.x, pointer.y - last.y) > Self.pointerSlop
            } else {
                moved = true
            }
        }
        let focusIsVisible = current.focused.map { snapshot.visible.contains($0) } ?? false
        if !moved && (focusIsVisible || !leadsWhenStill) {
            focus = current
            return nil
        }
        if let pointer, !snapshot.obstructions.contains(where: { $0.contains(pointer) }),
           let hit = KeyNavGeometry.focus(at: pointer, in: snapshot.nodes, primaryOnly: primaryOnly) {
            focus = hit
            return nil
        }
        focus = .none
        return pointer
    }

    // MARK: State

    private func apply(_ next: KeyNavFocus<NodeID>, snapshot: Snapshot, window: NSWindow, reveal: Bool) {
        focus = next
        var shown: [KeyNavTargetBox] = []
        if let id = next.entered, let box = snapshot.boxes[id] {
            box.setRing(.entered)
            shown.append(box)
        }
        if let id = next.focused, let box = snapshot.boxes[id] {
            box.setRing(.focused)
            shown.append(box)
        }
        for entry in lit {
            if let box = entry.value, !shown.contains(where: { $0 === box }) {
                box.setRing(.none)
            }
        }
        lit = shown.map(WeakBox.init)
        if reveal, let id = next.focused {
            self.reveal(id, snapshot: snapshot, window: window)
        }
    }

    @discardableResult
    private func reveal(_ id: NodeID, snapshot: Snapshot, window: NSWindow) -> CGVector {
        guard let placement = snapshot.placements[id] else { return CGVector(dx: 0, dy: 0) }
        return KeyNavScroller.reveal(placement, in: window, obstructions: snapshot.obstructions)
    }

    private func reset() {
        focus = .none
        for entry in lit {
            entry.value?.setRing(.none)
        }
        lit = []
    }

    private func snapshot(in window: NSWindow) -> Snapshot? {
        let space = KeyNavWindowSpace(window: window)
        var offsets: [ObjectIdentifier: CGVector] = [:]
        let live = hosts.compactMap(\.value).filter { host in
            guard host.window === window, let offset = host.windowOffset(in: space) else { return false }
            offsets[ObjectIdentifier(host)] = offset
            return true
        }
        let containers = live.filter { $0.kind == .container }
        let uncovered = containers.filter { host in
            !containers.contains { other in other !== host && other.isDescendant(of: host) }
        }
        guard let container = uncovered.max(by: { $0.serial < $1.serial }) else { return nil }
        let layer = [container] + live.filter { $0.kind == .accessory && $0.parent === container }
        var snapshot = Snapshot()
        snapshot.container = container
        for host in layer {
            let hostID = ObjectIdentifier(host)
            let offset = offsets[hostID] ?? CGVector(dx: 0, dy: 0)
            if !host.yields.isEmpty { snapshot.yields = true }
            for box in host.targets.values {
                guard let measured = box.placement, measured.frame.width >= 1, measured.frame.height >= 1 else { continue }
                let placement = measured.offsetBy(offset)
                let node = NodeID(host: hostID, id: box.key)
                snapshot.nodes.append(KeyNavNode(
                    id: node,
                    frame: placement.frame,
                    parent: box.parentKey.map { NodeID(host: hostID, id: $0) },
                    isEnabled: box.isEnabled
                ))
                snapshot.boxes[node] = box
                snapshot.placements[node] = placement
            }
            snapshot.obstructions += host.obstructions.values.map { $0.offsetBy(dx: offset.dx, dy: offset.dy) }
        }
        for (node, placement) in snapshot.placements
        where placement.isVisible(in: space.bounds, obstructions: snapshot.obstructions) {
            snapshot.visible.insert(node)
        }
        return snapshot
    }
}
#endif
