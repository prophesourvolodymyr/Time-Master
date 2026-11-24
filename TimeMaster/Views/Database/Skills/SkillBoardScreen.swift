import SwiftUI
import TimeMasterCore

/// How a board shows its sub-skills: the sections list, a status board, a sortable table, or (on a skill) the tiers of the
/// exercises that train it.
enum SkillBoardMode: String, CaseIterable, Identifiable {
    case list
    case board
    case table
    case tiers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "List"
        case .board: "Board"
        case .table: "Table"
        case .tiers: "Tiers"
        }
    }

    var symbolName: String {
        switch self {
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        case .table: "tablecells"
        case .tiers: "rosette"
        }
    }

    /// ⌘1 / ⌘2 / ⌘3 / ⌘4 on the Mac.
    var shortcutKey: KeyEquivalent {
        switch self {
        case .list: "1"
        case .board: "2"
        case .table: "3"
        case .tiers: "4"
        }
    }

    /// Tooltip: the name, plus its shortcut on the Mac.
    var helpText: String {
        #if os(macOS)
        return "\(title) (⌘\(shortcutKey.character))"
        #else
        return title
        #endif
    }
}

/// The Skills section of a skill page, a container page or a group opened as a page: the "Skills" heading, one row of
/// round corner buttons (View, Group by, Filter, New section, more ways to add; each opens its own menu), then the
/// sections list, the status board or the table. The board of a skill or a tutorial can also group its columns by type
/// (Group by, remembered per board; Status by default). Opening a sub-skill or a group pushes it onto the navigation
/// stack the screen sits in (`DatabaseNavigationState` of the Database tab, a search sheet or the workout popup).
struct SkillBoardScreen: View {
    /// Tmax orange as `RRGGBB`: the tint of rows, cards and progress.
    static let accentHex = "FF6A00"

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A board page's id, or a group id.
    let boardID: String
    /// Draws the "Skills" heading (a host with a heading of its own passes false).
    let showsHeading: Bool
    /// Asks the surrounding scroll view to bring an id into view (rows and sections added at the end).
    let scrollTo: (String) -> Void

    @AppStorage private var modeRaw: String
    @AppStorage private var groupingRaw: String

    @State private var filter: SkillStatus?
    @State private var groupOverride: Bool?
    @State private var addingSection = false
    @State private var sectionToEdit: SkillBoardSection?
    @State private var sectionToDelete: SkillBoardSection?
    @State private var pageToEdit: SkillPageTarget?
    @State private var pageToChangeIcon: SkillPageTarget?
    @State private var pageToMove: SkillPageTarget?
    @State private var pageToDelete: ExercisePage?
    @State private var showingDetailedCreation = false
    /// `path.count` of the screen the board sits on, read when it appears.
    @State private var stackDepth = 0

    init(boardID: String, showsHeading: Bool = true, scrollTo: @escaping (String) -> Void = { _ in }) {
        self.boardID = boardID
        self.showsHeading = showsHeading
        self.scrollTo = scrollTo
        _modeRaw = AppStorage(wrappedValue: SkillBoardMode.board.rawValue, SkillSettings.viewModeKeyPrefix + boardID)
        _groupingRaw = AppStorage(wrappedValue: SkillBoardGrouping.status.rawValue, SkillSettings.groupByKeyPrefix + boardID)
    }

    private var mode: SkillBoardMode { SkillBoardMode(rawValue: modeRaw) ?? .board }

    private var grouping: SkillBoardGrouping { SkillBoardGrouping(rawValue: groupingRaw) ?? .status }

    var body: some View {
        let mode = self.mode
        let snapshot = SkillBoardSnapshot(store: store, boardID: boardID, includesNested: mode != .list)
        let typeSnapshot = showsTypes(snapshot) ? PageTypeBoardSnapshot(skills: snapshot, store: store) : nil
        let shownIDs = siblingIDs(snapshot, types: typeSnapshot)
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            if showsHeading {
                SkillSectionHeading(symbol: "square.grid.2x2", title: "Skills", count: snapshot.direct.count)
            }
            VStack(alignment: .leading, spacing: SkillMetrics.s3) {
                header(snapshot, mode: mode)
                switch mode {
                case .list:
                    SkillBoardListView(
                        snapshot: snapshot,
                        statusFilter: filter,
                        actions: actions(snapshot),
                        onEditSection: { sectionToEdit = $0 },
                        onDeleteSection: { sectionToDelete = $0 },
                        scrollTo: scrollTo
                    )
                case .board:
                    if let typeSnapshot {
                        PageTypeBoardView(
                            snapshot: typeSnapshot,
                            actions: typeActions(snapshot),
                            newPage: .named(placeholder: "New", create: { title, type in addTyped(title, type, scope: snapshot.scope) })
                        )
                    } else {
                        SkillStatusBoardView(snapshot: snapshot, groupBySection: groupBinding(snapshot), actions: actions(snapshot))
                    }
                case .table:
                    SkillTableView(snapshot: snapshot, items: filtered(snapshot.items), statusFilter: filter, actions: actions(snapshot))
                case .tiers:
                    SkillTierBoardView(skillID: snapshot.scope.boardID)
                }
                if mode == .board, snapshot.container?.isSkillLike == true, !snapshot.scope.isGroup {
                    SkillTierBoardView(skillID: snapshot.scope.boardID, embedded: true)
                }
            }
        }
        .onAppear {
            stackDepth = navigationState.path.count
            offerSiblings(shownIDs, scope: snapshot.scope)
        }
        .onChange(of: shownIDs) { offerSiblings($0, scope: snapshot.scope) }
        .sheet(isPresented: $addingSection) {
            SkillSectionEditorSheet(
                boardID: snapshot.scope.containerID,
                suggestedColorHex: SkillColors.random(avoiding: snapshot.sections.compactMap(\.colorHex)),
                onCreated: { _ in sectionCreated() }
            )
            .environmentObject(store)
        }
        .sheet(item: $sectionToEdit) { section in
            SkillSectionEditorSheet(boardID: snapshot.scope.containerID, section: section)
                .environmentObject(store)
        }
        .sheet(item: $pageToEdit) { target in
            if let page = store.page(manifestID: target.id) {
                PageCreationSheet(page: page) { manifest, _ in
                    try store.updatePage(id: page.manifest.id, manifest: manifest, newParentID: manifest.parentID)
                }
                .environmentObject(store)
                .environmentObject(workoutStore)
            }
        }
        .sheet(item: $pageToChangeIcon) { target in
            SkillIconChooserSheet(pageID: target.id)
                .environmentObject(store)
        }
        .sheet(item: $pageToMove) { target in
            SkillMovePickerSheet(pageID: target.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingDetailedCreation) {
            PageCreationSheet(parentID: boardID, initialPageType: .skill) { manifest, parentID in
                try store.createPage(manifest: manifest, parentID: parentID)
            } onSaveWithMedia: { manifest, parentID, coverData, mediaData in
                try store.createPageWithMedia(manifest: manifest, parentID: parentID, coverData: coverData, mediaData: mediaData)
            }
            .environmentObject(store)
            .environmentObject(workoutStore)
        }
        .confirmationDialog(
            "Delete this sub-skill?",
            isPresented: Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } }),
            titleVisibility: .visible,
            presenting: pageToDelete
        ) { page in
            Button("Delete “\(page.title)”", role: .destructive) {
                if SkillErrorCenter.shared.attempt("Delete the sub-skill", { try store.deletePage(id: page.manifest.id) }) {
                    EverHaptic.warning()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its notes, files and sub-skills go with it.")
        }
        .confirmationDialog(
            "Delete this section?",
            isPresented: Binding(get: { sectionToDelete != nil }, set: { if !$0 { sectionToDelete = nil } }),
            titleVisibility: .visible,
            presenting: sectionToDelete
        ) { section in
            Button("Delete “\(section.title)”", role: .destructive) {
                SkillErrorCenter.shared.attempt("Delete the section") {
                    try store.deleteSkillGroup(containerID: snapshot.scope.containerID, sectionID: section.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its sub-skills stay on the board, outside any section. The section's own notes and files are removed.")
        }
    }

    // MARK: Header

    /// One row of round corner buttons, always in view, each with its own dropdown where it fits: View, Group by (Board),
    /// Filter (List and Table), the type controls (Board by type), New section and the extra ways to add a sub-skill.
    private func header(_ snapshot: SkillBoardSnapshot, mode: SkillBoardMode) -> some View {
        let modes = availableModes(snapshot)
        return HStack(spacing: SkillMetrics.s2) {
            Spacer(minLength: 0)
            viewMenu(modes: modes, mode: mode)
            if mode == .board {
                if showsGroupMenu(snapshot) {
                    groupMenu(snapshot)
                }
                if grouping == .type, supportsTypeGrouping(snapshot), let owner = store.skillTypeOwner(of: snapshot.scope.boardID) {
                    PageTypesMenuButton(ownerID: owner.manifest.id, presets: store.skillTypePresets(for: owner.manifest.id))
                }
            }
            if mode == .list || mode == .table {
                filterMenu(snapshot, mode: mode)
            }
            if !snapshot.scope.isGroup {
                SkillCornerButton(
                    symbol: "plus",
                    title: "New section",
                    hint: "Adds a coloured group for your sub-skills",
                    prominent: true
                ) { addingSection = true }
                moreMenu
            }
        }
        .skillViewShortcuts(modes: modes) { select($0) }
    }

    private func viewMenu(modes: [SkillBoardMode], mode: SkillBoardMode) -> some View {
        SkillCornerMenu(symbol: mode.symbolName, title: "View", value: mode.title) {
            ForEach(modes) { option in
                Button {
                    select(option)
                } label: {
                    Label(option.title, systemImage: option == mode ? "checkmark" : option.symbolName)
                }
            }
        }
    }

    private func groupMenu(_ snapshot: SkillBoardSnapshot) -> some View {
        let grouped = isGrouped(snapshot)
        return SkillCornerMenu(symbol: "rectangle.3.group", title: "Group by", value: grouping.title) {
            if supportsTypeGrouping(snapshot) {
                SwiftUI.Section("Group by") {
                    ForEach(SkillBoardGrouping.allCases) { option in
                        Button {
                            setGrouping(option)
                        } label: {
                            Label(option.title, systemImage: option == grouping ? "checkmark" : option.symbolName)
                        }
                    }
                }
            }
            if snapshot.hasSections && !showsTypes(snapshot) {
                Button {
                    groupOverride = !grouped
                    EverHaptic.selection()
                } label: {
                    Label("By section", systemImage: grouped ? "checkmark" : "rectangle.grid.1x2")
                }
            }
        }
    }

    private func filterMenu(_ snapshot: SkillBoardSnapshot, mode: SkillBoardMode) -> some View {
        let tally = counts(snapshot, mode: mode)
        let total = SkillStatus.boardOrder.reduce(0) { $0 + (tally[$1] ?? 0) }
        return SkillCornerMenu(symbol: "line.3.horizontal.decrease.circle", title: "Filter", value: filter?.title ?? "All", isActive: filter != nil) {
            Button {
                setFilter(nil)
            } label: {
                Label("All (\(total))", systemImage: filter == nil ? "checkmark" : "tray.full")
            }
            ForEach(SkillStatus.boardOrder, id: \.self) { status in
                Button {
                    setFilter(status)
                } label: {
                    Label("\(status.title) (\(tally[status] ?? 0))", systemImage: filter == status ? "checkmark" : status.symbolName)
                }
            }
        }
    }

    private var moreMenu: some View {
        SkillCornerMenu(symbol: "ellipsis", title: "More ways to add") {
            Button {
                showingDetailedCreation = true
            } label: {
                Label("New sub-skill with details…", systemImage: "square.and.pencil")
            }
        }
    }

    private func availableModes(_ snapshot: SkillBoardSnapshot) -> [SkillBoardMode] {
        let tiers = snapshot.container?.isSkillLike == true && !snapshot.scope.isGroup
        return SkillBoardMode.allCases.filter { tiers || $0 != .tiers }
    }

    private func showsGroupMenu(_ snapshot: SkillBoardSnapshot) -> Bool {
        supportsTypeGrouping(snapshot) || (snapshot.hasSections && !showsTypes(snapshot))
    }

    private func select(_ mode: SkillBoardMode) {
        guard mode != self.mode else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { modeRaw = mode.rawValue }
        EverHaptic.selection()
    }

    private func setGrouping(_ option: SkillBoardGrouping) {
        guard option != grouping else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { groupingRaw = option.rawValue }
        EverHaptic.selection()
    }

    private func setFilter(_ status: SkillStatus?) {
        guard filter != status else { return }
        filter = status
        EverHaptic.selection()
    }

    // MARK: Data

    /// The list counts the board's own sub-skills; the table counts every depth.
    private func counts(_ snapshot: SkillBoardSnapshot, mode: SkillBoardMode) -> [SkillStatus: Int] {
        SkillBoardSnapshot.counts(of: mode == .table ? snapshot.items : snapshot.direct)
    }

    private func filtered(_ items: [SkillBoardItem]) -> [SkillBoardItem] {
        guard let filter else { return items }
        return items.filter { $0.status == filter }
    }

    /// Swimlanes by default once two sections hold sub-skills.
    private func isGrouped(_ snapshot: SkillBoardSnapshot) -> Bool {
        groupOverride ?? (snapshot.sectionsWithPages >= 2)
    }

    private func groupBinding(_ snapshot: SkillBoardSnapshot) -> Binding<Bool> {
        Binding(get: { isGrouped(snapshot) }, set: { groupOverride = $0 })
    }

    /// A section made from the header shows at once on the board too (swimlanes only appear by themselves once two
    /// sections hold sub-skills).
    private func sectionCreated() {
        if mode == .board { groupOverride = true }
    }

    /// Type grouping needs one pool of types: the board of a skill or a tutorial (or of one of its groups). On a plain
    /// folder every skill keeps its own types, so its board stays by status.
    private func supportsTypeGrouping(_ snapshot: SkillBoardSnapshot) -> Bool {
        snapshot.container?.isSkillLike == true
    }

    /// The Board view shows its columns by type.
    private func showsTypes(_ snapshot: SkillBoardSnapshot) -> Bool {
        mode == .board && grouping == .type && supportsTypeGrouping(snapshot)
    }

    // MARK: Previous and Next

    /// The sub-skills in the order this view shows them, what Previous and Next walk on a page opened from here: the
    /// list's own sub-skills lane by lane and the table's rows (the status filter applied), the status board column by
    /// column (lane by lane in swimlanes), the type board in its reading order.
    private func siblingIDs(_ snapshot: SkillBoardSnapshot, types: PageTypeBoardSnapshot?) -> [String] {
        switch mode {
        case .list:
            return filtered(snapshot.direct).map(\.id)
        case .table:
            return filtered(snapshot.items).map(\.id)
        case .tiers:
            return store.trainers(of: snapshot.scope.boardID).map(\.id)
        case .board:
            if let types { return types.readingOrder }
            let laneKeys: [String?] = isGrouped(snapshot) && snapshot.hasSections ? snapshot.boardLanes.map { Optional($0.key) } : [nil]
            return laneKeys.flatMap { key in
                let items = snapshot.items(inLane: key)
                return SkillStatus.boardOrder.flatMap { status in items.filter { $0.status == status }.map(\.id) }
            }
        }
    }

    private func offerSiblings(_ ids: [String], scope: SkillBoardScope) {
        navigationState.offerSiblings(ids, containerID: scope.containerID, surface: "skill-board", depth: stackDepth)
    }

    // MARK: Actions

    private func actions(_ snapshot: SkillBoardSnapshot) -> SkillBoardActions {
        SkillBoardActions(
            open: { page in navigationState.open(skillID: page.manifest.id) },
            openFromCover: { page in PageCoverOpening.open(page, in: navigationState) },
            setStatus: { page, status in setStatus(page, status) },
            changeIcon: { pageToChangeIcon = SkillPageTarget(id: $0.manifest.id) },
            edit: { pageToEdit = SkillPageTarget(id: $0.manifest.id) },
            moveTo: { pageToMove = SkillPageTarget(id: $0.manifest.id) },
            moveToSection: { page, sectionID in moveToSection(page, sectionID, scope: snapshot.scope) },
            requestDelete: { pageToDelete = $0 },
            openLink: { openURL($0) }
        )
    }

    /// The type board's cards: the same writes and sheets as the status board, plus the type a drop or the menu gives and
    /// the cover a gallery card opens.
    private func typeActions(_ snapshot: SkillBoardSnapshot) -> PageTypeBoardActions {
        let base = actions(snapshot)
        return PageTypeBoardActions(
            open: base.open,
            openFromCover: { page in PageCoverOpening.open(page, in: navigationState) },
            setType: { page, type in setType(page, type) },
            setStatus: base.setStatus,
            changeIcon: base.changeIcon,
            addToWorkout: nil,
            edit: base.edit,
            moveTo: base.moveTo,
            requestDelete: base.requestDelete,
            openLink: base.openLink
        )
    }

    private func setType(_ page: ExercisePage, _ type: SkillType?) {
        guard page.manifest.typeID != type?.id else { return }
        if SkillErrorCenter.shared.attempt("Change the type", { try store.setSkillType(type?.id, for: page.manifest.id) }) {
            EverHaptic.selection()
        }
    }

    /// "New" at the foot of a type column: the sub-skill starts outside every group, wearing the column's type.
    private func addTyped(_ title: String, _ type: SkillType?, scope: SkillBoardScope) -> Bool {
        let added = SkillErrorCenter.shared.attempt("Add the sub-skill") {
            let id = try store.createBoardSkill(title: title, on: scope.boardID, sectionID: nil, status: .notStarted)
            if let type { try store.setSkillType(type.id, for: id) }
        }
        if added { EverHaptic.selection() }
        return added
    }

    private func setStatus(_ page: ExercisePage, _ status: SkillStatus) {
        guard (page.manifest.skillStatus ?? .notStarted) != status else { return }
        if SkillErrorCenter.shared.attempt("Change the status", { try store.setSkillStatus(status, for: page.manifest.id) }) {
            if status == .completed { EverHaptic.success() } else { EverHaptic.selection() }
        }
    }

    private func moveToSection(_ page: ExercisePage, _ sectionID: String?, scope: SkillBoardScope) {
        let stored = scope.storedSectionID(forLane: sectionID)
        if SkillErrorCenter.shared.attempt("Move the sub-skill", { try store.placeSkillPage(page.manifest.id, sectionID: .some(stored)) }) {
            EverHaptic.selection()
        }
    }
}

/// A page a sheet is about (by manifest id, so the sheet survives the page being reloaded).
struct SkillPageTarget: Identifiable, Equatable {
    let id: String
}
