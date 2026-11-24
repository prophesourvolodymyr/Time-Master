import Combine
import SwiftUI
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

enum QuickPreviewBlockKind: Equatable {
    case single
    case bundle
    case library

    var title: String {
        switch self {
        case .single: "Single exercise"
        case .bundle: "Bundle"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .single: "figure.strengthtraining.traditional"
        case .bundle: "rectangle.stack.fill"
        case .library: "books.vertical.fill"
        }
    }

    var tint: Color {
        switch self {
        case .single: Theme.toolbarOrange
        case .bundle: Color(hex: "5AA9FF")
        case .library: Theme.textSecondary
        }
    }
}

struct QuickPreviewStep: Identifiable, Equatable {
    let id: String
    let pageID: UUID?
    let title: String
    let detail: String?
    let isRest: Bool
    let note: String?
    let blockID: String
    let blockKind: QuickPreviewBlockKind
    let blockTitle: String
    var blockNumber = 1
    var blockCount = 1
}

struct QuickPreviewOpen {
    let pageID: UUID
    let clip: URL?
    let tab: PageTab?
}

enum QuickPreviewSteps {
    static func steps(for workout: Workout, page: (UUID) -> ExercisePage?) -> [QuickPreviewStep] {
        var result: [QuickPreviewStep] = []
        var blocks = 0
        for section in workout.sections {
            let kind: QuickPreviewBlockKind = section.mode == .bundle ? .bundle : .single
            let blockID = section.id.uuidString
            var steps: [QuickPreviewStep] = []

            func add(_ id: String, _ pageID: UUID?, _ title: String, _ detail: String?, rest: Bool = false, note: String? = nil) {
                guard pageID != nil || note != nil else { return }
                steps.append(QuickPreviewStep(
                    id: id, pageID: pageID, title: title, detail: detail, isRest: rest, note: note,
                    blockID: blockID, blockKind: kind, blockTitle: section.name
                ))
            }

            func titled(_ pageID: UUID?, _ fallback: String) -> String {
                pageID.flatMap(page)?.title ?? fallback
            }

            func effort(_ slot: SetSlot) -> String {
                section.isTimerEnabled ? clock(slot.duration) : (slot.repCount.map { "\($0) reps" } ?? "until done")
            }

            func addRest(row: RestRow?, exercise: UUID?, key: String, label: String, seconds: Int) {
                let when = seconds > 0 ? "\(label) · \(clock(seconds))" : label
                add(key, exercise, "Rest exercise: \(titled(exercise, "Exercise"))", when, rest: true)
                for content in row?.contents ?? [] {
                    switch content.kind {
                    case .stretch:
                        let name = content.text.isEmpty ? titled(content.pageID, "Stretch") : content.text
                        add("rest-content-\(content.id)", content.pageID, name, "Stretch · \(when)", rest: true)
                    case .note:
                        let text = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        add("rest-content-\(content.id)", nil, "Note", when, rest: true, note: text.isEmpty ? nil : text)
                    }
                }
            }

            if section.mode == .bundle {
                let rounds = section.bundleSets
                for (round, set) in rounds.enumerated() {
                    let prefix = "Round \(round + 1) of \(rounds.count)"
                    for (position, child) in set.children.enumerated() {
                        add("set-\(child.id)", child.exercisePageID, child.displayName,
                            "\(prefix) · \(position + 1) of \(set.children.count) · \(effort(child))")
                        for drop in child.drops {
                            add("drop-\(drop.id)", drop.exercisePageID, drop.name, "\(prefix) · drop set")
                        }
                        addRest(row: child.restRow, exercise: child.restExercisePageID,
                                key: "rest-exercise-\(child.id.uuidString)", label: "Rest", seconds: child.playbackRest)
                    }
                    addRest(row: set.restRow, exercise: set.restExercisePageID,
                            key: "rest-exercise-\(set.id.uuidString)", label: "Rest after round \(round + 1)", seconds: set.playbackRest)
                }
            } else {
                let slots = section.effectiveSlots
                for (index, slot) in slots.enumerated() {
                    let prefix = "Set \(index + 1) of \(slots.count)"
                    add("set-\(slot.id)", slot.exercisePageID, slot.displayName, "\(prefix) · \(effort(slot))")
                    for drop in slot.drops {
                        add("drop-\(drop.id)", drop.exercisePageID, drop.name, "\(prefix) · drop set")
                    }
                    addRest(row: slot.restRow, exercise: slot.restExercisePageID,
                            key: "rest-exercise-\(slot.id.uuidString)", label: "Rest after set \(index + 1)", seconds: slot.playbackRest)
                }
            }

            let big = section.bigRestRow
            addRest(row: big, exercise: big?.exercisePageID,
                    key: "rest-exercise-\(section.id.uuidString)", label: "Big rest", seconds: big?.duration ?? 0)

            guard !steps.isEmpty else { continue }
            blocks += 1
            result += steps.map { step in
                var numbered = step
                numbered.blockNumber = blocks
                return numbered
            }
        }
        return result.map { step in
            var counted = step
            counted.blockCount = blocks
            return counted
        }
    }

    static func steps(for pages: [ExercisePage]) -> [QuickPreviewStep] {
        pages.filter { $0.isContentPage && !$0.isNote }.map { page in
            QuickPreviewStep(
                id: "page-\(page.manifest.id)", pageID: page.id, title: page.title, detail: PageKindStyle.title(page),
                isRest: false, note: nil, blockID: "library", blockKind: .library, blockTitle: "Library"
            )
        }
    }

    static func index(of key: String?, pageID: UUID?, blockID: String? = nil, in steps: [QuickPreviewStep]) -> Int? {
        if let key {
            if let hit = steps.firstIndex(where: { $0.id == key }) { return hit }
            if key.hasPrefix("section-"), let hit = steps.firstIndex(where: { $0.blockID == String(key.dropFirst(8)) }) {
                return hit
            }
        }
        guard let pageID else { return nil }
        if let blockID, let hit = steps.firstIndex(where: { $0.pageID == pageID && $0.blockID == blockID }) { return hit }
        return steps.firstIndex { $0.pageID == pageID }
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}

@MainActor
final class QuickPreviewController: ObservableObject {
    @Published private(set) var steps: [QuickPreviewStep] = []
    @Published private(set) var index = 0
    @Published private(set) var isPresented = false
    @Published private(set) var crossing: QuickPreviewStep?
    @Published private(set) var direction = 1

    private var crossingTask: Task<Void, Never>?

    nonisolated init() {}

    var step: QuickPreviewStep? {
        isPresented && steps.indices.contains(index) ? steps[index] : nil
    }

    var canGoBack: Bool { isPresented && index > 0 }
    var canGoForward: Bool { isPresented && index + 1 < steps.count }

    func present(_ steps: [QuickPreviewStep], at index: Int) {
        guard steps.indices.contains(index) else { return }
        ClickThroughGuard.noteOpening()
        crossingTask?.cancel()
        crossing = nil
        direction = 1
        self.steps = steps
        self.index = index
        isPresented = true
    }

    func move(_ delta: Int) {
        let next = index + delta
        guard isPresented, steps.indices.contains(next) else { return }
        let crossed = steps[next].blockID != steps[index].blockID
        direction = delta >= 0 ? 1 : -1
        index = next
        crossingTask?.cancel()
        crossing = crossed ? steps[next] : nil
        guard crossed else { return }
        crossingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            self?.crossing = nil
        }
    }

    func close() {
        crossingTask?.cancel()
        crossing = nil
        isPresented = false
    }
}

struct QuickPreviewPopup: View {
    @ObservedObject var controller: QuickPreviewController
    let onOpen: (QuickPreviewOpen) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clipIndex = 0
    @State private var clipAspect: CGFloat = 16.0 / 9.0
    private static let pictureHeightCap: CGFloat = 480

    var body: some View {
        ZStack {
            if let step = controller.step {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { controller.close() }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                card(step)
                    .padding(20)
                    .keyNavHost()
                    .accessibilityAddTraits(.isModal)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    #if os(macOS)
                    .background {
                        QuickPreviewKeys(onStep: { move($0) }, onEscape: { controller.close() })
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    #endif
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: controller.isPresented)
        .onChange(of: controller.step?.id) { _ in clipIndex = 0 }
    }

    private func move(_ delta: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { controller.move(delta) }
    }

    private func card(_ step: QuickPreviewStep) -> some View {
        let page = step.pageID.flatMap { store.page(id: $0) }
        let clips = page.map(PageCoverOpening.clips(of:)) ?? []
        let clip = clips.indices.contains(clipIndex) ? clips[clipIndex] : clips.first
        let slide: AnyTransition = reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: controller.direction > 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            )
        return VStack(spacing: 0) {
            header(step)
            VStack(spacing: 0) {
                titles(step)
                media(step, page: page, clip: clip)
                if clips.count > 1 { clipChips(count: clips.count) }
            }
            .id(step.id)
            .transition(slide)
            footer(page: page, clip: clip)
        }
        .frame(maxWidth: 780)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 32, y: 12)
        #if os(iOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 32).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                move(value.translation.width < 0 ? 1 : -1)
            }
        )
        #endif
    }

    private func header(_ step: QuickPreviewStep) -> some View {
        HStack(spacing: 10) {
            blockChip(step)
            Spacer(minLength: 8)
            Text("\(controller.index + 1) / \(controller.steps.count)")
                .font(TimeMasterFont.caption())
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .accessibilityLabel("Step \(controller.index + 1) of \(controller.steps.count)")
            Button { controller.close() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close preview")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func blockChip(_ step: QuickPreviewStep) -> some View {
        let kind = step.blockKind
        return HStack(spacing: 6) {
            Image(systemName: kind.symbol)
            Text(kind == .library ? kind.title : "\(kind.title) · \(step.blockTitle)")
                .lineLimit(1)
            if step.blockCount > 1 {
                Text("\(step.blockNumber)/\(step.blockCount)")
                    .monospacedDigit()
                    .opacity(0.7)
            }
        }
        .font(TimeMasterFont.caption())
        .fontWeight(.semibold)
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(kind.tint.opacity(0.16)))
        .overlay(Capsule(style: .continuous).strokeBorder(kind.tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(step.blockTitle)")
    }

    private func titles(_ step: QuickPreviewStep) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(step.title)
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if let detail = step.detail {
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func media(_ step: QuickPreviewStep, page: ExercisePage?, clip: URL?) -> some View {
        ZStack {
            Color.black
            if let clip {
                QuickPreviewVideo(url: clip, aspect: $clipAspect)
                    .id(clip)
            } else if let cover = page?.coverImageURL {
                GeometryReader { proxy in
                    AsyncCoverImage(url: cover, height: proxy.size.height, contentMode: .fit, overlayGradient: false)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: step.isRest ? "pause.circle" : "video.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    Text(step.note ?? (step.isRest ? (step.detail ?? "Rest") : "No video on this page"))
                        .font(TimeMasterFont.body())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .aspectRatio(clip == nil ? 16.0 / 9.0 : min(max(clipAspect, 1.0), 16.0 / 9.0), contentMode: .fit)
        .frame(maxHeight: Self.pictureHeightCap)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: clipAspect)
        .overlay(alignment: .top) { crossingBanner }
    }

    @ViewBuilder
    private var crossingBanner: some View {
        if let crossing = controller.crossing {
            HStack(spacing: 8) {
                Image(systemName: crossing.blockKind.symbol)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Now in \(crossing.blockKind.title.lowercased())")
                        .font(TimeMasterFont.caption())
                    Text(crossing.blockTitle)
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(crossing.blockKind.tint.opacity(0.7), lineWidth: 1.5))
            .padding(.top, 12)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    private func clipChips(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { position in
                let selected = position == clipIndex
                Button { clipIndex = position } label: {
                    Text("\(position + 1)")
                        .font(TimeMasterFont.caption())
                        .fontWeight(.semibold)
                        .frame(minWidth: 30, minHeight: 28)
                        .foregroundStyle(selected ? Color.black : Theme.textPrimary)
                        .background(Capsule(style: .continuous).fill(selected ? Theme.toolbarOrange : Theme.surface2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clip \(position + 1) of \(count)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.top, 10)
    }

    private func footer(page: ExercisePage?, clip: URL?) -> some View {
        let attached = page.map { $0.manifest.linkedPageIDs.compactMap { store.page(manifestID: $0) } } ?? []
        return ViewThatFits(in: .horizontal) {
            controls(page: page, clip: clip, attached: attached, compact: false)
            controls(page: page, clip: clip, attached: attached, compact: true)
        }
        .padding(14)
    }

    private func controls(page: ExercisePage?, clip: URL?, attached: [ExercisePage], compact: Bool) -> some View {
        HStack(spacing: 10) {
            stepButton(-1, symbol: "chevron.left", label: "Previous")
            Spacer(minLength: 0)
            if let page {
                if hasNotes(page) {
                    Button { open(page, clip: clip, tab: .notes) } label: { actionLabel("Notes", "note.text", compact) }
                        .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 44))
                }
                if !attached.isEmpty {
                    Menu {
                        ForEach(attached, id: \.manifest.id) { linked in
                            Button(linked.title) { open(linked, clip: nil, tab: nil) }
                        }
                    } label: {
                        actionLabel("Pages \(attached.count)", "rectangle.stack", compact)
                    }
                    .menuStyle(.button)
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 44))
                }
                Button { open(page, clip: clip, tab: nil) } label: { actionLabel("Open Page", "arrow.up.forward.square", compact) }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 44))
            }
            Spacer(minLength: 0)
            stepButton(1, symbol: "chevron.right", label: "Next")
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, _ symbol: String, _ compact: Bool) -> some View {
        if compact {
            Image(systemName: symbol).accessibilityLabel(title)
        } else {
            Label(title, systemImage: symbol).lineLimit(1)
        }
    }

    @ViewBuilder
    private func stepButton(_ delta: Int, symbol: String, label: String) -> some View {
        let enabled = delta < 0 ? controller.canGoBack : controller.canGoForward
        let button = Button { move(delta) } label: { Image(systemName: symbol) }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 44))
            .disabled(!enabled)
            .accessibilityLabel(label)
        #if os(iOS)
        button.keyboardShortcut(delta < 0 ? .leftArrow : .rightArrow, modifiers: [])
        #else
        button
        #endif
    }

    private func hasNotes(_ page: ExercisePage) -> Bool {
        !page.manifest.markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !page.manifest.mediaComments.isEmpty
    }

    private func open(_ page: ExercisePage, clip: URL?, tab: PageTab?) {
        controller.close()
        onOpen(QuickPreviewOpen(pageID: page.id, clip: clip, tab: tab))
    }
}

struct QuickPreviewHost: ViewModifier {
    @ObservedObject var controller: QuickPreviewController
    let onOpen: (QuickPreviewOpen) -> Void

    func body(content: Content) -> some View {
        content
            .overlay { QuickPreviewPopup(controller: controller, onOpen: onOpen) }
            .slotNavigationInteractionDisabled(controller.isPresented)
    }
}

private struct QuickPreviewStackHost: ViewModifier {
    let navigationState: DatabaseNavigationState
    @StateObject private var controller = QuickPreviewController()
    @EnvironmentObject private var store: DatabaseStore

    func body(content: Content) -> some View {
        content
            .modifier(QuickPreviewHost(controller: controller) { open($0) })
            .onAppear { navigationState.quickPreview = controller }
            .onDisappear {
                controller.close()
                if navigationState.quickPreview === controller { navigationState.quickPreview = nil }
            }
            .onReceive(navigationState.$path.dropFirst()) { _ in controller.close() }
    }

    private func open(_ request: QuickPreviewOpen) {
        if let tab = request.tab {
            PageTabMemory.remember(tab, for: request.pageID.uuidString)
            navigationState.path.append(DatabasePageRoute(pageID: request.pageID.uuidString))
        } else if let page = store.page(id: request.pageID) {
            PageCoverOpening.openPage(page, playing: request.clip, in: navigationState)
        }
    }
}

extension View {
    func quickPreviewHost(_ controller: QuickPreviewController, onOpen: @escaping (QuickPreviewOpen) -> Void) -> some View {
        modifier(QuickPreviewHost(controller: controller, onOpen: onOpen))
    }

    func quickPreviewHost(_ navigationState: DatabaseNavigationState) -> some View {
        modifier(QuickPreviewStackHost(navigationState: navigationState))
    }
}

#if os(macOS)
private struct QuickPreviewKeys: NSViewRepresentable {
    let onStep: (Int) -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onStep = onStep
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onStep = onStep
        view.onEscape = onEscape
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class CatcherView: NSView {
        var onStep: ((Int) -> Void)?
        var onEscape: (() -> Void)?
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
            guard let window, event.window === window,
                  event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty,
                  window.attachedSheet == nil, NSApp.modalWindow == nil, !KeyNavMonitor.shared.isTrackingMenu
            else { return false }
            switch event.keyCode {
            case KeyNavKey.left:
                onStep?(-1)
                return true
            case KeyNavKey.right:
                onStep?(1)
                return true
            case KeyNavKey.escape:
                if event.isARepeat { return true }
                if KeyNavRouter.router(for: window)?.handleKey(event) == true { return true }
                onEscape?()
                return true
            default:
                return false
            }
        }
    }
}
#endif
