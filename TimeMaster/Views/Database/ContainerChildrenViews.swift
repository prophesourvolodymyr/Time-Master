import SwiftUI
import TimeMasterCore

enum ContainerChildTab: String, CaseIterable, Identifiable, Hashable {
    case exercises
    case skills

    var id: String { rawValue }
    var title: String { self == .exercises ? "Exercises" : "Skills" }
}

struct ContainerCategoryDestination: Identifiable, Hashable {
    let containerID: UUID
    let tab: ContainerChildTab

    var id: String { "\(containerID.uuidString)-\(tab.rawValue)" }
}

struct ContainerChildrenTabs: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState

    let container: ExercisePage
    @State private var selectedTab: ContainerChildTab = .exercises

    private var exercises: [ExercisePage] {
        store.children(of: container.id).filter { $0.isExercise || $0.pageType == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ContainerChildTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedTab == tab ? Theme.toolbarOrange : Theme.surface2,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        selectedTab == tab ? Color.white.opacity(0.55) : Color.white.opacity(0.1),
                                        lineWidth: 1
                                    )
                            }
                    }.keyNavPlainButtonStyle()
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            navigationState.path.append(
                                DatabaseCategoryRoute(
                                    containerID: container.manifest.id,
                                    tab: tab
                                )
                            )
                        }
                    )
                    .accessibilityHint("Double tap to open \(tab.title.lowercased()) as a full page")
                }
            }

            if selectedTab == .skills {
                Text("Skills")
                    .font(TimeMasterFont.black(34, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                SkillBoardScreen(boardID: container.manifest.id)
            } else {
                ExerciseChildList(pages: exercises)
            }
        }
    }
}

private struct ExerciseChildList: View {
    let pages: [ExercisePage]

    var body: some View {
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
                    NavigationLink(value: DatabasePageRoute(pageID: page.manifest.id)) {
                        PageCardView(page: page)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .keyNavPlainButtonStyle()
                }
            }
        }
    }
}

struct ContainerCategoryPage: View {
    @EnvironmentObject private var store: DatabaseStore

    let destination: ContainerCategoryDestination

    private var container: ExercisePage? {
        store.page(id: destination.containerID)
    }

    private var exercises: [ExercisePage] {
        guard let container else { return [] }
        return store.children(of: container.id).filter { $0.isExercise || $0.pageType == nil }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let container {
                        if destination.tab == .skills {
                            TimeMasterPageTitle("Skills")
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            SkillBoardScreen(boardID: container.manifest.id)
                        } else {
                            TimeMasterPageTitle("Exercises")
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            ExerciseChildList(pages: exercises)
                        }
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
    }
}
