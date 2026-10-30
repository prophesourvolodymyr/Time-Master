import SwiftUI
import TimeMasterCore

/// A group opened as a page of its own: its strip (colour, or the picture clipped inside it), icon and name, the
/// skills inside it as a board, and everything a skill page holds: what to learn first, notes, files, links.
struct SkillGroupPageView: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    let route: DatabaseSkillGroupRoute

    @State private var editing: SkillGroupEditorSheet.Mode?
    @State private var choosingIcon = false
    @StateObject private var strip = SkillStripImageModel()

    private var container: ExercisePage? { store.page(manifestID: route.containerID) }
    private var section: SkillBoardSection? { container?.manifest.skillBoardSection(route.sectionID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let container, let section {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        hero(container: container, section: section)
                        SkillBoardScreen(boardID: route.groupID)
                        SkillPrerequisitesSection(materialID: route.groupID)
                        SkillNotesSection(materialID: route.groupID)
                        SkillFilesSection(materialID: route.groupID)
                        SkillLinksSection(materialID: route.groupID)
                    }
                    .padding(.vertical, 16)
                    .skillsContained()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.textSecondary)
                    Text("This group is gone.")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                }
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
            if let section {
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button { editing = .edit(section) } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .help("Edit group")
                    .accessibilityLabel("Edit group")
                    .oneHandedActionSource()
                }
            }
        }
        .oneHandedActions(
            id: "skill-group-\(route.groupID)",
            actions: [ReachabilityAction("back", title: "Back") { TimeMasterBackButton() }]
        )
        .sheet(item: $editing) { mode in
            SkillGroupEditorSheet(containerID: route.containerID, mode: mode)
                .environmentObject(store)
        }
        .sheet(isPresented: $choosingIcon) {
            SkillIconChooserSheet(pageID: route.groupID)
                .environmentObject(store)
        }
        .skillErrorAlert()
    }

    private func hero(container: ExercisePage, section: SkillBoardSection) -> some View {
        let imageURL = store.skillGroupImageURL(container: container, section: section)
        return VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 36)
            Text("Group in \(container.title)")
                .font(TimeMasterFont.caption())
                .foregroundStyle(.white.opacity(0.75))
            HStack(alignment: .center, spacing: 12) {
                Button { choosingIcon = true } label: {
                    SkillGroupIconView(section: section, size: 30, colorHex: strip.colors?.top ?? SkillColors.normalizedHex(section.colorHex))
                }.keyNavPlainButtonStyle()
                .help("Change the icon")
                .accessibilityLabel("Change the icon")
                SkillEditableTitle(
                    pageID: route.groupID,
                    title: section.title,
                    font: TimeMasterFont.pageTitle(34, relativeTo: .largeTitle),
                    color: .white,
                    lineLimit: 3,
                    renamesOnPhone: true
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 150, alignment: .bottomLeading)
        .background { SkillGroupStripBackground(imageURL: imageURL, color: section.stripColor, cornerRadius: 20) }
        .task(id: imageURL) { await strip.load(imageURL) }
    }
}
