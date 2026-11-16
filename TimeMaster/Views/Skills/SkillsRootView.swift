import SwiftUI
import TimeMasterCore

/// The Skills page: every top-level skill and tutorial of the library (wherever its folder is) as a tile or a row,
/// filtered by status, searched across everything inside them, a quick way to make a new skill, and its own
/// navigation stack that opens them with the Database's page routes.
struct SkillsRootView: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileHeight = SkillSummaryCard.tileMinimumHeight

    @StateObject private var navigationState = DatabaseNavigationState()
    @AppStorage("tm.skills.root.viewMode") private var viewMode: SkillsViewMode = .tiles
    @AppStorage("tm.skills.root.sort") private var sortOption: SkillSortOption = .status

    @State private var query = ""
    @State private var searchPresented = false
    @State private var statusFilter: SkillStatus?
    @State private var showingCreate = false
    @State private var pageToEdit: ExercisePage?
    @State private var pageToDelete: ExercisePage?
    @State private var errorMessage: String?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var listAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)
    }

    var body: some View {
        NavigationStack(path: $navigationState.path) {
            ZStack {
                TmaxGlowBackground()
                ScrollingChrome(metrics: { width in
                    ScrollingChromeMetrics(width: width, controlCount: 4)
                }) { metrics in
                    content(metrics: metrics)
                } header: { progress, metrics in
                    chrome(progress: progress, metrics: metrics)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: DatabasePageRoute.self) { route in
                if let pageID = UUID(uuidString: route.pageID) {
                    ExercisePageDetailView(pageID: pageID)
                }
            }
            .navigationDestination(for: DatabaseCategoryRoute.self) { route in
                if let containerID = UUID(uuidString: route.containerID) {
                    ContainerCategoryPage(
                        destination: ContainerCategoryDestination(containerID: containerID, tab: route.tab)
                    )
                    .environmentObject(store)
                    .environmentObject(workoutStore)
                }
            }
            .navigationDestination(for: DatabaseSkillGroupRoute.self) { route in
                SkillGroupPageView(route: route)
                    .environmentObject(store)
                    .environmentObject(workoutStore)
            }
            .oneHandedActions(id: "skills", actions: oneHandedActions)
            .sheet(isPresented: $showingCreate) {
                SkillCreateSheet { id in
                    statusFilter = nil
                    navigationState.path.append(DatabasePageRoute(pageID: id))
                }
                .environmentObject(store)
                .keyNavHost()
            }
            .sheet(item: $pageToEdit) { page in
                PageCreationSheet(page: page) { manifest, parentID in
                    try store.updatePage(id: page.manifest.id, manifest: manifest, newParentID: parentID)
                }
                .environmentObject(workoutStore)
                .environmentObject(store)
                .keyNavHost()
            }
            .confirmationDialog(
                pageToDelete?.isTutorial == true ? "Delete this tutorial?" : "Delete this skill?",
                isPresented: Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } }),
                titleVisibility: .visible,
                presenting: pageToDelete
            ) { page in
                Button("Move “\(page.title)” to the Trash", role: .destructive) { delete(page) }
                Button("Cancel", role: .cancel) {}
            } message: { page in
                Text(deleteMessage(page))
            }
            .alert(
                "Couldn’t save",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .environmentObject(navigationState)
        .findCommand {
            guard navigationState.path.isEmpty, !showingCreate, pageToEdit == nil else { return false }
            openSearch()
            return true
        }
        .font(TimeMasterFont.body())
    }

    // MARK: Chrome

    private func chrome(progress: CGFloat, metrics: ScrollingChromeMetrics) -> some View {
        let morph = metrics.morph(progress)
        return VStack(spacing: 0) {
            if searchPresented {
                SpotlightSearchBar(text: $query, isPresented: $searchPresented, placeholder: "Search skills and notes") {
                    EmptyView()
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, 8)
            } else {
                ScrollingChromeHeader(title: "Skills", progress: morph, metrics: metrics) {
                    controls(progress: morph, metrics: metrics)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea(edges: .top))
    }

    private func controls(progress: CGFloat, metrics: ScrollingChromeMetrics) -> some View {
        let width = metrics.controlWidth(progress)
        let height = metrics.controlHeight(progress)
        return HStack(spacing: metrics.controlSpacing) {
            searchButton(progress: progress, width: width, height: height)
            addButton(progress: progress, width: width, height: height)
            viewToggleButton(progress: progress, width: width, height: height)
            sortMenu(progress: progress, width: width, height: height)
        }
    }

    private func searchButton(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Button(action: openSearch) {
            ScrollingChromeControl(systemImage: "magnifyingglass", title: "Search", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Search")
        .help("Search")
    }

    private func addButton(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Button {
            showingCreate = true
        } label: {
            ScrollingChromeControl(systemImage: "plus", title: "New", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("New skill")
        .help("New skill")
    }

    private func viewToggleButton(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let isTiles = viewMode == .tiles
        return Button(action: toggleViewMode) {
            ScrollingChromeControl(
                systemImage: isTiles ? "list.bullet" : "square.grid.2x2",
                title: isTiles ? "List" : "Tiles",
                progress: progress,
                width: width,
                height: height
            )
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel(isTiles ? "Show as a list" : "Show as tiles")
        .help(isTiles ? "Show as a list" : "Show as tiles")
    }

    private func sortMenu(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Menu {
            ForEach(SkillSortOption.allCases) { option in
                Button {
                    sort(by: option)
                } label: {
                    Label(option.title, systemImage: option == sortOption ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            ScrollingChromeControl(systemImage: "arrow.up.arrow.down", title: "Sort", progress: progress, width: width, height: height)
        }
        .menuIndicator(.hidden)
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Sort")
        .accessibilityValue(sortOption.title)
        .help("Sort: \(sortOption.title)")
    }

    private var oneHandedActions: [ReachabilityAction] {
        [
            ReachabilityAction("search", title: "Search") {
                searchButton(progress: 1, width: 48, height: 48)
            },
            ReachabilityAction("add", title: "New skill") {
                addButton(progress: 1, width: 48, height: 48)
            },
            ReachabilityAction("view", title: viewMode == .tiles ? "List" : "Tiles") {
                viewToggleButton(progress: 1, width: 48, height: 48)
            },
            ReachabilityAction("sort", title: "Sort", dismissesOnActivation: false) {
                sortMenu(progress: 1, width: 48, height: 48)
            }
        ]
    }

    // MARK: Content

    private func content(metrics: ScrollingChromeMetrics) -> some View {
        let library = SkillLibrary(pages: store.allPagesFlat)
        let entries = sortOption.ordered(library.topLevelEntries())
        return VStack(alignment: .leading, spacing: 16) {
            if !trimmedQuery.isEmpty {
                SkillsSearchResults(query: trimmedQuery, roots: entries.map(\.page), library: library) { page in
                    open(page.manifest.id)
                }
            } else if entries.isEmpty {
                emptyView
            } else {
                let counts = Dictionary(grouping: entries) { $0.status }.mapValues { $0.count }
                if counts.count > 1 || statusFilter != nil {
                    statusFilterRow(counts: counts, total: entries.count, metrics: metrics)
                }
                let visible = statusFilter.map { filter in entries.filter { $0.status == filter } } ?? entries
                if visible.isEmpty {
                    filteredEmptyView
                } else {
                    skillGrid(visible, metrics: metrics)
                }
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func skillGrid(_ entries: [SkillLibraryEntry], metrics: ScrollingChromeMetrics) -> some View {
        switch viewMode {
        case .tiles:
            LazyVGrid(columns: gridColumns(metrics), spacing: 14) {
                ForEach(entries) { entry in
                    card(entry, style: .tile)
                }
                newSkillTile
            }
        case .list:
            LazyVStack(spacing: 10) {
                ForEach(entries) { entry in
                    card(entry, style: .row)
                }
                newSkillRow
            }
        }
    }

    private func gridColumns(_ metrics: ScrollingChromeMetrics) -> [GridItem] {
        let spacing: CGFloat = 14
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: spacing)]
        }
        #if os(macOS)
        let minimum: CGFloat = 210
        #else
        let minimum: CGFloat = 156
        #endif
        let fit = Int((max(1, metrics.contentWidth) + spacing) / (minimum + spacing))
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: min(5, max(2, fit)))
    }

    private func card(_ entry: SkillLibraryEntry, style: SkillSummaryCard.Style) -> some View {
        SkillSummaryCard(page: entry.page, style: style, progress: entry.progress)
            .contextMenu { cardMenu(entry.page) }
    }

    @ViewBuilder
    private func cardMenu(_ page: ExercisePage) -> some View {
        let current = page.manifest.skillStatus ?? .notStarted
        Button {
            open(page.manifest.id)
        } label: {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        Menu {
            ForEach(SkillSortOption.statusOrder, id: \.self) { status in
                Button {
                    setStatus(status, of: page)
                } label: {
                    Label(status.title, systemImage: status == current ? "checkmark" : status.symbolName)
                }
            }
        } label: {
            Label("Status", systemImage: current.symbolName)
        }
        Divider()
        Button {
            pageToEdit = page
        } label: {
            Label("Edit…", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            pageToDelete = page
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }

    private func statusFilterRow(counts: [SkillStatus: Int], total: Int, metrics: ScrollingChromeMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, title: "All", count: total)
                ForEach(SkillSortOption.statusOrder.filter { counts[$0, default: 0] > 0 || $0 == statusFilter }, id: \.self) { status in
                    filterChip(status, title: status.title, count: counts[status, default: 0])
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -metrics.horizontalPadding)
    }

    private func filterChip(_ status: SkillStatus?, title: String, count: Int) -> some View {
        let isSelected = statusFilter == status
        return Button {
            guard !isSelected else { return }
            withAnimation(listAnimation) { statusFilter = status }
            EverHaptic.selection()
        } label: {
            HStack(spacing: 6) {
                if let status {
                    Image(systemName: status.symbolName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.textPrimary : status.color)
                }
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.textPrimary.opacity(0.8) : Theme.textSecondary)
            }
            .fixedSize()
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: isSelected))
        .accessibilityLabel(title)
        .accessibilityValue("\(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var newSkillTile: some View {
        Button {
            showingCreate = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                Text("New skill")
                    .font(TimeMasterFont.rowTitle())
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: tileHeight)
            .overlay {
                RoundedRectangle(cornerRadius: SkillSummaryCard.tileCornerRadius, style: .continuous)
                    .strokeBorder(Theme.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: SkillSummaryCard.tileCornerRadius, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: SkillSummaryCard.tileCornerRadius))
        .accessibilityLabel("New skill")
    }

    private var newSkillRow: some View {
        Button {
            showingCreate = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("New skill")
                    .font(TimeMasterFont.rowTitle())
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .overlay {
                RoundedRectangle(cornerRadius: SkillSummaryCard.rowCornerRadius, style: .continuous)
                    .strokeBorder(Theme.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(RoundedRectangle(cornerRadius: SkillSummaryCard.rowCornerRadius, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .keyNavShape(.roundedRectangle(cornerRadius: SkillSummaryCard.rowCornerRadius))
        .accessibilityLabel("New skill")
    }

    // MARK: States

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 104, height: 104)
                .background(SkillCardSurface(cornerRadius: 30))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("What do you want to get good at?")
                    .font(TimeMasterFont.title())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Make a skill, then fill it with the clips, notes and sub-skills you'll learn.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingCreate = true
            } label: {
                Label("Make your first skill", systemImage: "plus")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52, fillsWidth: true))
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var filteredEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: statusFilter?.symbolName ?? "line.3.horizontal.decrease.circle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(statusFilter?.color ?? Theme.textSecondary)
                .accessibilityHidden(true)
            Text("No skills here")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            Button("Show all") {
                withAnimation(listAnimation) { statusFilter = nil }
                EverHaptic.selection()
            }
            .buttonStyle(TimeMasterActionButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: Actions

    private func open(_ id: String) {
        EverHaptic.selection()
        navigationState.path.append(DatabasePageRoute(pageID: id))
    }

    private func openSearch() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84)) {
            searchPresented = true
        }
    }

    private func toggleViewMode() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            viewMode = viewMode == .tiles ? .list : .tiles
        }
        EverHaptic.selection()
    }

    private func sort(by option: SkillSortOption) {
        guard option != sortOption else { return }
        withAnimation(listAnimation) { sortOption = option }
        EverHaptic.selection()
    }

    private func setStatus(_ status: SkillStatus, of page: ExercisePage) {
        guard status != (page.manifest.skillStatus ?? .notStarted) else { return }
        do {
            try store.skillWrite { database in
                var manifest = try database.getPage(id: page.manifest.id)
                manifest.skillStatus = status
                try database.updatePage(id: manifest.id, manifest: manifest, newParentID: manifest.parentID)
            }
            EverHaptic.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ page: ExercisePage) {
        do {
            try store.deletePage(id: page.manifest.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMessage(_ page: ExercisePage) -> String {
        let count = SkillLibrary(pages: store.allPagesFlat).pages(below: page).count
        guard count > 0 else { return "It moves to the trash." }
        return "It and the \(count) \(count == 1 ? "page" : "pages") inside it move to the trash."
    }
}
