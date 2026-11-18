import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

/// Where the page's file importer puts what it picks.
private enum PageImportPurpose {
    case attachments
    /// A skill's or a tutorial's files to have first.
    case dependencies
    /// A new cover picture, kept with the page's files.
    case cover

    var contentTypes: [UTType] { self == .cover ? [.image] : [.item] }
}

/// Every library page but a note, on one design: Tmax's cover hero holding the page's head (a workout's popup shows
/// the head alone), the widget strip, Skillmax's tabs and the parts of the selected tab, the attachments first and the
/// notes after them. `PageTabModel` says which tabs each kind of page gets and where it opens.
struct ExercisePageDetailView: View {
    @EnvironmentObject var store: DatabaseStore
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.pageCloseAction) private var closeAction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pageID: UUID
    var showsHero = true

    @State private var isEditing = false
    @State private var selectedMediaIndex = 0
    @State private var viewer: MediaViewerPresentation?
    @StateObject private var inlinePlayback = MediaInlinePlayback()
    @State private var trimTarget: MediaTrimTarget?
    @State private var showingImporter = false
    @State private var importPurpose = PageImportPurpose.attachments
    @State private var isImportingCover = false
    @State private var linkMetadata: [LinkMetadata] = []
    @State private var showMediaPicker = false
    @State private var showWorkoutPicker = false
    @State private var showingAddChildPage = false
    @State private var showingLinkedPagePicker = false
    @State private var choosingIcon = false
    @State private var showingWorkouts = false
    @State private var selectedTab: PageTab?
    @State private var mediaToRemove: URL?
    @State private var viewportHeight: CGFloat = 0
    @State private var scrollEdge = PageScrollEdge()
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    @State private var picksCover = false
    @State private var showingAddOptions = false
    #endif

    private static let tabBarID = "page-tab-bar"

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
        if page?.isNote == true {
            NotePageView(pageID: pageID)
        } else {
            pageBody
        }
    }

    private var pageBody: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let page {
                scrollContent(page)
                PageTopChrome(edge: scrollEdge, page: page, breadcrumbs: showsHero ? breadcrumbs : [])
            } else {
                emptyPageView
            }

            if let page, let viewer {
                mediaViewer(page: page, presentation: viewer)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.mediaExpand(from: viewer.source, in: viewer.container))
                    .zIndex(1)
            }
        }
        .pageScrollSpace()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            inlinePlayback.setContainerFrame(frame)
            if viewportHeight != frame.height { viewportHeight = frame.height }
        }
        .timeMasterNavigationTitle(navigationTitle)
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
                    .disabled(viewerHoldsEscape)
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
        .oneHandedActions(id: "exercise-page-\(pageID)", actions: viewer == nil ? pageActions : [])
        .slotNavigationInteractionDisabled(viewer != nil)
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
            if let page {
                PageCreationSheet(parentID: page.manifest.id) { manifest, parentID in
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
        .sheet(isPresented: $showingWorkouts) {
            PageWorkoutsSheet(pageID: pageID)
                .environmentObject(store)
                .environmentObject(workoutStore)
        }
        .sheet(item: $trimTarget) { target in
            MediaTrimSheet(target: target, onOpenFullEditor: fullEditorAction(for: target.url))
        }
        .confirmationDialog(
            "Remove this file?",
            isPresented: Binding(get: { mediaToRemove != nil }, set: { if !$0 { mediaToRemove = nil } }),
            titleVisibility: .visible,
            presenting: mediaToRemove
        ) { url in
            Button("Remove", role: .destructive) {
                if let page { removeMedia(url, from: page) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its notes go with it.")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: importPurpose.contentTypes,
            allowsMultipleSelection: importPurpose != .cover
        ) { result in
            guard case .success(let picked) = result, let page else { return }
            importPicked(picked, purpose: importPurpose, into: page.manifest.id)
        }
        .onDisappear { inlinePlayback.pause() }
        .task(id: page?.manifest.linkURLs ?? []) {
            guard let page, !page.manifest.linkURLs.isEmpty else { return }
            linkMetadata = await LinkMetadataFetcher.fetchMetadata(
                for: page.manifest.linkURLs,
                existing: page.manifest.linkMetadata
            )
        }
        #if os(iOS)
        .confirmationDialog("Add to the attachments", isPresented: $showingAddOptions) {
            Button("Photos & Videos") { pickPhotos(forCover: false) }
            Button("Files") { importFiles(for: .attachments) }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showMediaPicker,
            selection: $pendingMediaItems,
            maxSelectionCount: picksCover ? 1 : 10,
            matching: picksCover ? PHPickerFilter.images : PHPickerFilter.any(of: [.images, .videos])
        )
        .onChange(of: pendingMediaItems) { items in
            guard let page, !items.isEmpty else { return }
            uploadPickedMedia(items: items, pageID: page.manifest.id, asCover: picksCover)
        }
        #endif
        .skillErrorAlert()
    }

    // MARK: Page

    private func scrollContent(_ page: ExercisePage) -> some View {
        let library = store.skillLibrary
        let usage = PageWorkoutUsage.of(page, library: library, workoutStore: workoutStore)
        let linked = linkedPages
        let model = PageTabModel(
            page: page,
            store: store,
            library: library,
            linkedPageCount: linked.count,
            hasWorkout: page.isExercise && (page.hasWorkoutConfig || !usage.isEmpty)
        )
        let tab = model.resolved(selectedTab ?? PageTabMemory.tab(for: page.manifest.id))
        let progress = library.progress(of: page)
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if showsHero {
                        PageCoverHero(
                            page: page,
                            isImportingCover: isImportingCover,
                            onChooseCover: { setCover($0, of: page) },
                            onImportCover: importCover
                        ) {
                            head(page, progress: progress, usage: usage, compact: false)
                        }
                    }
                    pageTop(page, model: model, tab: tab, progress: progress, usage: usage, proxy: proxy)
                    tabContent(tab, page: page, model: model, linked: linked, proxy: proxy)
                }
                .padding(.bottom, 40)
                .pageScrollEdgeProbe(scrollEdge)
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
    }

    private func head(_ page: ExercisePage, progress: SkillProgress, usage: PageWorkoutUsage, compact: Bool) -> some View {
        PageHeroHeader(
            page: page,
            progress: progress,
            usage: usage,
            onCover: !compact,
            compact: compact,
            onChangeIcon: { choosingIcon = true },
            onSetStatus: { setStatus($0, of: page) }
        )
    }

    /// The head of a page shown without its cover, the widgets and the tabs.
    private func pageTop(
        _ page: ExercisePage,
        model: PageTabModel,
        tab: PageTab,
        progress: SkillProgress,
        usage: PageWorkoutUsage,
        proxy: ScrollViewProxy
    ) -> some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s4) {
            if !showsHero {
                head(page, progress: progress, usage: usage, compact: true)
            }
            PageWidgetStrip(pageID: pageID) { target in
                open(target, page: page, model: model, current: tab, proxy: proxy)
            }
            TmaxTabBar(
                model.tabs.map { TmaxTab($0, title: $0.title, count: model.badge(for: $0)) },
                selection: tab
            ) { selected in
                select(selected, page: page, current: tab, proxy: proxy, reveal: false)
            }
            .overlay(alignment: .top) { revealAnchor }
            #if os(macOS)
            .background {
                PageTabStepKeys(tabs: model.tabs, selection: tab, isEnabled: viewer == nil) { selected in
                    select(selected, page: page, current: tab, proxy: proxy, reveal: true)
                }
            }
            #endif
        }
        .skillsContained()
        .padding(.top, showsHero ? SkillMetrics.s4 : SkillMetrics.s5)
        .padding(.bottom, SkillMetrics.s4)
    }

    /// What a reveal scrolls to the top: a point far enough above the tabs that they land below the pinned path and
    /// the fade.
    private var revealAnchor: some View {
        let inset = PageTopChrome.revealInset(showsPath: showsHero && PageTopChrome.showsPath(breadcrumbs))
        return Color.clear
            .frame(width: 1, height: 1)
            .alignmentGuide(.top) { $0[.top] + inset }
            .id(Self.tabBarID)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The selected tab's parts, cross-fading in place when the tab changes. At least as tall as the page, so a short
    /// tab never pulls the tabs away from under the finger.
    private func tabContent(_ tab: PageTab, page: ExercisePage, model: PageTabModel, linked: [ExercisePage], proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .top) {
            Group {
                if tab == .all {
                    VStack(alignment: .leading, spacing: SkillMetrics.s6) {
                        ForEach(Array(model.allParts.enumerated()), id: \.element) { index, part in
                            if index > 0 {
                                PageSectionDivider()
                            }
                            section(part, page: page, model: model, linked: linked, proxy: proxy)
                        }
                    }
                } else {
                    section(tab, page: page, model: model, linked: linked, proxy: proxy)
                }
            }
            .id(tab)
            .transition(.opacity)
        }
        .skillsContained()
        .frame(minHeight: viewportHeight, alignment: .top)
    }

    @ViewBuilder
    private func section(_ part: PageTab, page: ExercisePage, model: PageTabModel, linked: [ExercisePage], proxy: ScrollViewProxy) -> some View {
        switch part {
        case .all:
            EmptyView()
        case .attachments:
            PageAttachmentsSection(
                page: page,
                role: .attachments,
                marksCover: showsHero,
                playback: inlinePlayback,
                linkedPages: linked,
                actions: mediaActions(page)
            )
        case .dependencies:
            PageDependenciesSection(page: page, playback: inlinePlayback, actions: mediaActions(page))
        case .notes:
            SkillNotesSection(materialID: page.manifest.id)
        case .skills:
            VStack(alignment: .leading, spacing: SkillMetrics.s6) {
                SkillBoardScreen(boardID: page.manifest.id, scrollTo: scrollAction(proxy))
                SkillSubPagesSection(skill: page)
            }
        case .children:
            VStack(alignment: .leading, spacing: SkillMetrics.s3) {
                PageSectionHeader(symbol: PageTab.children.symbol, title: PageTab.children.title, count: model.badge(for: .children))
                if page.isSkillLike {
                    // A skill or a tutorial that needs no skills lists what sits inside it, with no board.
                    ExerciseChildList(pages: store.children(of: page.id))
                        .environmentObject(store)
                        .environmentObject(workoutStore)
                } else {
                    ContainerChildrenTabs(container: page)
                        .environmentObject(store)
                        .environmentObject(workoutStore)
                }
            }
        case .todos:
            SkillTodoSection(pageID: page.manifest.id)
        case .milestones:
            SkillMilestonesSection(pageID: page.manifest.id)
        case .workout:
            PageWorkoutSection(page: page) { showWorkoutPicker = true }
        case .links:
            PageLinksSection(urls: page.manifest.linkURLs, metadata: linkMetadata, onOpen: openLink)
        }
    }

    // MARK: Tabs

    /// Selects a tab (remembered for the page); `reveal` brings the tabs to the top so the new tab reads from its start.
    private func select(_ tab: PageTab, page: ExercisePage, current: PageTab, proxy: ScrollViewProxy, reveal: Bool) {
        PageTabMemory.remember(tab, for: page.manifest.id)
        if tab == current {
            selectedTab = tab
        } else {
            withAnimation(reduceMotion ? nil : EverMotion.state) {
                selectedTab = tab
            }
            EverHaptic.selection()
        }
        guard reveal else { return }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                proxy.scrollTo(Self.tabBarID, anchor: .top)
            }
        }
    }

    /// A tap on a widget: its tab, scrolled into view. The Clips widget also opens its clip in the viewer, grown out of
    /// its card; the Workouts widget of a page without a Workout tab lists them in a sheet.
    private func open(_ target: PageWidgetTarget, page: ExercisePage, model: PageTabModel, current: PageTab, proxy: ScrollViewProxy) {
        let tab: PageTab
        switch target {
        case .attachments(let index):
            let url = index.flatMap { page.mediaURLs.indices.contains($0) ? page.mediaURLs[$0] : nil }
            let isNeededFirst = url.map { page.manifest.dependencyMediaFilenames.contains($0.lastPathComponent) } ?? false
            tab = page.isSkillLike && !page.manifest.hidesSkills && isNeededFirst ? .dependencies : .attachments
            if let url { openViewerSoon(for: url) }
        case .subSkills:
            tab = .skills
        case .children:
            tab = model.tabs.contains(.children) ? .children : .skills
        case .todos:
            tab = .todos
        case .milestones:
            tab = .milestones
        case .dependencies:
            tab = .dependencies
        case .workouts:
            guard model.tabs.contains(.workout) else {
                showingWorkouts = true
                return
            }
            tab = .workout
        }
        select(model.tabs.contains(tab) ? tab : .all, page: page, current: current, proxy: proxy, reveal: true)
    }

    private func scrollAction(_ proxy: ScrollViewProxy) -> (String) -> Void {
        { id in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    // MARK: Head

    private func setStatus(_ status: SkillStatus, of page: ExercisePage) {
        guard (page.manifest.skillStatus ?? .notStarted) != status else { return }
        let id = page.manifest.id
        let changed = SkillErrorCenter.shared.attempt("Change the status") {
            if let parentID = page.manifest.parentID, store.page(manifestID: parentID) != nil {
                try store.setSkillStatus(status, for: id)
            } else {
                try store.skillWrite { database in
                    var manifest = try database.getPage(id: id)
                    manifest.skillStatus = status
                    try database.updatePage(id: id, manifest: manifest, newParentID: manifest.parentID)
                }
            }
        }
        guard changed else { return }
        if status == .completed { EverHaptic.success() } else { EverHaptic.selection() }
    }

    /// Makes one of the page's files its cover; nil goes back to its first file.
    private func setCover(_ filename: String?, of page: ExercisePage) {
        guard page.manifest.coverMediaFilename != filename else { return }
        if SkillErrorCenter.shared.attempt("Set the cover", { try store.setSkillCover(page.manifest.id, filename: filename) }) {
            EverHaptic.selection()
        }
    }

    private func importCover() {
        #if os(iOS)
        pickPhotos(forCover: true)
        #else
        importPurpose = .cover
        showingImporter = true
        #endif
    }

    // MARK: Media

    private func mediaActions(_ page: ExercisePage) -> PageMediaActions {
        PageMediaActions(
            open: { openViewer(for: $0, of: page, opensEditor: false) },
            openNotes: { openViewer(for: $0, of: page, opensEditor: true) },
            cardActions: { cardActions(for: $0, of: page) },
            add: { add($0) },
            addFiles: { importFiles(for: $0) },
            addPhotos: photosAction,
            attachPage: { showingLinkedPagePicker = true }
        )
    }

    private var photosAction: (() -> Void)? {
        #if os(iOS)
        return { pickPhotos(forCover: false) }
        #else
        return nil
        #endif
    }

    /// The plus of a part's heading: photos or files on iPhone and iPad, files on the Mac.
    private func add(_ role: PageAttachmentRole) {
        #if os(iOS)
        if role == .attachments {
            showingAddOptions = true
            return
        }
        #endif
        importFiles(for: role)
    }

    private func importFiles(for role: PageAttachmentRole) {
        importPurpose = role == .dependencies ? .dependencies : .attachments
        showingImporter = true
    }

    private func importPicked(_ urls: [URL], purpose: PageImportPurpose, into id: String) {
        var added: [String] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            SkillErrorCenter.shared.attempt("Add the file") {
                let filename = try store.uploadSkillMedia(url, to: id, asDependency: purpose == .dependencies)
                added.append(filename)
            }
        }
        guard let first = added.first else { return }
        if purpose == .cover {
            guard SkillErrorCenter.shared.attempt("Set the cover", { try store.setSkillCover(id, filename: first) }) else { return }
        }
        EverHaptic.success()
    }

    /// The menu of a media card: open it, trim and edit a video, make it the cover, make a picture the icon, on a skill or
    /// a tutorial move it between Attachments and Dependencies (unless it needs no skills), and remove it.
    private func cardActions(for url: URL, of page: ExercisePage) -> [MediaCardAction] {
        guard let index = page.mediaURLs.firstIndex(of: url) else { return [] }
        let filename = url.lastPathComponent
        let pageID = page.manifest.id
        let isVideo = PageMediaKind.isVideo(url)
        let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
        var actions = [
            MediaCardAction("Open in viewer", systemImage: "arrow.up.left.and.arrow.down.right") {
                openViewer(at: index, of: page, opensEditor: false)
            }
        ]
        if isVideo {
            actions.append(MediaCardAction("Trim video…", systemImage: "scissors") {
                inlinePlayback.pause()
                trimTarget = MediaTrimTarget(url: url, pageID: pageID)
            })
            #if os(macOS)
            actions.append(MediaCardAction("Open full editor…", systemImage: "film") {
                openFullEditor(url)
            })
            #endif
        }
        if isVideo || isImage {
            let isCover = page.manifest.coverMediaFilename == filename
            actions.append(MediaCardAction(isCover ? "Remove the cover" : "Use as cover", systemImage: "photo") {
                setCover(isCover ? nil : filename, of: page)
            })
        }
        if page.isSkillLike, !page.manifest.hidesSkills {
            let isNeededFirst = page.manifest.dependencyMediaFilenames.contains(filename)
            actions.append(MediaCardAction(
                isNeededFirst ? "Move to Attachments" : "Move to Dependencies",
                systemImage: isNeededFirst ? "paperclip" : "arrow.triangle.branch"
            ) {
                if SkillErrorCenter.shared.attempt("Change the prerequisite flag", {
                    try store.setSkillMediaIsDependency(filename, in: pageID, !isNeededFirst)
                }) {
                    EverHaptic.selection()
                }
            })
        }
        if isImage {
            actions.append(MediaCardAction("Use as icon", systemImage: "person.crop.square") {
                SkillErrorCenter.shared.attempt("Set the icon") {
                    try store.setSkillIcon(pageID, name: nil, type: nil, image: filename)
                }
            })
        }
        actions.append(MediaCardAction("Remove", systemImage: "trash", role: .destructive) {
            mediaToRemove = url
        })
        return actions
    }

    private func removeMedia(_ url: URL, from page: ExercisePage) {
        if inlinePlayback.url == url { inlinePlayback.stop() }
        if SkillErrorCenter.shared.attempt("Remove the file", { try store.removeSkillMedia(url.lastPathComponent, from: page.manifest.id) }) {
            EverHaptic.selection()
        }
    }

    private func mediaViewer(page: ExercisePage, presentation: MediaViewerPresentation) -> some View {
        PageMediaGallery(
            urls: page.mediaURLs,
            selectedIndex: $selectedMediaIndex,
            isPresented: Binding(get: { viewer != nil }, set: { if !$0 { closeViewer() } }),
            comments: page.mediaCommentsByURL,
            onSaveComment: { url, comment in
                try store.updateMediaComment(pageID: page.manifest.id, filename: url.lastPathComponent, comment: comment)
            },
            opensEditor: presentation.opensEditor,
            notesAssets: { _ in FolderMarkdownAssets(folder: store.folderURL(for: page)) },
            presentation: .inPlace,
            playback: inlinePlayback,
            mediaOwnerID: { _ in page.manifest.id }
        )
        .keyNavHost()
    }

    private var viewerAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.9)
    }

    private func openViewer(for url: URL, of page: ExercisePage, opensEditor: Bool) {
        guard let index = page.mediaURLs.firstIndex(of: url) else { return }
        openViewer(at: index, of: page, opensEditor: opensEditor)
    }

    /// Opens the media viewer in place: it grows out of the card at `index` (the card's video keeps playing in it).
    private func openViewer(at index: Int, of page: ExercisePage, opensEditor: Bool) {
        guard page.mediaURLs.indices.contains(index) else { return }
        let url = page.mediaURLs[index]
        if inlinePlayback.url != url { inlinePlayback.pause() }
        selectedMediaIndex = index
        let presentation = MediaViewerPresentation(
            opensEditor: opensEditor,
            source: inlinePlayback.cardRect(for: url),
            container: inlinePlayback.containerSize
        )
        withAnimation(viewerAnimation) { viewer = presentation }
    }

    /// Opens the viewer once a tab change has settled and the card it grows out of is on screen.
    private func openViewerSoon(for url: URL) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard viewer == nil, let page else { return }
            openViewer(for: url, of: page, opensEditor: false)
        }
    }

    /// Shrinks the viewer back into the card of the media it shows (the card it came from when that one is gone).
    private func closeViewer() {
        guard viewer != nil else { return }
        if let page, page.mediaURLs.indices.contains(selectedMediaIndex),
           let card = inlinePlayback.cardRect(for: page.mediaURLs[selectedMediaIndex]) {
            viewer?.source = card
        }
        let animation = viewerAnimation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            withAnimation(animation) { viewer = nil }
            try? await Task.sleep(nanoseconds: 550_000_000)
            inlinePlayback.redrawSurface()
        }
    }

    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    private var navigationTitle: String {
        #if os(macOS)
        return showsHero ? "" : (page?.title ?? "Workout")
        #else
        return ""
        #endif
    }

    /// On the Mac the in-place viewer answers Escape, so the page's close or back button rests while it is open.
    private var viewerHoldsEscape: Bool {
        #if os(macOS)
        return viewer != nil
        #else
        return false
        #endif
    }

    private func fullEditorAction(for url: URL) -> (() -> Void)? {
        #if os(macOS)
        return { openFullEditor(url) }
        #else
        return nil
        #endif
    }

    #if os(macOS)
    private func openFullEditor(_ url: URL) {
        inlinePlayback.pause()
        MacVideoWorkspaceWindowPresenter.shared.present(
            sources: [MacVideoSource(url: url)],
            databaseStore: store,
            workoutStore: workoutStore
        )
    }
    #endif

    // MARK: Toolbar

    private var pageActions: [ReachabilityAction] {
        var actions = [
            ReachabilityAction("back", title: closeAction == nil ? "Back" : "Close") {
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
            pickPhotos(forCover: false)
        } label: {
            Image(systemName: "photo.badge.plus")
        }
        .accessibilityLabel("Add Media")
    }

    private func pickPhotos(forCover: Bool) {
        picksCover = forCover
        showMediaPicker = true
    }

    /// Copies the picked photos and videos into the page; with `asCover` the first becomes its cover.
    private func uploadPickedMedia(items: [PhotosPickerItem], pageID: String, asCover: Bool) {
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        if asCover { isImportingCover = true }
        Task { @MainActor in
            var added: [String] = []
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
                if let filename = try? ExerciseLibraryAccess.shared.perform(token: libraryToken, operation: {
                    try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: sourceURL)
                }) {
                    added.append(filename)
                }
            }
            store.reload()
            pendingMediaItems = []
            if asCover, let first = added.first {
                if SkillErrorCenter.shared.attempt("Set the cover", { try store.setSkillCover(pageID, filename: first) }) {
                    EverHaptic.success()
                }
            } else if !added.isEmpty {
                EverHaptic.success()
            }
            isImportingCover = false
        }
    }
    #endif

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
                                    Text(PageKindStyle.title(candidate))
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
