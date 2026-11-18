import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// The drags of a board carry what they move as text ("card:<id>", "page:<id>", "section:<id>") while the board's own
/// drag state says what moves. A drag that ends outside every target leaves that state behind, so a drop only moves
/// something once its text turns out to be the payload the board's own drag handed over: text dragged in from elsewhere
/// moves nothing.
enum SkillDropPayload {
    /// Runs `apply` on the main queue once the dropped text is `expected`; false when the drop holds no text.
    static func whenDropped(_ info: DropInfo, is expected: String, apply: @escaping () -> Void) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? NSString, text as String == expected else { return }
            DispatchQueue.main.async(execute: apply)
        }
        return true
    }
}

// MARK: - List (sections)

/// What is being dragged on the sections list.
enum SkillBoardDrag: Equatable {
    case page(String)
    case section(String)
}

/// Where a drop on the sections list lands.
enum SkillBoardDropPlacement: Equatable {
    /// Before or after another sub-skill, in that sub-skill's section.
    case beside(String, after: Bool)
    /// Inside another sub-skill.
    case into(String)
    /// At the end of a section (`nil` = the skills outside every group).
    case endOfGroup(String?)
    /// A section dropped on another section's header takes its place.
    case beforeSection(String)
}

/// What the pointer hovers while dragging (drives the highlights).
enum SkillBoardHover: Equatable {
    case row(String, SkillDropZone)
    case group(String?)
}

/// Where inside a row a drag hovers: the top edge inserts before, the bottom edge after, the middle moves inside.
enum SkillDropZone: Equatable {
    case before, into, after

    static func zone(y: CGFloat, height: CGFloat) -> SkillDropZone {
        guard height > 0 else { return .into }
        let ratio = y / height
        if ratio < 0.28 { return .before }
        if ratio > 0.72 { return .after }
        return .into
    }
}

/// Drag state of one sections list (touched only from SwiftUI drag and drop callbacks on the main thread).
final class SkillBoardDragState: ObservableObject {
    @Published var drag: SkillBoardDrag?
    @Published var hover: SkillBoardHover?

    func reset() {
        drag = nil
        hover = nil
    }

    func zone(forRow id: String) -> SkillDropZone? {
        if case let .row(rowID, zone)? = hover, rowID == id { return zone }
        return nil
    }

    func isHoveringGroup(_ sectionID: String?) -> Bool {
        if case let .group(hovered)? = hover { return hovered == sectionID }
        return false
    }

    /// The item provider of a dragged sub-skill or section. The payload only has to be text; this state holds the truth.
    func provider(for item: SkillBoardDrag) -> NSItemProvider {
        drag = item
        switch item {
        case .page(let id): return NSItemProvider(object: "page:\(id)" as NSString)
        case .section(let id): return NSItemProvider(object: "section:\(id)" as NSString)
        }
    }
}

/// A row's measured height, written by the row's background reader and read when something is dropped on it. Not
/// state: nothing is drawn from it.
final class SkillRowHeight {
    var value: CGFloat = 0
}

/// Drop target on a sub-skill row: the top edge inserts before, the bottom edge after, the middle moves inside.
struct SkillRowDropDelegate: DropDelegate {
    let rowID: String
    let height: SkillRowHeight
    let state: SkillBoardDragState
    let onDrop: (SkillBoardDrag, SkillBoardDropPlacement) -> Void

    private var movingID: String? {
        if case let .page(id)? = state.drag, id != rowID { return id }
        return nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        movingID != nil
    }

    func dropEntered(info: DropInfo) {
        track(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        track(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if case let .row(id, _)? = state.hover, id == rowID { state.hover = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        let moving = movingID
        let zone = SkillDropZone.zone(y: info.location.y, height: height.value)
        state.reset()
        guard let moving else { return false }
        let placement: SkillBoardDropPlacement
        switch zone {
        case .before: placement = .beside(rowID, after: false)
        case .after: placement = .beside(rowID, after: true)
        case .into: placement = .into(rowID)
        }
        return SkillDropPayload.whenDropped(info, is: "page:\(moving)") { onDrop(.page(moving), placement) }
    }

    private func track(_ info: DropInfo) {
        guard movingID != nil else { return }
        let hover = SkillBoardHover.row(rowID, SkillDropZone.zone(y: info.location.y, height: height.value))
        if state.hover != hover { state.hover = hover }
    }
}

/// Drop target on a section (its card, its header or its quick-add row): sub-skills land at the end of the section,
/// and on headers a dragged section takes this section's place.
struct SkillGroupDropDelegate: DropDelegate {
    let sectionID: String?
    let acceptsSections: Bool
    let state: SkillBoardDragState
    let onDrop: (SkillBoardDrag, SkillBoardDropPlacement) -> Void

    private var isUsable: Bool {
        switch state.drag {
        case .page?: return true
        case .section(let id)?: return acceptsSections && sectionID != nil && id != sectionID
        case nil: return false
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        isUsable
    }

    func dropEntered(info: DropInfo) {
        if isUsable, state.hover != .group(sectionID) { state.hover = .group(sectionID) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if isUsable, state.hover != .group(sectionID) { state.hover = .group(sectionID) }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if state.isHoveringGroup(sectionID) { state.hover = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        let item = state.drag
        state.reset()
        switch item {
        case .page(let id)?:
            return SkillDropPayload.whenDropped(info, is: "page:\(id)") { onDrop(.page(id), .endOfGroup(sectionID)) }
        case .section(let id)?:
            guard acceptsSections, let sectionID else { return false }
            return SkillDropPayload.whenDropped(info, is: "section:\(id)") { onDrop(.section(id), .beforeSection(sectionID)) }
        case nil:
            return false
        }
    }
}

/// Pure id-list reordering used by drag and drop and the Move up / Move down entries.
enum SkillOrdering {
    /// The dragged id lands just before or after `target`.
    static func moving(_ id: String, beside target: String, after: Bool, in ids: [String]) -> [String] {
        guard id != target, ids.contains(id), ids.contains(target) else { return ids }
        var result = ids.filter { $0 != id }
        guard let index = result.firstIndex(of: target) else { return ids }
        result.insert(id, at: after ? index + 1 : index)
        return result
    }

    /// `id` moves by `offset` places (negative = up), clamped to the list.
    static func shifted(_ id: String, by offset: Int, in ids: [String]) -> [String] {
        guard let from = ids.firstIndex(of: id) else { return ids }
        let to = min(max(0, from + offset), ids.count - 1)
        guard to != from else { return ids }
        var result = ids
        result.remove(at: from)
        result.insert(id, at: to)
        return result
    }
}

// MARK: - Status board (columns)

/// The card being dragged on the status board right now (set on pick-up, read by the column that takes the drop).
final class SkillCardDragState {
    private(set) var pageID: String?

    func pickUp(_ id: String) { pageID = id }
    func clear() { pageID = nil }
}

/// One column (or collapsed strip) of the status board as a drop target: lights up while a card hovers, moves the
/// card on drop (its status follows the column, its section the lane).
struct SkillCardDropDelegate: DropDelegate {
    let status: SkillStatus
    let lane: SkillBoardLane?
    let dragging: SkillCardDragState
    let onDrop: (String, SkillStatus, SkillBoardLane?) -> Bool
    let onTargeted: (Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        dragging.pageID != nil
    }

    func dropEntered(info: DropInfo) {
        guard dragging.pageID != nil else { return }
        onTargeted(true)
        EverHaptic.selection()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onTargeted(false)
    }

    func performDrop(info: DropInfo) -> Bool {
        onTargeted(false)
        guard let id = dragging.pageID else { return false }
        dragging.clear()
        return SkillDropPayload.whenDropped(info, is: "card:\(id)") { _ = onDrop(id, status, lane) }
    }
}
