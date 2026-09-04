import SwiftUI
import TimeMasterCore
#if os(iOS)
import PhotosUI
import UniformTypeIdentifiers
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
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    private var page: ExercisePage? { store.page(id: pageID) }
    private var children: [ExercisePage] { store.children(of: pageID) }
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
            if page?.isLeaf == true {
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
            if page?.isContainer == true {
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
            if page.hasMarkdown {
                markdownSection(page: page)
            }
            if page.hasWorkoutConfig {
                workoutConfigSection(page: page)
            }
            if page.hasMedia {
                PageMediaGalleryGrid(urls: page.mediaURLs) { index in
                    selectedMediaIndex = index
                    mediaGalleryPresented = true
                }
            }
            if page.hasLinks {
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
            if page.isContainer && !children.isEmpty {
                childrenSection
            }
            if !page.hasMarkdown && !page.hasMedia && !page.hasLinks && !page.hasWorkoutConfig && children.isEmpty {
                emptyContentPrompt
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private func markdownSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guide")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            MarkdownTextView(text: guideContent.isEmpty ? page.manifest.markdownBody : guideContent)
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

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Child Pages")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if page?.isContainer == true {
                    Button {
                        childPageParent = page
                        showingAddChildPage = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.primary)
                }
            }

            ForEach(children) { child in
                NavigationLink(destination: ExercisePageDetailView(pageID: child.id)) {
                    PageCardView(
                        page: child,
                        onAddToWorkout: { childToAddWorkout = child },
                        onEdit: { childToEdit = child },
                        onAddChild: { childPageParent = child; showingAddChildPage = true },
                        onDuplicate: { try? store.duplicatePage(child) },
                        onDelete: { try? store.deletePage(id: child.manifest.id) },
                        onMoveIntoContainer: { sourceID in
                            try? store.movePage(
                                id: sourceID,
                                newParentID: child.manifest.id,
                                newOrder: child.children.count
                            )
                        }
                    )
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(item: $childToEdit) { child in
            PageCreationSheet(page: child) { manifest, _ in
                try store.updatePage(id: child.manifest.id, manifest: manifest, newParentID: manifest.parentID)
            }
            .environmentObject(workoutStore)
            .environmentObject(store)
        }
        .sheet(item: $childToAddWorkout) { child in
            WorkoutPickerSheet(page: child)
                .environmentObject(workoutStore)
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
