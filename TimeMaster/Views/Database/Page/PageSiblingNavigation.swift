import SwiftUI
import TimeMasterCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A page's Previous and Next: the sequence its screen froze (`DatabaseNavigationState.siblingSequence`) and the step
/// to a sibling. The page keeps it in `@State` without observing it; the top row, the keys, the swipes and the page's
/// motion observe it, so it never redraws the page.
final class PageSiblingNavigator: ObservableObject {
    @Published private(set) var sequence: PageSiblingSequence?
    /// Points the page leans while a step past either end rubber-bands.
    @Published private(set) var rubberBand: CGFloat = 0
    /// The page on screen. Published: a step swaps the top of the stack and SwiftUI keeps the page's screen, so only this
    /// changes, and the row must show the new place.
    @Published private(set) var pageID = ""
    /// `path.count` of the stack while the page is on top, taken when it first appeared.
    private var depth: Int?
    private weak var navigation: DatabaseNavigationState?
    private weak var store: DatabaseStore?
    private var settling: Task<Void, Never>?

    /// How far the page leans at either end.
    private static let reach: CGFloat = 16

    /// Where the page sits in its sequence; nil while the controls stay hidden (no container, a page alone in it).
    var position: PageSiblingPosition? {
        guard let sequence, sequence.isSteppable else { return nil }
        return sequence.position(of: pageID)
    }

    var isShown: Bool { position != nil }

    /// Takes up the sequence of the page `pageID` as its screen appears in `navigation`'s stack: the depth it sits at is
    /// the stack's `path.count` the first time (a page keeps its place while it lives), the sequence the one its screen
    /// froze, else the newest offer below it, else `fallback`, its container's own order.
    @MainActor
    func appear(pageID: String, navigation: DatabaseNavigationState, store: DatabaseStore,
                fallback: () -> PageSiblingSequence?) {
        if self.pageID != pageID || depth == nil {
            self.pageID = pageID
            depth = navigation.path.count
        }
        self.navigation = navigation
        self.store = store
        let found = navigation.siblingSequence(for: pageID, depth: depth ?? navigation.path.count, fallback: fallback)
        if found != sequence { sequence = found }
    }

    /// Whether the page is the top of its stack: keys and swipes rest on a page another one covers.
    @MainActor
    func isOnTop(of navigation: DatabaseNavigationState) -> Bool {
        depth == navigation.path.count
    }

    /// The page `step` places away (+1 next, -1 previous) that still exists; nil past either end.
    @MainActor
    func neighbour(_ step: Int) -> String? {
        guard let sequence else { return nil }
        var current = pageID
        while let candidate = sequence.neighbour(of: current, step: step) {
            if store?.page(manifestID: candidate) != nil { return candidate }
            current = candidate
        }
        return nil
    }

    /// Goes to the next (+1) or the previous (-1) page in place of this one; past either end the page rubber-bands
    /// with a light tap instead (Reduce Motion keeps the tap alone).
    @MainActor
    func step(_ direction: Int, reduceMotion: Bool) {
        guard let navigation, isShown, isOnTop(of: navigation) else { return }
        guard let target = neighbour(direction) else {
            refuse(direction, reduceMotion: reduceMotion)
            return
        }
        navigation.goToSibling(target, direction: direction)
    }

    @MainActor
    func go(to target: String) {
        guard let navigation, isShown, isOnTop(of: navigation), let sequence,
              let from = sequence.pageIDs.firstIndex(of: pageID),
              let destination = sequence.pageIDs.firstIndex(of: target),
              from != destination else { return }
        navigation.goToSibling(target, direction: destination < from ? -1 : 1)
    }

    @MainActor
    private func refuse(_ direction: Int, reduceMotion: Bool) {
        EverHaptic.selection()
        guard !reduceMotion else { return }
        settling?.cancel()
        withAnimation(.spring(response: 0.16, dampingFraction: 0.82)) {
            rubberBand = CGFloat(direction < 0 ? 1 : -1) * Self.reach
        }
        settling = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled, let self else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { self.rubberBand = 0 }
        }
    }
}

/// The order Previous and Next follow on a page opened from anywhere but one of its container's surfaces (the search
/// sheet, a link, a deep link): a folder's tab that lists the page (Exercises or Skills, as the folder lists them), a
/// skill's or a tutorial's board in reading order and then its other pages, any other page's children in child order.
/// A page with no container has none.
@MainActor
enum PageSiblingDefaults {
    static func sequence(for pageID: String, in store: DatabaseStore) -> PageSiblingSequence? {
        guard let page = store.page(manifestID: pageID), let parentID = page.manifest.parentID,
              let parent = store.page(manifestID: parentID) else { return nil }
        let children = store.children(ofManifestID: parentID).map(\.manifest.id)
        if parent.pageType == nil {
            let lists = store.containerBrowseModel(for: parent).lists(query: "")
            let tabs = [ContainerChildTab.exercises, .skills].map { (lists[$0] ?? []).map(\.id) }
            return PageSiblingOrder.folder(parentID, tabs: tabs, holding: pageID)
                ?? PageSiblingSequence(containerID: parentID, pageIDs: children)
        }
        guard parent.isSkillLike else { return PageSiblingSequence(containerID: parentID, pageIDs: children) }
        let groups: [String?] = [nil] + store.skillGroups(of: parentID).map { Optional($0.id) }
        let board = groups.flatMap { store.skillPages(onBoard: parentID, sectionID: $0) }.map(\.manifest.id)
        return PageSiblingOrder.skill(parentID, board: board, children: children)
    }
}

/// Previous and Next on their own glass capsule with the page's place between them ("5 / 23"), beside the path under
/// the back button. Each arrow answers a 44 pt touch; at either end its arrow rests.
struct PageSiblingBar: View {
    @ObservedObject var navigator: PageSiblingNavigator
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showsList = false

    private static let height: CGFloat = 32

    var body: some View {
        if let position = navigator.position {
            let shape = Capsule(style: .continuous)
            HStack(spacing: 0) {
                arrow(-1, target: navigator.neighbour(-1))
                countButton(position)
                arrow(1, target: navigator.neighbour(1))
            }
            .background {
                shape.fill(glass)
                    .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(height: Self.height)
                    .padding(.horizontal, SkillMetrics.s2)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(containerLabel)
        }
    }

    private func countButton(_ position: PageSiblingPosition) -> some View {
        Button {
            showsList = true
        } label: {
            Text(position.label)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .frame(minHeight: Self.height)
                .contentShape(Rectangle())
        }
        .keyNavBounceButtonStyle(shape: .capsule, cornerRadius: Self.height / 2, lift: 5)
        .pagePopover(isPresented: $showsList) {
            PageSiblingListPopup(
                title: containerLabel,
                rows: listRows,
                onOpen: { id in
                    showsList = false
                    navigator.go(to: id)
                }
            )
        }
        .accessibilityLabel(position.spokenLabel)
        .accessibilityHint("Shows the pages in this list")
    }

    private var listRows: [PageSiblingListPopup.Row] {
        guard let ids = navigator.sequence?.pageIDs else { return [] }
        return ids.enumerated().compactMap { index, id in
            guard let page = store.page(manifestID: id) else { return nil }
            return PageSiblingListPopup.Row(id: id, number: index + 1, title: page.title, isCurrent: id == navigator.pageID)
        }
    }

    private func arrow(_ step: Int, target: String?) -> some View {
        let name = step < 0 ? "Previous page" : "Next page"
        let title = target.flatMap { store.page(manifestID: $0)?.title }
        return Button {
            navigator.step(step, reduceMotion: reduceMotion)
        } label: {
            Image(systemName: step < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(target == nil ? 0.3 : 0.9))
                .frame(width: SkillMetrics.touch, height: SkillMetrics.touch)
                .contentShape(Rectangle())
        }
        .keyNavBounceButtonStyle(
            shape: .circle,
            cornerRadius: SkillMetrics.touch / 2,
            inset: (SkillMetrics.touch - Self.height) / 2,
            lift: 6
        )
        .disabled(target == nil)
        #if os(macOS)
        .help(step < 0 ? "Previous page (⌘[)" : "Next page (⌘])")
        #endif
        .accessibilityLabel(title.map { "\(name), \($0)" } ?? name)
    }

    private var containerLabel: String {
        guard let id = navigator.sequence?.containerID, let title = store.page(manifestID: id)?.title,
              !title.isEmpty else { return "Pages" }
        return "Pages in \(title)"
    }

    private var glass: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.ultraThinMaterial)
    }
}

/// Room at the top of a page with no path row of its own (a note) for the row of Previous and Next, once it shows.
struct PageSiblingClearance: View {
    @ObservedObject var navigator: PageSiblingNavigator
    let height: CGFloat

    var body: some View {
        if navigator.isShown {
            Color.clear
                .frame(height: height)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Previous and Next for the page `pageID` (a manifest id), applied to the page's content above its background.
    /// When the page appears, `navigator` takes up its sequence for the top row (`PageTopChrome`); ⌘[ and ⌘] step on
    /// the Mac and, with `swipes`, so does a two-finger sideways swipe (a pan on iPhone and iPad, the trackpad on the
    /// Mac; folders keep their buttons and keys only). `isEnabled` false rests keys and swipes (text being edited,
    /// a viewer over the page). The content slides in from the way a swap went where the Mac's page travel does not
    /// move the stack (fading with Reduce Motion), and leans and springs back at either end.
    func pageSiblingNavigation(_ navigator: PageSiblingNavigator, pageID: String, swipes: Bool,
                               isEnabled: Bool) -> some View {
        modifier(PageSiblingNavigationModifier(navigator: navigator, pageID: pageID, swipes: swipes, isEnabled: isEnabled))
    }
}

private struct PageSiblingNavigationModifier: ViewModifier {
    @ObservedObject var navigator: PageSiblingNavigator
    let pageID: String
    let swipes: Bool
    let isEnabled: Bool

    @EnvironmentObject private var navigation: DatabaseNavigationState
    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The page has taken up the swap that brought it, or found none.
    @State private var arrived = false
    @State private var arrivalDirection: CGFloat = 0
    @State private var arrivalProgress: CGFloat = 1

    func body(content: Content) -> some View {
        let active = isEnabled && navigator.isShown && navigator.isOnTop(of: navigation)
        // A swap the page has not taken up yet already draws at its start in this pass, never a frame at rest first.
        let waiting = arrived ? nil : navigation.pendingSiblingArrival(for: pageID)
        let progress = waiting == nil ? arrivalProgress : 0
        let slide: CGFloat = 0
        return content
            .background {
                #if os(iOS)
                if swipes {
                    PageSiblingPan(isEnabled: active) { navigator.step($0, reduceMotion: reduceMotion) }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #elseif os(macOS)
                PageSiblingKeys(isEnabled: active) { navigator.step($0, reduceMotion: reduceMotion) }
                if swipes {
                    PageSiblingTrackpadSwipe(isEnabled: active) { navigator.step($0, reduceMotion: reduceMotion) }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #endif
            }
            .offset(x: slide + navigator.rubberBand)
            .opacity(reduceMotion ? Double(progress) : 1)
            .onAppear { appear(pageID) }
            // The action is the one of the view before the change: it must take the new id from its argument.
            .onChange(of: pageID) { appear($0) }
            .task { await arrive() }
    }

    /// Takes up the page's sequence: as the page appears, and should the page on screen change in place (a step swaps
    /// the top of the stack and SwiftUI keeps the page's screen).
    private func appear(_ pageID: String) {
        navigator.appear(pageID: pageID, navigation: navigation, store: store) {
            PageSiblingDefaults.sequence(for: pageID, in: store)
        }
    }

    /// Plays the arrival of a page a swap brought: in from the side it travelled toward, or a fade with Reduce Motion.
    private func arrive() async {
        guard !arrived else { return }
        let taken = navigation.takeSiblingArrival(for: pageID)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            arrived = true
            if let taken {
                arrivalDirection = taken
                arrivalProgress = 0
            }
        }
        guard taken != nil else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : EverPageMotion.curve) {
            arrivalProgress = 1
        }
    }
}

#if os(macOS)
/// ⌘[ and ⌘] on the Mac: the previous and the next page of the sequence (⌘← and ⌘→ change the app's page, ⌥⌘← and
/// ⌥⌘→ the page's tab). The keys rest while a text field or a text view has the keyboard.
private struct PageSiblingKeys: View {
    let isEnabled: Bool
    let onStep: (Int) -> Void

    var body: some View {
        ZStack {
            Button("Previous page") { step(-1) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next page") { step(1) }
                .keyboardShortcut("]", modifiers: .command)
        }
        .disabled(!isEnabled)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ direction: Int) {
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSText || responder is NSTextField { return }
        onStep(direction)
    }
}

/// Two-finger sideways swipes on a Mac trackpad over the page, read from the window's scroll events without taking
/// any: one step per gesture (`PageSiblingScrollTracker`), momentum and mouse wheels ignored. A gesture that starts over
/// a scroll view that moves sideways (a media strip, board columns, a long path) is that view's, as is one that starts
/// while text is edited.
private struct PageSiblingTrackpadSwipe: NSViewRepresentable {
    var isEnabled: Bool
    var onStep: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.isEnabled = isEnabled
        view.onStep = onStep
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.isEnabled = isEnabled
        view.onStep = onStep
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class CatcherView: NSView {
        var isEnabled = false
        var onStep: ((Int) -> Void)?
        private var monitor: Any?
        private var tracker = PageSiblingScrollTracker()

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.receive(event)
                return event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tracker = PageSiblingScrollTracker()
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func receive(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let phase: PageSiblingScrollTracker.Phase
            if !event.momentumPhase.isEmpty {
                phase = .momentum
            } else if event.phase.isEmpty {
                return
            } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                phase = .ended
            } else if event.phase.contains(.mayBegin) || event.phase.contains(.began) {
                // Fingers landing always start afresh, even when the end of the last gesture never came.
                if event.phase.contains(.mayBegin) { _ = tracker.receive(.ended, dx: 0, dy: 0) }
                phase = .began(eligible: mayStep(at: event, in: window))
            } else {
                phase = .changed
            }
            let inverted = event.isDirectionInvertedFromDevice
            let dx = inverted ? event.scrollingDeltaX : -event.scrollingDeltaX
            let dy = inverted ? -event.scrollingDeltaY : event.scrollingDeltaY
            guard let step = tracker.receive(phase, dx: dx, dy: dy) else { return }
            onStep?(step)
        }

        private func mayStep(at event: NSEvent, in window: NSWindow) -> Bool {
            guard isEnabled, !isHiddenOrHasHiddenAncestor,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return false }
            if let responder = window.firstResponder, responder is NSText || responder is NSTextField { return false }
            return !Self.scrollsSideways(at: event.locationInWindow, in: window)
        }

        /// Whether a scroll view of the window that moves sideways lies under `point` (window coordinates).
        private static func scrollsSideways(at point: NSPoint, in window: NSWindow) -> Bool {
            guard let root = window.contentView else { return false }
            var stack: [NSView] = [root]
            while let view = stack.popLast() {
                guard !view.isHidden else { continue }
                if let scroll = view as? NSScrollView, let document = scroll.documentView {
                    let clip = scroll.contentView
                    if document.frame.width > clip.bounds.width + 1,
                       clip.convert(clip.bounds, to: nil).contains(point) {
                        return true
                    }
                }
                stack.append(contentsOf: view.subviews)
            }
            return false
        }
    }
}
#endif

#if os(iOS)
/// A two-finger sideways pan anywhere on the page, next to everything else the page answers: it takes no touch, so
/// scrolling, the sliding tabs and one-finger swipes keep working. A pan that starts over something that scrolls
/// sideways is that view's, as is one made while text is edited.
private struct PageSiblingPan: UIViewRepresentable {
    var isEnabled: Bool
    var onStep: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.isUserInteractionEnabled = false
        probe.onWindowChanged = { [weak coordinator = context.coordinator] probe in
            coordinator?.attach(to: probe)
        }
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onStep = onStep
        return probe
    }

    func updateUIView(_ probe: Probe, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onStep = onStep
    }

    static func dismantleUIView(_ probe: Probe, coordinator: Coordinator) {
        coordinator.detach()
        probe.onWindowChanged = nil
    }

    final class Probe: UIView {
        var onWindowChanged: ((Probe) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = false
        var onStep: (Int) -> Void = { _ in }
        private lazy var recognizer: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.cancelsTouchesInView = false
            pan.delaysTouchesEnded = false
            pan.delegate = self
            return pan
        }()

        /// Puts the recognizer on the root view of the controller showing the page, so it covers the page and leaves
        /// with it.
        func attach(to probe: Probe) {
            detach()
            guard probe.window != nil, let page = Self.pageView(holding: probe) else { return }
            page.addGestureRecognizer(recognizer)
        }

        func detach() {
            recognizer.view?.removeGestureRecognizer(recognizer)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let view = recognizer.view, let window = view.window else { return false }
            let translation = recognizer.translation(in: view)
            guard abs(translation.x) > abs(translation.y) else { return false }
            let location = recognizer.location(in: view)
            let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            return !Self.isEditingText(in: window) && !Self.scrollsSideways(at: start, in: view)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func panned(_ pan: UIPanGestureRecognizer) {
            guard pan.state == .ended, let view = pan.view else { return }
            let translation = pan.translation(in: view)
            let velocity = pan.velocity(in: view)
            guard let step = PageSiblingSwipe.step(
                translation: CGSize(width: translation.x, height: translation.y),
                velocity: CGSize(width: velocity.x, height: velocity.y)
            ) else { return }
            onStep(step)
        }

        private static func pageView(holding view: UIView) -> UIView? {
            var responder: UIResponder? = view.next
            while let current = responder {
                if let controller = current as? UIViewController { return controller.view }
                responder = current.next
            }
            return nil
        }

        private static func isEditingText(in view: UIView) -> Bool {
            if view.isFirstResponder, view is UITextInput { return true }
            return view.subviews.contains { isEditingText(in: $0) }
        }

        /// Whether a scroll view that moves sideways (a media strip, board columns, a long path) lies under `point`.
        private static func scrollsSideways(at point: CGPoint, in root: UIView) -> Bool {
            var current = root.hitTest(point, with: nil)
            while let view = current, view !== root {
                if let scroll = view as? UIScrollView, scroll.isScrollEnabled,
                   scroll.contentSize.width > scroll.bounds.width + 1 {
                    return true
                }
                current = view.superview
            }
            return false
        }
    }
}
#endif

struct PageSiblingListPopup: View {
    struct Row: Identifiable {
        let id: String
        let number: Int
        let title: String
        let isCurrent: Bool
    }

    let title: String
    let rows: [Row]
    let onOpen: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(TimeMasterFont.black(11, relativeTo: .caption2))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 2)
                    ForEach(rows) { row in
                        listRow(row).id(row.id)
                    }
                }
                .padding(10)
            }
            .onAppear {
                if let current = rows.first(where: \.isCurrent) {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 340)
        .background(Theme.background)
    }

    @ViewBuilder
    private func listRow(_ row: Row) -> some View {
        let content = HStack(spacing: 10) {
            Text("\(row.number)")
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .monospacedDigit()
                .foregroundStyle(row.isCurrent ? Theme.toolbarOrange : Color.white.opacity(0.45))
                .frame(width: 24, alignment: .trailing)
            Text(row.title)
                .font(TimeMasterFont.black(13, relativeTo: .footnote))
                .foregroundStyle(Color.white.opacity(row.isCurrent ? 1 : 0.8))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.toolbarOrange.opacity(row.isCurrent ? 0.28 : 0))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        if row.isCurrent {
            content
        } else {
            Button {
                onOpen(row.id)
            } label: {
                content
            }
            .keyNavBounceButtonStyle(shape: .roundedRectangle(cornerRadius: 12), cornerRadius: 12, lift: 4)
        }
    }
}
