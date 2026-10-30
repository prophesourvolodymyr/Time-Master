import SwiftUI
import AVKit
import TimeMasterCore
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

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

    @State private var drawer: CGFloat
    @State private var liveDrag: CGFloat = 0
    @State private var dismissDrag: CGFloat = 0
    @State private var dragAxis: Axis?
    @State private var scrollID: Int?
    @State private var isZoomed = false
    @State private var mediaHidden = false
    @State private var drafts: [URL: String] = [:]
    @State private var lastSaved: [URL: String] = [:]
    @State private var saveTasks: [URL: Task<Void, Never>] = [:]
    @State private var saveError: String?
    @State private var showDatabase = false
    @State private var showMusic = false
    #if os(iOS)
    @State private var keyboardVisible = false
    #endif
    @ObservedObject private var library = MusicLibraryStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    #endif

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
        databasePageID: ((URL) -> UUID?)? = nil
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
        _drawer = State(initialValue: opensEditor && onSaveComment != nil ? 1 : 0)
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

    private var fraction: CGFloat {
        guard hasNotesSurface else { return 0 }
        return min(1, max(0, drawer + liveDrag))
    }

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
            GeometryReader { proxy in
                content(size: proxy.size)
            }
            .offset(y: dismissDrag * 0.6)
            .opacity(1 - min(0.5, dismissDrag / 500))
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
        .frame(minWidth: 720, idealWidth: 980, minHeight: 560, idealHeight: 760)
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
        let pagerHeight = collapsedPager + (expandedPager - collapsedPager) * fraction
        let travel = max(1, collapsedPager - expandedPager)

        return VStack(spacing: 0) {
            topBar
                .frame(height: topBarHeight)
            pager
                .frame(height: pagerHeight)
                .clipped()
                #if os(macOS)
                .overlay { macChevrons }
                #endif
                .simultaneousGesture(drawerDrag(travel: travel), including: isZoomed ? .subviews : .all)
            if hasNotesSurface, let url = selectedURL {
                drawerView(url: url, travel: travel)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 10) {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 44))
                .accessibilityLabel("Close media viewer")
                Spacer()
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
                #if os(macOS)
                if let url = selectedURL, PageMediaKind.isVideo(url) {
                    Button {
                        MacVideoWorkspaceWindowPresenter.shared.present(
                            sources: [MacVideoSource(url: url)],
                            databaseStore: databaseStore,
                            workoutStore: workoutStore
                        )
                    } label: {
                        Label("Cut video", systemImage: "scissors")
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 36, horizontalPadding: 12))
                }
                #endif
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
                PageGalleryInlineVideo(url: url, isActive: index == selectedIndex)
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

    private func drawerView(url: URL, travel: CGFloat) -> some View {
        VStack(spacing: 0) {
            drawerHeader(url: url)
                .contentShape(Rectangle())
                .onTapGesture { if fraction < 0.5 { setDrawer(1) } }
                .gesture(drawerDrag(travel: travel))
                #if os(macOS)
                .overlay { MacScrollSwipeCatcher { up in setDrawer(up ? 1 : 0) } }
                #endif
            if fraction > 0.02 {
                drawerBody(url: url)
                    .opacity(min(1, fraction * 1.6))
                    .allowsHitTesting(fraction > 0.9)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background, in: TopRoundedShape(radius: 22))
        .overlay(alignment: .top) {
            TopRoundedShape(radius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(TopRoundedShape(radius: 22))
    }

    private func drawerHeader(url: URL) -> some View {
        let note = currentNote
        let expanded = fraction > 0.5
        return VStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
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
                } else {
                    Text(note.isEmpty ? "Swipe up to write notes" : Self.preview(of: note))
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(note.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: expanded ? "Collapse notes" : "Open notes") { setDrawer(expanded ? 0 : 1) }
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

    private func kindLabel(for url: URL) -> String {
        let index = (urls.firstIndex(of: url) ?? 0) + 1
        return "\(PageMediaKind.isVideo(url) ? "Video" : "Photo") \(index)"
    }

    private static func preview(of note: String) -> String {
        let line = note.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? note
        return line.trimmingCharacters(in: CharacterSet(charactersIn: "#>*-` ").union(.whitespaces))
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
        withAnimation(motion) {
            drawer = value
            liveDrag = 0
            dismissDrag = 0
        }
        if value == 0 { flushDrafts() }
        #if os(iOS)
        if value == 0 {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        #endif
    }

    private func drawerDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if dragAxis == nil {
                    dragAxis = abs(value.translation.height) > abs(value.translation.width) ? .vertical : .horizontal
                }
                guard dragAxis == .vertical else { return }
                let dy = value.translation.height
                if hasNotesSurface {
                    let delta = -dy / travel
                    liveDrag = min(1 - drawer, max(-drawer, delta))
                }
                dismissDrag = drawer == 0 && dy > 0 ? dy : 0
            }
            .onEnded { value in
                let axis = dragAxis
                dragAxis = nil
                guard axis == .vertical else {
                    withAnimation(motion) { liveDrag = 0; dismissDrag = 0 }
                    return
                }
                let dy = value.translation.height
                if drawer == 0, dy > 110 {
                    isPresented = false
                    return
                }
                guard hasNotesSurface else {
                    withAnimation(motion) { liveDrag = 0; dismissDrag = 0 }
                    return
                }
                let projected = drawer + (-value.predictedEndTranslation.height / travel)
                setDrawer(projected > 0.5 ? 1 : 0)
            }
    }

    #if os(macOS)
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
            .disabled(fraction > 0.5)
            Button("Collapse notes") { setDrawer(0) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(fraction < 0.5)
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

private struct PageGalleryInlineVideo: View {
    let url: URL
    let isActive: Bool
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                TmaxLoadingIndicator()
            }
        }
        .onAppear {
            if player == nil { player = AVPlayer(url: url) }
            sync()
        }
        .onChange(of: isActive) { _ in sync() }
        .onDisappear { player?.pause() }
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
private struct MacScrollSwipeCatcher: NSViewRepresentable {
    let onSwipe: (Bool) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onSwipe = onSwipe
    }

    final class CatcherView: NSView {
        var onSwipe: ((Bool) -> Void)?
        private var monitor: Any?
        private var accumulated: CGFloat = 0
        private var fired = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func handle(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point), abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return }
            let fingersUp = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY < 0 : event.scrollingDeltaY > 0
            if event.phase.isEmpty && event.momentumPhase.isEmpty {
                onSwipe?(fingersUp)
                return
            }
            if event.phase == .began || event.phase == .mayBegin {
                accumulated = 0
                fired = false
            }
            guard event.momentumPhase.isEmpty, !fired else { return }
            accumulated += fingersUp ? abs(event.scrollingDeltaY) : -abs(event.scrollingDeltaY)
            if abs(accumulated) > 18 {
                fired = true
                onSwipe?(accumulated > 0)
            }
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
