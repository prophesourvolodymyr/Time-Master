import SwiftUI
import TimeMasterCore

enum ContainerChildTab: String, CaseIterable, Identifiable, Hashable {
    case exercises
    case skills

    var id: String { rawValue }
    var title: String { self == .exercises ? "Exercises" : "Skills" }
    var symbolName: String { self == .exercises ? "figure.run" : "flag.checkered" }
}

struct ContainerCategoryDestination: Identifiable, Hashable {
    let containerID: UUID
    let tab: ContainerChildTab

    var id: String { "\(containerID.uuidString)-\(tab.rawValue)" }
}

/// A container's pages under two tabs (a `TmaxTabBar` across the width): Exercises (its exercises, notes and
/// containers) and Skills, each with its count (its search hits while searching). One search runs across both tabs.
/// Double-click a tab, or use its menu, to open it as a page of its own.
struct ContainerChildrenTabs: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let container: ExercisePage
    @State private var selectedTab: ContainerChildTab = .exercises
    @State private var query = ""
    @State private var choseFirstTab = false

    private var tabs: [ContainerChildTab] { container.manifest.hidesSkills ? [.exercises] : [.exercises, .skills] }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let model = store.containerBrowseModel(for: container)
        let lists = model.lists(query: query)
        let shownTab = tabs.contains(selectedTab) ? selectedTab : .exercises
        VStack(alignment: .leading, spacing: 14) {
            if tabs.count > 1 { tabTrack(lists) }
            ContainerBrowser(
                model: model,
                tab: shownTab,
                entries: lists[shownTab] ?? [],
                query: $query,
                otherTab: otherTabHits(lists)
            )
        }
        .onAppear { chooseFirstTab(lists) }
    }

    private func tabTrack(_ lists: [ContainerChildTab: [ContainerBrowseEntry]]) -> some View {
        TmaxTabBar(
            tabs.map { tab -> TmaxTab<ContainerChildTab> in
                let count = lists[tab]?.count ?? 0
                return TmaxTab(
                    tab,
                    title: tab.title,
                    symbol: tab.symbolName,
                    count: count,
                    help: "Double-click to open \(tab.title.lowercased()) as a page",
                    accessibilityValue: isSearching ? "\(count) matches" : "\(count)",
                    alternate: TmaxTabAlternate(title: "Open as a Page", systemImage: "arrow.up.left.and.arrow.down.right") {
                        openAsPage(tab)
                    }
                )
            },
            selection: selectedTab,
            fillsWidth: true
        ) { tab in
            select(tab)
        }
    }

    private func select(_ tab: ContainerChildTab) {
        guard tab != selectedTab else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
            selectedTab = tab
        }
        EverHaptic.selection()
    }

    private func openAsPage(_ tab: ContainerChildTab) {
        navigationState.path.append(DatabaseCategoryRoute(containerID: container.manifest.id, tab: tab))
    }

    /// A container holding only skills opens on its Skills tab.
    private func chooseFirstTab(_ lists: [ContainerChildTab: [ContainerBrowseEntry]]) {
        guard !choseFirstTab else { return }
        choseFirstTab = true
        if tabs.count > 1, lists[.exercises]?.isEmpty ?? true, !(lists[.skills]?.isEmpty ?? true) {
            selectedTab = .skills
        }
    }

    private func otherTabHits(_ lists: [ContainerChildTab: [ContainerBrowseEntry]]) -> ContainerOtherTabHits? {
        guard isSearching, tabs.count > 1 else { return nil }
        let other: ContainerChildTab = selectedTab == .exercises ? .skills : .exercises
        return ContainerOtherTabHits(tab: other, count: lists[other]?.count ?? 0) { select(other) }
    }
}

/// Pages as Database rows in their stored order that open on tap, with the page menu (edit, move, duplicate, delete…):
/// the exercises and notes inside a skill. Drag a row onto another to put it before or after it, or onto a container's
/// row to move it inside. Tells the navigation the rows' order, so Previous and Next on an opened page walk it.
struct ExerciseChildList: View {
    let pages: [ExercisePage]

    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @State private var pageDrag: PageDragSource?
    /// `path.count` of the screen the list sits on, read when it appears.
    @State private var depth = 0

    var body: some View {
        ContainerPageActionHost { actions in
            VStack(alignment: .leading, spacing: 8) {
                if pages.isEmpty {
                    VStack(spacing: 6) {
                        Text("No exercises")
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                        Text("Create or move exercises into this container.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        ContainerPageListRow(page: page, actions: actions)
                            .modifier(PageCardDragDrop(
                                page: page,
                                axis: .vertical,
                                cornerRadius: 16,
                                gap: 8,
                                reorders: true,
                                holds: page.isContainer,
                                source: $pageDrag,
                                onDrop: { id, placement in actions.drop(id, placement, on: page) },
                                onMoveUp: index > 0 ? { actions.place(page.manifest.id, pages[index - 1], false) } : nil,
                                onMoveDown: index + 1 < pages.count ? { actions.place(page.manifest.id, pages[index + 1], true) } : nil
                            ))
                    }
                }
            }
        }
        .onAppear {
            depth = navigationState.path.count
            offerSiblings(pages.map(\.manifest.id))
        }
        .onChange(of: pages.map(\.manifest.id)) { offerSiblings($0) }
    }

    private func offerSiblings(_ ids: [String]) {
        guard let containerID = pages.first?.manifest.parentID else { return }
        navigationState.offerSiblings(ids, containerID: containerID, surface: "children", depth: depth)
    }
}

/// One tab of a container opened as a page of its own, with the same search, layouts, sort and groups.
struct ContainerCategoryPage: View {
    @EnvironmentObject private var store: DatabaseStore

    let destination: ContainerCategoryDestination
    @State private var query = ""
    @State private var scrollEdge = PageScrollEdge()

    private var container: ExercisePage? {
        store.page(id: destination.containerID)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let container {
                        let model = store.containerBrowseModel(for: container)
                        VStack(spacing: 2) {
                            TimeMasterPageTitle(destination.tab.title)
                                .foregroundStyle(Theme.textPrimary)
                            Text(container.title)
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        ContainerBrowser(
                            model: model,
                            tab: destination.tab,
                            entries: model.lists(query: query)[destination.tab] ?? [],
                            query: $query
                        )
                    }
                }
                .padding(.vertical, 16)
                .skillsContained()
                .pageScrollEdgeProbe(scrollEdge)
            }
            PageTopChrome(edge: scrollEdge)
        }
        .pageScrollSpace()
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        #else
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            AppToolbar.iconItem(placement: .cancellationAction) {
                TimeMasterBackButton()
                    .oneHandedActionSource()
            }
        }
        .oneHandedActions(
            id: "container-category-\(destination.containerID)-\(destination.tab)",
            actions: [
                ReachabilityAction("back", title: "Back") {
                    TimeMasterBackButton()
                }
            ]
        )
        .skillErrorAlert()
    }
}
