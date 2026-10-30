import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

struct ExercisePageDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.workoutMedia) private var workoutMedia
    let pageID: UUID
    var showsHero = true
    @ScaledMetric(relativeTo: .largeTitle) private var coverMinimumHeight: CGFloat = 220

    @State private var isEditing = false
    @State private var mediaGalleryPresented = false
    @State private var selectedMediaIndex = 0
    @State private var mediaGalleryOpensEditor = false
    @State private var linkMetadata: [LinkMetadata] = []
    @State private var showMediaPicker = false
    @State private var showWorkoutPicker = false
    @State private var showingAddChildPage = false
    @State private var childPageParent: ExercisePage?
    @State private var showingLinkedPagePicker = false
    @State private var choosingIcon = false
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    private var page: ExercisePage? { store.page(id: pageID) }

    private var linkedPages: [ExercisePage] {
        guard let page else { return [] }
        return page.manifest.linkedPageIDs.compactMap { id in
            guard let pageID = UUID(uuidString: id) else { return nil }
            return store.page(id: pageID)
        }
    }
    private var breadcrumbs: [ExercisePage] { store.breadcrumbs(for: pageID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let page {
                ScrollView {
                    VStack(spacing: 0) {
                        if showsHero { coverHero(page: page) }
                        detailContent(page: page)
                    }
                }
            } else {
                emptyPageView
            }
        }
        .timeMasterNavigationTitle(showsHero ? "" : (page?.title ?? "Workout"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #else
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            AppToolbar.iconItem(placement: .cancellationAction) {
                TimeMasterBackButton()
                    .oneHandedActionSource()
            }
            if page?.isWorkoutAddable == true {
                AppToolbar.iconItem(placement: .primaryAction) {
                    addToWorkoutButton.oneHandedActionSource()
                }
            }
            if page?.isSkillLike == true {
                AppToolbar.iconItem(placement: .primaryAction) {
                    attachPageButton.oneHandedActionSource()
                }
            }
            AppToolbar.iconItem(placement: .primaryAction) {
                editPageButton.oneHandedActionSource()
            }
            if page?.canContainChildren == true {
                AppToolbar.iconItem(placement: .primaryAction) {
                    addChildPageButton.oneHandedActionSource()
                }
            }
            #if os(iOS)
            AppToolbar.iconItem(placement: .primaryAction) {
                addMediaButton.oneHandedActionSource()
            }
            #endif
        }
        .oneHandedActions(id: "exercise-page-\(pageID)", actions: pageActions)
        .sheet(isPresented: $isEditing) {
            if let page {
                PageCreationSheet(page: page) { manifest, _ in
                    try store.updatePage(id: page.manifest.id, manifest: manifest, newParentID: manifest.parentID)
                }
                .environmentObject(workoutStore)
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showWorkoutPicker) {
            if let page {
                WorkoutPickerSheet(page: page)
                    .environmentObject(workoutStore)
            }
        }
        .sheet(isPresented: $choosingIcon) {
            if let page {
                SkillIconChooserSheet(pageID: page.manifest.id)
                    .environmentObject(store)
            }
        }

        .sheet(isPresented: $showingLinkedPagePicker) {
            if let page {
                LinkedPagePickerSheet(
                    page: page,
                    onSave: { pageIDs in
                        try store.updateLinkedPages(
                            pageID: page.manifest.id,
                            linkedPageIDs: pageIDs
                        )
                    }
                )
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showingAddChildPage) {
            if let parent = childPageParent ?? page {
                PageCreationSheet(parentID: parent.manifest.id) { manifest, parentID in
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
        }
        .onChange(of: showingAddChildPage) { isPresented in
            if !isPresented { childPageParent = nil }
        }
        .mediaViewerCover(isPresented: $mediaGalleryPresented) {
            if let page {
                PageMediaGallery(
                    urls: page.mediaURLs,
                    selectedIndex: $selectedMediaIndex,
                    isPresented: $mediaGalleryPresented,
                    comments: page.mediaCommentsByURL,
                    onSaveComment: { url, comment in
                        try store.updateMediaComment(pageID: page.manifest.id, filename: url.lastPathComponent, comment: comment)
                    },
                    opensEditor: mediaGalleryOpensEditor,
                    notesAssets: { _ in FolderMarkdownAssets(folder: store.folderURL(for: page)) },
                    workout: workoutMedia?.workout,
                    liveContext: workoutMedia?.liveContext
                )
            }
        }
        .task {
            guard let page, !page.manifest.linkURLs.isEmpty else { return }
            linkMetadata = await LinkMetadataFetcher.fetchMetadata(
                for: page.manifest.linkURLs,
                existing: page.manifest.linkMetadata
            )
        }
        #if os(iOS)
        .photosPicker(
            isPresented: $showMediaPicker,
            selection: $pendingMediaItems,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pendingMediaItems) { items in
            guard let page, !items.isEmpty else { return }
            uploadPickedMedia(items: items, pageID: page.manifest.id)
        }
        #endif
        .skillErrorAlert()
    }

    private var pageActions: [ReachabilityAction] {
        var actions = [
            ReachabilityAction("back", title: "Back") {
                TimeMasterBackButton()
            }
        ]
        if page?.isWorkoutAddable == true {
            actions.append(ReachabilityAction("add-to-workout", title: "Add to Workout") {
                addToWorkoutButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
            })
        }
        if page?.isSkillLike == true {
            actions.append(ReachabilityAction("attach-page", title: "Attach Page") {
                attachPageButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
            })
        }
        actions.append(ReachabilityAction("edit", title: "Edit") {
            editPageButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
        })
        if page?.canContainChildren == true {
            actions.append(ReachabilityAction("add-child", title: "Add Child Page") {
                addChildPageButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
            })
        }
        #if os(iOS)
        actions.append(ReachabilityAction("add-media", title: "Add Media") {
            addMediaButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
        })
        #endif
        return actions
    }

    private var addToWorkoutButton: some View {
        Button {
            showWorkoutPicker = true
        } label: {
            Image(systemName: "figure.strengthtraining.traditional")
        }
        .help("Add to Workout")
        .accessibilityLabel("Add to Workout")
    }

    private var attachPageButton: some View {
        Button {
            showingLinkedPagePicker = true
        } label: {
            Image(systemName: "plus")
        }
        .help("Attach Page")
        .accessibilityLabel("Attach Page")
    }

    private var editPageButton: some View {
        Button {
            isEditing = true
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .bold))
        }
        .help("Edit Page")
        .accessibilityLabel("Edit Page")
    }

    private var addChildPageButton: some View {
        Button {
            showingAddChildPage = true
        } label: {
            Image(systemName: "doc.badge.plus")
        }
        .help("Add Child Page")
        .accessibilityLabel("Add Child Page")
    }

    #if os(iOS)
    private var addMediaButton: some View {
        Button {
            showMediaPicker = true
        } label: {
            Image(systemName: "photo.badge.plus")
        }
        .accessibilityLabel("Add Media")
    }
    #endif

    private func coverHero(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: coverMinimumHeight * 0.35)
            if breadcrumbs.count > 1 {
                breadcrumbRow
            }
            if page.isSkillLike {
                HStack(alignment: .center, spacing: 12) {
                    Button { choosingIcon = true } label: {
                        SkillPageIconTile(page: page, size: 44)
                    }
                    .keyNavPlainButtonStyle()
                    .help("Change the icon")
                    .accessibilityLabel("Change the icon")
                    SkillEditableTitle(
                        pageID: page.manifest.id,
                        title: page.title,
                        font: TimeMasterFont.pageTitle(40, relativeTo: .largeTitle),
                        color: .white,
                        lineLimit: 3,
                        renamesOnPhone: true
                    )
                }
                .shadow(color: .black.opacity(0.4), radius: 3)
            } else {
                TimeMasterPageTitle(page.title)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text(pageTypeLabel(page))
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.85))
                if let type = page.effectiveWorkoutType {
                    Label {
                        Text(type.name)
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                    } icon: {
                        Image(systemName: type.iconName)
                            .font(.caption.weight(.medium))
                    }
                        .foregroundStyle(.white)
                }
                if page.isSkillLike {
                    SkillTypePicker(pageID: page.manifest.id) {
                        if let skillType = store.skillType(of: page) {
                            SkillTypeChip(type: skillType, showsChevron: true)
                        } else {
                            SkillAddTypeChip()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: coverMinimumHeight, alignment: .bottomLeading)
        .background {
            GeometryReader { proxy in
                ZStack {
                    if let coverURL = page.coverImageURL {
                        AsyncCoverImage(url: coverURL, height: proxy.size.height, overlayGradient: false)
                    } else {
                        Theme.surface
                    }
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
            }
        }
        .clipped()
    }

    private var breadcrumbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if crumb.id != pageID {
                        NavigationLink(value: DatabasePageRoute(pageID: crumb.manifest.id)) {
                            Text(crumb.title)
                                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .keyNavPlainButtonStyle()
                    } else {
                        Text(crumb.title)
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func detailContent(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if page.hasMedia && !page.isSkillLike {
                MediaStrip(
                    title: showsHero ? "Media" : "",
                    urls: page.mediaURLs,
                    marksCover: showsHero,
                    comments: page.mediaCommentsByURL,
                    onOpen: { index in
                        selectedMediaIndex = index
                        mediaGalleryOpensEditor = false
                        mediaGalleryPresented = true
                    },
                    onOpenNotes: { index in
                        selectedMediaIndex = index
                        mediaGalleryOpensEditor = true
                        mediaGalleryPresented = true
                    }
                )
            }

            if page.isSkill || page.isTutorial {
                SkillPrerequisitesSection(materialID: page.manifest.id)
                SkillNotesSection(materialID: page.manifest.id)
                SkillFilesSection(materialID: page.manifest.id)
                SkillLinksSection(materialID: page.manifest.id)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sub-skills")
                        .font(TimeMasterFont.sectionTitle())
                        .foregroundStyle(Theme.textPrimary)
                    SkillBoardScreen(boardID: page.manifest.id)
                }
                if !linkedPages.isEmpty {
                    attachedPagesSection
                }
            } else if page.isContainer {
                ContainerChildrenTabs(container: page)
                    .environmentObject(store)
                    .environmentObject(workoutStore)
                if page.hasMarkdown {
                    markdownSection(page: page, title: "Notes")
                }
                if page.hasLinks {
                    linksSection(page: page)
                }
            } else {
                if page.hasMarkdown {
                    markdownSection(page: page, title: "Guide")
                }
                if page.hasWorkoutConfig {
                    workoutConfigSection(page: page)
                }
                if page.hasLinks {
                    linksSection(page: page)
                }
            }

            if !page.isContainer &&
                !page.isSkillLike &&
                !page.hasMarkdown &&
                !page.hasMedia &&
                !page.hasLinks {
                emptyContentPrompt
            }
        }
        .skillsContained(maxWidth: page.isSkillLike || page.isContainer ? SkillsLayout.pageWidth : .infinity)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }


    private func markdownSection(page: ExercisePage, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            MarkdownTextView(
                text: page.manifest.markdownBody,
                assets: FolderMarkdownAssets(folder: store.folderURL(for: page))
            )
        }
    }


    private func linksSection(page: ExercisePage) -> some View {
        VideoEmbedListView(
            urls: page.manifest.linkURLs,
            metadata: linkMetadata
        ) { urlString in
            guard let url = URL(string: urlString) else { return }
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }

    private func workoutConfigSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Config")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                configBadge(label: "Duration", value: "\(page.manifest.duration ?? 0)s")
                if let sets = page.manifest.sets {
                    configBadge(label: "Sets", value: "\(sets)")
                }
                if let restSets = page.manifest.restBetweenSets, (page.manifest.sets ?? 1) > 1 {
                    configBadge(label: "Rest Between Sets", value: "\(restSets)s")
                }
                if let rest = page.manifest.restAfter {
                    configBadge(
                        label: (page.manifest.sets ?? 1) > 1 ? "Big Rest" : "Rest",
                        value: "\(rest)s"
                    )
                }
            }
        }
    }

    private func configBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(TimeMasterFont.heading())
                .foregroundStyle(.white)
            Text(label)
                .font(TimeMasterFont.micro())
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var attachedPagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attached Pages")
                    .font(TimeMasterFont.sectionTitle())
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showingLinkedPagePicker = true
                } label: {
                    Label {
                        Text("Attach")
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    } icon: {
                        Image(systemName: "link.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 12))
            }

            if linkedPages.isEmpty {
                Text("Attach any existing page as a reference.")
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(linkedPages) { linkedPage in
                    NavigationLink(value: DatabasePageRoute(pageID: linkedPage.manifest.id)) {
                        PageCardView(page: linkedPage)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .keyNavPlainButtonStyle()
                }
            }
        }
    }

    private var emptyContentPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("This page is empty")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            Text("Tap Edit to add a guide, media, links, and more.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyPageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("Page not found")
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            Text("This page may have been moved or deleted.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    #if os(iOS)
    private func uploadPickedMedia(items: [PhotosPickerItem], pageID: String) {
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        Task { @MainActor in
            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .audiovisualContent) }
                let sourceURL: URL?
                if isVideo, let movie = try? await item.loadTransferable(type: MovieFile.self) {
                    sourceURL = movie.url
                } else if let data = try? await item.loadTransferable(type: Data.self) {
                    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                    try? data.write(to: temporaryURL)
                    sourceURL = temporaryURL
                } else {
                    sourceURL = nil
                }

                guard let sourceURL else { continue }
                defer { try? FileManager.default.removeItem(at: sourceURL) }
                try? ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                    _ = try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: sourceURL)
                }
            }
            store.reload()
            pendingMediaItems = []
        }
    }
    #endif
}

private struct LinkedPagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    let page: ExercisePage
    let onSave: ([String]) throws -> Void
    @State private var selectedIDs: Set<String>
    @State private var saveError: String?

    init(page: ExercisePage, onSave: @escaping ([String]) throws -> Void) {
        self.page = page
        self.onSave = onSave
        _selectedIDs = State(initialValue: Set(page.manifest.linkedPageIDs))
    }

    private var candidates: [ExercisePage] {
        store.allPagesFlat
            .filter { $0.manifest.id != page.manifest.id }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    ForEach(candidates) { candidate in
                        Button {
                            toggle(candidate.manifest.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedIDs.contains(candidate.manifest.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(candidate.manifest.id) ? Theme.toolbarOrange : Theme.textSecondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(pageTypeLabel(candidate))
                                        .font(TimeMasterFont.caption())
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .timeMasterNavigationTitle("Attach Pages")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
            .overlay(alignment: .bottom) {
                if let saveError {
                    Text(saveError)
                        .font(TimeMasterFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func save() {
        let ids = candidates
            .map(\.manifest.id)
            .filter { selectedIDs.contains($0) }
        do {
            try onSave(ids)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}


private func pageTypeLabel(_ page: ExercisePage) -> String {
    switch page.pageType {
    case .exercise: "Exercise"
    case .skill: "Skill"
    case .tutorial: "Tutorial"
    case nil: "Container"
    }
}
