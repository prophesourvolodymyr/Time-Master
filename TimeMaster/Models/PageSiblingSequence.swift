import CoreGraphics

/// The pages Previous and Next step through from a page: the ones a container surface showed when the page was opened
/// from it (a gallery, a list, search hits, a board in reading order, the pages inside a skill), in that order, or the
/// container's own order when the page came from anywhere else. Ids are manifest ids; a repeated id keeps its first
/// place. Free of SwiftUI and the library, so it can be tested anywhere.
struct PageSiblingSequence: Equatable {
    /// Manifest id of the container whose pages these are.
    let containerID: String
    /// Manifest ids in the order shown.
    let pageIDs: [String]

    init(containerID: String, pageIDs: [String]) {
        var seen = Set<String>()
        self.containerID = containerID
        self.pageIDs = pageIDs.filter { seen.insert($0).inserted }
    }

    /// Whether Previous and Next have anywhere to go: two pages at least.
    var isSteppable: Bool { pageIDs.count > 1 }

    func contains(_ pageID: String) -> Bool { pageIDs.contains(pageID) }

    /// Where `pageID` sits; nil when the sequence does not hold it.
    func position(of pageID: String) -> PageSiblingPosition? {
        pageIDs.firstIndex(of: pageID).map { PageSiblingPosition(index: $0, count: pageIDs.count) }
    }

    /// The page `step` places after `pageID` (before it when negative); nil past either end, since the sequence does
    /// not wrap, and for a page it does not hold.
    func neighbour(of pageID: String, step: Int) -> String? {
        guard let index = pageIDs.firstIndex(of: pageID) else { return nil }
        let target = index + step
        return pageIDs.indices.contains(target) ? pageIDs[target] : nil
    }
}

/// A page's place in its sequence, as the position label shows it.
struct PageSiblingPosition: Equatable {
    /// From 0.
    let index: Int
    let count: Int

    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index + 1 < count }
    /// "5 / 23".
    var label: String { "\(index + 1) / \(count)" }
    /// "Page 5 of 23", for VoiceOver.
    var spokenLabel: String { "Page \(index + 1) of \(count)" }
}

/// What one navigation stack knows of sibling pages. Container surfaces offer the pages they show, keyed by the depth
/// of the screen they sit on (`path.count` while that screen is on top) and by container and surface; several
/// surfaces of one screen are alternatives, the newest first. A page screen at depth `d` freezes the newest offer from
/// depth `d - 1` that holds it (else its container's own order) the first time it asks, so lists that change
/// underneath later never move it. Popping drops everything above the new top; swapping the top page for a sibling
/// drops what its screen offered and keeps the frozen sequence for the sibling.
struct PageSiblingBook {
    private struct Offer {
        let sequence: PageSiblingSequence
        /// Larger is newer.
        let stamp: Int
    }

    /// Offers by screen depth, then by container and surface.
    private var offers: [Int: [String: Offer]] = [:]
    /// Frozen sequences by the depth of the page screen that froze them.
    private var frozen: [Int: PageSiblingSequence] = [:]
    private var clock = 0

    /// Records what a surface on the screen at `depth` shows, in display order, in place of what it showed before; an
    /// empty list withdraws the surface.
    mutating func offer(_ pageIDs: [String], containerID: String, surface: String, depth: Int) {
        let key = containerID + "\u{1F}" + surface
        guard !pageIDs.isEmpty else {
            offers[depth]?[key] = nil
            return
        }
        clock += 1
        let sequence = PageSiblingSequence(containerID: containerID, pageIDs: pageIDs)
        offers[depth, default: [:]][key] = Offer(sequence: sequence, stamp: clock)
    }

    /// The newest list offered on the screen at `depth` that holds `pageID`.
    func offer(containing pageID: String, at depth: Int) -> PageSiblingSequence? {
        offers[depth]?.values
            .filter { $0.sequence.contains(pageID) }
            .max { $0.stamp < $1.stamp }?
            .sequence
    }

    /// The sequence the page screen at `depth` froze, if any.
    func frozenSequence(at depth: Int) -> PageSiblingSequence? {
        frozen[depth]
    }

    /// The sequence of the page `pageID` whose screen sits at `depth`: the one that screen froze while it still holds
    /// the page (back from a deeper page, or swapped in for a sibling), else the newest offer of the screen below that
    /// holds it, else `fallback` (the container's own order) when that holds it. Whatever it finds stays frozen.
    mutating func sequence(for pageID: String, depth: Int,
                           fallback: () -> PageSiblingSequence?) -> PageSiblingSequence? {
        if let kept = frozen[depth], kept.contains(pageID) { return kept }
        let found = offer(containing: pageID, at: depth - 1)
            ?? fallback().flatMap { $0.contains(pageID) ? $0 : nil }
        frozen[depth] = found
        return found
    }

    /// The stack shrank to `depth` pages: the offers of the screens above it and the sequences they froze are gone.
    mutating func pop(toDepth depth: Int) {
        offers = offers.filter { $0.key <= depth }
        frozen = frozen.filter { $0.key <= depth }
    }

    /// The page on top, at `depth`, is about to be swapped for a sibling: what its own screen offered leaves with it,
    /// its frozen sequence stays for the sibling that takes its place.
    mutating func swapTop(atDepth depth: Int) {
        offers = offers.filter { $0.key < depth }
        frozen = frozen.filter { $0.key <= depth }
    }
}

/// The order Previous and Next follow on a page opened from anywhere but a container surface (the search sheet, a
/// link, a deep link): its container's own order. The callers read the lists from the library.
enum PageSiblingOrder {
    /// A folder: the first of its tab lists (Exercises, then Skills, as `lists(query: "")` gives them) that holds the
    /// page.
    static func folder(_ containerID: String, tabs: [[String]], holding pageID: String) -> PageSiblingSequence? {
        tabs.first { $0.contains(pageID) }.map { PageSiblingSequence(containerID: containerID, pageIDs: $0) }
    }

    /// A skill or a tutorial: its sub-skills as its board reads them (`board`, already in board order), then
    /// everything else inside it in child order.
    static func skill(_ containerID: String, board: [String], children: [String]) -> PageSiblingSequence {
        let onBoard = Set(board)
        return PageSiblingSequence(containerID: containerID, pageIDs: board + children.filter { !onBoard.contains($0) })
    }
}

/// When a two-finger swipe across a page steps to a sibling: a swipe to the left goes to the next page, a swipe to
/// the right to the previous one. It has to run mostly sideways, and far enough or fast enough.
enum PageSiblingSwipe {
    /// Sideways travel of the fingers that steps on its own (points).
    static let distance: CGFloat = 72
    /// A shorter flick steps when its fingers lift moving at least this fast sideways (points per second)…
    static let flickSpeed: CGFloat = 520
    /// …after travelling at least this far.
    static let flickDistance: CGFloat = 28
    /// How many times its vertical travel the sideways travel has to be.
    static let dominance: CGFloat = 1.5
    /// Sideways scroll a Mac trackpad gesture needs before it steps (points of scroll).
    static let trackpadDistance: CGFloat = 64

    /// The step a finished pan asks for, from the fingers' travel and their speed as they lifted: +1 (next) to the
    /// left, -1 (previous) to the right, nil for a pan too short, too slow or not sideways enough.
    static func step(translation: CGSize, velocity: CGSize) -> Int? {
        let sideways = abs(translation.width)
        guard sideways > 0, sideways > abs(translation.height) * dominance else { return nil }
        let far = sideways >= distance
        let flick = sideways >= flickDistance && abs(velocity.width) >= flickSpeed
            && (velocity.width < 0) == (translation.width < 0)
        guard far || flick else { return nil }
        return translation.width < 0 ? 1 : -1
    }
}

/// Follows the scroll events of one Mac trackpad gesture, from the fingers landing to their lift, and steps at most
/// once: when its sideways travel is far enough and dominates the vertical one. Momentum after the lift never counts;
/// a gesture that began where it may not step (over something that scrolls sideways, while text is edited) is ignored
/// whole.
struct PageSiblingScrollTracker {
    enum Phase: Equatable {
        /// The fingers landed or began to move: a new gesture, unless one is already under way.
        case began(eligible: Bool)
        case changed
        /// The fingers lifted, or the system took the gesture.
        case ended
        /// Scrolling that goes on by itself after the lift.
        case momentum
    }

    private var inGesture = false
    private var eligible = false
    private var stepped = false
    private var travelX: CGFloat = 0
    private var travelY: CGFloat = 0

    /// Takes one event of the gesture; `dx` and `dy` are the fingers' travel since the last one (positive x to the
    /// right). Returns the step it asks for (+1 next for a swipe to the left, -1 previous), once per gesture.
    mutating func receive(_ phase: Phase, dx: CGFloat, dy: CGFloat) -> Int? {
        switch phase {
        case .began(let eligible):
            guard !inGesture else { return track(dx: dx, dy: dy) }
            inGesture = true
            self.eligible = eligible
            stepped = false
            travelX = 0
            travelY = 0
            return track(dx: dx, dy: dy)
        case .changed:
            return track(dx: dx, dy: dy)
        case .ended:
            inGesture = false
            return nil
        case .momentum:
            return nil
        }
    }

    private mutating func track(dx: CGFloat, dy: CGFloat) -> Int? {
        guard inGesture, eligible, !stepped else { return nil }
        travelX += dx
        travelY += abs(dy)
        let sideways = abs(travelX)
        guard sideways >= PageSiblingSwipe.trackpadDistance,
              sideways > travelY * PageSiblingSwipe.dominance else { return nil }
        stepped = true
        return travelX < 0 ? 1 : -1
    }
}
