import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

// MARK: - Grouping

/// What the columns of a Board view stand for, like the Group by of a Notion board: where a page stands (Status) or
/// the type it wears (Type). Remembered per board (`SkillSettings.groupByKeyPrefix`).
enum SkillBoardGrouping: String, CaseIterable, Identifiable {
    case status
    case type

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .type: "Type"
        }
    }

    var symbolName: String {
        switch self {
        case .status: "circle.lefthalf.filled"
        case .type: "tag"
        }
    }

    var helpText: String { "Group by \(title.lowercased())" }
}

/// Status · Type as a slim track of glyphs beside the view switch (Board only); the names show as tooltips and are
/// read by VoiceOver ("Group by").
struct SkillBoardGroupingPicker: View {
    @Binding var selection: SkillBoardGrouping

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TmaxTabBar(
            SkillBoardGrouping.allCases.map { TmaxTab($0, title: $0.title, symbol: $0.symbolName, showsTitle: false, help: $0.helpText) },
            selection: selection,
            fillsWidth: false,
            accessibilityLabel: "Group by"
        ) { grouping in
            guard grouping != selection else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                selection = grouping
            }
            EverHaptic.selection()
        }
        .fixedSize()
    }
}

// MARK: - Columns

/// One column of a type board: the pages that wear no type ("Untagged"), or one type of the owner's presets.
struct PageTypeColumn: Identifiable, Equatable {
    static let untaggedID = "untagged"

    let type: SkillType?

    var id: String { type?.id ?? Self.untaggedID }
    var title: String { type?.title ?? "Untagged" }
    /// Solid colour of the head, the outline and the glyphs.
    var color: Color { type.map(SkillTypeStyle.color) ?? Theme.textSecondary }
    /// Soft fill of the column.
    var tint: Color { color.opacity(0.14) }
    /// `RRGGBB` for the controls that take a hex tint; nil = Tmax orange.
    var tintHex: String? { type.map(SkillTypeStyle.hex) }
    /// A menu entry's title: an emoji icon goes in front, since a menu cannot draw it as an image.
    var menuTitle: String { type.map(SkillTypeStyle.menuTitle) ?? "Untagged" }
}

/// A type board read once per render: the columns (Untagged first while it holds pages or while no type exists yet,
/// then every type of the owner's presets in preset and option order) and each column's cards in reading order. One
/// pass over the pages; types are looked up in one dictionary, never per card in the store.
struct PageTypeBoardSnapshot {
    /// The page that keeps the types: its presets are the columns.
    let ownerID: String?
    let presets: [SkillTypePreset]
    let columns: [PageTypeColumn]
    /// Untagged and every type, whether its column shows or not: where a menu can move a card.
    let moveTargets: [PageTypeColumn]
    let itemsByColumn: [String: [SkillBoardItem]]
    let itemsByID: [String: SkillBoardItem]
    /// Every card, column by column and top to bottom: the order a reader walks the board in.
    let readingOrder: [String]

    /// A skill board's sub-skills at every depth, by the types of its skill tree.
    init(skills snapshot: SkillBoardSnapshot, store: DatabaseStore) {
        let owner = store.skillTypeOwner(of: snapshot.scope.boardID)
        self.init(
            ownerID: owner?.manifest.id,
            presets: owner.map { store.skillTypePresets(for: $0.manifest.id) } ?? [],
            items: snapshot.items
        )
    }

    /// The exercises and notes at every depth below `folder` (through its sub-folders, and through the skills inside it),
    /// by the tags of the top page of its tree. `folder` carries its page tree (`ContainerBrowseModel.container`).
    init(folder: ExercisePage, store: DatabaseStore) {
        let owner = store.tagRoot(of: folder)
        let presets = owner.map { store.skillTypePresets(for: $0.manifest.id) } ?? []
        let types = Dictionary(presets.flatMap(\.types).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var items: [SkillBoardItem] = []
        var visited: Set<String> = [folder.manifest.id]
        func visit(_ parent: ExercisePage, path: [String]) {
            for child in parent.children where visited.insert(child.manifest.id).inserted {
                if child.isExercise || child.isNote {
                    let type = child.manifest.typeID.flatMap { types[$0] }
                    items.append(Self.item(for: child, path: path, isDirect: path.isEmpty, type: type))
                }
                if !child.children.isEmpty {
                    visit(child, path: path + [child.title])
                }
            }
        }
        visit(folder, path: [])
        self.init(ownerID: owner?.manifest.id, presets: presets, items: items)
    }

    private init(ownerID: String?, presets: [SkillTypePreset], items: [SkillBoardItem]) {
        let types = presets.flatMap(\.orderedTypes)
        let known = Set(types.map(\.id))
        var byColumn: [String: [SkillBoardItem]] = [:]
        for item in items {
            let key = item.type.flatMap { known.contains($0.id) ? $0.id : nil } ?? PageTypeColumn.untaggedID
            byColumn[key, default: []].append(item)
        }
        let untagged = PageTypeColumn(type: nil)
        let typeColumns = types.map { PageTypeColumn(type: $0) }
        let showsUntagged = !(byColumn[PageTypeColumn.untaggedID]?.isEmpty ?? true) || types.isEmpty
        let columns = (showsUntagged ? [untagged] : []) + typeColumns
        self.ownerID = ownerID
        self.presets = presets
        self.columns = columns
        self.moveTargets = [untagged] + typeColumns
        self.itemsByColumn = byColumn
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.readingOrder = columns.flatMap { (byColumn[$0.id] ?? []).map(\.id) }
    }

    /// An exercise or a note as a card: no status, progress or sub-skills, its own Markdown counted as a note.
    private static func item(for page: ExercisePage, path: [String], isDirect: Bool, type: SkillType?) -> SkillBoardItem {
        SkillBoardItem(
            page: page,
            laneKey: type?.id ?? PageTypeColumn.untaggedID,
            laneIndex: 0,
            sectionTitle: nil,
            sectionColorHex: nil,
            path: path.joined(separator: " › "),
            isDirect: isDirect,
            type: type,
            children: [],
            progress: SkillBoardTally(),
            noteCount: !page.isNote && page.hasMarkdown ? 1 : 0,
            dependencyCount: 0,
            links: SkillCardLink.openable(in: page.manifest)
        )
    }

    var hasTypes: Bool { moveTargets.count > 1 }

    func items(in column: PageTypeColumn) -> [SkillBoardItem] { itemsByColumn[column.id] ?? [] }

    /// The column a card sits in: its type when the owner still has it, else Untagged.
    func columnID(of item: SkillBoardItem) -> String {
        guard let id = item.type?.id, itemsByColumn[id]?.contains(where: { $0.id == item.id }) == true else {
            return PageTypeColumn.untaggedID
        }
        return id
    }

    /// Ids, columns and titles of every card: what the board animates when the library moves something.
    var signature: [String] {
        columns.flatMap { column in (itemsByColumn[column.id] ?? []).map { "\($0.id)|\(column.id)|\($0.title)" } }
    }

    /// The route of the sheet that makes a new type: an option of the first preset, or a preset first.
    var newTypeRoute: SkillTypeEditorRoute {
        presets.first.map { SkillTypeEditorRoute.newType(presetID: $0.id) } ?? SkillTypeEditorRoute.newPreset
    }
}

// MARK: - Actions

/// What the cards of a type board can do. The screen showing the board owns the store calls and the sheets.
struct PageTypeBoardActions {
    var open: (ExercisePage) -> Void
    /// A tap on the card's cover: what a gallery card's cover does (`PageCoverOpening`).
    var openFromCover: (ExercisePage) -> Void
    /// Gives the page a type (nil = none).
    var setType: (ExercisePage, SkillType?) -> Void
    /// Skill and tutorial pages: their status (from the menu; the card shows none).
    var setStatus: ((ExercisePage, SkillStatus) -> Void)?
    /// Skill, tutorial and note pages: their icon.
    var changeIcon: ((ExercisePage) -> Void)?
    var addToWorkout: ((ExercisePage) -> Void)?
    var edit: (ExercisePage) -> Void
    /// "Move to…": another page of the library.
    var moveTo: (ExercisePage) -> Void
    var requestDelete: (ExercisePage) -> Void
    var openLink: (URL) -> Void
}

/// What a column's New row makes, wearing the column's type: a sub-skill from its name (a skill board), or a page
/// through the page editor (a folder's board, whose exercises take timing and media).
enum PageTypeNewPage {
    case named(placeholder: String, create: (String, SkillType?) -> Bool)
    case editor(title: String, open: (SkillType?) -> Void)
}

// MARK: - Board

/// The Board view grouped by type: one column per type of the owner's presets (Untagged first while it holds pages or
/// while there is no type yet), each with the type's pill and count, its tint, the per-column limit with Expand all and
/// a New row; a dashed column at the end makes a new type. A card dragged to another column takes that type (Untagged
/// clears it); every drag has a menu twin. Scrolls sideways when the columns do not fit.
struct PageTypeBoardView: View {
    let snapshot: PageTypeBoardSnapshot
    let actions: PageTypeBoardActions
    let newPage: PageTypeNewPage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @AppStorage(SkillSettings.perGroupKey) private var groupLimit = SkillGroupLimit.standard
    /// Columns whose Expand all was pressed, until the page closes.
    @State private var expandedColumns: Set<String> = []
    @State private var hoveredColumn: String?
    @State private var availableWidth: CGFloat = 0
    /// The width has been read once, so the board no longer waits for it.
    @State private var hasMeasuredWidth = false
    @State private var cardDrag = SkillCardDragState()
    @State private var typeEditor: SkillTypeEditorRoute?
    @State private var showingTypeManager = false

    private static let gap = SkillMetrics.s3

    var body: some View {
        Group {
            if isWide && !hasMeasuredWidth {
                Color.clear
                    .frame(height: 160)
                    .background(widthReader)
            } else {
                board
            }
        }
        .pageTypeSheets(ownerID: snapshot.ownerID, editor: $typeEditor, showingManager: $showingTypeManager)
    }

    private var board: some View {
        let width = columnWidth
        return ScrollView(.horizontal, showsIndicators: isWide) {
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(snapshot.columns) { column in
                    PageTypeBoardColumnView(
                        column: column,
                        items: snapshot.items(in: column),
                        snapshot: snapshot,
                        width: width,
                        isTargeted: hoveredColumn == column.id,
                        limit: groupLimit,
                        isExpanded: expandedColumns.contains(column.id),
                        onToggleExpanded: { toggleExpanded(column.id) },
                        actions: actions,
                        dragging: cardDrag,
                        newPage: newPage,
                        delegate: delegate(for: column)
                    )
                }
                if snapshot.ownerID != nil {
                    PageTypeNewTypeColumn(width: width, hasPresets: !snapshot.presets.isEmpty) {
                        typeEditor = snapshot.newTypeRoute
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
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

    /// Mac and wide windows: the columns share the width (250…400 each) and scroll once they no longer fit. Phones:
    /// 280 pt columns that scroll sideways.
    private var columnWidth: CGFloat {
        guard isWide, availableWidth > 0 else { return 280 }
        let count = CGFloat(max(1, snapshot.columns.count))
        let shared = (availableWidth - Self.gap * count) / (count + 0.6)
        return min(400, max(250, shared.rounded(.down)))
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

    // MARK: Actions

    private func toggleExpanded(_ id: String) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if expandedColumns.contains(id) {
                expandedColumns.remove(id)
            } else {
                expandedColumns.insert(id)
            }
        }
    }

    private func delegate(for column: PageTypeColumn) -> PageTypeDropDelegate {
        PageTypeDropDelegate(column: column, dragging: cardDrag, onDrop: drop) { isTargeted in
            if isTargeted {
                hoveredColumn = column.id
            } else if hoveredColumn == column.id {
                hoveredColumn = nil
            }
        }
    }

    /// A card dropped on a column takes the column's type (Untagged clears it).
    private func drop(_ id: String, _ column: PageTypeColumn) -> Bool {
        hoveredColumn = nil
        guard let item = snapshot.itemsByID[id] else { return false }
        guard snapshot.columnID(of: item) != column.id else { return true }
        actions.setType(item.page, column.type)
        return true
    }
}

// MARK: - Column

private struct PageTypeBoardColumnView: View {
    let column: PageTypeColumn
    let items: [SkillBoardItem]
    let snapshot: PageTypeBoardSnapshot
    let width: CGFloat
    let isTargeted: Bool
    let limit: Int
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let actions: PageTypeBoardActions
    let dragging: SkillCardDragState
    let newPage: PageTypeNewPage
    let delegate: PageTypeDropDelegate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.cardRadius, style: .continuous)
        let visible = SkillGroupLimit.split(items, limit: limit, expanded: isExpanded)
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            header
            if items.isEmpty {
                RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
                    .strokeBorder(column.color.opacity(isTargeted ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .frame(height: 64)
                    .accessibilityHidden(true)
            } else {
                ForEach(visible.shown) { item in
                    PageTypeBoardCard(
                        item: item,
                        columnID: column.id,
                        moveTargets: snapshot.moveTargets,
                        presets: snapshot.presets,
                        actions: actions,
                        dragging: dragging
                    )
                }
                if SkillGroupLimit.isCapped(count: items.count, limit: limit) {
                    SkillGroupMoreButton(hidden: visible.hidden, isExpanded: isExpanded, tintHex: column.tintHex, action: onToggleExpanded)
                }
            }
            newRow
        }
        .padding(SkillMetrics.s3)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: 200, maxHeight: .infinity, alignment: .top)
        .background(shape.fill(isTargeted ? column.tint : column.tint.opacity(0.55)))
        .overlay {
            shape
                .strokeBorder(column.color.opacity(isTargeted ? 0.65 : 0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
        .onDrop(of: [UTType.plainText], delegate: delegate)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: SkillMetrics.s2) {
            PageTypeColumnPill(column: column)
            Text("\(items.count)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var newRow: some View {
        switch newPage {
        case .named(let placeholder, let create):
            SkillQuickAddRow(placeholder: placeholder, tintHex: column.tintHex, isDropTarget: isTargeted) { title in
                create(title, column.type)
            }
        case .editor(let title, let open):
            PageTypeNewPageButton(title: title, tintHex: column.tintHex, columnTitle: column.title) {
                open(column.type)
            }
        }
    }
}

/// A type as the head of its column, the pill the status columns wear: the type's icon and name in its colour on a wash
/// of it. Untagged wears a slashed tag in grey.
struct PageTypeColumnPill: View {
    let column: PageTypeColumn

    var body: some View {
        HStack(spacing: 5) {
            if let type = column.type {
                SkillIconView(iconName: SkillTypeStyle.iconName(type), iconType: type.iconType, colorHex: SkillTypeStyle.hex(type), size: 11)
            } else {
                Image(systemName: "tag.slash")
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(column.title)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .lineLimit(1)
        }
        .foregroundStyle(column.color)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Capsule().fill(column.tint))
        .overlay(Capsule().strokeBorder(column.color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(column.type == nil ? "Untagged" : "Type: \(column.title)")
    }
}

/// The New row of a column on a folder's board: a dashed row that opens the page editor, the new page wearing the
/// column's type.
private struct PageTypeNewPageButton: View {
    let title: String
    let tintHex: String?
    let columnTitle: String
    let action: () -> Void

    var body: some View {
        let tint = tintHex.map { Color(hex: $0) } ?? Theme.toolbarOrange
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: SkillMetrics.s3) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.8))
                    .frame(width: 24)
                Text(title)
                    .font(TimeMasterFont.body(16))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SkillMetrics.s4)
            .frame(maxWidth: .infinity, minHeight: SkillMetrics.touch + SkillMetrics.s2, alignment: .leading)
            .background(shape.fill(Color.white.opacity(0.03)))
            .overlay {
                shape
                    .strokeBorder(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel("\(title) in \(columnTitle)")
        .help("\(title) in \(columnTitle)")
    }
}

/// The dashed column after the last: makes a new type (a preset first while there is none).
private struct PageTypeNewTypeColumn: View {
    let width: CGFloat
    let hasPresets: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.cardRadius, style: .continuous)
        let title = hasPresets ? "New type" : "Make a preset"
        Button(action: action) {
            VStack(spacing: SkillMetrics.s2) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(TimeMasterFont.rowTitle())
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(SkillMetrics.s3)
            .frame(width: max(160, (width * 0.6).rounded()))
            .frame(minHeight: 200, maxHeight: .infinity)
            .overlay {
                shape
                    .strokeBorder(Theme.textSecondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
        .buttonStyle(SkillPressButtonStyle())
        .accessibilityLabel(hasPresets ? "New type" : "Make a type preset")
        .accessibilityHint("Adds a column")
        .help(title)
    }
}

// MARK: - Card

/// One page on a type board: its cover (or its icon) and title, the folder it sits in, its links as chips, its own
/// sub-skills and its counts. No done check, no status chip and no type chip: the column says the type. A tap opens it,
/// the cover does what a gallery cover does, dragging moves it to another type, and its menu holds the twin.
struct PageTypeBoardCard: View {
    let item: SkillBoardItem
    /// The column the card sits in.
    let columnID: String
    /// Untagged and every type, for "Move to type".
    let moveTargets: [PageTypeColumn]
    let presets: [SkillTypePreset]
    let actions: PageTypeBoardActions
    let dragging: SkillCardDragState

    @State private var isHovering = false
    @State private var typeEditor: SkillTypeEditorRoute?
    @State private var showingTypeManager = false
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true

    private static let coverHeight: CGFloat = 112
    private static let inlineMenuLinks = 3

    private var page: ExercisePage { item.page }

    /// An exercise shows its first picture or clip, as its gallery card does; a skill only a cover it chose.
    private var coverURL: URL? {
        guard showsCovers else { return nil }
        return page.isSkillLike ? page.cardCoverURL : page.coverImageURL
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            if let coverURL {
                cover(coverURL)
            }
            header
            if !item.path.isEmpty {
                ContainerPathLabel(path: item.path)
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
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, accent: Theme.toolbarOrange, flat: true))
        .overlay {
            shape
                .strokeBorder(Color.white.opacity(isHovering ? 0.22 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
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
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .modifier(PageClipAccessibilityAction(page: page) { actions.openFromCover(page) })
        .accessibilityActions {
            ForEach(moveTargets.filter { $0.id != columnID }) { column in
                Button("Move to \(column.title)") { actions.setType(page, column.type) }
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

    /// The cover filling the card's width: a tap opens it as a gallery cover does, with a play glyph on a clip.
    private func cover(_ url: URL) -> some View {
        let radius = SkillMetrics.fieldRadius - 4
        return Color.clear
            .frame(height: Self.coverHeight)
            .overlay {
                AsyncCoverImage(
                    url: url,
                    fallbackIcon: page.effectiveWorkoutType?.iconName ?? ContainerPageKind(page).symbolName,
                    fallbackColor: page.effectiveWorkoutType.map { Color(hex: $0.colorHex) },
                    height: Self.coverHeight,
                    contentMode: .fill,
                    overlayGradient: false
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .modifier(PageCoverTap(page: page, cornerRadius: radius, glyphSize: 26) { actions.openFromCover(page) })
            .padding(.bottom, SkillMetrics.s2)
            .padding(.trailing, SkillMetrics.s1)
    }

    /// The icon (when there is no cover) and the title on one line.
    private var header: some View {
        HStack(spacing: SkillMetrics.s2) {
            if coverURL == nil {
                icon
            }
            SkillEditableTitle(
                pageID: item.id,
                title: item.title,
                font: TimeMasterFont.rowTitle(),
                color: Theme.textPrimary,
                onOpen: open
            )
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let changeIcon = actions.changeIcon, page.isSkillLike {
            SkillIconChangeButton(page: page, side: 32) { changeIcon(page) }
        } else if page.isSkillLike {
            SkillPageIconTile(page: page, size: 32, tilesSymbols: true)
        } else {
            PageTypeBoardGlyph(page: page)
        }
    }

    private var hasMeta: Bool {
        item.mediaCount > 0 || item.linkCount > 0 || item.noteCount > 0 || item.progress.total > 0
            || item.dependencyCount > 0 || timing != nil
    }

    /// An exercise's length: "45s", or "3 × 45s" with several sets.
    private var timing: String? {
        guard page.isExercise, let duration = page.manifest.duration else { return nil }
        if let sets = page.manifest.sets, sets > 1 { return "\(sets) × \(duration)s" }
        return "\(duration)s"
    }

    private var metaRow: some View {
        HStack(spacing: SkillMetrics.s3) {
            if let timing { badge("timer", timing) }
            if item.mediaCount > 0 { badge("paperclip", "\(item.mediaCount)") }
            if item.linkCount > 0 { badge("link", "\(item.linkCount)") }
            if item.noteCount > 0 { badge("note.text", "\(item.noteCount)") }
            if item.progress.total > 0 { badge("arrow.turn.down.right", "\(item.progress.completed)/\(item.progress.total)") }
            if item.dependencyCount > 0 { badge("arrow.triangle.branch", "\(item.dependencyCount)") }
            Spacer(minLength: 0)
        }
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

    /// "Title, Untagged, in Hips, 45 seconds, 2 files, 1 link" for VoiceOver.
    private var spokenSummary: String {
        var parts = [item.title, moveTargets.first { $0.id == columnID }?.title ?? "Untagged"]
        if !item.path.isEmpty { parts.append("in \(item.path)") }
        if page.isExercise, let duration = page.manifest.duration {
            let sets = page.manifest.sets ?? 1
            parts.append(sets > 1 ? "\(sets) sets of \(duration) seconds" : "\(duration) seconds")
        }
        if item.mediaCount > 0 { parts.append(item.mediaCount == 1 ? "1 file" : "\(item.mediaCount) files") }
        if item.linkCount > 0 { parts.append(item.linkCount == 1 ? "1 link" : "\(item.linkCount) links") }
        if item.noteCount > 0 { parts.append(item.noteCount == 1 ? "1 note" : "\(item.noteCount) notes") }
        if item.progress.total > 0 { parts.append("\(item.progress.completed) of \(item.progress.total) done") }
        return parts.joined(separator: ", ")
    }

    // MARK: Menu

    /// Open, add to a workout, the icon and the links; the type (the twin of a drag) and a skill's status; edit, move and
    /// delete.
    @ViewBuilder
    private var menu: some View {
        Button(action: open) {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        if let addToWorkout = actions.addToWorkout, page.isWorkoutAddable {
            Button {
                addToWorkout(page)
            } label: {
                Label("Add to Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        if let changeIcon = actions.changeIcon, page.isSkillLike {
            Button {
                changeIcon(page)
            } label: {
                Label("Change icon…", systemImage: "face.smiling")
            }
        }
        linkItems
        Divider()
        moveToTypeMenu
        if let setStatus = actions.setStatus, page.isSkillLike {
            SkillStatusMenu(status: item.status, onChange: { setStatus(page, $0) }) {
                Label("Status", systemImage: "flag")
            }
        }
        Divider()
        Button {
            actions.edit(page)
        } label: {
            Label("Edit…", systemImage: "pencil")
        }
        Button {
            actions.moveTo(page)
        } label: {
            Label("Move to…", systemImage: "arrow.turn.up.right")
        }
        Divider()
        Button(role: .destructive) {
            actions.requestDelete(page)
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }

    /// "Move to type ▸": Untagged and every type with a check on the current one, then a new type for this page and the
    /// presets.
    private var moveToTypeMenu: some View {
        Menu {
            ForEach(moveTargets) { column in
                Button {
                    actions.setType(page, column.type)
                } label: {
                    Label(column.menuTitle, systemImage: column.id == columnID ? "checkmark" : (column.type == nil ? "tag.slash" : "tag"))
                }
            }
            Divider()
            Button {
                typeEditor = presets.first.map { SkillTypeEditorRoute.newType(presetID: $0.id) } ?? SkillTypeEditorRoute.newPreset
            } label: {
                Label(presets.isEmpty ? "Make a preset…" : "Add an option…", systemImage: "plus")
            }
            Button {
                showingTypeManager = true
            } label: {
                Label("Manage types…", systemImage: "slider.horizontal.3")
            }
        } label: {
            Label("Move to type", systemImage: "tag")
        }
    }

    /// An "Open link" entry per link; one submenu once the page holds more than a few.
    @ViewBuilder
    private var linkItems: some View {
        if item.links.count > Self.inlineMenuLinks {
            Menu {
                ForEach(item.links) { link in
                    Button {
                        actions.openLink(link.url)
                    } label: {
                        Label(link.menuTitle, systemImage: "link")
                    }
                }
            } label: {
                Label("Open link", systemImage: "link")
            }
        } else {
            ForEach(item.links) { link in
                Button {
                    actions.openLink(link.url)
                } label: {
                    Label("Open link · \(link.menuTitle)", systemImage: "link")
                }
            }
        }
    }
}

/// The glyph of an exercise or a note without a cover: a note's own icon, else what the page is (an exercise wears its
/// workout type's symbol in that type's colour) on a debossed tile.
private struct PageTypeBoardGlyph: View {
    let page: ExercisePage
    var side: CGFloat = 32

    var body: some View {
        Group {
            if let name = page.manifest.iconName, !name.isEmpty {
                SkillIconView(iconName: name, iconType: page.manifest.iconType ?? .emoji, size: side * 0.5)
            } else {
                Image(systemName: page.effectiveWorkoutType?.iconName ?? ContainerPageKind(page).symbolName)
                    .font(.system(size: side * 0.44, weight: .semibold))
                    .foregroundStyle(page.effectiveWorkoutType.map { Color(hex: $0.colorHex) } ?? Theme.toolbarOrange)
            }
        }
        .frame(width: side, height: side)
        .skillTile(cornerRadius: side * 0.32)
        .accessibilityHidden(true)
    }
}

// MARK: - Drop

/// One column of a type board as a drop target: lights up while a card hovers, gives the card the column's type on
/// drop.
struct PageTypeDropDelegate: DropDelegate {
    let column: PageTypeColumn
    let dragging: SkillCardDragState
    let onDrop: (String, PageTypeColumn) -> Bool
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
        return onDrop(id, column)
    }
}

// MARK: - Header controls and sheets

/// The type controls of a board header: a menu with "New type…" (or "Make a preset…" while there is none) and "Manage
/// types…", hosting the sheets they open for the page that keeps the types.
struct PageTypesMenuButton: View {
    let ownerID: String
    let presets: [SkillTypePreset]

    @State private var editor: SkillTypeEditorRoute?
    @State private var showingManager = false

    var body: some View {
        Menu {
            Button {
                editor = presets.first.map { SkillTypeEditorRoute.newType(presetID: $0.id) } ?? SkillTypeEditorRoute.newPreset
            } label: {
                Label(presets.isEmpty ? "Make a preset…" : "New type…", systemImage: "plus")
            }
            Button {
                showingManager = true
            } label: {
                Label("Manage types…", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "tag")
                .font(.system(size: 15, weight: .semibold))
        }
        .menuStyle(.button)
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .menuIndicator(.hidden)
        .accessibilityLabel("Types")
        .accessibilityHint("Make a type or manage the types")
        .help("Types")
        .pageTypeSheets(ownerID: ownerID, editor: $editor, showingManager: $showingManager)
    }
}

extension View {
    /// Hosts the sheets that make or edit a type or a preset of `ownerID` (nothing is put on a page), and the list of
    /// presets. Without an owner nothing opens.
    func pageTypeSheets(ownerID: String?, editor: Binding<SkillTypeEditorRoute?>, showingManager: Binding<Bool>) -> some View {
        modifier(PageTypeSheets(ownerID: ownerID, editor: editor, showingManager: showingManager))
    }
}

private struct PageTypeSheets: ViewModifier {
    @EnvironmentObject private var store: DatabaseStore
    let ownerID: String?
    @Binding var editor: SkillTypeEditorRoute?
    @Binding var showingManager: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $editor) { route in
                if let ownerID {
                    Group {
                        switch route {
                        case .newType, .editType:
                            SkillTypeEditorSheet(rootID: ownerID, route: route)
                        case .newPreset, .editPreset:
                            SkillTypePresetSheet(rootID: ownerID, route: route)
                        }
                    }
                    .environmentObject(store)
                }
            }
            .sheet(isPresented: $showingManager) {
                if let ownerID {
                    SkillTypesManagerSheet(rootID: ownerID)
                        .environmentObject(store)
                }
            }
    }
}
