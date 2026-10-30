import CoreGraphics

/// An arrow key, in screen space (y grows downward).
enum KeyNavDirection: CaseIterable, Hashable {
    case up, down, left, right

    var isHorizontal: Bool { self == .left || self == .right }
}

/// A navigable rectangle in one shared coordinate space (y grows downward).
struct KeyNavItem<ID: Hashable>: Equatable {
    var id: ID
    var frame: CGRect
}

/// A target as the step logic sees it. `parent == nil` marks a primary target; otherwise the target is a
/// secondary one inside `parent`. A secondary whose parent is not among the nodes counts as primary, so a
/// mis-wired small button is never unreachable.
struct KeyNavNode<ID: Hashable>: Equatable {
    var id: ID
    var frame: CGRect
    var parent: ID? = nil
    var isEnabled = true
}

/// Where the cursor is: the focused target and, while the user is inside a primary target, that primary.
struct KeyNavFocus<ID: Hashable>: Equatable {
    var focused: ID?
    var entered: ID?

    static var none: KeyNavFocus { KeyNavFocus(focused: nil, entered: nil) }
}

/// Pure geometry and step logic behind keyboard navigation: frames plus the current focus in, the next focus
/// out. No UI and no state, so all of it is unit-tested (`KeyNavGeometryTests`).
///
/// Direction search follows Android's FocusFinder (the rule set TV and keyboard UIs have used for years):
/// a candidate must lie in the pressed direction (edge test); a candidate overlapping the source's beam (its
/// extent across the axis) beats one outside it unless the outside one is entirely closer; the rest are ranked
/// by the axis-weighted cost `13 × major² + minor²` (`major` = edge gap along the axis, `minor` = centre offset
/// across it). Exact ties go to reading order (top, then left), so results never depend on registration order.
enum KeyNavGeometry {
    /// Layout produces subpixel offsets; half a point must not read as "above" or "left of".
    static let tolerance: CGFloat = 0.5
    /// Shift + arrow moves this many targets.
    static let bigStep = 3

    // MARK: Direction search

    /// The best target in `direction` from `source`, or `nil` at the edge.
    static func nearest<ID: Hashable>(
        from source: CGRect,
        direction: KeyNavDirection,
        among items: [KeyNavItem<ID>],
        excluding excluded: ID? = nil
    ) -> KeyNavItem<ID>? {
        var best: KeyNavItem<ID>?
        for item in items where item.id != excluded {
            guard isCandidate(source, item.frame, direction) else { continue }
            guard let current = best else {
                best = item
                continue
            }
            if isBetter(item.frame, than: current.frame, from: source, direction: direction)
                || (!isBetter(current.frame, than: item.frame, from: source, direction: direction)
                    && precedesInReadingOrder(item.frame, current.frame)) {
                best = item
            }
        }
        return best
    }

    /// `dest` lies in `direction` from `source`.
    static func isCandidate(_ source: CGRect, _ dest: CGRect, _ direction: KeyNavDirection) -> Bool {
        let e = tolerance
        switch direction {
        case .left:
            return (source.maxX > dest.maxX + e || source.minX >= dest.maxX - e) && source.minX > dest.minX + e
        case .right:
            return (source.minX < dest.minX - e || source.maxX <= dest.minX + e) && source.maxX < dest.maxX - e
        case .up:
            return (source.maxY > dest.maxY + e || source.minY >= dest.maxY - e) && source.minY > dest.minY + e
        case .down:
            return (source.minY < dest.minY - e || source.maxY <= dest.minY + e) && source.maxY < dest.maxY - e
        }
    }

    /// `a` beats `b` as the next target from `source` (both already candidates).
    static func isBetter(_ a: CGRect, than b: CGRect, from source: CGRect, direction: KeyNavDirection) -> Bool {
        if beamBeats(direction, source, a, b) { return true }
        if beamBeats(direction, source, b, a) { return false }
        return weightedDistance(direction, source, a) < weightedDistance(direction, source, b) - 0.0001
    }

    /// `b` overlaps `a` across the axis of `direction` (it sits in `a`'s beam).
    static func beamsOverlap(_ direction: KeyNavDirection, _ a: CGRect, _ b: CGRect) -> Bool {
        let e = tolerance
        if direction.isHorizontal {
            return b.maxY > a.minY + e && b.minY < a.maxY - e
        }
        return b.maxX > a.minX + e && b.minX < a.maxX - e
    }

    /// `dest` lies entirely past `source`'s leading edge in `direction`.
    static func isToDirection(_ direction: KeyNavDirection, of source: CGRect, _ dest: CGRect) -> Bool {
        let e = tolerance
        switch direction {
        case .left: return source.minX >= dest.maxX - e
        case .right: return source.maxX <= dest.minX + e
        case .up: return source.minY >= dest.maxY - e
        case .down: return source.maxY <= dest.minY + e
        }
    }

    /// `a` (in the beam) wins over `b` (outside it), unless `b` is entirely closer along a vertical axis.
    static func beamBeats(_ direction: KeyNavDirection, _ source: CGRect, _ a: CGRect, _ b: CGRect) -> Bool {
        let aInBeam = beamsOverlap(direction, source, a)
        let bInBeam = beamsOverlap(direction, source, b)
        if bInBeam || !aInBeam { return false }
        if !isToDirection(direction, of: source, b) { return true }
        if direction.isHorizontal { return true }
        return majorAxisDistance(direction, source, a) < majorAxisDistanceToFarEdge(direction, source, b)
    }

    /// Edge gap along the axis (0 when the rectangles overlap on it).
    static func majorAxisDistance(_ direction: KeyNavDirection, _ source: CGRect, _ dest: CGRect) -> CGFloat {
        let raw: CGFloat
        switch direction {
        case .left: raw = source.minX - dest.maxX
        case .right: raw = dest.minX - source.maxX
        case .up: raw = source.minY - dest.maxY
        case .down: raw = dest.minY - source.maxY
        }
        return max(0, raw)
    }

    /// Distance along the axis to the far edge of `dest` (at least 1).
    static func majorAxisDistanceToFarEdge(_ direction: KeyNavDirection, _ source: CGRect, _ dest: CGRect) -> CGFloat {
        let raw: CGFloat
        switch direction {
        case .left: raw = source.minX - dest.minX
        case .right: raw = dest.maxX - source.maxX
        case .up: raw = source.minY - dest.minY
        case .down: raw = dest.maxY - source.maxY
        }
        return max(1, raw)
    }

    /// Centre offset across the axis.
    static func minorAxisDistance(_ direction: KeyNavDirection, _ source: CGRect, _ dest: CGRect) -> CGFloat {
        direction.isHorizontal ? abs(source.midY - dest.midY) : abs(source.midX - dest.midX)
    }

    /// The axis-weighted cost: being far along the axis costs 13 times more than being off-centre across it.
    static func weightedDistance(_ direction: KeyNavDirection, _ source: CGRect, _ dest: CGRect) -> CGFloat {
        let major = majorAxisDistance(direction, source, dest)
        let minor = minorAxisDistance(direction, source, dest)
        return 13 * major * major + minor * minor
    }

    // MARK: Steps

    /// Moves `count` targets from `id` (Shift + arrow passes `bigStep`), stopping early at the edge.
    /// `nil` when it cannot move at all. With `wraps`, an edge continues on the far side of the same row/column.
    static func step<ID: Hashable>(
        from id: ID,
        direction: KeyNavDirection,
        count: Int = 1,
        among items: [KeyNavItem<ID>],
        wraps: Bool = false
    ) -> ID? {
        guard var current = items.first(where: { $0.id == id }) else { return nil }
        var moved = false
        for _ in 0..<max(1, count) {
            let next = nearest(from: current.frame, direction: direction, among: items, excluding: current.id)
                ?? (wraps ? wrapped(from: current, direction: direction, among: items) : nil)
            guard let next else { break }
            current = next
            moved = true
        }
        return moved ? current.id : nil
    }

    /// At an edge: the target on the far side of the same row (or column), or `nil` when there is none.
    static func wrapped<ID: Hashable>(
        from item: KeyNavItem<ID>,
        direction: KeyNavDirection,
        among items: [KeyNavItem<ID>]
    ) -> KeyNavItem<ID>? {
        guard var bounds = items.first?.frame else { return nil }
        for other in items { bounds = bounds.union(other.frame) }
        var virtual = item.frame
        switch direction {
        case .right: virtual.origin.x = bounds.minX - virtual.width - 1
        case .left: virtual.origin.x = bounds.maxX + 1
        case .down: virtual.origin.y = bounds.minY - virtual.height - 1
        case .up: virtual.origin.y = bounds.maxY + 1
        }
        guard let target = nearest(from: virtual, direction: direction, among: items), target.id != item.id else {
            return nil
        }
        return target
    }

    // MARK: Order and pointer

    /// Top row first (whole points, so subpixel offsets stay in one row), then left to right.
    static func precedesInReadingOrder(_ a: CGRect, _ b: CGRect) -> Bool {
        let ay = a.minY.rounded()
        let by = b.minY.rounded()
        if ay != by { return ay < by }
        return a.minX < b.minX
    }

    /// The top-left target.
    static func first<ID: Hashable>(in items: [KeyNavItem<ID>]) -> KeyNavItem<ID>? {
        items.min { precedesInReadingOrder($0.frame, $1.frame) }
    }

    /// The most specific target under `point` (smallest area).
    static func item<ID: Hashable>(at point: CGPoint, among items: [KeyNavItem<ID>]) -> KeyNavItem<ID>? {
        items.filter { $0.frame.contains(point) }.min { a, b in
            let areaA = a.frame.width * a.frame.height
            let areaB = b.frame.width * b.frame.height
            if areaA != areaB { return areaA < areaB }
            return precedesInReadingOrder(a.frame, b.frame)
        }
    }

    /// The target closest to `point` (0 when the point is inside it).
    static func nearest<ID: Hashable>(to point: CGPoint, among items: [KeyNavItem<ID>]) -> KeyNavItem<ID>? {
        items.min { a, b in
            let da = distance(from: point, to: a.frame)
            let db = distance(from: point, to: b.frame)
            if abs(da - db) > 0.0001 { return da < db }
            return precedesInReadingOrder(a.frame, b.frame)
        }
    }

    static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Where navigation starts from the pointer: the nearest target in the pressed direction, else the nearest one.
    static func entry<ID: Hashable>(from point: CGPoint, direction: KeyNavDirection, among items: [KeyNavItem<ID>]) -> KeyNavItem<ID>? {
        nearest(from: CGRect(origin: point, size: .zero), direction: direction, among: items)
            ?? nearest(to: point, among: items)
    }

    // MARK: Levels (primary / secondary)

    /// Nodes that can take focus now: enabled, with a real frame.
    static func usable<ID: Hashable>(_ nodes: [KeyNavNode<ID>]) -> [KeyNavNode<ID>] {
        nodes.filter { node in
            node.isEnabled && node.frame.width > 0 && node.frame.height > 0
                && node.frame.minX.isFinite && node.frame.minY.isFinite
        }
    }

    /// The targets the arrows move between: the entered primary's secondaries, or every primary.
    static func level<ID: Hashable>(_ entered: ID?, in nodes: [KeyNavNode<ID>]) -> [KeyNavItem<ID>] {
        let usableNodes = usable(nodes)
        if let entered {
            return usableNodes.filter { $0.parent == entered }.map { KeyNavItem(id: $0.id, frame: $0.frame) }
        }
        let ids = Set(nodes.map(\.id))
        return usableNodes
            .filter { node in node.parent.map { !ids.contains($0) } ?? true }
            .map { KeyNavItem(id: $0.id, frame: $0.frame) }
    }

    /// `id` has usable secondary targets.
    static func hasChildren<ID: Hashable>(_ id: ID, in nodes: [KeyNavNode<ID>]) -> Bool {
        !level(id, in: nodes).isEmpty
    }

    /// Drops a focus that no longer exists: a vanished entered primary resets everything, an entered primary
    /// without children takes the focus back, a focused target missing from the current level is cleared.
    static func sanitized<ID: Hashable>(_ focus: KeyNavFocus<ID>, in nodes: [KeyNavNode<ID>]) -> KeyNavFocus<ID> {
        var focus = focus
        if let entered = focus.entered, !hasChildren(entered, in: nodes) {
            let stillThere = level(nil, in: nodes).contains { $0.id == entered }
            focus = KeyNavFocus(focused: stillThere ? entered : nil, entered: nil)
        }
        if let focused = focus.focused, !level(focus.entered, in: nodes).contains(where: { $0.id == focused }) {
            focus.focused = nil
        }
        return focus
    }

    /// What the pointer selects: the most specific usable target under it. A secondary target is focused
    /// inside its primary (which becomes `entered`); with `primaryOnly`, its primary is focused instead.
    static func focus<ID: Hashable>(at point: CGPoint, in nodes: [KeyNavNode<ID>], primaryOnly: Bool = false) -> KeyNavFocus<ID>? {
        let ids = Set(nodes.map(\.id))
        let hits = usable(nodes).filter { $0.frame.contains(point) }
        func isSecondary(_ node: KeyNavNode<ID>) -> Bool { node.parent.map { ids.contains($0) } ?? false }
        let hit = hits.min { a, b in
            let secondaryA = isSecondary(a)
            let secondaryB = isSecondary(b)
            if secondaryA != secondaryB { return secondaryA }
            let areaA = a.frame.width * a.frame.height
            let areaB = b.frame.width * b.frame.height
            if areaA != areaB { return areaA < areaB }
            return precedesInReadingOrder(a.frame, b.frame)
        }
        guard let hit else { return nil }
        if isSecondary(hit), let parent = hit.parent {
            return primaryOnly ? KeyNavFocus(focused: parent, entered: nil) : KeyNavFocus(focused: hit.id, entered: parent)
        }
        return KeyNavFocus(focused: hit.id, entered: nil)
    }

    // MARK: Commands

    /// An arrow press. With nothing usable focused, navigation starts from `pointer` (the nearest target in the
    /// pressed direction, else the nearest one) or, without a pointer, from the top-left target.
    static func move<ID: Hashable>(
        _ focus: KeyNavFocus<ID>,
        direction: KeyNavDirection,
        count: Int = 1,
        in nodes: [KeyNavNode<ID>],
        pointer: CGPoint? = nil,
        wraps: Bool = false
    ) -> KeyNavFocus<ID> {
        var focus = sanitized(focus, in: nodes)
        let items = level(focus.entered, in: nodes)
        if let focused = focus.focused {
            if let next = step(from: focused, direction: direction, count: count, among: items, wraps: wraps) {
                focus.focused = next
            }
            return focus
        }
        let start = pointer.flatMap { entry(from: $0, direction: direction, among: items) } ?? first(in: items)
        guard let start else { return focus }
        focus.focused = start.id
        if count > 1, let next = step(from: start.id, direction: direction, count: count - 1, among: items, wraps: wraps) {
            focus.focused = next
        }
        return focus
    }

    /// Space: enters the focused primary (its secondary under `pointer`, else its top-left one) or leaves the
    /// entered one. A primary without secondaries stays as it is.
    static func toggleEntry<ID: Hashable>(_ focus: KeyNavFocus<ID>, in nodes: [KeyNavNode<ID>], pointer: CGPoint? = nil) -> KeyNavFocus<ID> {
        let focus = sanitized(focus, in: nodes)
        if let entered = focus.entered { return KeyNavFocus(focused: entered, entered: nil) }
        guard let focused = focus.focused else { return focus }
        let children = level(focused, in: nodes)
        guard let start = pointer.flatMap({ item(at: $0, among: children) }) ?? first(in: children) else { return focus }
        return KeyNavFocus(focused: start.id, entered: focused)
    }

    /// Escape: leaves the entered primary (focus returns to it); `nil` when not inside one.
    static func exit<ID: Hashable>(_ focus: KeyNavFocus<ID>) -> KeyNavFocus<ID>? {
        guard let entered = focus.entered else { return nil }
        return KeyNavFocus(focused: entered, entered: nil)
    }
}
