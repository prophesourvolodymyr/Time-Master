import SwiftUI
import TimeMasterCore
#if os(iOS)
import PhotosUI
#endif

struct ExercisePageDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    let pageID: UUID

    @State private var scrollOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var mediaGalleryPresented = false
    @State private var selectedMediaIndex = 0
    @State private var linkMetadata: [LinkMetadata] = []
    @State private var guideContent: String = ""
    @State private var showMediaPicker = false
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    private var page: ExercisePage? { store.page(id: pageID) }
    private var children: [ExercisePage] { store.children(of: pageID) }
    private var breadcrumbs: [ExercisePage] { store.breadcrumbs(for: pageID) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let page = page {
                ScrollView {
                    scrollOffsetReader
                    coverHero(page: page)
                    detailContent(page: page)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    scrollOffset = offset
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
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .foregroundColor(.white)
            }
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showMediaPicker = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .foregroundColor(.white)
            }
            #endif
        }
        .sheet(isPresented: $isEditing) {
            if let page = page {
                PageCreationSheet(page: page) { manifest, _ in
                    try? store.updatePage(id: page.manifest.id, manifest: manifest, newParentID: manifest.parentID)
                }
                .environmentObject(WorkoutStore())
            }
        }
        .sheet(isPresented: $mediaGalleryPresented) {
            if let page = page {
                PageMediaGallery(
                    urls: page.mediaURLs,
                    selectedIndex: $selectedMediaIndex,
                    isPresented: $mediaGalleryPresented
                )
            }
        }
        .task {
            loadGuideContent()
            guard let page = page else { return }
            if !page.manifest.linkURLs.isEmpty {
                linkMetadata = await LinkMetadataFetcher.fetchMetadata(
                    for: page.manifest.linkURLs,
                    existing: page.manifest.linkMetadata
                )
            }
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
            guard let page = page, !items.isEmpty else { return }
            uploadPickedMedia(items: items, pageID: page.manifest.id)
        }
        #endif
    }

    @ViewBuilder
    private var scrollOffsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollOffsetKey.self,
                value: geo.frame(in: .named("scroll")).minY
            )
        }
        .frame(height: 0)
    }

    private func coverHero(page: ExercisePage) -> some View {
        let baseHeight: CGFloat = 220
        let parallaxOffset = scrollOffset > 0 ? -scrollOffset * 0.5 : 0
        let totalHeight = max(baseHeight + parallaxOffset, baseHeight * 0.6)

        return ZStack(alignment: .bottomLeading) {
            if let coverURL = page.coverImageURL {
                coverImageView(url: coverURL)
                    .frame(height: totalHeight)
            } else if let iconName = page.manifest.iconName {
                iconHeroView(iconName: iconName, page: page)
                    .frame(height: totalHeight)
            } else {
                gradientHeroView(page: page)
                    .frame(height: totalHeight)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !breadcrumbs.isEmpty {
                    breadcrumbRow
                }
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .lineLimit(2)
                if let wt = page.manifest.workoutType {
                    HStack(spacing: 4) {
                        Image(systemName: wt.iconName).font(.caption)
                        Text(wt.name).font(.caption.weight(.medium))
                    }
                    .foregroundColor(Color(hex: wt.colorHex))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: wt.colorHex).opacity(0.2))
                    .cornerRadius(5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .clipped()
        .offset(y: parallaxOffset > 0 ? 0 : parallaxOffset)
    }

    private var breadcrumbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if crumb.id != pageID {
                        NavigationLink(destination: ExercisePageDetailView(pageID: crumb.id)) {
                            Text(crumb.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    } else {
                        Text(crumb.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func coverImageView(url: URL) -> some View {
        #if os(iOS)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            )
        }
        #elseif os(macOS)
        if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            return AnyView(
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            )
        }
        #endif
        return AnyView(gradientHeroView(page: page!))
    }

    private func iconHeroView(iconName: String, page: ExercisePage) -> some View {
        let color = page.manifest.workoutType?.colorHex ?? "FFFFFF"
        return AnyView(
            ZStack {
                Color(hex: color).opacity(0.3)
                Image(systemName: iconName)
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: color).opacity(0.7))
            }
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
        )
    }

    private func gradientHeroView(page: ExercisePage) -> some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: page.isContainer ? "folder.fill" : "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.08))
                        Spacer()
                    }
                    Spacer()
                }
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
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
                .padding(.horizontal, 0)
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

            if !page.manifest.tags.isEmpty {
                tagsSection(page: page)
            }

            if !children.isEmpty {
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
                .foregroundColor(Theme.textPrimary)
            MarkdownTextView(text: guideContent.isEmpty ? page.manifest.markdownBody : guideContent)
        }
    }

    private func workoutConfigSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Config")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack(spacing: 10) {
                configBadge(label: "Duration", value: "\(page.manifest.duration ?? 0)s")
                if let rest = page.manifest.restAfter {
                    configBadge(label: "Rest", value: "\(rest)s")
                }
                if let sets = page.manifest.sets {
                    configBadge(label: "Sets", value: "\(sets)")
                }
                if let restSets = page.manifest.restBetweenSets {
                    configBadge(label: "Set Rest", value: "\(restSets)s")
                }
            }
        }
    }

    private func configBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .cornerRadius(10)
    }

    private func tagsSection(page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            FlowLayout(spacing: 6) {
                ForEach(page.manifest.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
            }
        }
    }

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Child Pages")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            ForEach(children) { child in
                NavigationLink(destination: ExercisePageDetailView(pageID: child.id)) {
                    PageCardView(page: child)
                        .padding(12)
                        .background(Theme.surface)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var emptyContentPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("This page is empty")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("Tap Edit to add a guide, media, links, and more.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyPageView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary)
            Text("Page not found")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text("This page may have been moved or deleted.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadGuideContent() {
        guard let page = page else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let content = try? DatabaseManager.shared.readGuideContent(pageID: page.manifest.id),
               !content.isEmpty {
                DispatchQueue.main.async {
                    guideContent = content
                }
            }
        }
    }

    #if os(iOS)
    private func uploadPickedMedia(items: [PhotosPickerItem], pageID: String) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                guard case .success(let data) = result else { return }
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try data.write(to: tempURL)
                    _ = try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: tempURL)
                    DispatchQueue.main.async {
                        store.reload()
                        loadGuideContent()
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {}
            }
        }
        pendingMediaItems = []
    }
    #endif
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        let height = rows.last?.max(by: { $0.maxY < $1.maxY })?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row {
                let x = bounds.minX + item.x
                let y = bounds.minY + item.y
                item.subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            }
        }
    }

    private struct RowItem { let subview: LayoutSubviews.Element; let x: CGFloat; let y: CGFloat; let maxY: CGFloat }

    private func arrangeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[RowItem]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var x: CGFloat = 0
        var y: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
                x = 0
                y += size.height + spacing
            }
            currentRow.append(RowItem(subview: subview, x: x, y: y, maxY: y + size.height))
            x += size.width + spacing
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }
}
