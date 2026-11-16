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

/// A container's pages under two tabs on one slim track: Exercises (its exercises, notes and containers) and Skills,
/// each with its count (its search hits while searching). One search runs across both tabs. Double-click a tab, or
/// use its menu, to open it as a page of its own.
struct ContainerChildrenTabs: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let container: ExercisePage
    @State private var selectedTab: ContainerChildTab = .exercises
    @State private var query = ""
    @State private var choseFirstTab = false
    @Namespace private var tabNamespace

    private static let tabs: [ContainerChildTab] = [.exercises, .skills]

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let model = ContainerBrowseModel(container: container, roots: store.rootPages, pages: store.allPagesFlat)
        let lists = model.lists(query: query)
        VStack(alignment: .leading, spacing: 14) {
            tabTrack(lists)
            ContainerBrowser(
                model: model,
                tab: selectedTab,
                entries: lists[selectedTab] ?? [],
                query: $query,
                otherTab: otherTabHits(lists)
            )
        }
        .onAppear { chooseFirstTab(lists) }
    }

    private func tabTrack(_ lists: [ContainerChildTab: [ContainerBrowseEntry]]) -> some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs) { tab in
                let count = lists[tab]?.count ?? 0
                Button {
                    select(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.title)
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        Text("\(count)")
                            .font(TimeMasterFont.technical())
                            .opacity(0.7)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .buttonStyle(ContainerSegmentButtonStyle(isSelected: selectedTab == tab, namespace: tabNamespace))
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { openAsPage(tab) }
                )
                .contextMenu {
                    Button {
                        openAsPage(tab)
                    } label: {
                        Label("Open as a Page", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
                .accessibilityLabel(tab.title)
                .accessibilityValue(isSearching ? "\(count) matches" : "\(count)")
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityAction(named: "Open as a page") { openAsPage(tab) }
                .help("Double-click to open \(tab.title.lowercased()) as a page")
            }
        }
        .containerSegmentTrack()
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
        if lists[.exercises]?.isEmpty ?? true, !(lists[.skills]?.isEmpty ?? true) {
            selectedTab = .skills
        }
    }

    private func otherTabHits(_ lists: [ContainerChildTab: [ContainerBrowseEntry]]) -> ContainerOtherTabHits? {
        guard isSearching else { return nil }
        let other: ContainerChildTab = selectedTab == .exercises ? .skills : .exercises
        return ContainerOtherTabHits(tab: other, count: lists[other]?.count ?? 0) { select(other) }
    }
}

/// Pages as Database rows that open on tap, with the page menu (edit, move, duplicate, delete…) and drops onto
/// containers: the exercises and notes inside a skill.
struct ExerciseChildList: View {
    let pages: [ExercisePage]

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
                    ForEach(pages) { page in
                        ContainerPageListRow(page: page, actions: actions)
                    }
                }
            }
        }
    }
}

/// One tab of a container opened as a page of its own, with the same search, layouts, sort and groups.
struct ContainerCategoryPage: View {
    @EnvironmentObject private var store: DatabaseStore

    let destination: ContainerCategoryDestination
    @State private var query = ""

    private var container: ExercisePage? {
        store.page(id: destination.containerID)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let container {
                        let model = ContainerBrowseModel(container: container, roots: store.rootPages, pages: store.allPagesFlat)
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
            }
        }
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
