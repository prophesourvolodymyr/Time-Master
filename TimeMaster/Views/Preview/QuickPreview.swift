import Combine
import SwiftUI
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

enum QuickPreviewBlockKind: Equatable {
    case single
    case bundle
    case combo
    case library

    var title: String {
        switch self {
        case .single: "Single exercise"
        case .bundle: "Bundle"
        case .combo: "Combo"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .single: "figure.strengthtraining.traditional"
        case .bundle: "rectangle.stack.fill"
        case .combo: ComboStyle.defaultIcon
        case .library: "books.vertical.fill"
        }
    }

    var tint: Color {
        switch self {
        case .single: Theme.toolbarOrange
        case .bundle: Color(hex: "5AA9FF")
        case .combo: ComboStyle.bright
        case .library: Theme.textSecondary
        }
    }
}

enum QuickPreviewFactKind: Equatable {
    case round
    case position
    case time
    case reps
    case untimed
    case rest
    case drop
    case stretch

    var tint: Color {
        switch self {
        case .round: Color(hex: "5AA9FF")
        case .position: Color(hex: "B28DFF")
        case .time: Theme.toolbarOrange
        case .reps: Color(hex: "5FD38D")
        case .untimed: Color(hex: "FFC857")
        case .rest: Theme.accent
        case .drop: Color(hex: "FF6B8B")
        case .stretch: Color(hex: "7BD88F")
        }
    }

    var symbol: String {
        switch self {
        case .round: "arrow.triangle.2.circlepath"
        case .position: "number"
        case .time: "timer"
        case .reps: "repeat"
        case .untimed: "hand.tap"
        case .rest: "pause.circle"
        case .drop: "arrow.down.right"
        case .stretch: "figure.flexibility"
        }
    }
}

struct QuickPreviewFact: Equatable {
    let kind: QuickPreviewFactKind
    let text: String

    init(_ kind: QuickPreviewFactKind, _ text: String) {
        self.kind = kind
        self.text = text
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
    var facts: [QuickPreviewFact] = []
    var examples: [UUID] = []
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
            let kind: QuickPreviewBlockKind = section.isCombo ? .combo : (section.mode == .bundle ? .bundle : .single)
            let blockID = section.id.uuidString
            var steps: [QuickPreviewStep] = []

            func add(
                _ id: String,
                _ pageID: UUID?,
                _ title: String,
                _ detail: String?,
                facts: [QuickPreviewFact] = [],
                rest: Bool = false,
                note: String? = nil,
                examples: [UUID] = []
            ) {
                guard pageID != nil || note != nil else { return }
                var step = QuickPreviewStep(
                    id: id, pageID: pageID, title: title, detail: detail, isRest: rest, note: note,
                    blockID: blockID, blockKind: kind, blockTitle: section.name
                )
                step.facts = facts
                step.examples = examples
                steps.append(step)
            }

            func titled(_ pageID: UUID?, _ fallback: String) -> String {
                pageID.flatMap(page)?.title ?? fallback
            }

            func effortFact(_ slot: SetSlot) -> QuickPreviewFact {
                if section.isTimerEnabled { return QuickPreviewFact(.time, clock(slot.duration)) }
                if let reps = slot.repCount { return QuickPreviewFact(.reps, "\(reps) reps") }
                return QuickPreviewFact(.untimed, "until done")
            }

            func examples(besides main: UUID?) -> [UUID] {
                section.examplePageIDs.filter { $0 != main && page($0) != nil }
            }

            func addRest(row: RestRow?, exercises: [UUID], key: String, label: String, seconds: Int) {
                let when = seconds > 0 ? "\(label) · \(clock(seconds))" : label
                let restFacts = [QuickPreviewFact(.rest, label)] + (seconds > 0 ? [QuickPreviewFact(.time, clock(seconds))] : [])
                for (offset, exercise) in exercises.enumerated() {
                    let title = "\(offset == 0 ? "Rest exercise" : "Rest option"): \(titled(exercise, "Exercise"))"
                    add(offset == 0 ? key : "\(key)-\(offset)", exercise, title, when, facts: restFacts, rest: true)
                }
                for content in row?.contents ?? [] {
                    switch content.kind {
                    case .stretch:
                        let name = content.text.isEmpty ? titled(content.pageID, "Stretch") : content.text
                        add(
                            "rest-content-\(content.id)", content.pageID, name, "Stretch · \(when)",
                            facts: [QuickPreviewFact(.stretch, "Stretch")] + restFacts, rest: true
                        )
                    case .note:
                        let text = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        add("rest-content-\(content.id)", nil, "Note", when, facts: restFacts, rest: true, note: text.isEmpty ? nil : text)
                    }
                }
            }

            if section.mode == .bundle {
                let rounds = section.bundleSets
                for (round, set) in rounds.enumerated() {
                    let prefix = "Round \(round + 1) of \(rounds.count)"
                    let roundFact = QuickPreviewFact(.round, prefix)
                    for (position, child) in set.children.enumerated() {
                        let effort = effortFact(child)
                        add("set-\(child.id)", child.exercisePageID, child.displayName,
                            "\(prefix) · \(position + 1) of \(set.children.count) · \(effort.text)",
                            facts: [roundFact, QuickPreviewFact(.position, "\(position + 1) of \(set.children.count)"), effort],
                            note: section.isCombo ? ComboCall.spoken(child.displayName) : nil)
                        for drop in child.drops {
                            add("drop-\(drop.id)", drop.exercisePageID, drop.name, "\(prefix) · drop set",
                                facts: [roundFact, QuickPreviewFact(.drop, "Drop set")])
                        }
                        addRest(row: child.restRow, exercises: child.restExercisePageIDs,
                                key: "rest-exercise-\(child.id.uuidString)", label: "Rest", seconds: child.playbackRest)
                    }
                    addRest(row: set.restRow, exercises: set.restExercisePageIDs,
                            key: "rest-exercise-\(set.id.uuidString)", label: "Rest after round \(round + 1)", seconds: set.playbackRest)
                }
            } else {
                let slots = section.effectiveSlots
                for (index, slot) in slots.enumerated() {
                    let prefix = "Set \(index + 1) of \(slots.count)"
                    let roundFact = QuickPreviewFact(.round, prefix)
                    let effort = effortFact(slot)
                    add("set-\(slot.id)", slot.exercisePageID, slot.displayName, "\(prefix) · \(effort.text)",
                        facts: [roundFact, effort], examples: examples(besides: slot.exercisePageID))
                    for drop in slot.drops {
                        add("drop-\(drop.id)", drop.exercisePageID, drop.name, "\(prefix) · drop set",
                            facts: [roundFact, QuickPreviewFact(.drop, "Drop set")])
                    }
                    addRest(row: slot.restRow, exercises: slot.restExercisePageIDs,
                            key: "rest-exercise-\(slot.id.uuidString)", label: "Rest after set \(index + 1)", seconds: slot.playbackRest)
                }
            }

            let big = section.bigRestRow
            addRest(row: big, exercises: big?.exercisePageIDs ?? [],
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
    @Published private(set) var gallerySelection = 0

    private var crossingTask: Task<Void, Never>?

    nonisolated init() {}

    var step: QuickPreviewStep? {
        isPresented && steps.indices.contains(index) ? steps[index] : nil
    }

    var canGoBack: Bool { isPresented && index > 0 }
    var canGoForward: Bool { isPresented && index + 1 < steps.count }

    func present(_ steps: [QuickPreviewStep], at index: Int, example: UUID? = nil) {
        guard steps.indices.contains(index) else { return }
        ClickThroughGuard.noteOpening()
        crossingTask?.cancel()
        crossing = nil
        direction = 1
        gallerySelection = example.flatMap { steps[index].examples.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        self.steps = steps
        self.index = index
        isPresented = true
        #if os(macOS)
        noteShown()
        #endif
    }

    func move(_ delta: Int) {
        let next = index + delta
        guard isPresented, steps.indices.contains(next) else { return }
        let crossed = steps[next].blockID != steps[index].blockID
        direction = delta >= 0 ? 1 : -1
        gallerySelection = 0
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

    func selectGallery(_ position: Int) {
        guard let step, position >= 0, position <= step.examples.count, position != gallerySelection else { return }
        gallerySelection = position
    }

    func close() {
        crossingTask?.cancel()
        if crossing != nil { crossing = nil }
        if isPresented { isPresented = false }
    }

    #if os(macOS)
    weak var hostWindow: NSWindow?

    private struct WeakController {
        weak var controller: QuickPreviewController?
    }

    private static var shown: [WeakController] = []

    /// Escape closes the quick preview on top in `window` before anything behind it hears the key.
    static func closeTopPreview(in window: NSWindow) -> Bool {
        shown.removeAll { $0.controller == nil || $0.controller?.isPresented != true }
        guard let top = shown.last(where: { $0.controller?.hostWindow === window })?.controller else { return false }
        top.close()
        return true
    }

    fileprivate func noteShown() {
        QuickPreviewController.shown.append(WeakController(controller: self))
    }
    #endif
}

/// Slides the old step out and the new one in from the side the user is moving towards. The direction is read when
/// the modifier is evaluated, so the leaving step follows the same way as the arriving one.
private struct QuickPreviewSlide: ViewModifier {
    let controller: QuickPreviewController
    let phase: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: phase * CGFloat(controller.direction) * 46)
            .scaleEffect(1 - abs(phase) * 0.05)
            .opacity(1 - abs(phase))
    }
}

/// Lays chips out in rows, wrapping to the next row when one is full.
private struct QuickPreviewFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), origins)
    }
}

struct QuickPreviewPopup: View {
    @ObservedObject var controller: QuickPreviewController
    let onOpen: (QuickPreviewOpen) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @State private var clipIndex = 0
    @State private var clipAspect: CGFloat = 16.0 / 9.0
    @State private var factsShownFor: String?
    private static let pictureHeightCap: CGFloat = 480
    private static let edgePadding: CGFloat = 20
    private static let switchSpring = Animation.spring(response: 0.4, dampingFraction: 0.82)
    private static let chipSpring = Animation.spring(response: 0.42, dampingFraction: 0.7)

    var body: some View {
        GeometryReader { proxy in
            let free = freeInsets(in: proxy)
            let room = max(
                260,
                proxy.size.height - free.top - free.bottom - Self.edgePadding * 2
            )
            ZStack {
                if let step = controller.step {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { controller.close() }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    card(step, room: room)
                        .padding(EdgeInsets(
                            top: Self.edgePadding + free.top,
                            leading: Self.edgePadding + free.leading,
                            bottom: Self.edgePadding + free.bottom,
                            trailing: Self.edgePadding + free.trailing
                        ))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .keyNavHost()
                        .accessibilityAddTraits(.isModal)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                        #if os(macOS)
                        .background {
                            QuickPreviewKeys(controller: controller, onStep: { move($0) }, onEscape: { controller.close() })
                                .frame(width: 0, height: 0)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        #endif
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: controller.isPresented)
        .onChange(of: controller.step?.id) { _ in clipIndex = 0 }
        .task(id: controller.step?.id) {
            factsShownFor = nil
            guard let id = controller.step?.id else { return }
            try? await Task.sleep(nanoseconds: 70_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : Self.chipSpring) { factsShownFor = id }
        }
    }

    /// The space the menu bar takes from each edge of the screen, so the card sits in the part left free.
    private func freeInsets(in proxy: GeometryProxy) -> EdgeInsets {
        guard let bounds = navigationBounds else { return EdgeInsets() }
        let frame = proxy.frame(in: .global)
        return EdgeInsets(
            top: max(0, bounds.minY - frame.minY),
            leading: max(0, bounds.minX - frame.minX),
            bottom: max(0, frame.maxY - bounds.maxY),
            trailing: max(0, frame.maxX - bounds.maxX)
        )
    }

    private func move(_ delta: Int) {
        withAnimation(reduceMotion ? nil : Self.switchSpring) { controller.move(delta) }
    }

    private func select(_ position: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
            controller.selectGallery(position)
            clipIndex = 0
        }
    }

    private var slideTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: QuickPreviewSlide(controller: controller, phase: 1),
                identity: QuickPreviewSlide(controller: controller, phase: 0)
            ),
            removal: .modifier(
                active: QuickPreviewSlide(controller: controller, phase: -1),
                identity: QuickPreviewSlide(controller: controller, phase: 0)
            )
        )
    }

    private func galleryIDs(_ step: QuickPreviewStep) -> [UUID] {
        guard let main = step.pageID else { return [] }
        return [main] + step.examples
    }

    private func card(_ step: QuickPreviewStep, room: CGFloat) -> some View {
        let gallery = galleryIDs(step)
        let selection = min(controller.gallerySelection, max(0, gallery.count - 1))
        let shownID = gallery.indices.contains(selection) ? gallery[selection] : step.pageID
        let page = shownID.flatMap { store.page(id: $0) }
        let clips = page.map(PageCoverOpening.clips(of:)) ?? []
        let clip = clips.indices.contains(clipIndex) ? clips[clipIndex] : clips.first
        return VStack(spacing: 0) {
            header(step)
            ZStack {
                stepContent(step, gallery: gallery, selection: selection, shownID: shownID, page: page, clips: clips, clip: clip)
                    .id(step.id)
                    .transition(slideTransition)
            }
            footer(page: page, clip: clip)
        }
        .frame(maxWidth: 780, maxHeight: room)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 32, y: 12)
    }

    private func stepContent(
        _ step: QuickPreviewStep,
        gallery: [UUID],
        selection: Int,
        shownID: UUID?,
        page: ExercisePage?,
        clips: [URL],
        clip: URL?
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                titles(step)
                media(step, shownID: shownID, page: page, clip: clip)
            }
            #if os(iOS)
            .simultaneousGesture(
                DragGesture(minimumDistance: 32).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    move(value.translation.width < 0 ? 1 : -1)
                }
            )
            #endif
            if gallery.count > 1 { galleryStrip(gallery: gallery, selection: selection) }
            if clips.count > 1 { clipChips(count: clips.count) }
        }
    }

    private func header(_ step: QuickPreviewStep) -> some View {
        HStack(spacing: 10) {
            blockChip(step)
            Spacer(minLength: 8)
            counterChip(step)
            Button { controller.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 36))
            .accessibilityLabel("Close preview")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func counterChip(_ step: QuickPreviewStep) -> some View {
        let tint = step.blockKind.tint
        return Text("\(controller.index + 1) / \(controller.steps.count)")
            .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(tint.opacity(0.16)))
            .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
            .contentTransition(.numericText())
            .accessibilityLabel("Step \(controller.index + 1) of \(controller.steps.count)")
    }

    private func blockChip(_ step: QuickPreviewStep) -> some View {
        let kind = step.blockKind
        return HStack(spacing: 6) {
            Image(systemName: kind.symbol)
            TmaxMarqueeText(
                kind == .library ? kind.title : "\(kind.title) · \(step.blockTitle)",
                font: TimeMasterFont.black(12, relativeTo: .caption),
                color: kind.tint,
                forceActive: true
            )
            if step.blockCount > 1 {
                Text("\(step.blockNumber)/\(step.blockCount)")
                    .monospacedDigit()
                    .opacity(0.7)
            }
        }
        .font(TimeMasterFont.black(12, relativeTo: .caption))
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(kind.tint.opacity(0.16)))
        .overlay(Capsule(style: .continuous).strokeBorder(kind.tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(step.blockTitle)")
    }

    private func titles(_ step: QuickPreviewStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TmaxFittingTitle(
                text: step.title,
                font: TimeMasterFont.black(20, relativeTo: .title3),
                color: Theme.textPrimary,
                lines: 2
            )
            if !step.facts.isEmpty {
                QuickPreviewFlow(spacing: 6) {
                    ForEach(Array(step.facts.enumerated()), id: \.offset) { position, fact in
                        factChip(fact, position: position, step: step)
                    }
                }
            } else if let detail = step.detail {
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([step.title, step.detail].compactMap { $0 }.joined(separator: ", "))
    }

    private func factChip(_ fact: QuickPreviewFact, position: Int, step: QuickPreviewStep) -> some View {
        let shown = factsShownFor == step.id
        let tint = fact.kind.tint
        return HStack(spacing: 4) {
            Image(systemName: fact.kind.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(fact.text)
        }
        .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.15)))
        .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown ? 1 : 0.6, anchor: .leading)
        .animation(reduceMotion ? nil : Self.chipSpring.delay(Double(position) * 0.06), value: shown)
    }

    private func media(_ step: QuickPreviewStep, shownID: UUID?, page: ExercisePage?, clip: URL?) -> some View {
        ZStack {
            Color.black
            Group {
                if let clip {
                    QuickPreviewVideo(url: clip, aspect: $clipAspect)
                        .id(clip)
                } else if step.blockKind == .combo {
                    comboCard(step)
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
            .id(shownID)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
        }
        .aspectRatio(clip == nil ? 16.0 / 9.0 : min(max(clipAspect, 1.0), 16.0 / 9.0), contentMode: .fit)
        .frame(maxHeight: Self.pictureHeightCap)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: clipAspect)
        .overlay(alignment: .top) { crossingBanner }
    }

    private func comboCard(_ step: QuickPreviewStep) -> some View {
        let tokens = ComboCall.tokens(in: step.title)
        return ZStack {
            ComboStyle.gradient
            VStack(spacing: 12) {
                ComboCallChip(tokens: tokens.isEmpty ? ComboCall.defaultCall : tokens)
                    .scaleEffect(1.35)
                    .padding(.vertical, 10)
                Text(step.note ?? "")
                    .font(TimeMasterFont.black(16, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private var crossingBanner: some View {
        if let crossing = controller.crossing {
            HStack(spacing: 8) {
                Image(systemName: crossing.blockKind.symbol)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Now in \(crossing.blockKind.title.lowercased())")
                        .font(TimeMasterFont.caption())
                    TmaxMarqueeText(crossing.blockTitle, font: TimeMasterFont.black(15, relativeTo: .subheadline), forceActive: true)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(crossing.blockKind.tint.opacity(0.7), lineWidth: 1.5))
            .padding(.top, 12)
            .padding(.horizontal, 12)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    private func galleryStrip(gallery: [UUID], selection: Int) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(gallery.enumerated()), id: \.offset) { position, pageID in
                        galleryTile(pageID, position: position, selected: position == selection, total: gallery.count)
                            .id(position)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: selection) { value in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { reader.scrollTo(value, anchor: .center) }
            }
        }
    }

    private func galleryTile(_ pageID: UUID, position: Int, selected: Bool, total: Int) -> some View {
        let title = store.page(id: pageID)?.title ?? "Example"
        let tint = Theme.toolbarOrange
        return Button { select(position) } label: {
            VStack(spacing: 5) {
                BundlePageThumbnail(pageID: pageID, size: 60, fallbackIcon: "photo.on.rectangle.angled")
                    .overlay(
                        RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(60), style: .continuous)
                            .strokeBorder(selected ? tint : Color.white.opacity(0.1), lineWidth: selected ? 2.5 : 1)
                    )
                    .scaleEffect(selected ? 1 : 0.92)
                    .opacity(selected ? 1 : 0.72)
                TmaxMarqueeText(
                    title,
                    font: TimeMasterFont.black(10, relativeTo: .caption2),
                    color: selected ? Theme.textPrimary : Theme.textSecondary,
                    forceActive: selected
                )
                .frame(width: 66)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(position == 0 ? "Main exercise, \(title)" : "Example \(position) of \(total - 1), \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func clipChips(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { position in
                let selected = position == clipIndex
                Button { clipIndex = position } label: {
                    Text("\(position + 1)")
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        .monospacedDigit()
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: selected, circular: true, minimumSize: 34))
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
                    TmaxMenu {
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
    let controller: QuickPreviewController
    let onStep: (Int) -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.controller = controller
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
        weak var controller: QuickPreviewController?
        var onStep: ((Int) -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            MainActor.assumeIsolated { controller?.hostWindow = window }
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
