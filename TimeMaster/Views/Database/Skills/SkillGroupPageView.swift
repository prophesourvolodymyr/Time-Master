import SwiftUI
import TimeMasterCore

/// A group opened as a page of its own: its picture as a banner when it has one, its icon tile and name, how much of it
/// is done, then everything it holds: its files and links first, its sub-skills as a board, what to learn first, and
/// its notes below.
struct SkillGroupPageView: View {
    @EnvironmentObject private var store: DatabaseStore

    let route: DatabaseSkillGroupRoute

    @State private var editing: SkillBoardSection?
    @State private var choosingIcon = false
    @StateObject private var strip = SkillStripImageModel()
    @State private var scrollEdge = PageScrollEdge()

    private var container: ExercisePage? { store.page(manifestID: route.containerID) }
    private var section: SkillBoardSection? { container?.manifest.skillBoardSection(route.sectionID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let container, let section {
                ScrollView {
                    VStack(alignment: .leading, spacing: SkillMetrics.s6) {
                        hero(container: container, section: section)
                        VStack(alignment: .leading, spacing: SkillMetrics.s6) {
                            SkillFilesSection(materialID: route.groupID)
                            SkillLinksSection(materialID: route.groupID)
                            divider
                            SkillBoardScreen(boardID: route.groupID)
                            divider
                            SkillPrerequisitesSection(materialID: route.groupID)
                            divider
                            SkillNotesSection(materialID: route.groupID)
                        }
                        .skillsContained()
                    }
                    .padding(.bottom, 40)
                    .pageScrollEdgeProbe(scrollEdge)
                }
                PageTopChrome(edge: scrollEdge)
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
            if let section {
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button { editing = section } label: {
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
        .sheet(item: $editing) { section in
            SkillSectionEditorSheet(boardID: route.containerID, section: section)
                .environmentObject(store)
        }
        .sheet(isPresented: $choosingIcon) {
            SkillIconChooserSheet(pageID: route.groupID)
                .environmentObject(store)
        }
        .skillErrorAlert()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    // MARK: Hero

    private func hero(container: ExercisePage, section: SkillBoardSection) -> some View {
        let imageURL = store.skillGroupImageURL(container: container, section: section)
        let index = container.manifest.orderedSkillBoardSections.firstIndex { $0.id == section.id } ?? 0
        let tintHex = strip.colors?.top ?? SkillSectionPalette.resolvedHex(for: section, index: index)
        let progress = store.skillProgress(of: route.groupID)
        return VStack(alignment: .leading, spacing: 0) {
            if let imageURL {
                banner(imageURL)
            }
            VStack(alignment: .leading, spacing: SkillMetrics.s1) {
                Text("Group in \(TimeMasterFont.initialCapitalizedTitle(container.title))")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                HStack(alignment: .center, spacing: SkillGroupHeroMetrics.iconSpacing) {
                    Button { choosingIcon = true } label: {
                        SkillIconView(
                            iconName: section.icon ?? "square.grid.2x2",
                            iconType: section.icon == nil ? SkillBoardIconType.system : section.iconType,
                            colorHex: tintHex,
                            size: SkillGroupHeroMetrics.glyphSize
                        )
                        .frame(width: SkillGroupHeroMetrics.iconSide, height: SkillGroupHeroMetrics.iconSide)
                        .skillTile(cornerRadius: SkillGroupHeroMetrics.iconSide * 0.32)
                    }
                    .buttonStyle(SkillPressButtonStyle())
                    .pageCoverPointer()
                    .help("Edit the icon")
                    .accessibilityLabel("Edit icon")
                    .accessibilityHint("Opens the icon chooser")
                    SkillEditableTitle(
                        pageID: route.groupID,
                        title: section.title,
                        font: TimeMasterFont.pageTitle(SkillGroupHeroMetrics.titleSize, relativeTo: .title),
                        lineLimit: 2,
                        renamesOnPhone: true
                    )
                    .accessibilityAddTraits(.isHeader)
                }
                HStack(spacing: SkillMetrics.s3) {
                    Capsule(style: .continuous)
                        .fill(Color(hex: tintHex))
                        .frame(width: 22, height: 5)
                        .accessibilityHidden(true)
                    if progress.total > 0 {
                        SkillProgressRing(fraction: progress.fraction, tint: Color(hex: tintHex), lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                    Text(progress.summary)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(minHeight: SkillMetrics.touch)
            }
            .padding(.top, imageURL == nil ? SkillMetrics.s5 : SkillMetrics.s2)
            .skillsContained()
        }
        .task(id: imageURL) { await strip.load(imageURL) }
    }

    /// The group's picture across the full width, fading into the page at the bottom.
    private func banner(_ url: URL) -> some View {
        SkillLocalImage(url: url, maxPixel: 1600)
            .frame(maxWidth: .infinity)
            .frame(height: SkillGroupHeroMetrics.bannerHeight)
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Theme.background.opacity(0.3), location: 0),
                        .init(color: Theme.background.opacity(0), location: 0.28),
                        .init(color: Theme.background.opacity(0), location: 0.5),
                        .init(color: Theme.background.opacity(0.72), location: 0.84),
                        .init(color: Theme.background, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }
}

/// Sizes of the group page's hero; the Mac gets a larger tile and title, read from further away than a phone.
private enum SkillGroupHeroMetrics {
    #if os(macOS)
    static let iconSide: CGFloat = 64
    static let glyphSize: CGFloat = 28
    static let titleSize: CGFloat = 34
    static let iconSpacing: CGFloat = SkillMetrics.s5
    static let bannerHeight: CGFloat = 168
    #else
    static let iconSide: CGFloat = 56
    static let glyphSize: CGFloat = 26
    static let titleSize: CGFloat = 28
    static let iconSpacing: CGFloat = SkillMetrics.s4
    static let bannerHeight: CGFloat = 132
    #endif
}
