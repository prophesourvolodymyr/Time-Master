import SwiftUI
import TimeMasterCore

/// How a board shows its sub-skills: the sections list, a status board, or a sortable table.
enum SkillBoardMode: String, CaseIterable, Identifiable {
    case list
    case board
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "List"
        case .board: "Board"
        case .table: "Table"
        }
    }

    var symbolName: String {
        switch self {
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        case .table: "tablecells"
        }
    }

    /// ⌘1 / ⌘2 / ⌘3 on the Mac.
    var shortcutKey: KeyEquivalent {
        switch self {
        case .list: "1"
        case .board: "2"
        case .table: "3"
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

/// The Skills section of a skill page, a container page or a group opened as a page: the "Skills" heading, one slim
/// row with the List · Board · Table switch (remembered per board) and "New section", the status chips with their
/// counts (List and Table), then the sections list, the status board or the table. Opening a sub-skill or a group
/// pushes it onto the navigation stack the screen sits in (`DatabaseNavigationState` of the Database tab, a search
/// sheet or the workout popup).
struct SkillBoardScreen: View {
    /// Tmax orange as `RRGGBB`: the tint of rows, cards and progress.
    static let accentHex = "FF6A00"

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.openURL) private var openURL

    /// A board page's id, or a group id.
    let boardID: String
    /// Draws the "Skills" heading (a host with a heading of its own passes false).
    let showsHeading: Bool
    /// Asks the surrounding scroll view to bring an id into view (rows and sections added at the end).
    let scrollTo: (String) -> Void

    @AppStorage private var modeRaw: String
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

    init(boardID: String, showsHeading: Bool = true, scrollTo: @escaping (String) -> Void = { _ in }) {
        self.boardID = boardID
        self.showsHeading = showsHeading
        self.scrollTo = scrollTo
        _modeRaw = AppStorage(wrappedValue: SkillBoardMode.list.rawValue, SkillSettings.viewModeKeyPrefix + boardID)
    }

    private var mode: SkillBoardMode { SkillBoardMode(rawValue: modeRaw) ?? .list }

    private var modeBinding: Binding<SkillBoardMode> {
        Binding(get: { mode }, set: { modeRaw = $0.rawValue })
    }

    var body: some View {
        let mode = self.mode
        let snapshot = SkillBoardSnapshot(store: store, boardID: boardID, includesNested: mode != .list)
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
                    SkillStatusBoardView(snapshot: snapshot, groupBySection: groupBinding(snapshot), actions: actions(snapshot))
                case .table:
                    SkillTableView(snapshot: snapshot, items: filtered(snapshot.items), statusFilter: filter, actions: actions(snapshot))
                }
            }
        }
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

    @ViewBuilder
    private func header(_ snapshot: SkillBoardSnapshot, mode: SkillBoardMode) -> some View {
        switch mode {
        case .board:
            switcherRow(snapshot, mode: mode)
        case .list, .table:
            VStack(alignment: .leading, spacing: SkillMetrics.s2) {
                switcherRow(snapshot, mode: mode)
                SkillStatusFilterBar(selection: $filter, counts: counts(snapshot, mode: mode))
            }
        }
    }

    /// List · Board · Table, the group toggle (Board) and New section: whatever the view, the section controls sit
    /// beside the view switch. The menu at the end makes a sub-skill with every detail (type, cover, media).
    private func switcherRow(_ snapshot: SkillBoardSnapshot, mode: SkillBoardMode) -> some View {
        HStack(spacing: SkillMetrics.s2) {
            SkillViewModePicker(selection: modeBinding)
            if mode == .board && snapshot.hasSections {
                groupToggle(snapshot)
            }
            if !snapshot.scope.isGroup {
                SkillNewSectionButton { addingSection = true }
            }
            Spacer(minLength: 0)
            if !snapshot.scope.isGroup {
                Menu {
                    Button {
                        showingDetailedCreation = true
                    } label: {
                        Label("New sub-skill with details…", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                }
                .menuStyle(.button)
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .menuIndicator(.hidden)
                .accessibilityLabel("More ways to add")
                .help("More ways to add")
            }
        }
    }

    private func groupToggle(_ snapshot: SkillBoardSnapshot) -> some View {
        let grouped = isGrouped(snapshot)
        return Button {
            groupOverride = !grouped
            EverHaptic.selection()
        } label: {
            Image(systemName: "rectangle.grid.1x2")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(SkillSegmentButtonStyle(isSelected: grouped, fillsWidth: false))
        .skillSegmentTrack()
        .fixedSize()
        .accessibilityLabel("Group by section")
        .accessibilityAddTraits(grouped ? .isSelected : [])
        .help("Group by section")
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

    // MARK: Actions

    private func actions(_ snapshot: SkillBoardSnapshot) -> SkillBoardActions {
        SkillBoardActions(
            open: { page in navigationState.open(skillID: page.manifest.id) },
            setStatus: { page, status in setStatus(page, status) },
            changeIcon: { pageToChangeIcon = SkillPageTarget(id: $0.manifest.id) },
            edit: { pageToEdit = SkillPageTarget(id: $0.manifest.id) },
            moveTo: { pageToMove = SkillPageTarget(id: $0.manifest.id) },
            moveToSection: { page, sectionID in moveToSection(page, sectionID, scope: snapshot.scope) },
            requestDelete: { pageToDelete = $0 },
            openLink: { openURL($0) }
        )
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
