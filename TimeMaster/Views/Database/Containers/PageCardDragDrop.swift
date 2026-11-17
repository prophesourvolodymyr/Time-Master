import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// Where a page dragged onto another page's card lands.
enum PageDropPlacement: Equatable {
    /// Right before the card's page: above it in a list, on its leading side in a gallery.
    case before
    /// Right after it.
    case after
    /// Inside it (a container's card).
    case inside

    /// Where a page dragged to `fraction` of a card (0 at its leading or top edge, 1 at the other one) lands. A card
    /// whose place the page can take (`reorders`) splits into halves; a container's card (`holds`) takes the page
    /// inside, and when it also reorders it keeps only its middle half for that and its outer quarters for the places
    /// beside it. Nil when the card takes nothing.
    static func resolve(fraction: CGFloat, reorders: Bool, holds: Bool) -> PageDropPlacement? {
        switch (reorders, holds) {
        case (false, false): return nil
        case (false, true): return .inside
        case (true, false): return fraction < 0.5 ? .before : .after
        case (true, true): return fraction < 0.25 ? .before : (fraction > 0.75 ? .after : .inside)
        }
    }
}

/// The page a list is dragging, noted when the drag starts so the cards it passes can tell a sibling (whose place it
/// can take) from a page from elsewhere. Only a hint: a drop reads the dragged page from the drag itself.
struct PageDragSource: Equatable {
    let pageID: String
    let parentID: String?
}

/// Drags a page card (its id as plain text) and takes pages dropped on it. With `reorders` (a list in its manual
/// order) a sibling dropped on the leading or trailing part of the card (its top or bottom in a list) takes the place
/// before or after it, shown as an orange line in the gap between the cards; with `holds` (a container's card) a page
/// dropped on it moves inside, outlined in orange. VoiceOver gets Move Up and Move Down where the list hands them over.
struct PageCardDragDrop: ViewModifier {
    let page: ExercisePage
    /// `.vertical` in a list, `.horizontal` in a gallery.
    let axis: Axis
    let cornerRadius: CGFloat
    /// The space between two cards; the line runs down its middle.
    let gap: CGFloat
    let reorders: Bool
    let holds: Bool
    @Binding var source: PageDragSource?
    /// The dragged page's id and where it lands.
    let onDrop: (String, PageDropPlacement) -> Void
    /// Moves the page one place up or down in the list (nil at either end, or when the list is not in manual order).
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    @State private var placement: PageDropPlacement?
    @State private var size: CGSize = .zero
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onDrag {
                source = PageDragSource(pageID: page.manifest.id, parentID: page.manifest.parentID)
                return NSItemProvider(object: page.manifest.id as NSString)
            }
            .onDrop(of: [UTType.plainText], delegate: PageCardDropDelegate(
                pageID: page.manifest.id,
                parentID: page.manifest.parentID,
                axis: axis,
                size: size,
                isRightToLeft: layoutDirection == .rightToLeft,
                reorders: reorders,
                holds: holds,
                source: source,
                placement: $placement,
                onDrop: onDrop,
                onFinish: { source = nil }
            ))
            .overlay {
                marker
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: placement)
            }
            .modifier(PageMoveActions(onMoveUp: reorders ? onMoveUp : nil, onMoveDown: reorders ? onMoveDown : nil))
    }

    private var marker: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let offset = gap / 2 + 1.5
        let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        return ZStack {
            shape
                .strokeBorder(Theme.toolbarOrange, lineWidth: 2)
                .opacity(placement == .inside ? 1 : 0)
            line
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: axis == .vertical ? .top : .leading)
                .offset(x: axis == .vertical ? 0 : -offset * direction, y: axis == .vertical ? -offset : 0)
                .opacity(placement == .before ? 1 : 0)
            line
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: axis == .vertical ? .bottom : .trailing)
                .offset(x: axis == .vertical ? 0 : offset * direction, y: axis == .vertical ? offset : 0)
                .opacity(placement == .after ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var line: some View {
        Capsule(style: .continuous)
            .fill(Theme.toolbarOrange)
            .frame(width: axis == .horizontal ? 3 : nil, height: axis == .vertical ? 3 : nil)
            .shadow(color: Theme.toolbarOrange.opacity(0.55), radius: 4)
    }
}

/// Tracks a drag over one card: where it would land as it moves, and hands the dragged page over on the drop.
private struct PageCardDropDelegate: DropDelegate {
    let pageID: String
    let parentID: String?
    let axis: Axis
    let size: CGSize
    let isRightToLeft: Bool
    let reorders: Bool
    let holds: Bool
    let source: PageDragSource?
    @Binding var placement: PageDropPlacement?
    let onDrop: (String, PageDropPlacement) -> Void
    let onFinish: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText]) && landing(info) != nil
    }

    func dropEntered(info: DropInfo) {
        placement = landing(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let next = landing(info)
        if next != placement { placement = next }
        return DropProposal(operation: next == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        placement = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let spot = landing(info)
        placement = nil
        onFinish()
        guard let spot, let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }
        let target = pageID
        let drop = onDrop
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let id = object as? String, id != target else { return }
            DispatchQueue.main.async { drop(id, spot) }
        }
        return true
    }

    /// Where the drag at `info` lands: never on the dragged page itself; beside the card only for a sibling (or a drag
    /// from elsewhere, checked again on the drop); inside only a container the page is not already in.
    private func landing(_ info: DropInfo) -> PageDropPlacement? {
        if source?.pageID == pageID { return nil }
        let isSibling = source.map { $0.parentID == parentID } ?? true
        let length = axis == .vertical ? size.height : size.width
        let position = axis == .vertical ? info.location.y : info.location.x
        var fraction = length > 0 ? position / length : 0.5
        if axis == .horizontal, isRightToLeft { fraction = 1 - fraction }
        return PageDropPlacement.resolve(
            fraction: fraction,
            reorders: reorders && isSibling,
            holds: holds && source?.parentID != pageID
        )
    }
}

/// Move Up and Move Down for VoiceOver, so a list in manual order can be rearranged without dragging.
private struct PageMoveActions: ViewModifier {
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        switch (onMoveUp, onMoveDown) {
        case let (up?, down?):
            content
                .accessibilityAction(named: "Move Up", up)
                .accessibilityAction(named: "Move Down", down)
        case let (up?, nil):
            content.accessibilityAction(named: "Move Up", up)
        case let (nil, down?):
            content.accessibilityAction(named: "Move Down", down)
        case (nil, nil):
            content
        }
    }
}
