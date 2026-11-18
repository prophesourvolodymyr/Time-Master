import SwiftUI
import AVKit
import TimeMasterCore
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// How a media viewer is shown: over everything (a full-screen cover or a sheet), or grown in place over the page
/// that opened it (see `AnyTransition.mediaExpand`).
enum PageMediaGalleryPresentation {
    case modal
    case inPlace
}

struct PageMediaGallery: View {
    let urls: [URL]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    let comments: [URL: String]
    let onSaveComment: ((URL, String) throws -> Void)?
    let notesAssets: ((URL) -> MarkdownAssets?)?
    let workout: Workout?
    let liveContext: WorkoutLiveContext?
    let databasePageID: ((URL) -> UUID?)?
    let presentation: PageMediaGalleryPresentation
    let playback: MediaInlinePlayback?
    let mediaOwnerID: ((URL) -> String?)?
    let onOpenPage: (() -> Void)?

    @State private var drawer: CGFloat
    @State private var notesRevealed: Bool
    @State private var dragMotion = GalleryDragMotion()
    @State private var scrollID: Int?
    @State private var isZoomed = false
    @State private var mediaHidden = false
    @State private var drafts: [URL: String] = [:]
    @State private var lastSaved: [URL: String] = [:]
    @State private var saveTasks: [URL: Task<Void, Never>] = [:]
    @State private var saveError: String?
    @State private var showDatabase = false
    @State private var showMusic = false
    @State private var trimTarget: MediaTrimTarget?
    #if os(iOS)
    @State private var keyboardVisible = false
    #endif
    @ObservedObject private var library = MusicLibraryStore.shared
    @ObservedObject private var revisions = MediaRevisions.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    #endif

    /// - Parameters:
    ///   - playback: the page's inline playback; the viewer continues its video instead of loading it again.
    ///   - mediaOwnerID: the page that holds a file, so a trim can be saved as a new clip on it.
    ///   - onOpenPage: "Open Page" in the top bar, where the viewer shows a page's clips outside the page (its cover in
    ///     a Database list).
    init(
        urls: [URL],
        selectedIndex: Binding<Int>,
        isPresented: Binding<Bool>,
        comments: [URL: String],
        onSaveComment: ((URL, String) throws -> Void)?,
        opensEditor: Bool = false,
        notesAssets: ((URL) -> MarkdownAssets?)? = nil,
        workout: Workout? = nil,
        liveContext: WorkoutLiveContext? = nil,
        databasePageID: ((URL) -> UUID?)? = nil,
        presentation: PageMediaGalleryPresentation = .modal,
        playback: MediaInlinePlayback? = nil,
        mediaOwnerID: ((URL) -> String?)? = nil,
        onOpenPage: (() -> Void)? = nil
    ) {
        self.urls = urls
        _selectedIndex = selectedIndex
        _isPresented = isPresented
        self.comments = comments
        self.onSaveComment = onSaveComment
        self.notesAssets = notesAssets
        self.workout = workout
        self.liveContext = liveContext
        self.databasePageID = databasePageID
        self.presentation = presentation
        self.playback = playback
        self.mediaOwnerID = mediaOwnerID
        self.onOpenPage = onOpenPage
        let opens = opensEditor && onSaveComment != nil
        _drawer = State(initialValue: opens ? 1 : 0)
        _notesRevealed = State(initialValue: opens)
        _scrollID = State(initialValue: selectedIndex.wrappedValue)
    }

    private var selectedURL: URL? {
        urls.indices.contains(selectedIndex) ? urls[selectedIndex] : nil
    }

    private var currentNote: String {
        guard let url = selectedURL else { return "" }
        return drafts[url] ?? comments[url] ?? ""
    }

    private var hasNotesSurface: Bool {
        selectedURL != nil && (onSaveComment != nil || !currentNote.isEmpty)
    }

    private var isDrawerOpen: Bool { hasNotesSurface && drawer > 0.5 }

    private var motion: Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)
    }

    private var compactScale: CGFloat {
        #if os(iOS)
        return keyboardVisible ? 0.62 : 1
        #else
        return 1
        #endif
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GalleryDismissOffset(motion: dragMotion) {
                GeometryReader { proxy in
                    content(size: proxy.size)
                }
            }
            #if os(macOS)
            arrowKeys
            #endif
        }
        .preferredColorScheme(.dark)
        .modifier(WorkoutFloatingControlsOverlay(
            workoutName: workout?.name ?? "",
            context: floatingContext,
            library: library
        ))
        .sheet(isPresented: $showDatabase) {
            if let workout, let pageID = currentDatabasePageID {
                WorkoutAttachmentBrowser(workout: workout, pageID: pageID, liveContext: liveContext) {
                    showDatabase = false
                }
            }
        }
        .sheet(isPresented: $showMusic) {
            if let workout, let liveContext {
                WorkoutMusicPlaybackSheet(workout: workout, isContinuationPrompt: false, library: library, session: liveContext.music)
            }
        }
        .sheet(item: $trimTarget) { target in
            MediaTrimSheet(target: target, onOpenFullEditor: fullEditorAction(for: target.url))
        }
        .alert("Notes", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .onChange(of: selectedIndex) { _ in
            flushDrafts()
            isZoomed = false
        }
        .onDisappear { flushDrafts() }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(motion) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(motion) { keyboardVisible = false }
        }
        #endif
        #if os(macOS)
        .frame(
            minWidth: presentation == .modal ? 720 : nil,
            idealWidth: presentation == .modal ? 980 : nil,
            minHeight: presentation == .modal ? 560 : nil,
            idealHeight: presentation == .modal ? 760 : nil
        )
        #endif
    }

    private var floatingContext: WorkoutLiveContext? {
        liveContext.map { context in
            WorkoutLiveContext(
                progress: context.progress,
                music: context.music,
                onPause: context.onPause,
                onStop: context.onStop,
                onOpenMusic: { showMusic = true }
            )
        }
    }

    private var currentDatabasePageID: UUID? {
        guard let url = selectedURL else { return nil }
        return databasePageID?(url)
    }

    private func content(size: CGSize) -> some View {
        let topBarHeight: CGFloat = 52
        let available = max(200, size.height - topBarHeight)
        let handle: CGFloat = hasNotesSurface ? 64 : 0
        let collapsedPager = max(120, available - handle)
        let compactPager = mediaHidden ? 0 : min(max(available * 0.32, 170), 300) * (compactScale)
        let expandedPager = hasNotesSurface ? min(compactPager, collapsedPager) : collapsedPager
        let openFraction: CGFloat = hasNotesSurface ? drawer : 0
        let pagerHeight = collapsedPager + (expandedPager - collapsedPager) * openFraction
        let travel = max(1, collapsedPager - expandedPager)

        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                topBar
                    .frame(height: topBarHeight)
                pager
                    .frame(height: pagerHeight)
                    .clipped()
                    #if os(macOS)
                    .overlay { macChevrons }
                    #else
                    .simultaneousGesture(mediaDrag(travel: travel), including: isZoomed ? .subviews : .all)
                    #endif
                Spacer(minLength: 0)
            }
            if hasNotesSurface, let url = selectedURL {
                GalleryDrawerOffset(motion: dragMotion, base: topBarHeight + pagerHeight) {
                    drawerView(url: url, travel: travel)
                        .frame(height: max(handle, size.height - topBarHeight - expandedPager), alignment: .top)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 10) {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: presentation == .inPlace ? "arrow.down.right.and.arrow.up.left" : "xmark")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 44))
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif
                .help(presentation == .inPlace ? (onOpenPage == nil ? "Shrink back into the page" : "Shrink back into the list") : "Close")
                .accessibilityLabel("Close media viewer")
                Spacer()
                if let onOpenPage {
                    openPageButton(onOpenPage)
                }
                if workout != nil, currentDatabasePageID != nil {
                    Button {
                        showDatabase = true
                    } label: {
                        Label("Database", systemImage: "books.vertical")
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 12))
                    .accessibilityHint("Opens the exercise page without leaving the viewer")
                }
                if let url = selectedURL, url.isFileURL, PageMediaKind.isVideo(url) {
                    trimButton(url)
                }
            }
            if urls.count > 1 {
                Text("\(selectedIndex + 1) / \(urls.count)")
                    .font(TimeMasterFont.black(14, relativeTo: .subheadline).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
                    .accessibilityLabel("Item \(selectedIndex + 1) of \(urls.count)")
            }
        }
        .padding(.horizontal, 12)
    }

    /// "Open Page": the page these clips belong to. A text button on the Mac; on iPhone and iPad an icon, so the
    /// position counter in the middle of the bar keeps its room.
    private func openPageButton(_ open: @escaping () -> Void) -> some View {
        Button(action: open) {
            #if os(macOS)
            Label("Open Page", systemImage: "arrow.up.right")
                .font(TimeMasterFont.black(14, relativeTo: .subheadline))
            #else
            Image(systemName: "arrow.up.right")
                .font(.system(size: 16, weight: .bold))
            #endif
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: Self.opensPageWithIcon, minimumSize: 44, horizontalPadding: 12))
        .help("Open the page")
        .accessibilityLabel("Open Page")
        .accessibilityHint("Closes the viewer and opens the page these clips belong to")
    }

    private static var opensPageWithIcon: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }

    private func trimButton(_ url: URL) -> some View {
        Button {
            trimTarget = MediaTrimTarget(url: url, pageID: mediaOwnerID?(url))
        } label: {
            Image(systemName: "scissors")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 44))
        .help("Trim video")
        .accessibilityLabel("Trim video")
        #if os(macOS)
        .contextMenu {
            Button {
                openFullEditor(url)
            } label: {
                Label("Open full editor…", systemImage: "film")
            }
        }
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
        MacVideoWorkspaceWindowPresenter.shared.present(
            sources: [MacVideoSource(url: url)],
            databaseStore: databaseStore,
            workoutStore: workoutStore
        )
    }
    #endif

    @ViewBuilder
    private var pager: some View {
        if urls.isEmpty {
            Text("No media")
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            #if os(iOS)
            if #available(iOS 17.0, *) {
                modernPager
            } else {
                legacyPager
            }
            #else
            modernPager
            #endif
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private var modernPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    page(url, index: index)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollID)
        .scrollDisabled(isZoomed)
        .onChange(of: scrollID) { _, newValue in
            if let newValue, newValue != selectedIndex { selectedIndex = newValue }
        }
        .onChange(of: selectedIndex) { _, newValue in
            if scrollID != newValue {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { scrollID = newValue }
            }
        }
    }

    #if os(iOS)
    private var legacyPager: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                page(url, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    #endif

    @ViewBuilder
    private func page(_ url: URL, index: Int) -> some View {
        Group {
            if PageMediaKind.isVideo(url) {
                PageGalleryInlineVideo(
                    url: url,
                    isActive: index == selectedIndex && trimTarget == nil,
                    sharedPlayer: playback?.player(for: url)
                )
                .id(revisions.revision(of: url))
            } else if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
                GalleryImagePage(url: url, isActive: index == selectedIndex, isZoomed: $isZoomed)
            } else {
                QuickLookPreview(url: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(url.lastPathComponent), \(index + 1) of \(urls.count)")
    }

    // MARK: Notes drawer

    private func drawerView(url: URL, travel: CGFloat) -> some View {
        VStack(spacing: 0) {
            drawerHeader(url: url, travel: travel)
            if drawer > 0 || notesRevealed {
                drawerBody(url: url)
                    .allowsHitTesting(isDrawerOpen)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background, in: TopRoundedShape(radius: 22))
        .overlay(alignment: .top) {
            TopRoundedShape(radius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(TopRoundedShape(radius: 22))
    }

    private func drawerHeader(url: URL, travel: CGFloat) -> some View {
        let note = currentNote
        let expanded = isDrawerOpen
        return VStack(spacing: 0) {
            grabber(travel: travel)
            HStack(spacing: 10) {
                Button {
                    setDrawer(expanded ? 0 : 1)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.toolbarOrange)
                        if expanded {
                            Text("Notes")
                                .font(TimeMasterFont.black(16, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            Text(kindLabel(for: url))
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                        } else if note.isEmpty {
                            Text(Self.emptyNotesPrompt)
                                .font(TimeMasterFont.rowTitle())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        } else {
                            DrawerNotePreview(note: note)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                }
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
                .help(expanded ? "Collapse the notes" : "Open the notes")
                .accessibilityLabel(expanded ? "Notes, \(kindLabel(for: url))" : (note.isEmpty ? "Write notes" : "Notes"))
                .accessibilityHint(expanded ? "Collapses the notes" : "Opens the notes")
                if expanded {
                    Button {
                        withAnimation(motion) { mediaHidden.toggle() }
                    } label: {
                        Image(systemName: mediaHidden ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 34))
                    .accessibilityLabel(mediaHidden ? "Show media" : "Hide media")
                }
                Button {
                    setDrawer(expanded ? 0 : 1)
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 34))
                .accessibilityLabel(expanded ? "Collapse notes" : "Open notes")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            #if os(iOS)
            .simultaneousGesture(headerDrag(travel: travel))
            #endif
        }
        #if os(macOS)
        .background {
            MacDrawerSwipeCatcher { up in swipeDrawer(up: up) }
        }
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: expanded ? "Collapse notes" : "Open notes") { setDrawer(expanded ? 0 : 1) }
    }

    /// The grabber strip: a click opens or closes the notes, a drag moves them with the pointer and settles.
    private func grabber(travel: CGFloat) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(grabberDrag(travel: travel))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func drawerBody(url: URL) -> some View {
        if onSaveComment != nil {
            MarkdownEditorView(text: noteBinding(for: url), assets: notesAssets?(url))
                .id(url)
        } else {
            ScrollView {
                MarkdownDocumentView(markdown: currentNote, assets: notesAssets?(url))
                    .padding(16)
            }
        }
    }

    private static var emptyNotesPrompt: String {
        #if os(macOS)
        return "Click to write notes"
        #else
        return "Swipe up to write notes"
        #endif
    }

    private func kindLabel(for url: URL) -> String {
        let index = (urls.firstIndex(of: url) ?? 0) + 1
        return "\(PageMediaKind.isVideo(url) ? "Video" : "Photo") \(index)"
    }

    private func noteBinding(for url: URL) -> Binding<String> {
        Binding(
            get: { drafts[url] ?? comments[url] ?? "" },
            set: { newValue in
                drafts[url] = newValue
                scheduleSave(url)
            }
        )
    }

    private func scheduleSave(_ url: URL) {
        saveTasks[url]?.cancel()
        saveTasks[url] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            persist(url)
        }
    }

    private func persist(_ url: URL) {
        saveTasks[url]?.cancel()
        saveTasks[url] = nil
        guard let onSaveComment, let text = drafts[url] else { return }
        let baseline = lastSaved[url] ?? comments[url] ?? ""
        guard text != baseline else { return }
        do {
            try onSaveComment(url, text)
            lastSaved[url] = text
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func flushDrafts() {
        for url in Array(drafts.keys) { persist(url) }
    }

    private func setDrawer(_ value: CGFloat) {
        if value > 0, !notesRevealed { notesRevealed = true }
        withAnimation(motion) {
            drawer = value
            dragMotion.drawer = 0
            dragMotion.dismiss = 0
        }
        if value == 0 { flushDrafts() }
        #if os(iOS)
        if value == 0 {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        #endif
    }

    private func revealNotes() {
        if !notesRevealed { notesRevealed = true }
    }

    /// How far a drag moves the drawer: up to fully open or closed, with a little give past either end.
    private func drawerOffset(for dy: CGFloat, travel: CGFloat) -> CGFloat {
        if isDrawerOpen {
            return dy < 0 ? -Self.rubberBand(-dy) : min(travel, dy)
        }
        return dy > 0 ? Self.rubberBand(dy) : max(-travel, dy)
    }

    private static func rubberBand(_ distance: CGFloat) -> CGFloat {
        20 * (1 - exp(-distance / 80))
    }

    private func settleDrawer(predicted dy: CGFloat, travel: CGFloat) {
        if isDrawerOpen {
            setDrawer(dy > travel * 0.5 ? 0 : 1)
        } else {
            setDrawer(-dy > travel * 0.5 ? 1 : 0)
        }
    }

    private func grabberDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation.height < 0 { revealNotes() }
                dragMotion.drawer = drawerOffset(for: value.translation.height, travel: travel)
            }
            .onEnded { value in
                let moved = abs(value.translation.height) > 4 || abs(value.translation.width) > 4
                if moved {
                    settleDrawer(predicted: value.predictedEndTranslation.height, travel: travel)
                } else {
                    setDrawer(isDrawerOpen ? 0 : 1)
                }
            }
    }

    #if os(iOS)
    private func headerDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if value.translation.height < 0 { revealNotes() }
                dragMotion.drawer = drawerOffset(for: value.translation.height, travel: travel)
            }
            .onEnded { value in
                settleDrawer(predicted: value.predictedEndTranslation.height, travel: travel)
            }
    }

    /// Swipes on the media: up opens the notes, down (with the notes closed) closes the viewer.
    private func mediaDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                let live = dragMotion
                if live.axis == nil {
                    live.axis = abs(value.translation.height) > abs(value.translation.width) ? .vertical : .horizontal
                }
                guard live.axis == .vertical else { return }
                let dy = value.translation.height
                if hasNotesSurface {
                    if dy < 0 { revealNotes() }
                    live.drawer = isDrawerOpen || dy < 0 ? drawerOffset(for: dy, travel: travel) : 0
                }
                live.dismiss = !isDrawerOpen && dy > 0 ? dy : 0
            }
            .onEnded { value in
                let axis = dragMotion.axis
                dragMotion.axis = nil
                guard axis == .vertical else {
                    resetDrag()
                    return
                }
                let dy = value.translation.height
                if !isDrawerOpen, dy > 110 {
                    isPresented = false
                    return
                }
                guard hasNotesSurface else {
                    resetDrag()
                    return
                }
                settleDrawer(predicted: value.predictedEndTranslation.height, travel: travel)
            }
    }

    private func resetDrag() {
        withAnimation(motion) {
            dragMotion.drawer = 0
            dragMotion.dismiss = 0
        }
    }
    #endif

    #if os(macOS)
    private func swipeDrawer(up: Bool) {
        if up, !isDrawerOpen {
            setDrawer(1)
        } else if !up, isDrawerOpen {
            setDrawer(0)
        }
    }

    private var macChevrons: some View {
        HStack {
            chevron("chevron.left", label: "Previous media", enabled: selectedIndex > 0) { step(-1) }
            Spacer()
            chevron("chevron.right", label: "Next media", enabled: selectedIndex < urls.count - 1) { step(1) }
        }
        .padding(.horizontal, 14)
        .opacity(urls.count > 1 ? 1 : 0)
        .allowsHitTesting(urls.count > 1)
    }

    private func chevron(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
        }
        .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 38))
        .opacity(enabled ? 1 : 0.25)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var arrowKeys: some View {
        ZStack {
            Group {
                Button("Previous media") { step(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next media") { step(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Open notes") { setDrawer(1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            }
            .disabled(isDrawerOpen)
            Button("Collapse notes") { setDrawer(0) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!isDrawerOpen)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        let target = max(0, min(urls.count - 1, selectedIndex + delta))
        if target != selectedIndex { selectedIndex = target }
    }
    #endif
}

/// The live drag of the notes drawer and of the viewer itself (swipe down to close on iPhone). Only the views that
/// draw these offsets observe it, so a drag moves layers instead of laying the viewer out again on every frame.
private final class GalleryDragMotion: ObservableObject {
    @Published var drawer: CGFloat = 0
    @Published var dismiss: CGFloat = 0
    var axis: Axis?
}

private struct GalleryDrawerOffset<Content: View>: View {
    @ObservedObject var motion: GalleryDragMotion
    let base: CGFloat
    let content: Content

    init(motion: GalleryDragMotion, base: CGFloat, @ViewBuilder content: () -> Content) {
        _motion = ObservedObject(wrappedValue: motion)
        self.base = base
        self.content = content()
    }

    var body: some View {
        content.offset(y: base + motion.drawer)
    }
}

private struct GalleryDismissOffset<Content: View>: View {
    @ObservedObject var motion: GalleryDragMotion
    let content: Content

    init(motion: GalleryDragMotion, @ViewBuilder content: () -> Content) {
        _motion = ObservedObject(wrappedValue: motion)
        self.content = content()
    }

    var body: some View {
        content
            .offset(y: motion.dismiss * 0.6)
            .opacity(1 - min(0.5, motion.dismiss / 500))
    }
}

/// The first line of a note in the closed drawer, its Markdown drawn: links show their title, emphasis its style.
private struct DrawerNotePreview: View {
    let note: String

    var body: some View {
        Text(Self.render(note))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    static func render(_ note: String) -> AttributedString {
        let block = MarkdownDocument(markdown: note).blocks.first { block in
            switch block.kind {
            case .divider, .image, .code: return false
            default: return !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        guard let block else {
            return styled(AttributedString(NotePreview.text(from: note, maxLines: 1)))
        }
        let line = block.text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? block.text
        if case .linkCard = block.kind {
            var title = styled(AttributedString(line))
            title.foregroundColor = Theme.toolbarOrange
            return title
        }
        let parsed = (try? AttributedString(
            markdown: line,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(line)
        var rendered = styled(parsed)
        let linked = rendered.runs.filter { $0.link != nil }.map(\.range)
        for range in linked {
            rendered[range].link = nil
            rendered[range].foregroundColor = Theme.toolbarOrange
        }
        return rendered
    }

    private static func styled(_ text: AttributedString) -> AttributedString {
        TimeMasterFont.styledText(text, size: 15, relativeTo: .subheadline)
    }
}

private struct TopRoundedShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// A video page of the viewer. With `sharedPlayer` (the page's inline playback of this video) it continues that
/// player and leaves it running when the viewer closes, so the card goes on where the viewer stopped.
private struct PageGalleryInlineVideo: View {
    let url: URL
    let isActive: Bool
    var sharedPlayer: AVPlayer?
    @State private var ownPlayer: AVPlayer?

    private var player: AVPlayer? { sharedPlayer ?? ownPlayer }

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                TmaxLoadingIndicator()
            }
        }
        .onAppear {
            if sharedPlayer == nil, ownPlayer == nil { ownPlayer = AVPlayer(url: url) }
            sync()
        }
        .onChange(of: isActive) { _ in sync() }
        .onDisappear {
            if sharedPlayer == nil { ownPlayer?.pause() }
        }
    }

    private func sync() {
        if isActive { player?.play() } else { player?.pause() }
    }
}

private struct GalleryImagePage: View {
    let url: URL
    let isActive: Bool
    @Binding var isZoomed: Bool
    @State private var image: PhotoPlatformImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnify)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
            } else if failed {
                Color.gray.opacity(0.3)
                    .overlay(Text("Could not load image").foregroundStyle(.white.opacity(0.6)))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            image = nil
            failed = false
            let loaded = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: PhotoManager.viewerPixelSize)
            guard !Task.isCancelled else { return }
            image = loaded
            failed = loaded == nil
        }
        .onChange(of: isActive) { active in
            if !active { reset() }
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(6, max(1, lastScale * value))
                isZoomed = scale > 1.02
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.02 { reset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.02 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            if scale > 1.02 {
                reset()
            } else {
                scale = 2.5
                lastScale = 2.5
                isZoomed = true
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
        isZoomed = false
    }
}

#if os(macOS)
/// Reads two-finger swipes over the notes header without taking any click: a whole trackpad swipe (or one turn of a
/// mouse wheel) reports its direction once, decided by where it started, so the drawer moves once per gesture.
private struct MacDrawerSwipeCatcher: NSViewRepresentable {
    let onSwipe: (Bool) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onSwipe = onSwipe
    }

    static func dismantleNSView(_ nsView: CatcherView, coordinator: ()) {
        nsView.stopMonitoring()
    }

    final class CatcherView: NSView {
        var onSwipe: ((Bool) -> Void)?
        private var monitor: Any?
        private var tracking = false
        private var fired = false
        private var travelX: CGFloat = 0
        private var travelY: CGFloat = 0
        private var lastWheel: TimeInterval = 0

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func handle(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let inside = bounds.contains(convert(event.locationInWindow, from: nil))
            let up = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            if event.phase.isEmpty && event.momentumPhase.isEmpty {
                guard inside, abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX), up != 0,
                      event.timestamp - lastWheel > 0.4 else { return }
                lastWheel = event.timestamp
                onSwipe?(up > 0)
                return
            }
            if event.phase.contains(.mayBegin) || (event.phase.contains(.began) && !tracking) {
                tracking = inside
                fired = false
                travelX = 0
                travelY = 0
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                tracking = false
                return
            }
            guard tracking, !fired, event.momentumPhase.isEmpty else { return }
            travelX += abs(event.scrollingDeltaX)
            travelY += up
            guard abs(travelY) > 24, abs(travelY) > travelX * 1.2 else { return }
            fired = true
            onSwipe?(travelY > 0)
        }
    }
}
#endif

extension View {
    func mediaViewerCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
