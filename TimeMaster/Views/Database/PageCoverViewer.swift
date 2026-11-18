import Combine
import SwiftUI
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

/// The viewer a page's cover opens in a Database list: the page's clips in the app's media viewer
/// (`PageMediaGallery`, in place), grown out of the cover the way a page's own media cards grow theirs
/// (`AnyTransition.mediaExpand`), the first clip playing, with "Open Page" to go on to the page. One lives over each
/// Database navigation stack (`pageCoverViewerHost`), and the stack's `DatabaseNavigationState` hands it to
/// `PageCoverOpening`.
@MainActor
final class PageCoverViewer: ObservableObject {
    /// The page whose clips are showing, and the cover they grew out of.
    struct Shown {
        let pageID: String
        let presentation: MediaViewerPresentation
    }

    @Published private(set) var shown: Shown?
    /// The clip on screen, in `PageCoverOpening.clips(of:)`.
    @Published var selectedIndex = 0
    /// Where the covers on screen sit, so the viewer grows out of the one clicked.
    let covers = PageCoverFrames()
    /// The stack the viewer fills, in global coordinates.
    var frame: CGRect = .zero
    var reduceMotion = false

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.9)
    }

    /// Shows `page`'s clips from the first one, grown out of its cover; false when it has no clip to show.
    func show(_ page: ExercisePage) -> Bool {
        guard !PageCoverOpening.clips(of: page).isEmpty else { return false }
        ClickThroughGuard.noteOpening()
        selectedIndex = 0
        let presentation = MediaViewerPresentation(
            opensEditor: false,
            source: covers.rect(for: page.manifest.id, in: frame),
            container: frame.size
        )
        withAnimation(animation) {
            shown = Shown(pageID: page.manifest.id, presentation: presentation)
        }
        return true
    }

    /// Shrinks the viewer back into the cover it came from; false when it was not showing.
    @discardableResult
    func close() -> Bool {
        guard shown != nil else { return false }
        withAnimation(animation) { shown = nil }
        return true
    }

    /// Takes the viewer away at once: the stack is moving on underneath it.
    func dismiss() {
        guard shown != nil else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { shown = nil }
    }

    /// "Open Page": the viewer goes and the page opens on the part that holds the clip on screen, playing it there.
    func openPage(_ page: ExercisePage, in navigationState: DatabaseNavigationState) {
        let clips = PageCoverOpening.clips(of: page)
        let clip = clips.indices.contains(selectedIndex) ? clips[selectedIndex] : clips.first
        dismiss()
        PageCoverOpening.openPage(page, playing: clip, in: navigationState)
    }
}

/// Where the page covers of one navigation stack sit on screen (global coordinates), kept while they show
/// (`pageCoverFrame`) so the cover viewer grows out of the one clicked. Keeping it draws nothing.
final class PageCoverFrames {
    private var rects: [String: CGRect] = [:]

    func set(_ rect: CGRect, for pageID: String) {
        rects[pageID] = rect
    }

    /// Forgets the cover of `pageID` when it is still the one at `rect` (another copy of the same page's card may have
    /// reported since).
    func remove(_ pageID: String, at rect: CGRect?) {
        guard let rect, rects[pageID] == rect else { return }
        rects[pageID] = nil
    }

    /// The cover of `pageID` in the coordinates of `container` (a global frame); nil when it is not on screen.
    func rect(for pageID: String, in container: CGRect) -> CGRect? {
        guard let rect = rects[pageID], container.width > 0, container.height > 0 else { return nil }
        let local = rect.offsetBy(dx: -container.minX, dy: -container.minY)
        return CGRect(origin: .zero, size: container.size).intersects(local) ? local : nil
    }
}

private struct PageCoverFramesKey: EnvironmentKey {
    static let defaultValue: PageCoverFrames? = nil
}

extension EnvironmentValues {
    /// The cover places of the navigation stack's cover viewer; nil where no stack hosts one.
    var pageCoverFrames: PageCoverFrames? {
        get { self[PageCoverFramesKey.self] }
        set { self[PageCoverFramesKey.self] = newValue }
    }
}

/// Tells the stack's cover viewer where a page's cover sits, so the viewer grows out of it. Nothing happens where no
/// viewer is hosted.
private struct PageCoverFrameReporter: ViewModifier {
    let pageID: String
    @Environment(\.pageCoverFrames) private var frames
    @State private var reported = ReportedCoverFrame()

    @ViewBuilder
    func body(content: Content) -> some View {
        if let frames {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                    reported.rect = rect
                    frames.set(rect, for: pageID)
                }
                .onDisappear { frames.remove(pageID, at: reported.rect) }
        } else {
            content
        }
    }
}

/// The place a cover last reported; held by reference so keeping it draws nothing.
private final class ReportedCoverFrame {
    var rect: CGRect?
}

extension View {
    /// Marks this as `page`'s cover for the viewer a click on it opens (`PageCoverOpening`), so the viewer grows out of
    /// it. `PageCoverTap` marks its cover itself.
    func pageCoverFrame(_ page: ExercisePage) -> some View {
        modifier(PageCoverFrameReporter(pageID: page.manifest.id))
    }

    /// Hosts the viewer the page covers inside this navigation stack open (`PageCoverOpening`): put it on the stack
    /// whose `DatabaseNavigationState` its pages use. A cover in a stack without one opens its page instead.
    func pageCoverViewerHost(_ navigationState: DatabaseNavigationState) -> some View {
        modifier(PageCoverViewerHost(navigationState: navigationState))
    }
}

/// The cover viewer over a navigation stack: it fills the stack, goes away at once when the stack moves (a back
/// button, a link, the page keys), and gives its stack's `DatabaseNavigationState` the viewer while it shows.
private struct PageCoverViewerHost: ViewModifier {
    let navigationState: DatabaseNavigationState
    @StateObject private var viewer = PageCoverViewer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.pageCoverFrames, viewer.covers)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewer.frame = $0 }
            .overlay { PageCoverViewerLayer(viewer: viewer, navigationState: navigationState) }
            .onAppear {
                viewer.reduceMotion = reduceMotion
                navigationState.coverViewer = viewer
            }
            .onDisappear {
                viewer.dismiss()
                if navigationState.coverViewer === viewer { navigationState.coverViewer = nil }
            }
            .onChange(of: reduceMotion) { viewer.reduceMotion = $0 }
            .onReceive(navigationState.$path.dropFirst()) { _ in viewer.dismiss() }
    }
}

/// The viewer itself while it shows: the page's clips, its notes, "Open Page"; Escape or the shrink button closes it
/// and the app's navigation bar steps aside meanwhile.
private struct PageCoverViewerLayer: View {
    @ObservedObject var viewer: PageCoverViewer
    let navigationState: DatabaseNavigationState
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let page = viewer.shown.flatMap { store.page(manifestID: $0.pageID) }
        ZStack {
            if let shown = viewer.shown, let page {
                gallery(page)
                    .id(shown.pageID)
                    .transition(reduceMotion
                        ? AnyTransition.opacity
                        : AnyTransition.mediaExpand(from: shown.presentation.source, in: shown.presentation.container))
            }
        }
        .slotNavigationInteractionDisabled(page != nil)
    }

    private func gallery(_ page: ExercisePage) -> some View {
        PageMediaGallery(
            urls: PageCoverOpening.clips(of: page),
            selectedIndex: $viewer.selectedIndex,
            isPresented: Binding(get: { viewer.shown != nil }, set: { if !$0 { viewer.close() } }),
            comments: page.mediaCommentsByURL,
            onSaveComment: { url, comment in
                try store.updateMediaComment(pageID: page.manifest.id, filename: url.lastPathComponent, comment: comment)
            },
            notesAssets: { _ in FolderMarkdownAssets(folder: store.folderURL(for: page)) },
            presentation: .inPlace,
            mediaOwnerID: { _ in page.manifest.id },
            onOpenPage: { viewer.openPage(page, in: navigationState) }
        )
        .keyNavHost()
        .accessibilityAddTraits(.isModal)
        #if os(macOS)
        .background {
            PageCoverViewerEscape { viewer.close() }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        #endif
    }
}

#if os(macOS)
/// Escape closes the cover viewer before anything else in its window answers the key: in a sheet its Back or Done
/// button shares it. Keyboard navigation still takes it first (leaving a group it entered), a sheet, an alert or a
/// menu over the viewer keeps it, and once the viewer is on its way out the key goes on as usual.
private struct PageCoverViewerEscape: NSViewRepresentable {
    /// Closes the viewer; false when it was not showing.
    let onEscape: () -> Bool

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onEscape = onEscape
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class CatcherView: NSView {
        var onEscape: (() -> Bool)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let taken = MainActor.assumeIsolated { self?.handle(event) ?? false }
                return taken ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard event.keyCode == KeyNavKey.escape, let window, event.window === window,
                  event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty,
                  window.attachedSheet == nil, NSApp.modalWindow == nil, !KeyNavMonitor.shared.isTrackingMenu
            else { return false }
            if event.isARepeat { return true }
            if KeyNavRouter.router(for: window)?.handleKey(event) == true { return true }
            return onEscape?() ?? false
        }
    }
}
#endif
