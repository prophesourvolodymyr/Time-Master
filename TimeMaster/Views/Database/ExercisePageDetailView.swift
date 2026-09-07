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
    let pageID: UUID

    @State private var isEditing = false
    @State private var mediaGalleryPresented = false
    @State private var selectedMediaIndex = 0
    @State private var linkMetadata: [LinkMetadata] = []
    @State private var guideContent = ""
    @State private var showMediaPicker = false
    @State private var showWorkoutPicker = false
    @State private var showingAddChildPage = false
    @State private var childPageParent: ExercisePage?
    @State private var childToEdit: ExercisePage?
    @State private var childToAddWorkout: ExercisePage?
    @State private var showingLinkedPagePicker = false
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    private var page: ExercisePage? { store.page(id: pageID) }
    private var children: [ExercisePage] { store.children(of: pageID) }

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
                    coverHero(page: page)
                    detailContent(page: page)
                }
            } else {
                emptyPageView
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if page?.isWorkoutAddable == true {
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button {
                        showWorkoutPicker = true
                    } label: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .foregroundStyle(Theme.primary)
                    .help("Add to Workout")
                }
            }
            AppToolbar.item(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
                .tint(Theme.primary)
            }
            if page?.canContainChildren == true {
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button {
                        showingAddChildPage = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .foregroundStyle(Theme.primary)
                    .help("Add Child Page")
                }
            }
            #if os(iOS)
            AppToolbar.iconItem(placement: .primaryAction) {
                Button {
                    showMediaPicker = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .foregroundStyle(Theme.primary)
            }
            #endif
        }
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
        .sheet(isPresented: $mediaGalleryPresented) {
            if let page {
                PageMediaGallery(
                    urls: page.mediaURLs,
                    selectedIndex: $selectedMediaIndex,
                    isPresented: $mediaGalleryPresented
                )
            }
        }
        .task {
            loadGuideContent()
            guard let page, !page.manifest.linkURLs.isEmpty else { return }
            linkMetadata = await LinkMetadataFetcher.fetchMetadata(
                for: page.manifest.linkURLs,
                existing: page.manifest.linkMetadata
            )
        }
        .onChange(of: isEditing) { newValue in
            if !newValue { loadGuideContent() }
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
    }

    private func coverHero(page: ExercisePage) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let coverURL = page.coverImageURL {
                AsyncCoverImage(url: coverURL, height: 220, overlayGradient: true)
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                if !breadcrumbs.isEmpty {
                    breadcrumbRow
                }
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(pageTypeLabel(page))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(page.isSkillLike ? Theme.primary : Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            page.isSkillLike ? Theme.primary.opacity(0.16) : Color.black.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                    if let type = page.effectiveWorkoutType {
                        HStack(spacing: 4) {
                            Image(systemName: type.iconName)
                                .font(.caption)
                            Text(type.name)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color(hex: type.colorHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: type.colorHex).opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 220)
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
                        NavigationLink(destination: ExercisePageDetailView(pageID: crumb.id)) {
                            Text(crumb.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    } else {
                        Text(crumb.title)
                            .font(.system(size: 11, weight: .medium))
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
            if page.isSkill {
                attachmentsSection(page: page)
                if page.hasMarkdown {
                    markdownSection(page: page, title: "Notes")
                }
                if !children.isEmpty {
                    skillChildPagesSection
                }
                attachedPagesSection
                if page.hasLinks {
                    linksSection(page: page)
                }
            } else if page.isTutorial {
                attachmentsSection(page: page)
                if page.hasMarkdown {
                    markdownSection(page: page, title: "Notes")
                }
                if page.hasLinks {
                    linksSection(page: page)
                }
                if !children.isEmpty {
                    skillChildPagesSection
                }
                attachedPagesSection
            } else {
                if page.hasMarkdown {
                    markdownSection(page: page, title: "Guide")
                }
                if page.hasWorkoutConfig {
                    workoutConfigSection(page: page)
                }
                if page.hasMedia {
                    PageMediaGalleryGrid(title: "Media", urls: page.mediaURLs) { index in
                        selectedMediaIndex = index
                        mediaGalleryPresented = true
                    }
                }
                if page.hasLinks {
                    linksSection(page: page)
                }
                if page.isContainer {
                    ContainerChildrenTabs(container: page)
                        .environmentObject(store)
                        .environmentObject(workoutStore)
                }
            }

            if !page.hasMarkdown && !page.hasMedia && !page.hasLinks && children.isEmpty && linkedPages.isEmpty {
                emptyContentPrompt
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private func markdownSection(page: ExercisePage, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            MarkdownTextView(text: guideContent.isEmpty ? page.manifest.markdownBody : guideContent)
        }
    }

    private func attachmentsSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if page.hasMedia {
                PageMediaGalleryGrid(title: "", urls: page.mediaURLs) { index in
                    selectedMediaIndex = index
                    mediaGalleryPresented = true
                }
            } else {
                Text("No attachments yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
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
                .font(.headline)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var skillChildPagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Child Pages")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    childPageParent = page
                    showingAddChildPage = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
            }

            ForEach(children) { child in
                NavigationLink(destination: ExercisePageDetailView(pageID: child.id)) {
                    PageCardView(page: child)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var attachedPagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attached Pages")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showingLinkedPagePicker = true
                } label: {
                    Label("Attach", systemImage: "link.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
            }

            if linkedPages.isEmpty {
                Text("Attach any existing page as a reference.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(linkedPages) { linkedPage in
                    NavigationLink(destination: ExercisePageDetailView(pageID: linkedPage.id)) {
                        PageCardView(page: linkedPage)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
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
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tap Edit to add a guide, media, links, and more.")
                .font(.subheadline)
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
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("This page may have been moved or deleted.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadGuideContent() {
        guard let page else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let content = try? DatabaseManager.shared.readGuideContent(pageID: page.manifest.id), !content.isEmpty else { return }
            DispatchQueue.main.async {
                guideContent = content
            }
        }
    }

    #if os(iOS)
    private func uploadPickedMedia(items: [PhotosPickerItem], pageID: String) {
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
                _ = try? DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: sourceURL)
            }
            store.reload()
            loadGuideContent()
            pendingMediaItems = []
        }
    }
    #endif
}

private enum ContainerChildTab: String, CaseIterable, Identifiable, Hashable {
    case exercises
    case skills

    var id: String { rawValue }
    var title: String { self == .exercises ? "Exercises" : "Skills" }
}

private struct ContainerCategoryDestination: Identifiable, Hashable {
    let containerID: UUID
    let tab: ContainerChildTab

    var id: String { "\(containerID.uuidString)-\(tab.rawValue)" }
}

private enum SkillBoardPresentation: String, CaseIterable, Identifiable {
    case notStarted
    case learning
    case completed
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notStarted: "Not Started"
        case .learning: "Learning"
        case .completed: "Completed"
        case .table: "Table"
        }
    }

    var status: SkillStatus? {
        switch self {
        case .notStarted: .notStarted
        case .learning: .learning
        case .completed: .completed
        case .table: nil
        }
    }
}

private struct ContainerChildrenTabs: View {
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    let container: ExercisePage
    @State private var selectedTab: ContainerChildTab = .exercises
    @State private var skillPresentation: SkillBoardPresentation = .notStarted
    @State private var categoryDestination: ContainerCategoryDestination?
    @State private var showingSkillCreation = false

    private var children: [ExercisePage] {
        store.children(of: container.id)
    }

    private var exercises: [ExercisePage] {
        children.filter { $0.isExercise || $0.pageType == nil }
    }

    private var skills: [ExercisePage] {
        children.filter(\.isSkillLike)
    }

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            tabsContent
                .navigationDestination(item: $categoryDestination) { destination in
                    categoryPage(destination)
                }
        } else {
            tabsContent
                .sheet(item: $categoryDestination) { destination in
                    NavigationStack {
                        categoryPage(destination)
                    }
                }
        }
        #else
        tabsContent
            .navigationDestination(item: $categoryDestination) { destination in
                categoryPage(destination)
            }
        #endif
    }

    private var tabsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ContainerChildTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .black : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedTab == tab ? Theme.primary : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            categoryDestination = ContainerCategoryDestination(containerID: container.id, tab: tab)
                        }
                    )
                    .accessibilityHint("Double tap to open \(tab.title.lowercased()) as a full page")
                }
            }

            if selectedTab == .skills {
                HStack(spacing: 10) {
                    Picker("Skills view", selection: $skillPresentation) {
                        ForEach(SkillBoardPresentation.allCases) { presentation in
                            Text(presentation.title).tag(presentation)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showingSkillCreation = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 38, height: 34)
                            .foregroundStyle(Theme.primary)
                            .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.primary.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create skill in \(container.title)")
                }

                if skillPresentation == .table {
                    SkillTableBoardView(container: container, skills: skills)
                } else if let status = skillPresentation.status {
                    SkillSectionList(container: container, skills: skills, status: status)
                }
            } else {
                ExerciseChildList(pages: exercises)
            }
        }
        .sheet(isPresented: $showingSkillCreation) {
            PageCreationSheet(
                parentID: container.manifest.id,
                initialPageType: .skill
            ) { manifest, parentID in
                try store.createPage(manifest: manifest, parentID: parentID)
            } onSaveWithMedia: { manifest, parentID, coverData, mediaData in
                try store.createPageWithMedia(
                    manifest: manifest,
                    parentID: parentID,
                    coverData: coverData,
                    mediaData: mediaData
                )
            }
            .environmentObject(store)
            .environmentObject(workoutStore)
        }
    }

    private func categoryPage(_ destination: ContainerCategoryDestination) -> some View {
        ContainerCategoryPage(destination: destination)
            .environmentObject(store)
            .environmentObject(workoutStore)
    }
}

private struct ExerciseChildList: View {
    let pages: [ExercisePage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if pages.isEmpty {
                VStack(spacing: 6) {
                    Text("No exercises")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Create or move exercises into this container.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(pages) { page in
                    NavigationLink(destination: ExercisePageDetailView(pageID: page.id)) {
                        PageCardView(page: page)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

private struct SkillSectionList: View {
    @EnvironmentObject private var store: DatabaseStore

    let container: ExercisePage
    let skills: [ExercisePage]
    let status: SkillStatus
    @State private var sections: [SkillBoardSection]
    @State private var draggedPageID: String?
    @State private var isPresentingNewSection = false
    @State private var newSectionTitle = ""

    init(container: ExercisePage, skills: [ExercisePage], status: SkillStatus) {
        self.container = container
        self.skills = skills
        self.status = status
        _sections = State(initialValue: container.manifest.skillBoardSections.sorted { $0.order < $1.order })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Skill Sections")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    isPresentingNewSection = true
                } label: {
                    Label("Section", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
            }

            listGroup(title: "Unsectioned", sectionID: nil)
            ForEach(sections) { section in
                listGroup(title: section.title, sectionID: section.id)
            }
        }
        .alert("New skill section", isPresented: $isPresentingNewSection) {
            TextField("Section title", text: $newSectionTitle)
            Button("Add") { addSection() }
            Button("Cancel", role: .cancel) { newSectionTitle = "" }
        } message: {
            Text("Sections divide skills inline.")
        }
    }

    private func listGroup(title: String, sectionID: String?) -> some View {
        let grouped = skills
            .filter { ($0.manifest.skillStatus ?? .notStarted) == status }
            .filter { $0.manifest.skillBoardSectionID == sectionID }
            .sorted { ($0.manifest.skillBoardOrder ?? 0) < ($1.manifest.skillBoardOrder ?? 0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let sectionID {
                    Button(role: .destructive) {
                        deleteSection(id: sectionID)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Delete \(title) section")
                }
            }

            VStack(spacing: 8) {
                if grouped.isEmpty {
                    Text("Drop skills here")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                } else {
                    ForEach(grouped) { page in
                        NavigationLink(destination: ExercisePageDetailView(pageID: page.id)) {
                            HStack(spacing: 10) {
                                PageCardView(page: page)
                                Text(skillStatusLabel(page.manifest.skillStatus ?? .notStarted))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(skillStatusColor(page.manifest.skillStatus ?? .notStarted))
                            }
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .onDrag {
                            draggedPageID = page.manifest.id
                            return NSItemProvider(object: page.manifest.id as NSString)
                        }
                        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
                            guard let draggedPageID, draggedPageID != page.manifest.id else { return false }
                            movePage(id: draggedPageID, to: sectionID, before: page.manifest.id)
                            self.draggedPageID = nil
                            return true
                        }
                    }
                }
            }
            .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
                guard let draggedPageID else { return false }
                movePage(id: draggedPageID, to: sectionID, before: nil)
                self.draggedPageID = nil
                return true
            }
        }
    }

    private func movePage(id: String, to sectionID: String?, before: String?) {
        guard let moved = skills.first(where: { $0.manifest.id == id }) else { return }
        var reorderedIDs = skills
            .filter { ($0.manifest.skillStatus ?? .notStarted) == status }
            .filter { $0.manifest.skillBoardSectionID == sectionID && $0.manifest.id != id }
            .sorted { ($0.manifest.skillBoardOrder ?? 0) < ($1.manifest.skillBoardOrder ?? 0) }
            .map(\.manifest.id)
        if let before, let index = reorderedIDs.firstIndex(of: before) {
            reorderedIDs.insert(id, at: index)
        } else {
            reorderedIDs.append(id)
        }

        let placements = skills.map { page -> SkillBoardPlacement in
            let pageID = page.manifest.id
            let isMoved = pageID == moved.manifest.id
            let targetOrder = reorderedIDs.firstIndex(of: pageID)
            return SkillBoardPlacement(
                pageID: pageID,
                status: isMoved ? status : page.manifest.skillStatus ?? .notStarted,
                sectionID: isMoved ? sectionID : page.manifest.skillBoardSectionID,
                order: targetOrder ?? page.manifest.skillBoardOrder ?? 0
            )
        }
        try? store.persistSkillBoard(
            containerID: container.manifest.id,
            sections: sections,
            placements: placements
        )
    }

    private func addSection() {
        let title = newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        sections.append(SkillBoardSection(title: title, order: sections.count))
        newSectionTitle = ""
        persistSections()
    }

    private func deleteSection(id: String) {
        sections.removeAll { $0.id == id }
        let placements = skills.map {
            SkillBoardPlacement(
                pageID: $0.manifest.id,
                status: $0.manifest.skillStatus ?? .notStarted,
                sectionID: $0.manifest.skillBoardSectionID == id ? nil : $0.manifest.skillBoardSectionID,
                order: $0.manifest.skillBoardOrder ?? 0
            )
        }
        try? store.persistSkillBoard(
            containerID: container.manifest.id,
            sections: sections,
            placements: placements
        )
    }

    private func persistSections() {
        let placements = skills.map {
            SkillBoardPlacement(
                pageID: $0.manifest.id,
                status: $0.manifest.skillStatus ?? .notStarted,
                sectionID: $0.manifest.skillBoardSectionID,
                order: $0.manifest.skillBoardOrder ?? 0
            )
        }
        try? store.persistSkillBoard(
            containerID: container.manifest.id,
            sections: sections,
            placements: placements
        )
    }
}

private struct SkillBoardItem: Identifiable {
    let page: ExercisePage
    var status: SkillStatus
    var sectionID: String?
    var order: Int

    var id: String {
        page.manifest.id
    }
}

private struct SkillTableBoardView: View {
    @EnvironmentObject private var store: DatabaseStore

    let container: ExercisePage
    @State private var sections: [SkillBoardSection]
    @State private var items: [SkillBoardItem]
    @State private var draggedItemID: String?
    @State private var isPresentingNewSection = false
    @State private var newSectionTitle = ""

    init(container: ExercisePage, skills: [ExercisePage]) {
        self.container = container
        _sections = State(initialValue: container.manifest.skillBoardSections.sorted { $0.order < $1.order })
        _items = State(initialValue: skills.enumerated().map { index, page in
            SkillBoardItem(
                page: page,
                status: page.manifest.skillStatus ?? .notStarted,
                sectionID: page.manifest.skillBoardSectionID,
                order: page.manifest.skillBoardOrder ?? index
            )
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Table")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    isPresentingNewSection = true
                } label: {
                    Label("Section", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(SkillStatus.allCases, id: \.self) { status in
                        tableColumn(for: status)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 18)
            }
            .frame(maxWidth: .infinity, minHeight: 340)
        }
        .alert("New skill section", isPresented: $isPresentingNewSection) {
            TextField("Section title", text: $newSectionTitle)
            Button("Add") { addSection() }
            Button("Cancel", role: .cancel) { newSectionTitle = "" }
        } message: {
            Text("Sections divide skills inside every status column.")
        }
    }

    private func tableColumn(for status: SkillStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(skillStatusLabel(status))
                    .font(.headline)
                    .foregroundStyle(skillStatusColor(status))
                Spacer()
                Text("\(items.filter { $0.status == status }.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }

            tableGroup(title: "Unsectioned", status: status, sectionID: nil)
            ForEach(sections) { section in
                tableGroup(title: section.title, status: status, sectionID: section.id)
            }
        }
        .padding(10)
        .frame(width: 288, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func tableGroup(title: String, status: SkillStatus, sectionID: String?) -> some View {
        let groupItems = sortedItems(status: status, sectionID: sectionID)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let sectionID {
                    Button(role: .destructive) {
                        deleteSection(id: sectionID)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Delete \(title) section")
                }
            }

            VStack(spacing: 8) {
                if groupItems.isEmpty {
                    Text("Drop skills here")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                } else {
                    ForEach(groupItems) { item in
                        skillCard(item, status: status, sectionID: sectionID)
                    }
                }
            }
            .padding(8)
            .background(Theme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
                guard let draggedItemID else { return false }
                moveItem(id: draggedItemID, to: status, sectionID: sectionID, before: nil)
                self.draggedItemID = nil
                return true
            }
        }
    }

    private func skillCard(_ item: SkillBoardItem, status: SkillStatus, sectionID: String?) -> some View {
        NavigationLink(destination: ExercisePageDetailView(pageID: item.page.id)) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(item.page.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                if !item.page.mediaURLs.isEmpty {
                    Text("\(item.page.mediaURLs.count) attachments")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onDrag {
            draggedItemID = item.id
            return NSItemProvider(object: item.id as NSString)
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { _ in
            guard let draggedItemID, draggedItemID != item.id else { return false }
            moveItem(id: draggedItemID, to: status, sectionID: sectionID, before: item.id)
            self.draggedItemID = nil
            return true
        }
    }

    private func sortedItems(status: SkillStatus, sectionID: String?) -> [SkillBoardItem] {
        items
            .filter { $0.status == status && $0.sectionID == sectionID }
            .sorted { $0.order < $1.order }
    }

    private func moveItem(id: String, to status: SkillStatus, sectionID: String?, before: String?) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return }
        var moved = items.remove(at: sourceIndex)
        moved.status = status
        moved.sectionID = sectionID
        items.append(moved)

        var targetIDs = sortedItems(status: status, sectionID: sectionID)
            .filter { $0.id != moved.id }
            .map(\.id)
        if let before, let insertionIndex = targetIDs.firstIndex(of: before) {
            targetIDs.insert(moved.id, at: insertionIndex)
        } else {
            targetIDs.append(moved.id)
        }
        applyOrders(targetIDs, status: status, sectionID: sectionID)
        normalizeOrders()
        persist()
    }

    private func applyOrders(_ ids: [String], status: SkillStatus, sectionID: String?) {
        for (index, id) in ids.enumerated() {
            guard let itemIndex = items.firstIndex(where: { $0.id == id }) else { continue }
            items[itemIndex].status = status
            items[itemIndex].sectionID = sectionID
            items[itemIndex].order = index
        }
    }

    private func normalizeOrders() {
        let sectionIDs: [String?] = [nil] + sections.map(\.id)
        for status in SkillStatus.allCases {
            for sectionID in sectionIDs {
                let ids = sortedItems(status: status, sectionID: sectionID).map(\.id)
                applyOrders(ids, status: status, sectionID: sectionID)
            }
        }
    }

    private func addSection() {
        let title = newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        sections.append(SkillBoardSection(title: title, order: sections.count))
        newSectionTitle = ""
        persist()
    }

    private func deleteSection(id: String) {
        for index in items.indices where items[index].sectionID == id {
            items[index].sectionID = nil
        }
        sections.removeAll { $0.id == id }
        normalizeOrders()
        persist()
    }

    private func persist() {
        let placements = items.map {
            SkillBoardPlacement(
                pageID: $0.id,
                status: $0.status,
                sectionID: $0.sectionID,
                order: $0.order
            )
        }
        try? store.persistSkillBoard(
            containerID: container.manifest.id,
            sections: sections,
            placements: placements
        )
    }
}

private struct ContainerCategoryPage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    let destination: ContainerCategoryDestination
    @State private var skillPresentation: SkillBoardPresentation = .notStarted

    private var container: ExercisePage? {
        store.page(id: destination.containerID)
    }

    private var children: [ExercisePage] {
        guard let container else { return [] }
        return store.children(of: container.id)
    }

    private var exercises: [ExercisePage] {
        children.filter { $0.isExercise || $0.pageType == nil }
    }

    private var skills: [ExercisePage] {
        children.filter(\.isSkillLike)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let container {
                        if destination.tab == .skills {
                            Picker("Skills view", selection: $skillPresentation) {
                                ForEach(SkillBoardPresentation.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            if skillPresentation == .table {
                                SkillTableBoardView(container: container, skills: skills)
                            } else if let status = skillPresentation.status {
                                SkillSectionList(container: container, skills: skills, status: status)
                            }
                        } else {
                            ExerciseChildList(pages: exercises)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(destination.tab.title)
        .toolbar {
            AppToolbar.item(placement: .cancellationAction) {
                Button("Back") { dismiss() }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
            }
        }
    }
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
                                    .foregroundStyle(selectedIDs.contains(candidate.manifest.id) ? Theme.primary : Theme.textSecondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(pageTypeLabel(candidate))
                                        .font(.caption)
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
            .navigationTitle("Attach Pages")
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
                        .font(.footnote)
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

private func skillStatusLabel(_ status: SkillStatus) -> String {
    switch status {
    case .notStarted: "Not Started"
    case .learning: "Learning"
    case .completed: "Completed"
    }
}

private func skillStatusColor(_ status: SkillStatus) -> Color {
    switch status {
    case .notStarted: Theme.textSecondary
    case .learning: Theme.primary
    case .completed: Color(hex: "B6E9BF")
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
