import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// How a board shows its skills.
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

    static var standard: SkillBoardMode {
        #if os(macOS)
        .board
        #else
        .list
        #endif
    }
}

/// The skills of one board page, or of one group opened as a page: List · Board · Table, groups as tinted panels
/// with their own strip, types on every card, drag to move between columns and groups.
struct SkillBoardScreen: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState

    /// A board page's id, or a group id.
    let boardID: String
    /// Whether the List · Board · Table switch and the add menu show (a page embeds the screen with its own title).
    var showsToolbar = true

    @State private var mode: SkillBoardMode = .standard
    @State private var folded: Set<String> = []
    @State private var draggedPageID: String?
    @State private var groupEditor: SkillGroupEditorSheet.Mode?
    @State private var pageToDelete: ExercisePage?
    @State private var groupToDelete: SkillBoardSection?
    @State private var showingDetailedCreation = false
    @State private var quickAddLane: String?

    private let looseLaneID = "ungrouped"

    private var isGroupBoard: Bool { SkillGroupID.split(boardID) != nil }
    private var container: ExercisePage? { isGroupBoard ? nil : store.page(manifestID: boardID) }
    private var groups: [SkillBoardSection] { store.skillGroups(of: boardID) }

    private struct Lane: Identifiable {
        let section: SkillBoardSection?
        let pages: [ExercisePage]
        var id: String { section?.id ?? "ungrouped" }
    }

    private var lanes: [Lane] {
        if isGroupBoard {
            return [Lane(section: nil, pages: store.orderedByTypeRules(store.skillBoardPages(of: boardID), boardID: boardID))]
        }
        var result: [Lane] = []
        let loose = store.skillPages(onBoard: boardID, sectionID: nil)
        if !loose.isEmpty || groups.isEmpty {
            result.append(Lane(section: nil, pages: store.orderedByTypeRules(loose, boardID: boardID)))
        }
        for group in groups {
            result.append(Lane(section: group, pages: store.orderedByTypeRules(store.skillPages(onBoard: boardID, sectionID: group.id), boardID: boardID)))
        }
        return result
    }

    private var allPages: [ExercisePage] { store.skillBoardPages(of: boardID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsToolbar { toolbarRow }
            if quickAddLane == looseLaneID {
                SkillQuickAddRow(boardID: boardID, sectionID: nil)
            }
            if mode == .table {
                SkillTableView(pages: store.orderedByTypeRules(allPages, boardID: boardID), context: context)
            } else {
                ForEach(lanes) { lane in
                    laneView(lane)
                }
                if allPages.isEmpty && groups.isEmpty {
                    emptyState
                }
            }
        }
        .onAppear { mode = restoredMode() }
        .onChange(of: mode) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: SkillSettings.viewModeKeyPrefix + boardID)
        }
        .sheet(item: $groupEditor) { editorMode in
            SkillGroupEditorSheet(containerID: boardID, mode: editorMode)
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
            "Delete this skill?",
            isPresented: Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } }),
            titleVisibility: .visible,
            presenting: pageToDelete
        ) { page in
            Button("Delete “\(page.title)”", role: .destructive) {
                SkillErrorCenter.shared.attempt("Delete the skill") { try store.deletePage(id: page.manifest.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its notes, files and sub-skills go with it.")
        }
        .confirmationDialog(
            "Delete this group?",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } }),
            titleVisibility: .visible,
            presenting: groupToDelete
        ) { group in
            Button("Delete “\(group.title)”", role: .destructive) {
                SkillErrorCenter.shared.attempt("Delete the group") {
                    try store.deleteSkillGroup(containerID: boardID, sectionID: group.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its skills stay on the board, outside any group. The group's own notes and files are removed.")
        }
    }

    // MARK: Toolbar

    private var toolbarRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(availableModes) { option in
                    SkillChoicePill(title: option.title, isSelected: mode == option) {
                        withAnimation(.easeInOut(duration: 0.18)) { mode = option }
                    }
                    .fixedSize()
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button { quickAddLane = quickAddLane == looseLaneID ? nil : looseLaneID } label: {
                    Label("Quick add", systemImage: "plus")
                }
                if !isGroupBoard {
                    Button { showingDetailedCreation = true } label: {
                        Label("New skill with details…", systemImage: "square.and.pencil")
                    }
                    Button { groupEditor = .new } label: {
                        Label("New group…", systemImage: "square.grid.2x2")
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
            }
            .menuStyle(.button)
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .menuIndicator(.hidden)
            .accessibilityLabel("Add to this board")
        }
    }

    private var availableModes: [SkillBoardMode] { SkillBoardMode.allCases }

    private func restoredMode() -> SkillBoardMode {
        let raw = UserDefaults.standard.string(forKey: SkillSettings.viewModeKeyPrefix + boardID)
        let stored = raw.flatMap(SkillBoardMode.init(rawValue:)) ?? .standard
        return availableModes.contains(stored) ? stored : .standard
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing here yet")
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textPrimary)
            Text("Add a skill, or make a group to sort them.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            SkillQuickAddRow(boardID: boardID, sectionID: nil)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Lanes

    private var context: SkillBoardContext {
        SkillBoardContext(
            boardID: boardID,
            groups: groups,
            open: { page in navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id)) },
            requestDelete: { pageToDelete = $0 },
            beginDrag: { page in
                draggedPageID = page.manifest.id
                return NSItemProvider(object: page.manifest.id as NSString)
            },
            dropBefore: { target in
                guard let dragged = draggedPageID, dragged != target.manifest.id else { return }
                draggedPageID = nil
                place(dragged, status: target.manifest.skillStatus ?? .notStarted, sectionID: store.skillSectionID(of: target), before: target.manifest.id)
            }
        )
    }

    private func place(_ pageID: String, status: SkillStatus, sectionID: String?, before: String?) {
        SkillErrorCenter.shared.attempt("Move the skill") {
            try store.placeSkillPage(pageID, status: status, sectionID: .some(sectionID), before: before)
        }
    }

    @ViewBuilder
    private func laneView(_ lane: Lane) -> some View {
        if let section = lane.section, let container {
            let isFolded = folded.contains(section.id)
            SkillGroupSurface(section: section, imageURL: store.skillGroupImageURL(container: container, section: section)) {
                VStack(alignment: .leading, spacing: 10) {
                    SkillGroupHeader(
                        container: container,
                        section: section,
                        count: lane.pages.count,
                        isCollapsed: isFolded,
                        onToggle: { withAnimation(.easeInOut(duration: 0.2)) { toggleFold(section.id) } },
                        onOpen: { navigationState.path.append(DatabaseSkillGroupRoute(containerID: container.manifest.id, sectionID: section.id)) },
                        onEdit: { groupEditor = .edit(section) },
                        onAddSkill: { quickAddLane = section.id; folded.remove(section.id) },
                        onDelete: { groupToDelete = section }
                    )
                    if !isFolded {
                        if quickAddLane == section.id {
                            SkillQuickAddRow(boardID: boardID, sectionID: section.id)
                                .padding(.horizontal, 10)
                        }
                        laneBody(lane)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !groups.isEmpty, !isGroupBoard {
                    Text("Outside any group")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                laneBody(lane)
            }
        }
    }

    private func toggleFold(_ id: String) {
        if folded.contains(id) { folded.remove(id) } else { folded.insert(id) }
    }

    @ViewBuilder
    private func laneBody(_ lane: Lane) -> some View {
        switch mode {
        case .list, .table:
            listBody(lane)
        case .board:
            boardBody(lane)
        }
    }

    private func listBody(_ lane: Lane) -> some View {
        let ctx = context
        return VStack(spacing: 8) {
            if lane.pages.isEmpty {
                dropHint(lane: lane, status: .notStarted)
            }
            ForEach(lane.pages) { page in
                SkillBoardRow(page: page, context: ctx)
            }
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            drop(on: lane, status: nil)
        }
    }

    private func boardBody(_ lane: Lane) -> some View {
        let statuses = SkillStatus.boardOrder.filter { status in
            status != .abandoned || lane.pages.contains { ($0.manifest.skillStatus ?? .notStarted) == .abandoned }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(statuses, id: \.self) { status in
                    column(status, lane: lane).frame(minWidth: 230)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(statuses, id: \.self) { status in
                        column(status, lane: lane).frame(width: 270)
                    }
                }
            }
        }
    }

    private func column(_ status: SkillStatus, lane: Lane) -> some View {
        let ctx = context
        let pages = lane.pages.filter { ($0.manifest.skillStatus ?? .notStarted) == status }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: status.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                Text(status.title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                Text("\(pages.count)")
                    .font(TimeMasterFont.caption())
                    .opacity(0.7)
            }
            .foregroundStyle(status.color)
            .padding(.horizontal, 4)
            ForEach(pages) { page in
                SkillBoardCard(page: page, context: ctx)
            }
            if pages.isEmpty {
                dropHint(lane: lane, status: status)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            drop(on: lane, status: status)
        }
    }

    private func dropHint(lane: Lane, status: SkillStatus) -> some View {
        Text("Drop skills here")
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
    }

    /// A drop on the empty part of a column or list: the skill goes to the end of it.
    private func drop(on lane: Lane, status: SkillStatus?) -> Bool {
        guard let dragged = draggedPageID else { return false }
        draggedPageID = nil
        let current = store.page(manifestID: dragged)?.manifest.skillStatus ?? .notStarted
        let sectionID = isGroupBoard ? store.page(manifestID: dragged).flatMap { store.skillSectionID(of: $0) } : lane.section?.id
        place(dragged, status: status ?? current, sectionID: sectionID, before: nil)
        return true
    }
}
