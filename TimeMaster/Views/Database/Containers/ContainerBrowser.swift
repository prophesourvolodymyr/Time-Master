import SwiftUI
import TimeMasterCore

/// One tab of a container (its exercises, notes and containers, or its skills) laid out the way Skillmax lists a
/// library, in Tmax colours: a search field that filters as you type across everything inside (nested pages show
/// where they sit), a gallery of big covers or a list (or, for skills, the container's own board), a sort menu, status
/// filters with counts and groups for skills, the page menu on every card and drops onto containers.
struct ContainerBrowser: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ContainerBrowseModel
    let tab: ContainerChildTab
    /// What the tab lists: its pages, or its search hits while `query` holds text.
    let entries: [ContainerBrowseEntry]
    @Binding var query: String
    /// Search hits on the container's other tab; nil where there is no other tab.
    var otherTab: ContainerOtherTabHits? = nil

    @AppStorage(ContainerBrowseSettings.exercisesLayoutKey) private var exercisesLayout = ContainerBrowseLayout.gallery
    @AppStorage(ContainerBrowseSettings.skillsLayoutKey) private var skillsLayout = ContainerBrowseLayout.gallery
    @AppStorage(ContainerBrowseSettings.exercisesSortKey) private var exercisesSort = ContainerBrowseSort.manual
    @AppStorage(ContainerBrowseSettings.skillsSortKey) private var skillsSort = ContainerBrowseSort.manual
    @AppStorage(ContainerBrowseSettings.skillGroupingKey) private var grouping = ContainerSkillGrouping.status

    @State private var statusFilter: SkillStatus?
    @State private var folded: Set<String> = []
    @State private var creation: PageCreationRequest?
    @State private var naming = ContainerNewPageKind.skill
    @State private var isNaming = false
    @State private var newName = ""
    @State private var stackDepth = 0
    @State private var pageDrag: PageDragSource?
    @FocusState private var searchFocused: Bool

    private static let searchFieldID = "container-search"
    private static let listSpacing: CGFloat = 10
    private static let gridSpacing: CGFloat = 14

    private var container: ExercisePage { model.container }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedQuery.isEmpty }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86) }

    private var layout: ContainerBrowseLayout {
        let stored = tab == .skills ? skillsLayout : exercisesLayout
        return layoutOptions.contains(stored) ? stored : .gallery
    }

    private var layoutOptions: [ContainerBrowseLayout] {
        ContainerBrowseLayout.options(for: tab, holdsExercises: model.holdsExercises)
    }

    private var sort: ContainerBrowseSort {
        let stored = tab == .skills ? skillsSort : exercisesSort
        return ContainerBrowseSort.options(for: tab).contains(stored) ? stored : .manual
    }

    /// A board stands in for the cards (a search still shows cards): the container's skill board on the Skills tab, its
    /// exercises and notes by tag on the Exercises tab.
    private var showsBoard: Bool { layout == .board && !isSearching }
    private var showsStatusFilter: Bool { tab == .skills && !showsBoard && !entries.isEmpty }
    private var showsNewCell: Bool { !isSearching && (tab != .skills || statusFilter == nil) }
    /// Cards take new places by dragging on the Exercises tab, in its manual order, while not searching.
    private var reorders: Bool { tab == .exercises && sort == .manual && !isSearching }

    var body: some View {
        let progress = tab == .skills ? skillProgress() : [:]
        let shown = shownEntries(progress: progress)
        ScrollViewReader { proxy in
            ContainerPageActionHost { actions in
                VStack(alignment: .leading, spacing: 12) {
                    ContainerSearchField(text: $query, prompt: "Search \(container.title)", isFocused: $searchFocused)
                        .id(Self.searchFieldID)
                    controls(shownCount: shown.count)
                    if showsStatusFilter {
                        ContainerStatusFilterBar(selection: statusBinding, counts: ContainerBrowseModel.statusCounts(entries))
                    }
                    content(shown, progress: progress, actions: actions, proxy: proxy)
                }
            }
            .findCommand {
                guard navigationState.path.count == stackDepth, creation == nil, !isNaming else { return false }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.searchFieldID, anchor: .top)
                }
                searchFocused = true
                return true
            }
        }
        .onAppear {
            stackDepth = navigationState.path.count
            offerSiblings(showsBoard ? [] : siblingIDs(shown))
        }
        .onChange(of: showsBoard ? [] : siblingIDs(shown)) { offerSiblings($0) }
        .sheet(item: $creation) { request in
            PageCreationSheet(parentID: request.parentID, initialPageType: request.pageType) { manifest, parentID in
                try store.createPage(manifest: manifest, parentID: parentID)
            } onSaveWithMedia: { manifest, parentID, coverData, mediaData in
                try store.createPageWithMedia(
                    manifest: manifest,
                    parentID: parentID,
                    coverData: coverData,
                    mediaData: mediaData
                )
            }
            .environmentObject(workoutStore)
            .environmentObject(store)
        }
        .alert(naming.title, isPresented: $isNaming) {
            TextField(naming.placeholder, text: $newName)
            Button("Create") { createNamed() }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }

    // MARK: Controls

    private func controls(shownCount: Int) -> some View {
        HStack(spacing: 8) {
            Text(summary(shownCount: shownCount))
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            ContainerLayoutPicker(selection: layoutBinding, options: layoutOptions)
            if !showsBoard {
                sortMenu
                addMenu
            } else if tab == .exercises {
                typesMenu
                addMenu
            }
        }
    }

    private func summary(shownCount: Int) -> String {
        if isSearching { return Self.count(entries.count, "match", "matches") }
        let all = tab == .skills ? Self.count(entries.count, "skill", "skills") : Self.count(entries.count, "page", "pages")
        return showsStatusFilter && statusFilter != nil ? "\(shownCount) of \(all)" : all
    }

    private static func count(_ value: Int, _ one: String, _ many: String) -> String {
        value == 1 ? "1 \(one)" : "\(value) \(many)"
    }

    private var sortMenu: some View {
        Menu {
            SwiftUI.Section("Sort by") {
                ForEach(ContainerBrowseSort.options(for: tab)) { option in
                    Button {
                        setSort(option)
                    } label: {
                        Label(option.title, systemImage: option == sort ? "checkmark" : option.systemImage)
                    }
                }
            }
            if tab == .skills {
                SwiftUI.Section("Group by") {
                    ForEach(ContainerSkillGrouping.allCases) { option in
                        Button {
                            setGrouping(option)
                        } label: {
                            Label(option.title, systemImage: option == grouping ? "checkmark" : option.systemImage)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .bold))
        }
        .menuStyle(.button)
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .menuIndicator(.hidden)
        .accessibilityLabel(tab == .skills ? "Sort and group" : "Sort")
        .accessibilityValue(sort.title)
        .help("Sort: \(sort.title)")
    }

    private var addMenu: some View {
        Menu {
            if tab == .skills {
                Button {
                    beginNaming(.skill)
                } label: {
                    Label("New Skill", systemImage: "flag.checkered")
                }
                Button {
                    creation = PageCreationRequest(pageType: .skill, parentID: container.manifest.id)
                } label: {
                    Label("New Skill with Details…", systemImage: "square.and.pencil")
                }
                Button {
                    creation = PageCreationRequest(pageType: .tutorial, parentID: container.manifest.id)
                } label: {
                    Label("New Tutorial…", systemImage: "book.closed")
                }
            } else {
                Button {
                    creation = PageCreationRequest(pageType: .exercise, parentID: container.manifest.id)
                } label: {
                    Label("New Exercise…", systemImage: "figure.run")
                }
                Button {
                    beginNaming(.note)
                } label: {
                    Label("New Note", systemImage: "note.text")
                }
                Button {
                    beginNaming(.container)
                } label: {
                    Label("New Container", systemImage: "folder.badge.plus")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
        }
        .menuStyle(.button)
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
        .menuIndicator(.hidden)
        .accessibilityLabel(tab == .skills ? "Add a skill" : "Add a page")
        .help(tab == .skills ? "Add a skill" : "Add a page")
    }

    /// The Exercises board's type menu: make a tag (a preset first while there is none) or manage the tags of the folder's
    /// top page.
    @ViewBuilder
    private var typesMenu: some View {
        if let owner = store.tagRoot(of: container) {
            PageTypesMenuButton(ownerID: owner.manifest.id, presets: store.skillTypePresets(for: owner.manifest.id))
        }
    }

    // MARK: Previous and Next

    /// The pages this tab shows, in the order they show (sections in their order on the grouped Skills tab): what
    /// Previous and Next walk on a page opened from here.
    private func siblingIDs(_ shown: [ContainerBrowseEntry]) -> [String] {
        guard tab == .skills, grouping != .flat else { return shown.map(\.id) }
        return model.sections(of: shown, by: grouping).flatMap(\.entries).map(\.id)
    }

    private func offerSiblings(_ ids: [String]) {
        navigationState.offerSiblings(ids, containerID: container.manifest.id, surface: "browser", depth: stackDepth)
    }

    // MARK: Content

    @ViewBuilder
    private func content(
        _ shown: [ContainerBrowseEntry],
        progress: [String: SkillProgress],
        actions: ContainerPageActions,
        proxy: ScrollViewProxy
    ) -> some View {
        if showsBoard {
            if tab == .skills {
                SkillBoardScreen(boardID: container.manifest.id, showsHeading: false) { id in
                    withAnimation(motion) { proxy.scrollTo(id) }
                }
            } else {
                ContainerTypeBoard(folder: container, actions: actions)
            }
        } else if isSearching && entries.isEmpty {
            searchEmptyState
        } else if entries.isEmpty {
            emptyState(actions: actions)
        } else if tab == .skills, shown.isEmpty, let statusFilter {
            filterEmptyState(statusFilter)
        } else {
            if tab == .skills, grouping != .flat {
                sectionsView(shown, progress: progress, actions: actions)
            } else {
                cells(shown, progress: progress, actions: actions, includesNewCell: showsNewCell)
            }
            if let otherTab, otherTab.count > 0 {
                otherTabButton(otherTab)
            }
        }
    }

    private func sectionsView(
        _ shown: [ContainerBrowseEntry],
        progress: [String: SkillProgress],
        actions: ContainerPageActions
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(model.sections(of: shown, by: grouping)) { section in
                let isFolded = folded.contains(section.id)
                VStack(alignment: .leading, spacing: 8) {
                    ContainerSectionHeader(
                        symbol: section.symbolName,
                        tint: section.tint,
                        title: section.title,
                        count: section.entries.count,
                        isFolded: isFolded
                    ) {
                        toggleFold(section.id)
                    }
                    if !isFolded {
                        cells(section.entries, progress: progress, actions: actions, includesNewCell: false)
                            .transition(.opacity)
                    }
                }
            }
            if showsNewCell {
                cells([], progress: progress, actions: actions, includesNewCell: true)
            }
        }
    }

    @ViewBuilder
    private func cells(
        _ list: [ContainerBrowseEntry],
        progress: [String: SkillProgress],
        actions: ContainerPageActions,
        includesNewCell: Bool
    ) -> some View {
        if layout == .list {
            LazyVStack(alignment: .leading, spacing: Self.listSpacing) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                    cell(entry, progress: progress[entry.id], actions: actions, neighbors: Self.neighbors(of: index, in: list))
                }
                if includesNewCell { newCell }
            }
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Self.gridSpacing) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                    cell(entry, progress: progress[entry.id], actions: actions, neighbors: Self.neighbors(of: index, in: list))
                }
                if includesNewCell { newCell }
            }
        }
    }

    @ViewBuilder
    private func cell(
        _ entry: ContainerBrowseEntry,
        progress: SkillProgress?,
        actions: ContainerPageActions,
        neighbors: PageNeighbors
    ) -> some View {
        if tab == .skills, SkillLibrary.isSkill(entry.page) {
            skillCell(entry, progress: progress, actions: actions)
        } else if layout == .list {
            ContainerPageListRow(page: entry.page, location: entry.pathText, match: entry.match, actions: actions)
                .modifier(dragDrop(entry.page, cornerRadius: 16, actions: actions, neighbors: neighbors))
        } else {
            pageTile(entry, actions: actions, neighbors: neighbors)
        }
    }

    private func skillCell(_ entry: ContainerBrowseEntry, progress: SkillProgress?, actions: ContainerPageActions) -> some View {
        let style: SkillSummaryCard.Style = layout == .list ? .row : .tile
        let radius: CGFloat = style == .row ? 20 : 22
        return VStack(alignment: .leading, spacing: 6) {
            summaryCard(entry.page, style: style, progress: progress)
                .frame(maxWidth: .infinity)
                .contextMenu { actions.menu(for: entry.page) }
                .modifier(dragDrop(entry.page, cornerRadius: radius, actions: actions))
            footnote(entry, showsPath: grouping != .folder)
        }
    }

    @ViewBuilder
    private func summaryCard(_ page: ExercisePage, style: SkillSummaryCard.Style, progress: SkillProgress?) -> some View {
        if let progress {
            SkillSummaryCard(page: page, style: style, progress: progress)
        } else {
            SkillSummaryCard(page: page, style: style)
        }
    }

    /// A page's cover filling a card: a click shows its clips in the viewer, grown out of the card; a page without a
    /// clip (a container, a note) opens.
    private func pageTile(_ entry: ContainerBrowseEntry, actions: ContainerPageActions, neighbors: PageNeighbors) -> some View {
        let page = entry.page
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                actions.openFromCover(page)
            } label: {
                ContainerPageTile(entry: entry, stats: model.stats(of: page))
            }
            .buttonStyle(ContainerTileButtonStyle(cornerRadius: ContainerPageTile.cornerRadius))
            .pageCoverPointer()
            .contextMenu { actions.menu(for: page) }
            .modifier(dragDrop(page, cornerRadius: ContainerPageTile.cornerRadius, actions: actions, neighbors: neighbors))
            .accessibilityHint(PageCoverOpening.firstClip(of: page) == nil ? "Opens this page" : "Previews its clip")
            .accessibilityActions {
                if PageCoverOpening.firstClip(of: page) != nil {
                    Button("Open Page") { actions.open(page) }
                }
            }
            footnote(entry, showsPath: false)
        }
    }

    /// The pages listed before and after one card, for Move Up and Move Down.
    private typealias PageNeighbors = (previous: ExercisePage?, next: ExercisePage?)

    private static func neighbors(of index: Int, in list: [ContainerBrowseEntry]) -> PageNeighbors {
        (index > 0 ? list[index - 1].page : nil, index + 1 < list.count ? list[index + 1].page : nil)
    }

    /// Drags a card and takes drops on it: any page into a container's card, a sibling beside it in the manual order.
    private func dragDrop(
        _ page: ExercisePage,
        cornerRadius: CGFloat,
        actions: ContainerPageActions,
        neighbors: PageNeighbors = (nil, nil)
    ) -> PageCardDragDrop {
        PageCardDragDrop(
            page: page,
            axis: layout == .list ? .vertical : .horizontal,
            cornerRadius: cornerRadius,
            gap: layout == .list ? Self.listSpacing : Self.gridSpacing,
            reorders: reorders,
            holds: page.isContainer,
            source: $pageDrag,
            onDrop: { id, placement in actions.drop(id, placement, on: page) },
            onMoveUp: neighbors.previous.map { previous in { actions.place(page.manifest.id, previous, false) } },
            onMoveDown: neighbors.next.map { next in { actions.place(page.manifest.id, next, true) } }
        )
    }

    /// The place of a nested page and why a search showed it, under its card.
    @ViewBuilder
    private func footnote(_ entry: ContainerBrowseEntry, showsPath: Bool) -> some View {
        let path = showsPath ? entry.pathText : nil
        if path != nil || entry.match != nil {
            VStack(alignment: .leading, spacing: 3) {
                if let path {
                    ContainerPathLabel(path: path)
                }
                if let match = entry.match {
                    ContainerMatchLabel(reason: match)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 14, alignment: .top)]
        }
        return [GridItem(.adaptive(minimum: tileMinimum, maximum: 360), spacing: 14, alignment: .top)]
    }

    private var tileMinimum: CGFloat {
        #if os(macOS)
        return tab == .skills ? 210 : 200
        #else
        return tab == .skills ? 156 : 150
        #endif
    }

    // MARK: New cell and empty states

    private var newCellTitle: String { tab == .skills ? "New skill" : "New exercise" }

    private var newCellRadius: CGFloat {
        if layout == .list { return 16 }
        return tab == .skills ? 22 : ContainerPageTile.cornerRadius
    }

    /// A dashed card at the end that makes a page here: a skill from its name, or an exercise in the page editor.
    private var newCell: some View {
        let shape = RoundedRectangle(cornerRadius: newCellRadius, style: .continuous)
        return Button(action: startNewPage) {
            newCellLabel
                .foregroundStyle(Theme.textSecondary)
                .overlay {
                    shape.strokeBorder(Theme.textSecondary.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
                .contentShape(shape)
        }
        .buttonStyle(ContainerTileButtonStyle(cornerRadius: newCellRadius))
        .accessibilityLabel(newCellTitle)
    }

    @ViewBuilder
    private var newCellLabel: some View {
        if layout == .list {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text(newCellTitle)
                    .font(TimeMasterFont.rowTitle())
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } else if tab == .skills {
            newCellStack
                .frame(maxWidth: .infinity, minHeight: 156)
        } else {
            Color.clear
                .aspectRatio(ContainerPageTile.aspect, contentMode: .fit)
                .overlay { newCellStack }
        }
    }

    private var newCellStack: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
            Text(newCellTitle)
                .font(TimeMasterFont.rowTitle())
        }
    }

    private func emptyState(actions: ContainerPageActions) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: tab == .skills ? "flag.checkered" : "tray")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange.opacity(0.85))
                    .accessibilityHidden(true)
                Text(tab == .skills ? "No skills here yet" : "Nothing here yet")
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                Text(tab == .skills
                     ? "Make a skill to keep what you learn in \(container.title) together."
                     : "Add an exercise, a note or a container with +.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .modifier(TimeMasterCardSurface(cornerRadius: 20, flat: true))
            cells([], progress: [:], actions: actions, includesNewCell: true)
        }
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange.opacity(0.85))
                .accessibilityHidden(true)
            Text("Nothing called “\(trimmedQuery)”")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Try a word from a title, a note, a comment or a type.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let otherTab, otherTab.count > 0 {
                Button(action: otherTab.show) {
                    Label(otherTab.label, systemImage: "arrow.right")
                        .font(TimeMasterFont.label())
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .modifier(TimeMasterCardSurface(cornerRadius: 20, flat: true))
    }

    private func filterEmptyState(_ status: SkillStatus) -> some View {
        VStack(spacing: 10) {
            Image(systemName: status.symbolName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(status.color)
                .accessibilityHidden(true)
            Text("No skills marked “\(status.title)”")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                statusBinding.wrappedValue = nil
            } label: {
                Text("Show all")
                    .font(TimeMasterFont.label())
            }
            .buttonStyle(TimeMasterActionButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .modifier(TimeMasterCardSurface(cornerRadius: 20, flat: true))
    }

    private func otherTabButton(_ hits: ContainerOtherTabHits) -> some View {
        Button(action: hits.show) {
            HStack(spacing: 6) {
                Text("Also \(hits.label)")
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.toolbarOrange)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Data

    private func shownEntries(progress: [String: SkillProgress]) -> [ContainerBrowseEntry] {
        var list = entries
        if tab == .skills, let statusFilter {
            list = list.filter { $0.status == statusFilter }
        }
        let usage = sort == .used ? store.pageUsage(workoutStore) : .empty
        return model.sorted(list, by: sort, relevance: isSearching && sort == .manual, progress: progress, usage: usage)
    }

    /// Each listed skill's sub-skill progress, from one index of the library.
    private func skillProgress() -> [String: SkillProgress] {
        let library = store.skillLibrary
        var result: [String: SkillProgress] = [:]
        for entry in entries {
            result[entry.id] = library.progress(of: entry.page)
        }
        return result
    }

    // MARK: Changes

    private var statusBinding: Binding<SkillStatus?> {
        Binding(
            get: { statusFilter },
            set: { value in
                guard value != statusFilter else { return }
                withAnimation(motion) { statusFilter = value }
                EverHaptic.selection()
            }
        )
    }

    private var layoutBinding: Binding<ContainerBrowseLayout> {
        Binding(
            get: { layout },
            set: { value in
                guard value != layout else { return }
                withAnimation(motion) {
                    if tab == .skills {
                        skillsLayout = value
                    } else {
                        exercisesLayout = value
                    }
                }
                EverHaptic.selection()
            }
        )
    }

    private func setSort(_ option: ContainerBrowseSort) {
        guard option != sort else { return }
        withAnimation(motion) {
            if tab == .skills {
                skillsSort = option
            } else {
                exercisesSort = option
            }
        }
        EverHaptic.selection()
    }

    private func setGrouping(_ option: ContainerSkillGrouping) {
        guard option != grouping else { return }
        withAnimation(motion) { grouping = option }
        EverHaptic.selection()
    }

    private func toggleFold(_ id: String) {
        withAnimation(motion) {
            if folded.contains(id) {
                folded.remove(id)
            } else {
                folded.insert(id)
            }
        }
        EverHaptic.selection()
    }

    private func startNewPage() {
        if tab == .skills {
            beginNaming(.skill)
        } else {
            creation = PageCreationRequest(pageType: .exercise, parentID: container.manifest.id)
        }
    }

    private func beginNaming(_ kind: ContainerNewPageKind) {
        naming = kind
        newName = ""
        isNaming = true
    }

    /// Makes the page the name alert asked for: a skill (then opens it), a note (then opens it to write), a container.
    private func createNamed() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        let parentID = container.manifest.id
        switch naming {
        case .skill:
            guard !name.isEmpty else { return }
            var createdID: String?
            let created = SkillErrorCenter.shared.attempt("Create the skill") {
                createdID = try store.createSkillPage(title: name, on: parentID)
            }
            guard created, let createdID else { return }
            EverHaptic.success()
            navigationState.path.append(DatabasePageRoute(pageID: createdID))
        case .note:
            var createdID: String?
            let created = SkillErrorCenter.shared.attempt("Create the note") {
                createdID = try store.createNote(title: name, parentID: parentID)
            }
            guard created, let createdID else { return }
            NoteEditIntent.pending.insert(createdID)
            EverHaptic.success()
            navigationState.path.append(DatabasePageRoute(pageID: createdID))
        case .container:
            let manifest = ExercisePageManifest(title: name.isEmpty ? "Untitled" : name, pageKind: .container, parentID: parentID)
            let created = SkillErrorCenter.shared.attempt("Create the container") {
                try store.createPage(manifest: manifest, parentID: parentID)
            }
            if created { EverHaptic.success() }
        }
    }
}
