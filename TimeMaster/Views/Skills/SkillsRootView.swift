import SwiftUI
import TimeMasterCore

/// The Skills page: every top-level skill and tutorial of the library (wherever its folder is) as a tile or a row,
/// in sections by the category its root Database folder names (Calisthenics, Boxing, Wrestling, Gymnastics, Other)
/// that fold like the Workouts page's, filtered by status, searched across everything inside them, a quick way to make
/// a new skill, and its own navigation stack that opens them with the Database's page routes.
struct SkillsRootView: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.everPageTravelActive) private var pageTravelActive

    @ObservedObject private var navigationState: DatabaseNavigationState

    init(navigationState: DatabaseNavigationState) {
        _navigationState = ObservedObject(wrappedValue: navigationState)
    }

    @AppStorage("tm.skills.root.viewMode") private var viewMode: SkillsViewMode = .tiles
    @AppStorage("tm.skills.root.sort") private var sortOption: SkillSortOption = .status
    /// Folded sections on this device, by `SkillCategory` raw value, comma separated.
    @AppStorage("tm.skills.root.foldedSections") private var foldedSectionsRaw = ""

    @State private var query = ""
    @State private var searchPresented = false
    @State private var statusFilter: SkillStatus?
    @State private var foldedCategories: Set<SkillCategory> = []
    @State private var hasEntered = false
    @State private var showingCreate = false
    @State private var pageToEdit: ExercisePage?
    @State private var categoryToChangePicture: SkillPageTarget?
    @State private var pageToDelete: ExercisePage?
    @State private var errorMessage: String?
    @Namespace private var statusNamespace

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var listAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)
    }

    private var sectionBodyTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .offset(y: -6))
        )
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
            .onAppear {
                foldedCategories = Set(foldedSectionsRaw.split(separator: ",").compactMap { SkillCategory(rawValue: String($0)) })
            }
            .task { await enter() }
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
            .sheet(item: $categoryToChangePicture) { target in
                SkillIconChooserSheet(pageID: target.id)
                    .environmentObject(store)
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
        .quickPreviewHost(navigationState)
        .environmentObject(navigationState)
        .everPageStack(depth: navigationState.path.count) { if !navigationState.path.isEmpty { navigationState.path.removeLast() } }
        .findCommand {
            guard navigationState.path.isEmpty, !showingCreate, pageToEdit == nil else { return false }
            openSearch()
            return true
        }
        .macWindowTitleHidden()
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
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: width, height: height))
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
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: width, height: height))
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
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: width, height: height))
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel(isTiles ? "Show as a list" : "Show as tiles")
        .help(isTiles ? "Show as a list" : "Show as tiles")
    }

    private func sortMenu(progress: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        TmaxMenu {
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
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: width, height: height))
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
        let library = store.skillLibrary
        let index = store.index
        let entries = library.listedEntries(by: sortOption)
        return VStack(alignment: .leading, spacing: 16) {
            if !trimmedQuery.isEmpty {
                SkillsSearchResults(
                    query: trimmedQuery,
                    sections: SkillShelf.sections(of: entries, index: index),
                    library: library,
                    anchors: library.categoryAnchors()
                ) { page in
                    open(page.manifest.id)
                }
            } else if entries.isEmpty {
                emptyView
                    .skillsEntrance(hasEntered, section: 0)
            } else {
                let counts = Dictionary(grouping: entries) { $0.status }.mapValues { $0.count }
                if counts.count > 1 || statusFilter != nil {
                    statusFilterRow(counts: counts, total: entries.count, metrics: metrics)
                        .skillsEntrance(hasEntered, section: 0)
                }
                let visible = statusFilter.map { filter in entries.filter { $0.status == filter } } ?? entries
                if visible.isEmpty {
                    filteredEmptyView
                } else {
                    let sections = SkillShelf.sections(of: visible, index: index)
                    sectionList(sections)
                    newSkillButton
                        .skillsEntrance(hasEntered, section: sections.count)
                }
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// Each section under its header, like the Workouts page's sections; a folded one keeps only its header.
    private func sectionList(_ sections: [SkillCategorySection]) -> some View {
        let anchors = store.skillLibrary.categoryAnchors()
        return LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { order, section in
                let folded = isFolded(section.category)
                let anchor = anchors[section.category]
                SkillCategoryHeader(
                    category: section.category,
                    count: section.entries.count,
                    page: anchor,
                    isFolded: folded,
                    onToggle: { toggleFold(section.category) },
                    onChangePicture: changePictureAction(for: anchor)
                )
                .padding(.top, order == 0 ? 0 : 14)
                .skillsEntrance(hasEntered, section: order)
                if !folded {
                    sectionBody(section, order: order)
                        .transition(sectionBodyTransition)
                }
            }
        }
    }

    private func changePictureAction(for anchor: ExercisePage?) -> (() -> Void)? {
        guard let anchor else { return nil }
        return { categoryToChangePicture = SkillPageTarget(id: anchor.manifest.id) }
    }

    @ViewBuilder
    private func sectionBody(_ section: SkillCategorySection, order: Int) -> some View {
        let cards = Array(section.entries.enumerated())
        switch viewMode {
        case .tiles:
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(cards, id: \.element.id) { position, entry in
                    card(entry, category: section.category, style: .tile)
                        .skillsEntrance(hasEntered, section: order, position: position + 1)
                }
            }
        case .list:
            LazyVStack(spacing: 10) {
                ForEach(cards, id: \.element.id) { position, entry in
                    card(entry, category: section.category, style: .row)
                        .skillsEntrance(hasEntered, section: order, position: position + 1)
                }
            }
        }
    }

    /// As many columns as fit the grid's own width at the minimum tile width, so nothing is measured; one column at
    /// accessibility text sizes.
    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 14)]
        }
        #if os(macOS)
        return [GridItem(.adaptive(minimum: 210), spacing: 14)]
        #else
        return [GridItem(.adaptive(minimum: 156), spacing: 14)]
        #endif
    }

    private func card(_ entry: SkillLibraryEntry, category: SkillCategory, style: SkillSummaryCard.Style) -> some View {
        SkillSummaryCard(page: entry.page, style: style, progress: entry.progress, category: category)
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
        TmaxSubmenu {
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
                        .foregroundStyle(isSelected ? Theme.background : status.color)
                }
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .monospacedDigit()
                    .opacity(isSelected ? 0.8 : 0.6)
            }
            .fixedSize()
        }
        .buttonStyle(TmaxChipButtonStyle(isSelected: isSelected, namespace: statusNamespace))
        .accessibilityLabel(title)
        .accessibilityValue("\(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The dashed row under the sections that makes a new skill, like the Workouts page's "New Section" row.
    private var newSkillButton: some View {
        Button {
            showingCreate = true
        } label: {
            Label("New skill", systemImage: "plus")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: 16))
        .accessibilityHint("Makes a new skill or tutorial")
        .padding(.top, 6)
    }

    // MARK: States

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 104, height: 104)
                .modifier(TimeMasterCardSurface(cornerRadius: 30, flat: true))
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

    /// While a status filter is on, every section is open, so no match hides behind a fold.
    private func isFolded(_ category: SkillCategory) -> Bool {
        statusFilter == nil && foldedCategories.contains(category)
    }

    private func toggleFold(_ category: SkillCategory) {
        withAnimation(listAnimation) {
            if foldedCategories.remove(category) == nil { foldedCategories.insert(category) }
        }
        foldedSectionsRaw = foldedCategories.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Plays the entrance once per visit of the page. On the Mac the page travel slides a picture of the page in, so
    /// the entrance starts once it has landed instead of changing under it.
    private func enter() async {
        guard !hasEntered else { return }
        if pageTravelActive {
            try? await Task.sleep(nanoseconds: UInt64(EverPageMotion.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
        }
        hasEntered = true
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
        let count = store.skillLibrary.pages(below: page).count
        guard count > 0 else { return "It moves to the trash." }
        return "It and the \(count) \(count == 1 ? "page" : "pages") inside it move to the trash."
    }
}
