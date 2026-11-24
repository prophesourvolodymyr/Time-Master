import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// Sizes shared by every lane of one status board.
struct SkillStatusBoardMetrics: Equatable {
    var columnWidth: CGFloat
    var stripWidth: CGFloat = 56
    var gap: CGFloat = SkillMetrics.s3
    var inset: CGFloat

    func laneWidth(abandonedExpanded: Bool) -> CGFloat {
        columnWidth * 3 + gap * 3 + (abandonedExpanded ? columnWidth : stripWidth)
    }
}

/// The Board view of a board: Not started · In progress · Done · Abandoned as columns, optionally in swimlanes by
/// section. A card dragged to another column takes its status (and, to another lane, its section); every drag has a
/// menu twin. Abandoned is a slim strip until it is opened. Scrolls sideways when the columns do not fit.
struct SkillStatusBoardView: View {
    let snapshot: SkillBoardSnapshot
    @Binding var groupBySection: Bool
    let actions: SkillBoardActions

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var collapsedLanes: Set<String> = []
    @AppStorage(SkillSettings.perGroupKey) private var groupLimit = SkillGroupLimit.standard
    /// Columns (keyed `<lane>|<status>`) whose Expand all was pressed, until the page closes.
    @State private var expandedCells: Set<String> = []
    @State private var abandonedExpanded = false
    @State private var hoveredCell: String?
    @State private var availableWidth: CGFloat = 0
    /// The width has been read once, so the board no longer waits for it.
    @State private var hasMeasuredWidth = false
    @State private var cardDrag = SkillCardDragState()

    private struct BoardLane: Identifiable {
        let id: String
        let lane: SkillBoardLane?
    }

    var body: some View {
        if isWide && !hasMeasuredWidth {
            Color.clear
                .frame(height: 160)
                .background(widthReader)
        } else {
            board
        }
    }

    private var board: some View {
        let metrics = self.metrics
        return ScrollView(.horizontal, showsIndicators: isWide) {
            VStack(alignment: .leading, spacing: SkillMetrics.s5) {
                ForEach(boardLanes) { entry in
                    SkillStatusBoardLaneView(
                        lane: entry.lane,
                        items: snapshot.items(inLane: entry.lane?.key),
                        metrics: metrics,
                        moveTargets: snapshot.moveTargets,
                        isCollapsed: collapsedLanes.contains(entry.id),
                        limit: groupLimit,
                        expandedCells: expandedCells,
                        abandonedExpanded: $abandonedExpanded,
                        hoveredCell: $hoveredCell,
                        dragging: cardDrag,
                        actions: actions,
                        onToggle: { toggle(entry.id) },
                        onToggleExpanded: { toggleExpanded($0) },
                        onOpen: openAction(for: entry.lane),
                        onDrop: drop,
                        onAdd: add
                    )
                }
            }
            .padding(.horizontal, metrics.inset)
            .padding(.vertical, 2)
            .animation(reduceMotion ? nil : EverMotion.state, value: snapshot.signature)
        }
        .background(widthReader)
    }

    // MARK: Layout

    private var isWide: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    /// Mac and wide windows: the columns share the width (250…560 each). Phones: 280 pt columns that scroll sideways.
    private var metrics: SkillStatusBoardMetrics {
        var metrics = SkillStatusBoardMetrics(columnWidth: 280, inset: 0)
        if isWide && availableWidth > 0 {
            let shared: CGFloat = abandonedExpanded ? 4 : 3
            let reserved = metrics.inset * 2 + metrics.gap * 3 + (abandonedExpanded ? 0 : metrics.stripWidth)
            metrics.columnWidth = min(560, max(250, ((availableWidth - reserved) / shared).rounded(.down)))
        }
        return metrics
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    availableWidth = proxy.size.width
                    hasMeasuredWidth = true
                }
                .onChange(of: proxy.size.width) { availableWidth = $0 }
        }
    }

    private var boardLanes: [BoardLane] {
        guard groupBySection && snapshot.hasSections else { return [BoardLane(id: "all", lane: nil)] }
        return snapshot.boardLanes.map { BoardLane(id: $0.key, lane: $0) }
    }

    // MARK: Actions

    private func openGroup(_ sectionID: String) {
        navigationState.open(skillID: SkillGroupID.make(containerID: snapshot.scope.containerID, sectionID: sectionID))
    }

    /// Opens a lane's section as a page; nil for the loose skills and for a board without lanes.
    private func openAction(for lane: SkillBoardLane?) -> (() -> Void)? {
        guard let sectionID = lane?.sectionID else { return nil }
        return { openGroup(sectionID) }
    }

    private func toggle(_ key: String) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if collapsedLanes.contains(key) {
                collapsedLanes.remove(key)
            } else {
                collapsedLanes.insert(key)
            }
        }
    }

    private func toggleExpanded(_ cell: String) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if expandedCells.contains(cell) {
                expandedCells.remove(cell)
            } else {
                expandedCells.insert(cell)
            }
        }
    }

    /// A card dropped on a column (and lane): its status follows the column; a direct sub-skill also takes the lane's
    /// section (nested ones keep their own parent's).
    private func drop(_ id: String, _ status: SkillStatus, _ lane: SkillBoardLane?) -> Bool {
        hoveredCell = nil
        guard let item = snapshot.itemsByID[id] else { return false }
        let changesLane = lane.map { item.isDirect && item.laneKey != $0.key } ?? false
        guard item.status != status || changesLane else { return true }
        let section: String?? = changesLane ? .some(snapshot.scope.storedSectionID(forLane: lane?.sectionID)) : nil
        if SkillErrorCenter.shared.attempt("Move the sub-skill", { try store.placeSkillPage(id, status: status, sectionID: section) }) {
            if status == .completed { EverHaptic.success() } else { EverHaptic.selection() }
        }
        return true
    }

    /// "New" at the foot of a column: the sub-skill starts in that column's status and lane.
    private func add(_ title: String, _ status: SkillStatus, _ lane: SkillBoardLane?) -> Bool {
        let scope = snapshot.scope
        let added = SkillErrorCenter.shared.attempt("Add the sub-skill") {
            try store.createBoardSkill(title: title, on: scope.boardID, sectionID: scope.isGroup ? nil : lane?.sectionID, status: status)
        }
        if added {
            expandedCells.insert("\(lane?.key ?? "all")|\(status.rawValue)")
            EverHaptic.selection()
        }
        return added
    }
}

// MARK: - Lane

/// One swimlane: an optional banner (the section's header in its group card) over the four status columns. Without
/// a lane the board is a single row of columns.
private struct SkillStatusBoardLaneView: View {
    let lane: SkillBoardLane?
    let items: [SkillBoardItem]
    let metrics: SkillStatusBoardMetrics
    let moveTargets: [SkillBoardLane]
    let isCollapsed: Bool
    let limit: Int
    let expandedCells: Set<String>
    @Binding var abandonedExpanded: Bool
    @Binding var hoveredCell: String?
    let dragging: SkillCardDragState
    let actions: SkillBoardActions
    let onToggle: () -> Void
    let onToggleExpanded: (String) -> Void
    var onOpen: (() -> Void)?
    let onDrop: (String, SkillStatus, SkillBoardLane?) -> Bool
    let onAdd: (String, SkillStatus, SkillBoardLane?) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            if let lane {
                SkillBoardSectionHeader(
                    title: lane.title,
                    iconName: lane.section == nil ? "tray" : lane.section?.icon,
                    iconType: lane.section == nil ? SkillBoardIconType.system : lane.section?.iconType,
                    colorHex: lane.colorHex,
                    count: items.count,
                    isCollapsed: isCollapsed,
                    showsMenu: false,
                    onToggle: onToggle,
                    onOpen: onOpen,
                    menu: { EmptyView() }
                )
                .skillSectionGroup(colorHex: lane.colorHex, stripImageURL: lane.imageURL, verticalPadding: SkillMetrics.s1)
                .frame(width: metrics.laneWidth(abandonedExpanded: abandonedExpanded), alignment: .leading)
            }
            if !isCollapsed {
                HStack(alignment: .top, spacing: metrics.gap) {
                    ForEach(SkillStatus.boardOrder, id: \.self) { status in
                        cell(for: status)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func cell(for status: SkillStatus) -> some View {
        let key = "\(lane?.key ?? "all")|\(status.rawValue)"
        let cellItems = items.filter { $0.status == status }
        if status == .abandoned && !abandonedExpanded {
            SkillStatusBoardStrip(
                status: status,
                count: cellItems.count,
                width: metrics.stripWidth,
                isTargeted: hoveredCell == key,
                onExpand: { setExpanded(true) },
                delegate: delegate(status, key)
            )
        } else {
            SkillStatusBoardColumn(
                status: status,
                items: cellItems,
                width: metrics.columnWidth,
                moveTargets: moveTargets,
                isTargeted: hoveredCell == key,
                limit: limit,
                isExpanded: expandedCells.contains(key),
                onToggleExpanded: { onToggleExpanded(key) },
                actions: actions,
                dragging: dragging,
                onCollapse: status == .abandoned ? { setExpanded(false) } : nil,
                onAdd: { onAdd($0, status, lane) },
                delegate: delegate(status, key)
            )
        }
    }

    private func delegate(_ status: SkillStatus, _ key: String) -> SkillCardDropDelegate {
        SkillCardDropDelegate(status: status, lane: lane, dragging: dragging, onDrop: onDrop) { isTargeted in
            if isTargeted {
                hoveredCell = key
            } else if hoveredCell == key {
                hoveredCell = nil
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            abandonedExpanded = expanded
        }
    }
}

// MARK: - Column

private struct SkillStatusBoardColumn: View {
    let status: SkillStatus
    let items: [SkillBoardItem]
    let width: CGFloat
    let moveTargets: [SkillBoardLane]
    let isTargeted: Bool
    let limit: Int
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let actions: SkillBoardActions
    let dragging: SkillCardDragState
    let onCollapse: (() -> Void)?
    let onAdd: (String) -> Bool
    let delegate: SkillCardDropDelegate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.cardRadius, style: .continuous)
        let visible = SkillGroupLimit.split(items, limit: limit, expanded: isExpanded)
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            header
            if items.isEmpty {
                RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
                    .strokeBorder(status.color.opacity(isTargeted ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .frame(height: 64)
                    .accessibilityHidden(true)
            } else {
                ForEach(visible.shown) { item in
                    SkillStatusBoardCard(item: item, moveTargets: item.isDirect ? moveTargets : [], actions: actions, dragging: dragging)
                }
                if SkillGroupLimit.isCapped(count: items.count, limit: limit) {
                    SkillGroupMoreButton(hidden: visible.hidden, isExpanded: isExpanded, action: onToggleExpanded)
                }
            }
            SkillQuickAddRow(placeholder: "New", isDropTarget: isTargeted, onAdd: onAdd)
        }
        .padding(SkillMetrics.s3)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: 200, maxHeight: .infinity, alignment: .top)
        .background(shape.fill(isTargeted ? status.tint : status.tint.opacity(0.55)))
        .overlay {
            shape
                .strokeBorder(status.color.opacity(isTargeted ? 0.65 : 0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
        .onDrop(of: [UTType.plainText], delegate: delegate)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: SkillMetrics.s2) {
            SkillStatusChip(status)
            Text("\(items.count)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            if let onCollapse {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: SkillMetrics.touch, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Collapse \(status.title)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Slim strip

/// A collapsed column: the count and the name turned on their side. A tap opens it; it still takes drops.
private struct SkillStatusBoardStrip: View {
    let status: SkillStatus
    let count: Int
    let width: CGFloat
    let isTargeted: Bool
    let onExpand: () -> Void
    let delegate: SkillCardDropDelegate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.cardRadius, style: .continuous)
        Button(action: onExpand) {
            VStack(spacing: SkillMetrics.s3) {
                Text("\(count)")
                    .font(TimeMasterFont.black(13, relativeTo: .footnote).monospacedDigit())
                    .foregroundStyle(status.color)
                Text(status.title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(status.color)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 96)
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, SkillMetrics.s3)
            .frame(width: width)
            .frame(minHeight: 168, maxHeight: .infinity, alignment: .top)
            .background(shape.fill(isTargeted ? status.tint : status.tint.opacity(0.55)))
            .overlay {
                shape
                    .strokeBorder(status.color.opacity(isTargeted ? 0.65 : 0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
        .buttonStyle(SkillPressButtonStyle())
        .onDrop(of: [UTType.plainText], delegate: delegate)
        .help("Show \(status.title)")
        .accessibilityLabel("\(status.title), \(count)")
        .accessibilityHint("Shows the column")
    }
}

// MARK: - Card

/// One sub-skill on the board: the done check, its icon (opens the icon picker) and title on one line, its links as
/// chips, its own sub-skills as small rectangles, then a meta row with the counts and its type. A tap anywhere else
/// opens it; a link chip opens just that link; a rectangle opens that sub-skill; dragging moves it.
struct SkillStatusBoardCard: View {
    let item: SkillBoardItem
    /// Sections offered under "Move to section" (empty = not offered).
    let moveTargets: [SkillBoardLane]
    let actions: SkillBoardActions
    let dragging: SkillCardDragState

    @State private var isHovering = false
    @State private var typeEditor: SkillTypeEditorRoute?
    @State private var showingTypeManager = false
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true

    private var page: ExercisePage { item.page }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            if showsCovers {
                SkillGalleryCover(page: page) { actions.openFromCover(page) }
            }
            VStack(alignment: .leading, spacing: 0) {
                header
                if !item.path.isEmpty {
                    Text(item.path)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .padding(.top, SkillMetrics.s2)
                }
                if !item.links.isEmpty {
                    SkillCardLinkRow(links: item.links, tint: Theme.toolbarOrange) { actions.openLink($0.url) }
                }
                if !item.children.isEmpty {
                    SkillCardChildRow(children: item.children) { actions.open($0) }
                }
                if hasMeta {
                    metaRow
                        .padding(.top, item.links.isEmpty && item.children.isEmpty ? SkillMetrics.s2 : 0)
                }
            }
            .padding(.leading, SkillMetrics.s3)
            .padding(.trailing, SkillMetrics.s2)
            .padding(.vertical, SkillMetrics.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, accent: Theme.toolbarOrange, flat: true))
        .skillTypeBase(item.type, cornerRadius: SkillMetrics.fieldRadius)
        .overlay {
            shape
                .strokeBorder(Color.white.opacity(isHovering ? 0.22 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if isHovering, item.type == nil {
                typeMenu { SkillAddTypeChip() }
                    .padding(SkillMetrics.s2)
            }
        }
        .opacity(item.status == .abandoned ? 0.72 : 1)
        .contentShape(shape)
        .keyNavTarget(id: item.id, role: .primary, shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius), action: open)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: open)
        .onDrag {
            dragging.pickUp(item.id)
            EverHaptic.selection()
            return NSItemProvider(object: "card:\(item.id)" as NSString)
        } preview: {
            dragPreview
        }
        .skillTypeSheets(for: item.id, editor: $typeEditor, showingManager: $showingTypeManager)
        .contextMenu {
            SkillPageMenuItems(
                item: item,
                actions: actions,
                moveTargets: moveTargets,
                statusAsMenu: true,
                showsContents: true,
                typeEditor: $typeEditor,
                showingTypeManager: $showingTypeManager
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.spokenSummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .modifier(PageClipAccessibilityAction(page: page) { actions.openFromCover(page) })
        .accessibilityAction(named: "Change icon") { actions.changeIcon(page) }
        .accessibilityActions {
            ForEach(SkillStatus.boardOrder.filter { $0 != item.status }, id: \.self) { option in
                Button("Move to \(option.title)") { actions.setStatus(page, option) }
            }
            ForEach(moveTargets.filter { $0.key != item.laneKey }) { lane in
                Button("Move to \(lane.title)") { actions.moveToSection(page, lane.sectionID) }
            }
            ForEach(item.links) { link in
                Button("Open link \(link.label)") { actions.openLink(link.url) }
            }
            ForEach(item.children, id: \.manifest.id) { child in
                Button("Open \(child.title)") { actions.open(child) }
            }
        }
    }

    private func open() {
        actions.open(page)
    }

    // MARK: Pieces

    /// The done check, the icon and the title, centred on one line. The check's 44 pt box already leaves a gap after
    /// its circle, so the icon follows it directly.
    private var header: some View {
        HStack(spacing: 0) {
            SkillDoneButton(title: item.title, status: item.status, pageID: item.id) { actions.setStatus(page, $0) }
                .padding(.leading, -SkillMetrics.s2)
                .padding(.vertical, -SkillMetrics.s2)
            SkillIconChangeButton(page: page, side: 32) { actions.changeIcon(page) }
                .padding(.trailing, SkillMetrics.s2)
            SkillEditableTitle(
                pageID: item.id,
                title: item.title,
                font: TimeMasterFont.rowTitle(),
                color: Theme.textPrimary.opacity(item.status.titleOpacity),
                onOpen: open
            )
        }
    }

    private var hasMeta: Bool {
        item.mediaCount > 0 || item.linkCount > 0 || item.noteCount > 0 || item.progress.total > 0
            || item.dependencyCount > 0 || item.type != nil
    }

    private var metaRow: some View {
        HStack(spacing: SkillMetrics.s3) {
            if item.mediaCount > 0 { badge("paperclip", "\(item.mediaCount)") }
            if item.linkCount > 0 { badge("link", "\(item.linkCount)") }
            if item.noteCount > 0 { badge("note.text", "\(item.noteCount)") }
            if item.progress.total > 0 { badge("arrow.turn.down.right", "\(item.progress.completed)/\(item.progress.total)") }
            if item.dependencyCount > 0 { badge("arrow.triangle.branch", "\(item.dependencyCount)") }
            Spacer(minLength: 0)
            if let type = item.type {
                typeMenu { SkillTypeChip(type: type) }
            }
        }
    }

    /// The type menu around `label`: change the page's type, make a new one or manage them.
    private func typeMenu<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Menu {
            SkillTypeMenuItems(pageID: item.id, editor: $typeEditor, showingManager: $showingTypeManager)
        } label: {
            label()
        }
        .menuStyle(.button)
        .buttonStyle(SkillPressButtonStyle())
        .menuIndicator(.hidden)
        #if os(macOS)
        .fixedSize()
        #endif
        .help("Type")
    }

    private func badge(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(TimeMasterFont.technical())
        }
        .foregroundStyle(Theme.textSecondary)
    }

    private var dragPreview: some View {
        Text(TimeMasterFont.initialCapitalizedTitle(item.title))
            .font(TimeMasterFont.rowTitle())
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, SkillMetrics.s3)
            .padding(.vertical, SkillMetrics.s2)
            .frame(maxWidth: 240)
            .background(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous).fill(Theme.surface2))
    }
}

// MARK: - Sub-skills on a card

/// What a card shows of its sub-skill's own sub-skills: one small rectangle each with its icon and the first letters
/// of its name. A tap opens that sub-skill, not the card.
enum SkillCardChildren {
    static let letterCount = 3
    static let chipWidth: CGFloat = 58
    static let chipHeight: CGFloat = 28
    static let spacing: CGFloat = 6

    /// "Car" for "card controls": the first letters of the name on one line, the first a capital, never ending on a space.
    static func letters(of title: String, count: Int = letterCount) -> String {
        let oneLine = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let first = oneLine.first else { return "" }
        let cut = String((String(first).uppercased() + oneLine.dropFirst()).prefix(count))
        return cut.trimmingCharacters(in: .whitespaces)
    }

    /// How many rectangles fit a row `width` points wide, and how many wait behind "+N" (which takes a place itself).
    static func split(total: Int, width: CGFloat) -> (shown: Int, hidden: Int) {
        let places = max(1, Int((max(0, width) + spacing) / (chipWidth + spacing)))
        if total <= places { return (total, 0) }
        let shown = max(0, places - 1)
        return (shown, total - shown)
    }
}

/// The sub-skills of a card's sub-skill on a row of their own: as many rectangles as fit, then "+N" with a menu of
/// all of them.
struct SkillCardChildRow: View {
    let children: [ExercisePage]
    let onOpen: (ExercisePage) -> Void

    var body: some View {
        GeometryReader { proxy in
            let split = SkillCardChildren.split(total: children.count, width: proxy.size.width)
            HStack(spacing: SkillCardChildren.spacing) {
                ForEach(children.prefix(split.shown), id: \.manifest.id) { child in
                    SkillCardChildChip(child: child) { onOpen(child) }
                }
                if split.hidden > 0 {
                    SkillCardMoreChildrenChip(children: children, hiddenCount: split.hidden, onOpen: onOpen)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: SkillMetrics.touch)
    }
}

/// One sub-skill as a rectangle: its icon and the first letters of its name. A real `Button`, so it wins over the
/// card's own tap and drag.
struct SkillCardChildChip: View {
    let child: ExercisePage
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            SkillCardChildFace(status: child.manifest.skillStatus ?? .notStarted, isHighlighted: isHovering) {
                HStack(spacing: 4) {
                    SkillPageIconTile(page: child, size: 20)
                    Text(SkillCardChildren.letters(of: child.title))
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(SkillPressButtonStyle())
        .onHover { isHovering = $0 }
        .help(child.title)
        .accessibilityLabel("Open \(child.title)")
        .accessibilityHint("Opens this sub-skill")
    }
}

/// "+3" after the rectangles: a menu with every sub-skill, each of which opens.
struct SkillCardMoreChildrenChip: View {
    let children: [ExercisePage]
    let hiddenCount: Int
    let onOpen: (ExercisePage) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(children, id: \.manifest.id) { child in
                Button {
                    onOpen(child)
                } label: {
                    Label(child.title, systemImage: "arrow.turn.down.right")
                }
            }
        } label: {
            SkillCardChildFace(status: nil, isHighlighted: isHovering) {
                Text("+\(hiddenCount)")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(SkillPressButtonStyle())
        .menuIndicator(.hidden)
        #if os(macOS)
        .fixedSize()
        #endif
        .onHover { isHovering = $0 }
        .help("All \(children.count) sub-skills")
        .accessibilityLabel("\(hiddenCount) more \(hiddenCount == 1 ? "sub-skill" : "sub-skills")")
    }
}

/// The rectangle itself: a rounded, slightly raised box whose edge says where the sub-skill stands.
private struct SkillCardChildFace<Content: View>: View {
    let status: SkillStatus?
    let isHighlighted: Bool
    @ViewBuilder let content: Content

    private var edge: Color {
        switch status {
        case .learning?: return SkillStatus.learning.color.opacity(isHighlighted ? 0.9 : 0.6)
        case .completed?: return SkillStatus.completed.color.opacity(isHighlighted ? 0.9 : 0.6)
        default: return Color.white.opacity(isHighlighted ? 0.3 : 0.12)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        content
            .frame(width: SkillCardChildren.chipWidth, height: SkillCardChildren.chipHeight)
            .background(shape.fill(Theme.surface2.opacity(isHighlighted ? 1 : 0.8)))
            .overlay(shape.strokeBorder(edge, lineWidth: 1))
            .opacity(status == .abandoned ? 0.55 : 1)
            .padding(.vertical, (SkillMetrics.touch - SkillCardChildren.chipHeight) / 2)
            .contentShape(Rectangle())
    }
}

// MARK: - Links on a card

/// The links of a card on a row of their own: every link as a chip in a row that scrolls sideways, plus a menu of all
/// of them once there are more than two.
struct SkillCardLinkRow: View {
    let links: [SkillCardLink]
    let tint: Color
    let onOpen: (SkillCardLink) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(links) { link in
                        SkillCardLinkChip(link: link, tint: tint) { onOpen(link) }
                    }
                }
            }
            if SkillCardLink.offersMenu(links) {
                SkillCardMoreLinksChip(links: links, tint: tint, onOpen: onOpen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: SkillMetrics.touch)
    }
}

/// One link as a chip: a tap opens that link and nothing else.
struct SkillCardLinkChip: View {
    let link: SkillCardLink
    let tint: Color
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            SkillCardLinkPill(symbol: "link", text: link.chipTitle, tint: tint, isHighlighted: isHovering)
        }
        .buttonStyle(SkillPressButtonStyle())
        .onHover { isHovering = $0 }
        .help("Open \(link.url.absoluteString)")
        .accessibilityLabel("Open link \(link.label)")
    }
}

/// The count at the end of a card's link row: a menu with every link of the page.
struct SkillCardMoreLinksChip: View {
    let links: [SkillCardLink]
    let tint: Color
    let onOpen: (SkillCardLink) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(links) { link in
                Button {
                    onOpen(link)
                } label: {
                    Label(link.menuTitle, systemImage: "link")
                }
            }
        } label: {
            SkillCardLinkPill(symbol: "list.bullet", text: "\(links.count)", tint: tint, isHighlighted: isHovering)
        }
        .menuStyle(.button)
        .buttonStyle(SkillPressButtonStyle())
        .menuIndicator(.hidden)
        #if os(macOS)
        .fixedSize()
        #endif
        .onHover { isHovering = $0 }
        .help("All \(links.count) links")
        .accessibilityLabel("All \(links.count) links")
    }
}

/// The face of a link chip: a tinted capsule at least 28 pt tall inside a hit area of at least 44 pt.
struct SkillCardLinkPill: View {
    let symbol: String?
    let text: String
    let tint: Color
    var isHighlighted = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Capsule().fill(tint.opacity(isHighlighted ? 0.26 : 0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(isHighlighted ? 0.65 : 0.4), lineWidth: 1))
        .padding(.vertical, SkillMetrics.s2)
        .frame(minWidth: SkillMetrics.touch)
        .contentShape(Rectangle())
    }
}
