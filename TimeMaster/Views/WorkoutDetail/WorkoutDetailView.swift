import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WorkoutDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore
    @EnvironmentObject private var musicLibrary: MusicLibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.slotNavigationContentBounds) private var navigationBounds
    @Environment(\.dismiss) private var dismiss
    @Environment(\.workoutPageHeroPresenter) private var heroPresenter
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: Section?
    @State private var playerWorkout: Workout?
    @State private var showingWorkoutSettings = false
    @State private var mediaPreviewSection: Section? = nil
    @State private var heroPage: WorkoutPageHeroRequest?
    @State private var quickPreview = QuickPreviewController()
    @State private var heroSources = WorkoutHeroSources()
    @State private var chrome = WorkoutEditorChromeState()
    @State private var durationEdit: DurationEditTarget?
    @State private var expandedRestRowIDs: Set<UUID> = []
    @State private var noteEditTarget: RestNoteTarget?
    @State private var showBrowserSheet = false
    @State private var showingSavedWorkoutPicker = false
    @State private var browserStartsInBundleMode = false
    @State private var bundleToEdit: Section?
    @State private var showingNewBundle = false
    @State private var editorControlsExpanded = false
    @State private var summaryCompletedSessionCount = 0
    @State private var pendingScrollTargetID: RowID?
    @State private var sectionIDs: [UUID] = []
    @State private var musicConfigurationOpen = false
    @GestureState private var musicRevealDrag: CGFloat = 0
    @State private var highlightedRowID: RowID?
    @State private var pendingScrollAnchor: UnitPoint = .bottom
    @State private var previewFocusRow: RowID?
    @State private var pendingScrollDelay: Double = 0

    let workoutID: UUID
    let liveContext: WorkoutLiveContext?
    let onClose: (() -> Void)?
    @State private var pendingSection: PendingSectionConfig?
    @State private var expandedSectionIDs: Set<UUID> = []
    @State private var draggedSlotID: UUID?
    @State private var draggedSectionID: UUID?
    @State private var browserTarget: BuilderBrowserTarget = .newSection
    @ScaledMetric(relativeTo: .body) private var expandedSummaryCover: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var compactSummaryCover: CGFloat = 32

    private enum RowID: Hashable {
        case header
        case summary
        case empty
        case end
        case pending
        case section(UUID)
        case bundleSet(UUID)
        case preparation(UUID)
        case set(UUID)
        case drop(UUID)
        case dropRest(UUID)
        case slotRest(UUID)
        case bigRest(UUID)
        case example(UUID, UUID)
        case restExercise(UUID, UUID)
        case restEmpty(UUID)
        case restContent(UUID, UUID)
    }

    private enum BuilderRowKind {
        case preparation(SetSlot)
        case set(SetSlot, Int)
        case drop(SetSlot, DropSet)
        case rest(RestRow, RestTarget)
        case restExercise(RestTarget, UUID)
        case restEmpty(RestTarget)
        case restContent(RestTarget, RestContent)
        case bundleSet(SetSlot, Int)
        case bundleChild(SetSlot, Int, Int)
        case example(UUID)
    }

    /// One row under a section's head, with its place on the section's rail and card.
    private struct BuilderRowItem: Identifiable {
        let id: RowID
        let kind: BuilderRowKind
        let level: Int
        var progress: Double = 0
        var rail = BuilderRail()
        var slice: BuilderSlice = .middle
    }

    private var editorAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9)
    }

    private var disclosureAnimation: Animation? {
        reduceMotion ? nil : EverMotion.disclosure
    }

    private var rowTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: -6)), removal: .opacity)
    }

    private func animateEditor(_ changes: () -> Void) {
        withAnimation(editorAnimation, changes)
    }

    private var browsingForExamples: Bool {
        if case .addExamples = browserTarget { return true }
        return false
    }

    private var workout: Workout {
        store.workout(id: workoutID) ?? Workout(name: "")
    }

    init(workout: Workout, liveContext: WorkoutLiveContext? = nil, onClose: (() -> Void)? = nil) {
        workoutID = workout.id
        self.liveContext = liveContext
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { proxy in
            let visibleHeight = navigationBounds.map {
                min(proxy.size.height, max(0, $0.maxY - proxy.frame(in: .global).minY))
            } ?? proxy.size.height
            let reveal = min(1, max(0, (musicConfigurationOpen ? 1 : 0) + musicRevealDrag))
            let editorPeek = proxy.size.width * 0.18
            let slideDistance = proxy.size.width - editorPeek
            ZStack(alignment: .topLeading) {
                if reveal > 0 {
                    WorkoutMusicTimelineView(
                        workout: workout,
                        library: musicLibrary,
                        onChange: { configuration in
                            var updated = workout
                            updated.musicTimeline = configuration
                            store.updateWorkout(updated)
                        },
                        onClose: { setMusicConfigurationOpen(false) }
                    )
                    .padding(.leading, editorPeek + 6)
                    .frame(height: visibleHeight)
                    .accessibilityHidden(!musicConfigurationOpen)
                }

                VStack(spacing: 0) {
                    if liveContext != nil {
                        WorkoutAttachmentStrip(workout: workout, liveContext: liveContext)
                    }
                    sectionList(width: proxy.size.width)
                    if !workout.sections.isEmpty && liveContext == nil {
                        startButton
                    }
                }
                .frame(height: visibleHeight, alignment: .top)
                .frame(width: proxy.size.width)
                .background(Theme.background)
                .allowsHitTesting(!musicConfigurationOpen && heroPage == nil)
                .offset(x: -slideDistance * reveal)
                .zIndex(1)
                .accessibilityHidden(musicConfigurationOpen || heroPage != nil)
                if musicConfigurationOpen {
                    Color.clear
                        .frame(width: editorPeek, height: visibleHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { setMusicConfigurationOpen(false) }
                        .gesture(musicRevealGesture(distance: slideDistance))
                        .accessibilityLabel("Return to workout editor")
                        .accessibilityAddTraits(.isButton)
                        .zIndex(2)
                }

                if !musicConfigurationOpen && heroPage == nil {
                    Color.clear
                        .frame(width: min(24, proxy.size.width * 0.06), height: visibleHeight)
                        .contentShape(Rectangle())
                        .gesture(musicRevealGesture(distance: slideDistance))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .zIndex(2)
                        .accessibilityHidden(true)
                }

                if let heroPage, heroPresenter == nil {
                    pageHero(heroPage)
                        .frame(width: proxy.size.width, height: visibleHeight)
                        .zIndex(3)
                }
            }
            .clipped()
            .animation(editorAnimation, value: musicConfigurationOpen)
        }
        .font(TimeMasterFont.body())
        .background(Theme.background.ignoresSafeArea())
        .quickPreviewHost(quickPreview) { openPreviewed($0) }
        .onReceive(quickPreview.$index) { index in
            guard quickPreview.isPresented else { return }
            followPreview(stepAt: index)
        }
        .onReceive(quickPreview.$isPresented) { presented in
            if presented {
                followPreview(stepAt: quickPreview.index)
            } else {
                settlePreview()
            }
        }
        .modifier(WorkoutFloatingControlsOverlay(
            workoutName: workout.name,
            context: heroPage == nil ? liveContext : nil,
            library: musicLibrary
        ))
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .slotNavigationPresentation(.visible)
        .slotNavigationPrefersStrip()
        .slotNavigationInteractionDisabled(musicConfigurationOpen || musicRevealDrag > 0.02 || heroPage != nil)
        .everEscapeClaim("workout-music", isActive: musicConfigurationOpen) { setMusicConfigurationOpen(false) }
        .preference(key: SlotNavigationEditingPreferenceKey.self, value: true)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .oneHandedActions(
            id: "workout-detail-\(workoutID.uuidString)",
            actions: musicConfigurationOpen || musicRevealDrag > 0 || heroPage != nil ? [] : oneHandedActions
        )
        .onAppear {
            PerfLog.event("workout builder appeared")
            materializeImplicitSlots()
            sectionIDs = workout.sections.map(\.id)
        }
        .onDisappear { PerfLog.event("workout builder disappeared") }
        .onChange(of: workout.sections.count) { _ in
            sectionIDs = workout.sections.map(\.id)
        }
        .onReceive(store.$historyEntries) { entries in
            summaryCompletedSessionCount = entries.reduce(into: 0) { count, entry in
                if entry.workoutId == workoutID { count += 1 }
            }
        }
        .workoutPlayerPage(item: $playerWorkout) { playingWorkout in
            WorkoutPlayerView(workout: playingWorkout)
                .environmentObject(store)
                .environmentObject(DatabaseStore.shared)
        }

        .alert("Delete Section", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { sectionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let section = sectionToDelete {
                    animateEditor {
                        store.deleteSection(in: workout, section: section)
                        sectionIDs = workout.sections.map(\.id)
                        expandedSectionIDs.remove(section.id)
                    }
                }
                sectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this section?")
        }
        .sheet(item: $mediaPreviewSection) { section in
            MediaPreviewSheet(items: section.mediaItems, workout: workout, liveContext: liveContext)
                .environmentObject(databaseStore)
                .environmentObject(store)
        }
        .sheet(item: $durationEdit) { target in
            DurationEditorSheet(
                title: target.title,
                seconds: target.seconds,
                isTimerEnabled: target.isTimerEnabled,
                onSave: { seconds, isTimerEnabled in
                    updateDuration(target, seconds: seconds, isTimerEnabled: isTimerEnabled)
                }
            )
        }
        .sheet(item: $noteEditTarget) { target in
            RestNoteEditorSheet(
                initialText: target.text,
                onSave: { text in
                    updateRestContent(target, content: RestContent(
                        id: target.contentID ?? UUID(),
                        kind: .note,
                        text: text
                    ))
                }
            )
        }
        .sheet(isPresented: $showingWorkoutSettings) {
            WorkoutSettingsView(workoutID: workoutID, store: store)
        }
        .sheet(item: $bundleToEdit) { section in
            BundleEditorSheet(section: section) { updated in
                store.updateSection(in: workout, section: updated)
            }
        }
        .sheet(isPresented: $showingNewBundle) {
            BundleEditorSheet { section in
                store.addSection(to: workout, section: section)
                sectionIDs = workout.sections.map(\.id)
                expandedSectionIDs.insert(section.id)
            }
        }
        .sheet(isPresented: $showBrowserSheet) {
            DatabasePageBrowserSheet(
                workout: workout,

                onAdd: { page, dur, sets, reps, restAfter, restBetween, prepareTime in
                    handlePageSelection(
                        page,
                        duration: dur,
                        sets: sets,
                        reps: reps,
                        restAfter: restAfter,
                        restBetween: restBetween,
                        prepareTime: prepareTime
                    )
                },
                onAddBundle: { sources, dur, sets, reps, restAfter, restBetween, prepareTime in
                    guard !sources.isEmpty else { return }
                    if case .addExamples(let sectionID) = browserTarget {
                        showBrowserSheet = false
                        addExamples(sources.compactMap(\.pageID), to: sectionID)
                        return
                    }
                    guard case .newSection = browserTarget else { return }
                    showBrowserSheet = false
                    animateEditor {
                        pendingSection = PendingSectionConfig(
                        name: "Bundle: \(sources.map(\.title).joined(separator: ", "))",
                        pageID: sources.first?.pageID,
                        sourcePages: sources.compactMap { source in
                            if case .page(let page) = source { return page }
                            return nil
                        },
                        bundleSources: sources,
                        duration: dur,
                        sets: sets,
                        repCount: reps > 0 ? reps : nil,
                        restAfter: restAfter,
                        restBetweenSets: restBetween,
                        prepareTime: prepareTime,
                        mode: .bundle
                    )
                    }
                },
                onNewExercise: nil,
                initialBundleMode: browserStartsInBundleMode,
                maxExerciseSeconds: restExerciseLimit(for: browserTarget),
                examplesMode: browsingForExamples
            )
            .environmentObject(databaseStore)
            .environmentObject(store)
            .onDisappear {
                browserStartsInBundleMode = false
            }
        }
        .sheet(isPresented: $showingSavedWorkoutPicker) {
            SavedWorkoutPickerSheet(excludingWorkoutID: workoutID) { savedWorkout in
                addSavedWorkoutSection(savedWorkout)
            }
            .environmentObject(store)
        }
        .macWindowTitle(workout.name)
        .macWindowTitleHidden()
    }

    private func setMusicConfigurationOpen(_ open: Bool) {
        guard musicConfigurationOpen != open else { return }
        musicEditorHaptic()
        animateEditor { musicConfigurationOpen = open }
    }

    private func musicRevealGesture(distance: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($musicRevealDrag) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                state = -value.translation.width / max(1, distance)
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                let projected = -value.predictedEndTranslation.width / max(1, distance)
                setMusicConfigurationOpen(musicConfigurationOpen ? projected > -0.3 : projected > 0.3)
            }
    }

    // MARK: - Sub-views

    private func heroCover(for request: WorkoutPageHeroRequest) -> WorkoutHeroCover {
        let page = databaseStore.page(id: request.pageID)
        return WorkoutHeroCover(
            url: page?.coverImageURL,
            fallbackIcon: page?.effectiveWorkoutType?.iconName ?? request.fallbackIcon,
            fallbackColor: page?.effectiveWorkoutType.map { Color(hex: $0.colorHex) }
        )
    }

    private func heroContent(for request: WorkoutPageHeroRequest, close: @escaping () -> Void) -> some View {
        WorkoutAttachmentBrowser(workout: workout, pageID: request.pageID, liveContext: liveContext, onClose: close)
            .environment(\.appToolbarInline, true)
            .environmentObject(databaseStore)
            .environmentObject(store)
    }

    /// The page over the builder where no Workouts page draws it (the player's own page).
    private func pageHero(_ request: WorkoutPageHeroRequest) -> some View {
        WorkoutPageHero(
            request: request,
            sources: heroSources,
            cover: heroCover(for: request),
            onFinished: {
                if heroPage?.id == request.id { heroPage = nil }
            }
        ) { close in
            heroContent(for: request, close: close)
        }
        .id(request.id)
    }

    /// Opens a page over the builder, growing out of the cover registered under `key` when it is on screen. Inside the
    /// Workouts page it draws the page outside the navigation stack the builder was pushed on.
    private func openPage(_ pageID: UUID?, from key: String?, fallbackIcon: String) {
        guard let pageID, heroPage == nil else { return }
        let request = WorkoutPageHeroRequest(
            pageID: pageID,
            sourceKey: key,
            sourceFrame: heroSources.frame(for: key),
            fallbackIcon: fallbackIcon
        )
        heroPage = request
        heroPresenter?.present(WorkoutPageHeroPresentation(
            request: request,
            windowTitle: workout.name,
            sources: heroSources,
            cover: heroCover(for: request),
            content: { close in AnyView(heroContent(for: request, close: close)) },
            onFinished: {
                if heroPage?.id == request.id { heroPage = nil }
            }
        ))
    }

    private func openAction(_ pageID: UUID?, key: String, fallbackIcon: String) -> (() -> Void)? {
        guard let pageID else { return nil }
        return { openPage(pageID, from: key, fallbackIcon: fallbackIcon) }
    }

    private func previewPage(_ pageID: UUID?, key: String?, sectionID: UUID? = nil, fallbackIcon: String) {
        guard let pageID else { return }
        let steps = QuickPreviewSteps.steps(for: workout) { databaseStore.page(id: $0) }
        guard let index = QuickPreviewSteps.index(of: key, pageID: pageID, blockID: sectionID?.uuidString, in: steps) else {
            openPage(pageID, from: key, fallbackIcon: fallbackIcon)
            return
        }
        quickPreview.present(steps, at: index)
    }

    private func followPreview(stepAt index: Int) {
        let steps = quickPreview.steps
        guard steps.indices.contains(index) else { return }
        let step = steps[index]
        guard let sectionID = UUID(uuidString: step.blockID),
              let section = workout.sections.first(where: { $0.id == sectionID }) else { return }
        let target = previewTarget(for: step, in: section)
        previewFocusRow = target.row
        let needsOpening = !expandedSectionIDs.contains(sectionID)
            || target.rest.map { !expandedRestRowIDs.contains($0) } == true
        withAnimation(disclosureAnimation) {
            expandedSectionIDs.insert(sectionID)
            if let restID = target.rest { expandedRestRowIDs.insert(restID) }
        }
        pendingScrollAnchor = .center
        pendingScrollDelay = needsOpening ? 0.22 : 0
        pendingScrollTargetID = target.row
    }

    private func settlePreview() {
        guard let row = previewFocusRow else { return }
        previewFocusRow = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { highlightedRowID = row }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard highlightedRowID == row else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { highlightedRowID = nil }
        }
    }

    private func previewTarget(for step: QuickPreviewStep, in section: Section) -> (row: RowID, rest: UUID?) {
        func owner(after prefix: String) -> UUID? {
            guard step.id.hasPrefix(prefix) else { return nil }
            return UUID(uuidString: String(step.id.dropFirst(prefix.count).prefix(36)))
        }
        let isBundle = section.mode == .bundle
        if let slotID = owner(after: "set-") { return (.set(slotID), nil) }
        if let dropID = owner(after: "drop-") {
            if isBundle,
               let child = section.bundleSets.flatMap(\.children).first(where: { child in child.drops.contains { $0.id == dropID } }) {
                return (.set(child.id), nil)
            }
            return (.drop(dropID), nil)
        }
        if let ownerID = owner(after: "rest-exercise-") {
            if ownerID == section.id && isBundle { return (.bigRest(section.id), nil) }
            if isBundle {
                let isChild = section.bundleSets.contains { set in set.children.contains { $0.id == ownerID } }
                return (isChild ? .set(ownerID) : .bundleSet(ownerID), nil)
            }
            let target = ownerID == section.id
                ? RestTarget(sectionID: section.id, slotID: nil, isBig: true)
                : RestTarget(sectionID: section.id, slotID: ownerID, isBig: false)
            if let restID = restRowID(for: target), let pageID = step.pageID {
                return (.restExercise(restID, pageID), restID)
            }
            return (.section(section.id), nil)
        }
        if let contentID = owner(after: "rest-content-"), !isBundle {
            let rows = section.effectiveSlots.compactMap(\.restRow) + [section.bigRestRow].compactMap { $0 }
            if let row = rows.first(where: { row in row.contents.contains { $0.id == contentID } }) {
                return (.restContent(row.id, contentID), row.id)
            }
        }
        return (.section(section.id), nil)
    }

    private func openPreviewed(_ request: QuickPreviewOpen) {
        if let tab = request.tab {
            PageTabMemory.remember(tab, for: request.pageID.uuidString)
        } else if let clip = request.clip, let page = databaseStore.page(id: request.pageID) {
            PageCoverOpening.prepare(page, playing: clip)
        }
        openPage(request.pageID, from: nil, fallbackIcon: "figure.run")
    }

    private var emptySectionsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                .accessibilityHidden(true)
            Text("No Sections Yet")
                .font(TimeMasterFont.black(22, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
            Text("Exercises define the structure of your workout.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(spacing: 10) {
                Button {
                    openBrowser(.newSection)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add First Exercise")
                    }
                    .font(TimeMasterFont.black(17, relativeTo: .headline))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
            }
            .frame(maxWidth: 320)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDescription: String {
        let current = workout
        let setCount = current.sections.reduce(0) { $0 + $1.slotCount }
        return "\(current.type.name), \(current.name), \(current.sectionCount) sections, " +
            "\(setCount) sets, \(formatCompactDuration(current.totalDuration)) duration, " +
            "\(summaryCompletedSessionCount) completed"
    }

    private var workoutSummary: some View {
        let current = workout
        let setCount = current.sections.reduce(0) { $0 + $1.slotCount }
        let duration = formatCompactDuration(current.totalDuration)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                WorkoutCoverMosaic(
                    workout: current,
                    size: expandedSummaryCover,
                    styleOverride: .exerciseThumbnails
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.type.name)
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .foregroundStyle(Theme.textSecondary)
                    TmaxFittingTitle(
                        text: current.name,
                        font: TimeMasterFont.black(17, relativeTo: .headline),
                        color: Theme.textPrimary,
                        lines: 2
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 0) {
                detailMetric(icon: "figure.strengthtraining.traditional", value: "\(current.sectionCount)", label: "sections")
                metricDivider
                detailMetric(icon: "repeat", value: "\(setCount)", label: "sets")
                metricDivider
                detailMetric(icon: "clock.fill", value: duration, label: "duration")
                metricDivider
                detailMetric(icon: "checkmark.circle.fill", value: "\(summaryCompletedSessionCount)", label: "completed")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(cornerRadius: BuilderMetrics.cardRadius, flat: true))
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryDescription)
    }

    /// The summary pinned over the top of the list once the full card has scrolled away; a tap scrolls back up.
    private func compactSummaryBar(onTap: @escaping () -> Void) -> some View {
        let current = workout
        let setCount = current.sections.reduce(0) { $0 + $1.slotCount }
        let duration = formatCompactDuration(current.totalDuration)

        return HStack(spacing: 10) {
            editorBackButton(diameter: 36)
            Button(action: onTap) {
                HStack(spacing: 10) {
                    WorkoutCoverMosaic(workout: current, size: compactSummaryCover, styleOverride: .exerciseThumbnails)
                    VStack(alignment: .leading, spacing: 2) {
                        TmaxMarqueeText(current.name, font: TimeMasterFont.black(15, relativeTo: .subheadline), color: Theme.textPrimary)
                        TmaxMarqueeText(
                            "\(current.sectionCount) sections · \(setCount) sets · \(duration) · \(summaryCompletedSessionCount) completed",
                            font: TimeMasterFont.caption().monospacedDigit(),
                            color: Theme.textSecondary
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summaryDescription)
            .accessibilityHint("Scrolls back to the top of the workout")
        }
        .padding(.vertical, 8)
        .builderColumn()
        .background {
            Theme.background
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.separator).frame(height: 1)
                }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Theme.background.opacity(0.85), Theme.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 14)
            .offset(y: 14)
            .allowsHitTesting(false)
        }
        .keyNavObstruction()
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 10)
    }

    private func detailMetric(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
                TmaxMarqueeText(value, font: TimeMasterFont.black(17, relativeTo: .headline).monospacedDigit(), color: Theme.textPrimary)
            }
            TmaxMarqueeText(label, font: TimeMasterFont.micro(), color: Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editorHeader(width: CGFloat) -> some View {
        let metrics = ScrollingChromeMetrics(
            width: width, horizontalPadding: 0, compactControlSize: 48,
            controlSpacing: 4, controlCount: 3
        )
        let progress: CGFloat = editorControlsExpanded ? 0 : 1
        let morph = metrics.morph(progress)
        let diameter = metrics.controlWidth(morph)

        return ScrollingChromeHeader(
            title: workout.name,
            progress: morph,
            metrics: metrics,
            leadingControlWidth: metrics.compactControlSize
        ) {
            editorHeaderControls(progress: morph, diameter: diameter)
        }
        .environment(\.scrollingChromeSetExpanded) { expanded in
            setControlsExpanded(expanded)
        }
        .overlay(alignment: .topLeading) {
            editorBackButton(diameter: metrics.compactControlSize)
                .padding(.top, 4)
                .oneHandedActionSource()
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        #if os(iOS)
        .accessibilityAction(named: "Expand page actions") { setControlsExpanded(true) }
        .accessibilityAction(named: "Collapse page actions") { setControlsExpanded(false) }
        #endif
    }

    private var oneHandedActions: [ReachabilityAction] {
        [
            ReachabilityAction("back", title: "Back to workouts") {
                editorBackButton(diameter: 48)
            },
            ReachabilityAction("add", title: "Add exercise from the database") {
                editorAddButton(progress: 1, diameter: 48)
            },
            ReachabilityAction("more", title: "Workout actions", dismissesOnActivation: false) {
                editorActionsMenu(progress: 1, diameter: 48)
            },
            ReachabilityAction("music", title: "Music") {
                editorMusicButton(progress: 1, diameter: 48)
            },
            ReachabilityAction("settings", title: "Workout Settings") {
                Button { showingWorkoutSettings = true } label: {
                    editorHeaderIcon("slider.horizontal.3", diameter: 48, title: "Settings")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityLabel("Workout Settings")
            }
        ]
    }

    private func editorHeaderControls(progress: CGFloat, diameter: CGFloat) -> some View {
        HStack(spacing: 4) {
            editorAddButton(progress: progress, diameter: diameter)
            editorActionsMenu(progress: progress, diameter: diameter)
            editorMusicButton(progress: progress, diameter: diameter)
        }
    }

    private func editorBackButton(diameter: CGFloat) -> some View {
        Button { if let onClose { onClose() } else { dismiss() } } label: {
            editorHeaderIcon("chevron.left", diameter: diameter)
        }
        .buttonStyle(ScrollingChromeButtonStyle(progress: 1, width: diameter, height: diameter))
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Back to workouts")
    }

    private func editorMusicButton(progress: CGFloat, diameter: CGFloat) -> some View {
        Button { setMusicConfigurationOpen(true) } label: {
            editorHeaderIcon("music.note.list", diameter: diameter, title: "Music", progress: progress)
        }
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: diameter, height: diameter))
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Configure workout music")
    }

    private func editorActionsMenu(progress: CGFloat, diameter: CGFloat) -> some View {
        TmaxMenu { editorActionMenuItems } label: {
            editorHeaderIcon("ellipsis", diameter: diameter, title: "More", progress: progress)
        }
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: diameter, height: diameter))
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Workout actions")
    }

    private func editorAddButton(progress: CGFloat, diameter: CGFloat) -> some View {
        Button { openBrowser(.newSection) } label: {
            editorHeaderIcon("plus", diameter: diameter, title: "Add", progress: progress)
        }
        .buttonStyle(ScrollingChromeButtonStyle(progress: progress, width: diameter, height: diameter))
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Add exercise from the database")
    }

    private func editorHeaderIcon(_ name: String, diameter: CGFloat, title: String = "", progress: CGFloat = 1) -> some View {
        ScrollingChromeControl(
            systemImage: name, title: title, progress: progress,
            width: diameter, height: diameter
        )
        .frame(width: diameter, height: diameter)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var editorActionMenuItems: some View {
        Button { handleAddContentType(.bundle) } label: {
            Label("Add Bundle", systemImage: "rectangle.stack.fill")
        }
        Button { handleAddContentType(.combo) } label: {
            Label("Add Combo", systemImage: "figure.boxing")
        }
        Button { handleAddContentType(.workout) } label: {
            Label("Add Saved Workout", systemImage: "figure.strengthtraining.traditional")
        }
        Button { handleAddContentType(.bike) } label: {
            Label("Add Bike Section", systemImage: "bicycle")
        }
        Button { handleAddContentType(.runWalk) } label: {
            Label("Add Walk & Run Section", systemImage: "figure.run")
        }
        Divider()
        Button { showingWorkoutSettings = true } label: {
            Label("Workout Settings", systemImage: "slider.horizontal.3")
        }
        Button { store.cloneWorkout(workout) } label: {
            Label("Clone Workout", systemImage: "doc.on.doc")
        }
        Button(role: .destructive) { store.deleteWorkout(workout) } label: {
            Label("Delete Workout", systemImage: "trash")
        }
    }

    private func sectionList(width: CGFloat) -> some View {
        let column = min(BuilderMetrics.columnWidth, max(0, width - BuilderMetrics.pageInset * 2))
        return ScrollViewReader { proxy in
            editorScroll(column: column)
                .coordinateSpace(name: workoutDetailScrollSpace)
                .environment(\.workoutHeroSources, heroSources)
                .overlay(alignment: .top) {
                    WorkoutCompactSummaryOverlay(state: chrome, isEnabled: !workout.sections.isEmpty) {
                        compactSummaryBar {
                            withAnimation(reduceMotion ? nil : EverMotion.state) {
                                proxy.scrollTo(RowID.header, anchor: .top)
                            }
                        }
                    }
                }
                .task(id: pendingScrollTargetID) {
                    guard let targetID = pendingScrollTargetID else { return }
                    await Task.yield()
                    if pendingScrollDelay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(pendingScrollDelay * 1_000_000_000))
                    }
                    guard !Task.isCancelled else { return }
                    withAnimation(editorAnimation) {
                        proxy.scrollTo(targetID, anchor: pendingScrollAnchor)
                    }
                    if pendingScrollTargetID == targetID {
                        pendingScrollTargetID = nil
                        pendingScrollDelay = 0
                        pendingScrollAnchor = .bottom
                    }
                }
        }
    }

    /// The builder scrolls in a list on iPhone and iPad (swipe actions, long-press reordering) and in a lazy stack on
    /// the Mac, where a list is a table view that cannot animate rows smoothly.
    @ViewBuilder
    private func editorScroll(column: CGFloat) -> some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(spacing: 0) {
                editorRows(column: column)
            }
            .scrollingChromeScrollProbe(in: workoutDetailScrollSpace, editorDidScroll)
        }
        .scrollingChromeScrollReader(editorDidScroll)
        #else
        List {
            editorRows(column: column)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollingChromeScrollReader(editorDidScroll)
        #endif
    }

    @ViewBuilder
    private func editorRows(column: CGFloat) -> some View {
        editorHeader(width: column)
            .padding(.top, 8)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                chrome.headerHeight = height
            }
            #if os(iOS)
            .scrollingChromeScrollProbe(in: workoutDetailScrollSpace, editorDidScroll)
            #endif
            .builderPageRow()
            .id(RowID.header)
            .listRowBackground(Theme.background)

        if !workout.sections.isEmpty {
            workoutSummary
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    chrome.summaryHeight = height
                }
                #if os(iOS)
                .scrollingChromeScrollProbe(in: workoutDetailScrollSpace, editorDidScroll)
                #endif
                .builderPageRow()
                .id(RowID.summary)
                .listRowBackground(Theme.background)
        }

        if workout.sections.isEmpty && pendingSection == nil {
            emptySectionsView
                .padding(.vertical, 32)
                .builderPageRow()
                .id(RowID.empty)
        }

        if let pending = pendingSection {
            pendingConfigCard(pending)
                .padding(.vertical, 6)
                .builderPageRow()
                .id(RowID.pending)
                .transition(rowTransition)
        }

        ForEach(sectionIDs, id: \.self) { id in
            if let section = workout.sections.first(where: { $0.id == id }) {
                sectionGroup(section)
            }
        }
        .onMove(perform: moveSections)

        Color.clear
            .frame(height: 28)
            .builderPageRow()
            .id(RowID.end)
            .accessibilityHidden(true)
    }

    /// A section as one card: its head, the rows of an expanded section and its big rest, tied by the rail.
    @ViewBuilder
    private func sectionGroup(_ section: Section) -> some View {
        let isExpanded = expandedSectionIDs.contains(section.id)
        let items = groupItems(for: section, isExpanded: isExpanded)
        let head = BuilderRail(
            level: 0,
            continuesBelow: items.first.map { !$0.rail.breaksRail } ?? false,
            live: liveContext != nil,
            fill: liveValue(section, phase: .active)
        )
        #if os(macOS)
        VStack(spacing: 0) {
            sectionHeaderRow(section, isExpanded: isExpanded, rail: head, slice: items.isEmpty ? .single : .top)
            ForEach(items) { item in
                builderRow(item, in: section)
                    .transition(rowTransition)
            }
        }
        .builderGroupSurface()
        .padding(.top, BuilderMetrics.groupSpacing)
        .builderPageRow()
        #else
        sectionHeaderRow(section, isExpanded: isExpanded, rail: head, slice: items.isEmpty ? .single : .top)
        ForEach(items) { item in
            builderRow(item, in: section)
        }
        #endif
    }

    private func rowSlice(_ slice: BuilderSlice) -> BuilderSlice? {
        #if os(macOS)
        return nil
        #else
        return slice
        #endif
    }

    private func rowChrome(_ item: BuilderRowItem) -> BuilderRowChrome {
        BuilderRowChrome(
            rail: item.rail,
            slice: rowSlice(item.slice),
            vertical: BuilderMetrics.rowVertical(item.level),
            pulse: highlightedRowID == item.id
        )
    }

    private func liveRing(_ item: BuilderRowItem) -> Double? {
        liveContext == nil ? nil : item.progress
    }

    private func liveValue(_ section: Section, slot: SetSlot? = nil, phase: WorkoutPhase) -> Double {
        liveContext == nil ? 0 : liveFraction(section: section, slot: slot, phase: phase)
    }

    private func liveFraction(section: Section, slot: SetSlot? = nil, phase: WorkoutPhase) -> Double {
        guard let live = liveContext?.progress,
              let currentIndex = workout.sections.firstIndex(where: { $0.id == live.sectionID }),
              let index = workout.sections.firstIndex(where: { $0.id == section.id }) else { return 0 }
        if index < currentIndex { return 1 }
        if index > currentIndex || live.phase == .warmUp { return 0 }
        if live.phase == .sectionRest { return phase == .sectionRest ? live.fraction : 1 }
        if phase == .sectionRest { return 0 }
        let slots = section.playbackSlots()
        guard let currentSlot = slots.firstIndex(where: { $0.id == live.slotID }) else { return 0 }
        guard let slot else {
            var completed = 0.0
            var total = 0.0
            for (index, value) in slots.enumerated() {
                let preparation = Double(section.preparationTime(for: value))
                let work = Double(value.duration)
                let rest = index + 1 < slots.count ? Double(value.restAfter) : 0
                let duration = preparation + work + rest
                total += duration
                if index < currentSlot { completed += duration }
                else if index == currentSlot {
                    switch live.phase {
                    case .prepare: completed += preparation * live.fraction
                    case .active: completed += preparation + work * live.fraction
                    case .setRest: completed += preparation + work + rest * live.fraction
                    case .warmUp, .sectionRest: break
                    }
                }
            }
            return total > 0 ? min(1, completed / total) : 0
        }
        guard let slotIndex = slots.firstIndex(where: { $0.id == slot.id }) else { return 0 }
        if slotIndex < currentSlot { return 1 }
        if slotIndex > currentSlot { return 0 }
        func rank(_ value: WorkoutPhase) -> Int {
            switch value {
            case .warmUp: 0
            case .prepare: 1
            case .active: 2
            case .setRest: 3
            case .sectionRest: 4
            }
        }
        if rank(phase) < rank(live.phase) { return 1 }
        return phase == live.phase ? live.fraction : 0
    }

    private func groupItems(for section: Section, isExpanded: Bool) -> [BuilderRowItem] {
        var items: [BuilderRowItem] = []

        func appendRestDetails(_ row: RestRow, _ target: RestTarget, level: Int) {
            guard expandedRestRowIDs.contains(row.id) else { return }
            let restPageIDs = restExercisePageIDs(for: target)
            for restPageID in restPageIDs {
                items.append(BuilderRowItem(
                    id: .restExercise(row.id, restPageID),
                    kind: .restExercise(target, restPageID),
                    level: level
                ))
            }
            if row.contents.isEmpty && restPageIDs.isEmpty {
                items.append(BuilderRowItem(id: .restEmpty(row.id), kind: .restEmpty(target), level: level))
            } else {
                for content in row.contents {
                    items.append(BuilderRowItem(
                        id: .restContent(row.id, content.id),
                        kind: .restContent(target, content),
                        level: level
                    ))
                }
            }
        }

        if isExpanded {
            if section.mode == .bundle {
                for (setIndex, set) in section.bundleSets.enumerated() {
                    items.append(BuilderRowItem(id: .bundleSet(set.id), kind: .bundleSet(set, setIndex), level: 1))
                    let exercises = set.children.isEmpty ? [set] : set.children
                    for (position, child) in exercises.enumerated() {
                        items.append(BuilderRowItem(
                            id: .set(child.id),
                            kind: .bundleChild(child, setIndex, position),
                            level: 2
                        ))
                    }
                }
            } else {
                for (index, slot) in section.effectiveSlots.enumerated() {
                    if section.preparationTime(for: slot) > 0 {
                        items.append(BuilderRowItem(
                            id: .preparation(slot.id),
                            kind: .preparation(slot),
                            level: 1,
                            progress: liveValue(section, slot: slot, phase: .prepare)
                        ))
                    }
                    items.append(BuilderRowItem(
                        id: .set(slot.id),
                        kind: .set(slot, index),
                        level: 1,
                        progress: liveValue(section, slot: slot, phase: .active)
                    ))
                    for drop in slot.drops {
                        items.append(BuilderRowItem(id: .drop(drop.id), kind: .drop(slot, drop), level: 2))
                        if drop.restAfter > 0 {
                            let target = RestTarget(sectionID: section.id, slotID: slot.id, dropID: drop.id, isBig: false)
                            let rest = RestRow(id: drop.id, kind: .normal, duration: drop.restAfter)
                            items.append(BuilderRowItem(id: .dropRest(drop.id), kind: .rest(rest, target), level: 2))
                            appendRestDetails(rest, target, level: 3)
                        }
                    }
                    if (slot.restRow?.duration ?? slot.restAfter) > 0
                        || !slot.restExercisePageIDs.isEmpty
                        || slot.restRow?.contents.isEmpty == false {
                        let rest = slot.restRow ?? RestRow(id: slot.id, kind: .normal, duration: slot.restAfter)
                        let target = RestTarget(sectionID: section.id, slotID: slot.id, isBig: false)
                        items.append(BuilderRowItem(
                            id: .slotRest(slot.id),
                            kind: .rest(rest, target),
                            level: 1,
                            progress: liveValue(section, slot: slot, phase: .setRest)
                        ))
                        appendRestDetails(rest, target, level: 2)
                    }
                }
                for pageID in section.examplePageIDs {
                    items.append(BuilderRowItem(id: .example(section.id, pageID), kind: .example(pageID), level: 1))
                }
            }
        }

        let bigRest = section.bigRestRow ?? RestRow(
            id: section.id,
            kind: .big,
            duration: section.customRestAfter ?? workout.restBetweenSections
        )
        let bigTarget = RestTarget(sectionID: section.id, slotID: nil, isBig: true)
        items.append(BuilderRowItem(
            id: .bigRest(section.id),
            kind: .rest(bigRest, bigTarget),
            level: 1,
            progress: liveValue(section, phase: .sectionRest)
        ))
        appendRestDetails(bigRest, bigTarget, level: 2)

        let rails = BuilderRail.thread(
            levels: items.map(\.level),
            progress: items.map(\.progress),
            crossing: items.map { _ in false },
            rootProgress: liveValue(section, phase: .active),
            live: liveContext != nil
        )
        for index in items.indices {
            items[index].rail = rails[index]
            items[index].slice = index == items.count - 1 ? .bottom : .middle
        }
        return items
    }

    @ViewBuilder
    private func builderRow(_ item: BuilderRowItem, in section: Section) -> some View {
        switch item.kind {
        case .preparation(let slot):
            preparationRow(section: section, slot: slot, item: item)
        case .set(let slot, let index):
            setRow(section: section, slot: slot, index: index, item: item)
        case .drop(let slot, let drop):
            dropRow(section: section, slot: slot, drop: drop, item: item)
        case .rest(let rest, let target):
            restRow(rest, target: target, item: item)
        case .restExercise(let target, let pageID):
            restExerciseRow(target: target, pageID: pageID, item: item)
        case .restEmpty(let target):
            restEmptyRow(target: target, item: item)
        case .restContent(let target, let content):
            restContentRow(content, target: target, item: item)
        case .bundleSet(let set, let index):
            bundleSetRow(section: section, set: set, index: index, item: item)
        case .bundleChild(let child, let setIndex, let position):
            bundleChildRow(section: section, child: child, setIndex: setIndex, position: position, item: item)
        case .example(let pageID):
            exampleRow(section: section, pageID: pageID, item: item)
        }
    }

    @ViewBuilder
    private func sectionHeaderRow(_ section: Section, isExpanded: Bool, rail: BuilderRail, slice: BuilderSlice) -> some View {
        Group {
            if section.mode == .bundle {
                BundleSectionHeader(
                    section: section,
                    isExpanded: isExpanded,
                    rail: rail,
                    slice: slice,
                    progress: liveContext == nil ? nil : rail.fill,
                    onToggle: { toggleSection(section.id) },
                    onAddSet: { addSlot(in: section.id) },
                    onEdit: { bundleToEdit = section },
                    onOpenPage: { pageID in
                        previewPage(pageID, key: nil, sectionID: section.id, fallbackIcon: "figure.boxing")
                    }
                )
            } else {
                timedSectionHeader(section, isExpanded: isExpanded, progress: liveContext == nil ? nil : rail.fill)
                    .modifier(BuilderRowChrome(
                        rail: rail,
                        slice: rowSlice(slice),
                        vertical: BuilderMetrics.headerVertical,
                        pulse: highlightedRowID == .section(section.id)
                    ))
            }
        }
        .keyNavTarget(id: section.id, role: .primary, shape: .roundedRectangle(cornerRadius: 12)) {
            toggleSection(section.id)
        }
        .builderContextMenu {
            Button { toggleSection(section.id) } label: {
                Label(isExpanded ? "Collapse" : "Expand", systemImage: "chevron.down")
            }
            sectionMenuItems(section)
        }
        .id(RowID.section(section.id))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                sectionToDelete = section
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        #if os(macOS)
        .onDrag {
            draggedSectionID = section.id
            return NSItemProvider(object: section.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: SectionDropDelegate(
            sourceID: draggedSectionID,
            targetID: section.id,
            move: { moveSection($0, onto: $1) },
            finish: { draggedSectionID = nil }
        ))
        #else
        .padding(.top, BuilderMetrics.groupSpacing)
        .builderPageRow()
        #endif
    }

    private func timedSectionHeader(_ section: Section, isExpanded: Bool, progress: Double?) -> some View {
        HStack(alignment: .top, spacing: 0) {
            BuilderHandle()
            pageNode(
                pageID: section.pageID,
                size: BuilderMetrics.root,
                fallbackIcon: "figure.run",
                heroKey: "section-\(section.id)",
                progress: progress
            )
            .padding(.leading, BuilderMetrics.handleGap)
            Button {
                toggleSection(section.id)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    TmaxMarqueeText(
                        section.name,
                        font: TimeMasterFont.black(17, relativeTo: .headline),
                        color: Theme.textPrimary,
                        forceActive: draggedSectionID == section.id
                    )
                    TmaxMarqueeText(
                        sectionSummary(section),
                        font: TimeMasterFont.caption().monospacedDigit(),
                        color: Theme.textSecondary
                    )
                }
                .frame(maxWidth: .infinity, minHeight: BuilderMetrics.root, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, BuilderMetrics.rootGap)
            .accessibilityLabel("\(section.name), \(sectionSummary(section))")
            .accessibilityHint(isExpanded ? "Collapses the section" : "Expands the section")
            BuilderCluster {
                TmaxMenu {
                    sectionAddMenuItems(section)
                } label: {
                    Image(systemName: "plus")
                }
                .builderChipMenu()
                .accessibilityLabel("Add to \(section.name)")
            } middle: {
                TmaxMenu {
                    sectionMenuItems(section)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Actions for \(section.name)")
            } last: {
                BuilderDisclosureChip(
                    isExpanded: isExpanded,
                    expandLabel: "Expand \(section.name)",
                    collapseLabel: "Collapse \(section.name)"
                ) {
                    toggleSection(section.id)
                }
            }
            .frame(height: BuilderMetrics.root)
            .padding(.leading, 8)
        }
    }

    @ViewBuilder
    private func sectionMenuItems(_ section: Section) -> some View {
        Button {
            addSlot(in: section.id)
        } label: {
            Label("Add Set", systemImage: "plus")
        }
        if section.mode == .bundle {
            Button {
                bundleToEdit = section
            } label: {
                Label("Edit Bundle", systemImage: "slider.horizontal.3")
            }
        } else {
            if let firstSlot = section.effectiveSlots.first {
                Button {
                    openBrowser(.addExamples(section.id))
                } label: {
                    Label("Add Examples from Database", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    openBrowser(.addDrop(section.id, firstSlot.id))
                } label: {
                    Label("Add Drop Set", systemImage: "arrow.down.right")
                }
            }
            Button {
                duplicateSection(section)
            } label: {
                Label("Duplicate Section", systemImage: "plus.square.on.square")
            }
        }
        Button {
            setTimerEnabled(!section.isTimerEnabled, in: section.id)
        } label: {
            if section.isTimerEnabled {
                Label("Switch to Until Done", systemImage: "hand.tap")
            } else {
                Label("Switch to Timer", systemImage: "timer")
            }
        }
        Divider()
        Button(role: .destructive) {
            sectionToDelete = section
            showingDeleteAlert = true
        } label: {
            Label("Delete Section", systemImage: "trash")
        }
    }

    private func sectionSummary(_ section: Section) -> String {
        var parts = [section.mode == .bundle ? "Bundle" : "\(section.slotCount) sets"]
        if let reps = section.repCount {
            parts.append("\(reps) reps")
        }
        let time = formatCompactDuration(section.calculatedDuration)
        parts.append(section.isTimerEnabled ? time : (section.mode == .bundle ? "~\(time)" : "Until Done"))
        if !section.examplePageIDs.isEmpty {
            let count = section.examplePageIDs.count
            parts.append("\(count) \(count == 1 ? "example" : "examples")")
        }
        return parts.joined(separator: " · ")
    }

    private func preparationRow(section: Section, slot: SetSlot, item: BuilderRowItem) -> some View {
        BuilderTimelineRow(level: item.level) {
            BuilderGlyphNode(systemImage: "timer", size: BuilderMetrics.node(item.level), progress: liveRing(item))
        } title: {
            BuilderRowTitle("Preparation", subtitle: "Before \(slot.displayName)", level: item.level)
        } trailing: {
            BuilderValueText(text: formatCompactDuration(section.preparationTime(for: slot)))
            BuilderCluster {
                EmptyView()
            } middle: {
                TmaxMenu {
                    preparationMenuItems(section: section, slot: slot)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Actions for preparation of set \(slot.displayName)")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(id: AnyHashable(item.id), role: .primary, shape: .roundedRectangle(cornerRadius: 10))
        .builderContextMenu {
            preparationMenuItems(section: section, slot: slot)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                disablePreparation(in: section.id, slotID: slot.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    private func preparationMenuItems(section: Section, slot: SetSlot) -> some View {
        Button(role: .destructive) {
            disablePreparation(in: section.id, slotID: slot.id)
        } label: {
            Label("Delete Preparation", systemImage: "trash")
        }
    }

    private func setRow(section: Section, slot: SetSlot, index: Int, item: BuilderRowItem) -> some View {
        let key = "set-\(slot.id)"
        let title = "Set \(index + 1) duration"
        let untimed = !section.isTimerEnabled
        let reps = untimed ? slot.repCount ?? section.repCount : nil
        return BuilderTimelineRow(level: item.level) {
            pageNode(
                pageID: slot.exercisePageID,
                size: BuilderMetrics.node(item.level),
                fallbackIcon: "figure.run",
                heroKey: key,
                progress: liveRing(item)
            )
        } title: {
            rowTitleButton(pageID: slot.exercisePageID, heroKey: key, fallbackIcon: "figure.run") {
                BuilderRowTitle(slot.displayName, subtitle: reps.map { "Set \(index + 1) · \($0) reps" } ?? "Set \(index + 1)", level: item.level)
            }
        } trailing: {
            durationButton(text: untimed ? "Until Done" : formatCompactDuration(slot.duration), title: title, seconds: slot.duration, untimed: untimed) {
                durationEdit = DurationEditTarget(title: title, seconds: slot.duration, kind: .slot(section.id, slot.id), isTimerEnabled: section.isTimerEnabled)
            }
            BuilderCluster {
                TmaxMenu {
                    setAddMenuItems(section: section, slot: slot)
                } label: {
                    Image(systemName: "plus")
                }
                .builderChipMenu()
                .accessibilityLabel("Add to set \(index + 1)")
            } middle: {
                TmaxMenu {
                    setMoreMenuItems(section: section, slot: slot, index: index)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Actions for set \(index + 1)")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(
            id: AnyHashable(item.id),
            role: .primary,
            shape: .roundedRectangle(cornerRadius: 10),
            action: openAction(slot.exercisePageID, key: key, fallbackIcon: "figure.run")
        )
        .builderContextMenu {
            setAddMenuItems(section: section, slot: slot)
            Divider()
            setMoreMenuItems(section: section, slot: slot, index: index)
        }
        .onDrag {
            draggedSlotID = slot.id
            return NSItemProvider(object: slot.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: SlotDropDelegate(
                sourceID: draggedSlotID,
                targetID: slot.id,
                move: { sourceID, targetID in
                    moveSlot(in: section.id, sourceID: sourceID, onto: targetID)
                },
                finish: { draggedSlotID = nil }
            )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                requestSlotRemoval(slot, from: section)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    @ViewBuilder
    private func setAddMenuItems(section: Section, slot: SetSlot) -> some View {
        if slot.prepareTime == 0 {
            Button {
                enablePreparation(in: section.id, slotID: slot.id)
            } label: {
                Label("Add Preparation", systemImage: "timer")
            }
        }
        Button {
            openBrowser(.addDrop(section.id, slot.id))
        } label: {
            Label("Add Drop Set", systemImage: "arrow.down.right")
        }
        if slot.playbackRest > 0 {
            Button {
                openBrowser(.setRestExercise(section.id, slot.id))
            } label: {
                Label(
                    slot.restExercisePageIDs.isEmpty ? "Set Rest Exercise" : "Add Another Rest Exercise",
                    systemImage: "figure.cooldown"
                )
            }
        }
    }

    @ViewBuilder
    private func setMoreMenuItems(section: Section, slot: SetSlot, index: Int) -> some View {
        Button {
            durationEdit = DurationEditTarget(
                title: "Set \(index + 1) duration",
                seconds: slot.duration,
                kind: .slot(section.id, slot.id),
                isTimerEnabled: section.isTimerEnabled
            )
        } label: {
            if section.isTimerEnabled {
                Label("Edit Duration", systemImage: "timer")
            } else {
                Label("Edit Estimate", systemImage: "hand.tap")
            }
        }
        if let pageID = slot.exercisePageID {
            Button {
                openPage(pageID, from: "set-\(slot.id)", fallbackIcon: "figure.run")
            } label: {
                Label("Open Exercise Page", systemImage: "book.pages")
            }
        }
        Divider()
        Button(role: .destructive) {
            requestSlotRemoval(slot, from: section)
        } label: {
            Label("Delete Set", systemImage: "trash")
        }
    }

    private func dropRow(section: Section, slot: SetSlot, drop: DropSet, item: BuilderRowItem) -> some View {
        let key = "drop-\(drop.id)"
        let title = "\(drop.displayName) duration"
        return BuilderTimelineRow(level: item.level) {
            pageNode(
                pageID: drop.exercisePageID,
                size: BuilderMetrics.node(item.level),
                fallbackIcon: "arrow.down.right",
                heroKey: key
            )
        } title: {
            rowTitleButton(pageID: drop.exercisePageID, heroKey: key, fallbackIcon: "arrow.down.right") {
                BuilderRowTitle(drop.displayName, subtitle: "Drop", level: item.level)
            }
        } trailing: {
            durationButton(text: section.isTimerEnabled ? formatCompactDuration(drop.duration) : "Until Done", title: title, seconds: drop.duration, untimed: !section.isTimerEnabled) {
                durationEdit = DurationEditTarget(title: title, seconds: drop.duration, kind: .drop(section.id, slot.id, drop.id), isTimerEnabled: section.isTimerEnabled)
            }
            BuilderCluster {
                EmptyView()
            } middle: {
                TmaxMenu {
                    dropMenuItems(section: section, slot: slot, drop: drop)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Actions for \(drop.displayName)")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(
            id: AnyHashable(item.id),
            role: .primary,
            shape: .roundedRectangle(cornerRadius: 10),
            action: openAction(drop.exercisePageID, key: key, fallbackIcon: "arrow.down.right")
        )
        .builderContextMenu {
            dropMenuItems(section: section, slot: slot, drop: drop)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeDrop(sectionID: section.id, slotID: slot.id, dropID: drop.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    @ViewBuilder
    private func dropMenuItems(section: Section, slot: SetSlot, drop: DropSet) -> some View {
        Button {
            durationEdit = DurationEditTarget(
                title: "\(drop.displayName) duration",
                seconds: drop.duration,
                kind: .drop(section.id, slot.id, drop.id),
                isTimerEnabled: section.isTimerEnabled
            )
        } label: {
            if section.isTimerEnabled {
                Label("Edit Duration", systemImage: "timer")
            } else {
                Label("Edit Estimate", systemImage: "hand.tap")
            }
        }
        if let pageID = drop.exercisePageID {
            Button {
                openPage(pageID, from: "drop-\(drop.id)", fallbackIcon: "arrow.down.right")
            } label: {
                Label("Open Exercise Page", systemImage: "book.pages")
            }
        }
        Divider()
        Button(role: .destructive) {
            removeDrop(sectionID: section.id, slotID: slot.id, dropID: drop.id)
        } label: {
            Label("Delete \(drop.displayName)", systemImage: "trash")
        }
    }

    private func durationButton(
        text: String,
        title: String,
        seconds: Int,
        untimed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
        }
        .buttonStyle(BuilderValueButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(untimed ? "Until Done, estimated \(formatCompactDuration(seconds))" : formatCompactDuration(seconds))
    }

    /// A rail node for a page: its cover (it opens the page, growing out of it), or a glyph when there is no page.
    @ViewBuilder
    private func pageNode(
        pageID: UUID?,
        size: CGFloat,
        fallbackIcon: String,
        heroKey: String,
        progress: Double? = nil
    ) -> some View {
        if let pageID {
            Button {
                previewPage(pageID, key: heroKey, fallbackIcon: fallbackIcon)
            } label: {
                pageThumbnail(pageID: pageID, size: size, fallbackIcon: fallbackIcon)
                    .workoutHeroSource(heroKey)
                    .overlay {
                        if let progress {
                            BuilderProgressRing(progress: progress, cornerRadius: BuilderMetrics.thumbnailRadius(size))
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview exercise")
        } else {
            BuilderGlyphNode(
                systemImage: fallbackIcon,
                size: size,
                square: size >= BuilderMetrics.root,
                progress: progress
            )
        }
    }

    private func pageThumbnail(pageID: UUID, size: CGFloat, fallbackIcon: String) -> some View {
        let page = databaseStore.page(id: pageID)
        let shape = RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(size), style: .continuous)
        return Group {
            if let url = page?.coverImageURL {
                AsyncCoverImage(
                    url: url,
                    fallbackIcon: page?.effectiveWorkoutType?.iconName ?? fallbackIcon,
                    fallbackColor: page?.effectiveWorkoutType.map { Color(hex: $0.colorHex) },
                    height: size,
                    contentMode: .fill,
                    overlayGradient: false
                )
                .frame(width: size, height: size)
                .clipShape(shape)
            } else {
                BuilderGlyphNode(
                    systemImage: page?.effectiveWorkoutType?.iconName ?? fallbackIcon,
                    size: size,
                    tint: page?.effectiveWorkoutType.map { Color(hex: $0.colorHex) } ?? Theme.textSecondary,
                    square: true
                )
            }
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    /// A row title that opens the row's page (from the row's cover) when there is one.
    @ViewBuilder
    private func rowTitleButton<Content: View>(
        pageID: UUID?,
        heroKey: String,
        fallbackIcon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let pageID {
            Button {
                openPage(pageID, from: heroKey, fallbackIcon: fallbackIcon)
            } label: {
                content()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the exercise page")
        } else {
            content()
        }
    }

    private func restRow(_ row: RestRow, target: RestTarget, item: BuilderRowItem) -> some View {
        let isExpanded = expandedRestRowIDs.contains(row.id)
        let isBig = row.kind == .big
        let title = isBig ? "Big rest duration" : "Rest duration"
        return BuilderTimelineRow(level: item.level) {
            BuilderGlyphNode(
                systemImage: isBig ? "square.stack.3d.up.fill" : "pause.fill",
                size: BuilderMetrics.node(item.level),
                tint: Theme.toolbarOrange,
                progress: liveRing(item)
            )
        } title: {
            Button {
                toggleRestRow(row.id)
            } label: {
                BuilderRowTitle(isBig ? "Big Rest" : "Rest", subtitle: restSubtitle(row, target: target), level: item.level)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides what plays during this rest" : "Shows what plays during this rest")
        } trailing: {
            durationButton(text: formatCompactDuration(row.duration), title: title, seconds: row.duration) {
                durationEdit = DurationEditTarget(title: title, seconds: row.duration, kind: .rest(target))
            }
            BuilderCluster {
                restActionMenu(target: target)
            } middle: {
                TmaxMenu {
                    restMoreItems(row, target: target)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel(isBig ? "Big rest actions" : "Rest actions")
            } last: {
                BuilderDisclosureChip(
                    isExpanded: isExpanded,
                    expandLabel: "Expand rest contents",
                    collapseLabel: "Collapse rest contents"
                ) {
                    toggleRestRow(row.id)
                }
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(id: AnyHashable(item.id), role: .primary, shape: .roundedRectangle(cornerRadius: 10)) {
            toggleRestRow(row.id)
        }
        .builderContextMenu {
            restAddItems(target: target)
            Divider()
            restMoreItems(row, target: target)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeRestRow(target)
            } label: {
                Label(isBig ? "Clear" : "Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    private func restSubtitle(_ row: RestRow, target: RestTarget) -> String? {
        var parts: [String] = []
        let pageIDs = restExercisePageIDs(for: target)
        if let first = pageIDs.first {
            let title = databaseStore.page(id: first)?.title ?? "Rest exercise"
            parts.append(pageIDs.count > 1 ? "\(title) +\(pageIDs.count - 1)" : title)
        }
        let notes = row.contents.filter { $0.kind == .note }.count
        let stretches = row.contents.filter { $0.kind == .stretch }.count
        if notes > 0 { parts.append(notes == 1 ? "1 note" : "\(notes) notes") }
        if stretches > 0 { parts.append(stretches == 1 ? "1 stretch" : "\(stretches) stretches") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func restMoreItems(_ row: RestRow, target: RestTarget) -> some View {
        let isBig = row.kind == .big
        Button {
            durationEdit = DurationEditTarget(
                title: isBig ? "Big rest duration" : "Rest duration",
                seconds: row.duration,
                kind: .rest(target)
            )
        } label: {
            Label("Edit Duration", systemImage: "timer")
        }
        Divider()
        Button(role: .destructive) {
            removeRestRow(target)
        } label: {
            Label(isBig ? "Clear Big Rest" : "Delete Rest", systemImage: "trash")
        }
    }

    private func restActionMenu(target: RestTarget) -> some View {
        TmaxMenu {
            restAddItems(target: target)
        } label: {
            Image(systemName: "plus")
        }
        .builderChipMenu()
        .accessibilityLabel("Add rest content")
    }

    @ViewBuilder
    private func restAddItems(target: RestTarget) -> some View {
        Button("Add Note", systemImage: "note.text") {
            noteEditTarget = RestNoteTarget(target: target, contentID: nil, text: "")
        }
        Button("Add Stretch", systemImage: "figure.cooldown") {
            openBrowser(.restStretch(target))
        }
        if target.dropID == nil, restSeconds(for: target) > 0 {
            let title = restExercisePageIDs(for: target).isEmpty ? "Add Rest Exercise" : "Add Another Rest Exercise"
            if target.isBig {
                Button(title, systemImage: "figure.cooldown") {
                    openBrowser(.bigRestExercise(target.sectionID))
                }
            } else if let slotID = target.slotID {
                Button(title, systemImage: "figure.cooldown") {
                    openBrowser(.setRestExercise(target.sectionID, slotID))
                }
            }
        }
    }

    private func restExerciseKey(target: RestTarget, pageID: UUID) -> String {
        let base = "rest-exercise-\((target.slotID ?? target.sectionID).uuidString)"
        let offset = restExercisePageIDs(for: target).firstIndex(of: pageID) ?? 0
        return offset == 0 ? base : "\(base)-\(offset)"
    }

    private func restExerciseRow(target: RestTarget, pageID: UUID, item: BuilderRowItem) -> some View {
        let key = restExerciseKey(target: target, pageID: pageID)
        return BuilderTimelineRow(level: item.level) {
            pageNode(pageID: pageID, size: BuilderMetrics.node(item.level), fallbackIcon: "figure.cooldown", heroKey: key)
        } title: {
            rowTitleButton(pageID: pageID, heroKey: key, fallbackIcon: "figure.cooldown") {
                BuilderRowTitle(
                    databaseStore.page(id: pageID)?.title ?? "Rest exercise",
                    subtitle: restExerciseSubtitle(target: target, pageID: pageID),
                    level: item.level
                )
            }
        } trailing: {
            BuilderCluster {
                EmptyView()
            } middle: {
                TmaxMenu {
                    restExerciseMenuItems(target: target, pageID: pageID, key: key)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Rest exercise actions")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(
            id: AnyHashable(item.id),
            role: .primary,
            shape: .roundedRectangle(cornerRadius: 10),
            action: openAction(pageID, key: key, fallbackIcon: "figure.cooldown")
        )
        .builderContextMenu {
            restExerciseMenuItems(target: target, pageID: pageID, key: key)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeRestExercise(pageID, target: target)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    @ViewBuilder
    private func restExerciseMenuItems(target: RestTarget, pageID: UUID, key: String) -> some View {
        Button {
            openPage(pageID, from: key, fallbackIcon: "figure.cooldown")
        } label: {
            Label("Open Exercise Page", systemImage: "book.pages")
        }
        if restExercisePageIDs(for: target).first != pageID {
            Button {
                makeDefaultRestExercise(pageID, target: target)
            } label: {
                Label("Make Default", systemImage: "star")
            }
        }
        Divider()
        Button(role: .destructive) {
            removeRestExercise(pageID, target: target)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private func restEmptyRow(target: RestTarget, item: BuilderRowItem) -> some View {
        BuilderTimelineRow(level: item.level) {
            Circle()
                .strokeBorder(Theme.textSecondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        } title: {
            TmaxMenu {
                restAddItems(target: target)
            } label: {
                Text("Add a note, stretch, or rest exercise")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .accessibilityLabel("Add rest content")
        } trailing: {
            EmptyView()
        }
        .modifier(rowChrome(item))
        .builderGroupedRow()
        .id(item.id)
    }

    private func restContentRow(_ content: RestContent, target: RestTarget, item: BuilderRowItem) -> some View {
        let key = "rest-content-\(content.id)"
        let icon = content.kind == .stretch ? "figure.cooldown" : "note.text"
        let kindName = content.kind == .stretch ? "Stretch" : "Note"
        let primaryAction: (() -> Void)?
        if content.kind == .note {
            primaryAction = { editNote(content, target: target) }
        } else {
            primaryAction = openAction(content.pageID, key: key, fallbackIcon: icon)
        }
        return BuilderTimelineRow(level: item.level) {
            pageNode(pageID: content.pageID, size: BuilderMetrics.node(item.level), fallbackIcon: icon, heroKey: key)
        } title: {
            rowTitleButton(pageID: content.pageID, heroKey: key, fallbackIcon: icon) {
                BuilderRowTitle(
                    content.text.isEmpty ? kindName : content.text,
                    subtitle: content.text.isEmpty ? nil : kindName,
                    level: item.level
                )
            }
        } trailing: {
            BuilderCluster {
                if content.kind == .note {
                    Button {
                        editNote(content, target: target)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(BuilderChipButtonStyle())
                    .accessibilityLabel("Edit note")
                }
            } middle: {
                TmaxMenu {
                    restContentMenuItems(content, target: target, key: key)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("\(kindName) actions")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(
            id: AnyHashable(item.id),
            role: .primary,
            shape: .roundedRectangle(cornerRadius: 10),
            action: primaryAction
        )
        .builderContextMenu {
            restContentMenuItems(content, target: target, key: key)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeRestContent(target, contentID: content.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    @ViewBuilder
    private func restContentMenuItems(_ content: RestContent, target: RestTarget, key: String) -> some View {
        if content.kind == .note {
            Button {
                editNote(content, target: target)
            } label: {
                Label("Edit Note", systemImage: "pencil")
            }
        }
        if let pageID = content.pageID {
            Button {
                openPage(pageID, from: key, fallbackIcon: "figure.cooldown")
            } label: {
                Label("Open Exercise Page", systemImage: "book.pages")
            }
        }
        Divider()
        Button(role: .destructive) {
            removeRestContent(target, contentID: content.id)
        } label: {
            Label("Delete Rest Content", systemImage: "trash")
        }
    }

    private func editNote(_ content: RestContent, target: RestTarget) {
        noteEditTarget = RestNoteTarget(target: target, contentID: content.id, text: content.text)
    }

    private func bundleSetRow(section: Section, set: SetSlot, index: Int, item: BuilderRowItem) -> some View {
        let count = max(1, set.children.count)
        let seconds = (set.children.isEmpty ? [set] : set.children).reduce(0) { $0 + $1.duration }
        let time = formatCompactDuration(seconds)
        return BuilderTimelineRow(level: item.level) {
            BuilderGlyphNode(
                systemImage: section.isCombo ? "repeat" : "list.number",
                size: BuilderMetrics.node(item.level),
                tint: Theme.toolbarOrange
            )
        } title: {
            BuilderRowTitle(
                section.isCombo ? "Round \(index + 1)" : "Set \(index + 1)",
                subtitle: "\(count) \(count == 1 ? "exercise" : "exercises")",
                level: item.level
            )
        } trailing: {
            BuilderValueText(text: section.isTimerEnabled ? time : "~\(time)")
        }
        .modifier(rowChrome(item))
        .builderGroupedRow()
        .id(item.id)
    }

    private func bundleChildRow(section: Section, child: SetSlot, setIndex: Int, position: Int, item: BuilderRowItem) -> some View {
        let key = "set-\(child.id)"
        let untimed = !section.isTimerEnabled
        let reps = untimed ? child.repCount : nil
        let subtitle = "\(section.isCombo ? "Round" : "Set") \(setIndex + 1) · \(position + 1)" + (reps.map { " · \($0) reps" } ?? "")
        let title = section.isCombo ? ComboCall.spoken(child.displayName) : child.displayName
        let open: (() -> Void)? = child.exercisePageID.map { id in
            { previewPage(id, key: key, sectionID: section.id, fallbackIcon: "figure.boxing") }
        }
        return BuilderTimelineRow(level: item.level) {
            if section.isCombo {
                BuilderGlyphNode(systemImage: "waveform", size: BuilderMetrics.node(item.level), tint: ComboStyle.bright)
            } else {
                pageNode(
                    pageID: child.exercisePageID,
                    size: BuilderMetrics.node(item.level),
                    fallbackIcon: "figure.boxing",
                    heroKey: key
                )
            }
        } title: {
            Button {
                open?()
            } label: {
                BuilderRowTitle(title, subtitle: subtitle, level: item.level)
            }
            .buttonStyle(.plain)
            .disabled(open == nil)
            .accessibilityHint("Previews the exercise")
        } trailing: {
            BuilderValueText(text: untimed ? "Until Done" : formatCompactDuration(child.duration))
        }
        .modifier(rowChrome(item))
        .keyNavTarget(id: AnyHashable(item.id), role: .primary, shape: .roundedRectangle(cornerRadius: 10), action: open)
        .builderGroupedRow()
        .id(item.id)
    }

    private func exampleRow(section: Section, pageID: UUID, item: BuilderRowItem) -> some View {
        let key = "example-\(section.id)-\(pageID)"
        let title = databaseStore.page(id: pageID)?.title ?? "Example"
        return BuilderTimelineRow(level: item.level) {
            Button {
                previewExample(sectionID: section.id, pageID: pageID)
            } label: {
                pageThumbnail(pageID: pageID, size: BuilderMetrics.node(item.level), fallbackIcon: "photo.on.rectangle.angled")
                    .workoutHeroSource(key)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview example")
        } title: {
            Button {
                previewExample(sectionID: section.id, pageID: pageID)
            } label: {
                BuilderRowTitle(title, subtitle: "Example from the database", level: item.level)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Previews this example")
        } trailing: {
            BuilderCluster {
                EmptyView()
            } middle: {
                TmaxMenu {
                    exampleMenuItems(section: section, pageID: pageID, key: key)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Example actions")
            } last: {
                EmptyView()
            }
        }
        .modifier(rowChrome(item))
        .keyNavTarget(id: AnyHashable(item.id), role: .primary, shape: .roundedRectangle(cornerRadius: 10)) {
            previewExample(sectionID: section.id, pageID: pageID)
        }
        .builderContextMenu {
            exampleMenuItems(section: section, pageID: pageID, key: key)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                removeExample(pageID, from: section.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .tint(.red)
        }
        .builderGroupedRow()
        .id(item.id)
    }

    @ViewBuilder
    private func exampleMenuItems(section: Section, pageID: UUID, key: String) -> some View {
        Button {
            previewExample(sectionID: section.id, pageID: pageID)
        } label: {
            Label("Preview", systemImage: "play.rectangle")
        }
        Button {
            openPage(pageID, from: key, fallbackIcon: "figure.run")
        } label: {
            Label("Open Exercise Page", systemImage: "book.pages")
        }
        Divider()
        Button(role: .destructive) {
            removeExample(pageID, from: section.id)
        } label: {
            Label("Remove Example", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func sectionAddMenuItems(_ section: Section) -> some View {
        Button {
            addSlot(in: section.id)
        } label: {
            Label("Add Set", systemImage: "plus")
        }
        Button {
            openBrowser(.addExamples(section.id))
        } label: {
            Label("Add Examples from Database", systemImage: "photo.on.rectangle.angled")
        }
    }

    private func previewExample(sectionID: UUID, pageID: UUID) {
        let steps = QuickPreviewSteps.steps(for: workout) { databaseStore.page(id: $0) }
        let block = sectionID.uuidString
        guard let index = steps.firstIndex(where: { $0.blockID == block && !$0.isRest })
            ?? steps.firstIndex(where: { $0.blockID == block }) else {
            openPage(pageID, from: nil, fallbackIcon: "figure.run")
            return
        }
        quickPreview.present(steps, at: index, example: pageID)
    }

    private func addExamples(_ ids: [UUID], to sectionID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { section in
                for id in ids where id != section.pageID && !section.examplePageIDs.contains(id) {
                    section.examplePageIDs.append(id)
                }
            }
            expandedSectionIDs.insert(sectionID)
        }
    }

    private func removeExample(_ pageID: UUID, from sectionID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { $0.examplePageIDs.removeAll { $0 == pageID } }
        }
    }

    private func toggleSection(_ id: UUID) {
        withAnimation(disclosureAnimation) {
            if expandedSectionIDs.contains(id) {
                expandedSectionIDs.remove(id)
            } else {
                expandedSectionIDs.insert(id)
            }
        }
    }

    private func toggleRestRow(_ id: UUID) {
        withAnimation(disclosureAnimation) {
            if expandedRestRowIDs.contains(id) {
                expandedRestRowIDs.remove(id)
            } else {
                expandedRestRowIDs.insert(id)
            }
        }
    }

    @ViewBuilder
    private func pendingConfigCard(_ pending: PendingSectionConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                Text("Configure New Section")
                    .font(TimeMasterFont.black(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }

            Text(pending.name)
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            SectionTimingPicker(isTimerEnabled: Binding(
                get: { pending.isTimerEnabled },
                set: { pendingSection?.isTimerEnabled = $0 }
            ))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                spacing: 8
            ) {
                inlineStepper(label: pending.isTimerEnabled ? "Duration" : "Estimate", value: Binding(
                    get: { pending.duration },
                    set: { pendingSection?.duration = $0 }
                ), range: 5...600, step: 5, unit: "s")
                inlineStepper(label: "Sets", value: Binding(
                    get: { pending.sets },
                    set: { pendingSection?.sets = $0 }
                ), range: 1...50, step: 1, unit: "")
                inlineStepper(label: "Reps", value: Binding(
                    get: { pending.repCount ?? 0 },
                    set: { pendingSection?.repCount = ($0 > 0 ? $0 : nil) }
                ), range: 0...100, step: 1, unit: "")
                inlineStepper(label: "Prepare", value: Binding(
                    get: { pending.prepareTime },
                    set: { pendingSection?.prepareTime = $0 }
                ), range: 0...30, step: 1, unit: "s")
                if pending.sets > 1 {
                    inlineStepper(label: "Between Sets", value: Binding(
                        get: { pending.restBetweenSets },
                        set: { pendingSection?.restBetweenSets = $0 }
                    ), range: 0...120, step: 5, unit: "s")
                }
                inlineStepper(label: pending.sets > 1 ? "Big Rest" : "Rest", value: Binding(
                    get: { pending.restAfter },
                    set: { pendingSection?.restAfter = $0 }
                ), range: 0...120, step: 5, unit: "s")
            }

            HStack(spacing: 10) {
                Button {
                    animateEditor {
                        pendingSection = nil
                    }
                } label: {
                    Text("Cancel")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 48))

                Button {
                    confirmPendingSection(pending)
                } label: {
                    Text("Confirm")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 48))
            }
        }
        .padding(14)
        .modifier(TimeMasterCardSurface(cornerRadius: BuilderMetrics.cardRadius, emphasized: true, flat: true))
    }

    private func inlineStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(TimeMasterFont.micro())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if unit == "s" {
                DurationPickerView(
                    seconds: value,
                    range: range,
                    step: step,
                    compact: true
                )
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 6) {
                    Button {
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(BuilderChipButtonStyle())
                    .disabled(value.wrappedValue - step < range.lowerBound)
                    .accessibilityLabel("Decrease \(label)")

                    Text("\(value.wrappedValue)\(unit)")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 26)

                    Button {
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(BuilderChipButtonStyle())
                    .disabled(value.wrappedValue + step > range.upperBound)
                    .accessibilityLabel("Increase \(label)")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface2))
    }

    private func confirmPendingSection(_ pending: PendingSectionConfig) {
        let configuration = WorkoutSectionImportConfiguration(
            duration: pending.duration,
            sets: pending.sets,
            repCount: pending.repCount,
            restAfter: pending.restAfter,
            restBetweenSets: pending.restBetweenSets,
            prepareTime: pending.prepareTime,
            isTimerEnabled: pending.isTimerEnabled
        )

        let section: Section?
        switch pending.mode {
        case .timed:
            section = pending.sourcePages.first.flatMap {
                WorkoutSectionBuilder.makeSection(page: $0, configuration: configuration)
            }
        case .bundle:
            section = WorkoutSectionBuilder.makeBundle(
                sources: pending.bundleSources,
                configuration: configuration
            )
        }
        guard let section else { return }

        animateEditor {
            store.addSection(to: workout, section: section)
            sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
            pendingSection = nil
        }
    }



    @ViewBuilder
    private var startButton: some View {
        if !workout.sections.isEmpty {
            Button { playerWorkout = workout } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
            .builderColumn()
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }


    // MARK: - Helpers

    private func handleAddContentType(_ type: WorkoutAddContentType) {
        switch type {
        case .combo:
            addComboSection()
        case .bundle:
            showingNewBundle = true
        case .workout:
            Task { @MainActor in
                await Task.yield()
                showingSavedWorkoutPicker = true
            }
        case .bike:
            addOutdoorSection(kind: .bike)
        case .runWalk:
            addOutdoorSection(kind: .runWalk)
        }
    }

    private func addSavedWorkoutSection(_ savedWorkout: Workout) {
        showingSavedWorkoutPicker = false
        animateEditor {
            pendingSection = PendingSectionConfig(
            name: "Workout: \(savedWorkout.name)",
            pageID: nil,
            bundleSources: [.workout(savedWorkout)],
            duration: max(5, savedWorkout.totalDuration),
            sets: 1,
            repCount: nil,
            restAfter: 0,
            restBetweenSets: 0,
            prepareTime: 0,
            mode: .bundle
        )
        }
    }

    private func addComboSection() {
        let section = WorkoutSectionBuilder.makeCombo()
        animateEditor {
            store.addSection(to: workout, section: section)
            sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
            expandedSectionIDs.insert(section.id)
        }
    }

    private func addOutdoorSection(kind: OutdoorActivityKind) {
        let duration = 30 * 60
        let section = Section(
            name: kind.displayName,
            duration: duration,
            sets: 1,
            restBetweenSets: 0,
            customRestAfter: 0,
            prepareTime: 0,
            mode: .timed,
            slots: [
                SetSlot(
                    name: kind.displayName,
                    duration: duration,
                    restAfter: 0,
                    prepareTime: 0
                )
            ]
        )
        animateEditor {
            store.addSection(to: workout, section: section)
            sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        animateEditor {
            sectionIDs.move(fromOffsets: source, toOffset: destination)
            var w = workout
            w.sections = sectionIDs.compactMap { id in w.sections.first(where: { $0.id == id }) }
            store.updateWorkout(w)
        }
    }

    private func handlePageSelection(
        _ page: ExercisePage,
        duration: Int,
        sets: Int,
        reps: Int,
        restAfter: Int,
        restBetween: Int,
        prepareTime: Int
    ) {
        switch browserTarget {
        case .newSection:
            animateEditor {
                pendingSection = PendingSectionConfig(
                name: page.title,
                pageID: page.id,
                sourcePages: [page],
                duration: duration,
                sets: sets,
                repCount: reps > 0 ? reps : nil,
                restAfter: restAfter,
                restBetweenSets: restBetween,
                prepareTime: prepareTime
                )
            }
        case .addDrop(let sectionID, let slotID):
            var didAdd = false
            animateEditor {
                mutateSection(id: sectionID) { section in
                    var slots = section.effectiveSlots
                    guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
                          page.id != section.pageID,
                          !slots[slotIndex].drops.contains(where: { $0.exercisePageID == page.id }) else { return }
                    slots[slotIndex].drops.append(
                        DropSet(
                            exercisePageID: page.id,
                            name: page.title,
                            duration: duration,
                            restAfter: restAfter
                        )
                    )
                    section.slots = slots
                    didAdd = true
                }
                if didAdd {
                    expandedSectionIDs.insert(sectionID)
                }
            }
        case .setRestExercise(let sectionID, let slotID):
            var didSet = false
            animateEditor {
                mutateSection(id: sectionID) { section in
                    var slots = section.effectiveSlots
                    if let index = slots.firstIndex(where: { $0.id == slotID }),
                       RestExercise.fits(page, restSeconds: slots[index].playbackRest) {
                        slots[index].restExercisePageIDs = RestExercise.adding(page.id, to: slots[index].restExercisePageIDs)
                        section.slots = slots
                        didSet = true
                    }
                }
                if didSet {
                    expandedSectionIDs.insert(sectionID)
                    if let restID = restRowID(for: RestTarget(sectionID: sectionID, slotID: slotID, isBig: false)) {
                        expandedRestRowIDs.insert(restID)
                    }
                }
            }
        case .bigRestExercise(let sectionID):
            let target = RestTarget(sectionID: sectionID, slotID: nil, isBig: true)
            if RestExercise.fits(page, restSeconds: restSeconds(for: target)) {
                animateEditor {
                    mutateRestRow(target) { $0.exercisePageIDs = RestExercise.adding(page.id, to: $0.exercisePageIDs) }
                    expandedSectionIDs.insert(sectionID)
                    if let restID = restRowID(for: target) {
                        expandedRestRowIDs.insert(restID)
                    }
                }
            }
        case .restStretch(let target):
            animateEditor {
                mutateRestRow(target) { row in
                    row.contents.append(
                        RestContent(
                            kind: .stretch,
                            pageID: page.id,
                            text: page.title
                        )
                    )
                }
                expandedSectionIDs.insert(target.sectionID)
                if let restID = restRowID(for: target) {
                    expandedRestRowIDs.insert(restID)
                }
            }
        case .addExamples(let sectionID):
            addExamples([page.id], to: sectionID)
        }
        showBrowserSheet = false
    }

    private func mutateSection(id: UUID, _ mutate: (inout Section) -> Void) {
        var updatedWorkout = workout
        guard let index = updatedWorkout.sections.firstIndex(where: { $0.id == id }) else { return }
        mutate(&updatedWorkout.sections[index])
        store.updateWorkout(updatedWorkout)
        sectionIDs = updatedWorkout.sections.map(\.id)
    }

    private func moveSlot(in sectionID: UUID, from source: Int, to destination: Int) {
        mutateSection(id: sectionID) { section in
            guard source != destination else { return }
            var slots = section.effectiveSlots
            guard slots.indices.contains(source), slots.indices.contains(destination) else { return }
            let slot = slots.remove(at: source)
            slots.insert(slot, at: destination)
            section.slots = slots
            section.sets = slots.count
        }
    }

    private func removeSlot(in sectionID: UUID, at index: Int) {
        animateEditor {
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard slots.count > 1, slots.indices.contains(index) else { return }
                slots.remove(at: index)
                section.slots = slots
                section.sets = slots.count
            }
        }
    }

    private func moveSlot(in sectionID: UUID, sourceID: UUID?, onto targetID: UUID) {
        guard let sourceID, sourceID != targetID else { return }
        animateEditor {
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let sourceIndex = slots.firstIndex(where: { $0.id == sourceID }),
                      let targetIndex = slots.firstIndex(where: { $0.id == targetID }) else { return }
                let movedSlot = slots.remove(at: sourceIndex)
                slots.insert(movedSlot, at: targetIndex)
                section.slots = slots
                section.sets = slots.count
            }
        }
    }

    private func moveSection(_ sourceID: UUID, onto targetID: UUID) {
        guard sourceID != targetID,
              let from = sectionIDs.firstIndex(of: sourceID),
              let to = sectionIDs.firstIndex(of: targetID) else { return }
        moveSections(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
    }

    private func duplicateSection(_ section: Section) {
        var copy = section
        copy.id = UUID()
        copy.name = "\(section.name) Copy"
        copy.slots = section.effectiveSlots.map { $0.duplicated() }
        if var bigRest = copy.bigRestRow {
            bigRest.id = copy.id
            copy.bigRestRow = bigRest
        }
        animateEditor {
            store.addSection(to: workout, section: copy)
            sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
        }
    }

    /// Stores the implicit sets of older sections once, so their rows keep stable identities between renders. Left
    /// alone while the workout plays, so the running session never sees its workout change underneath it.
    private func materializeImplicitSlots() {
        guard liveContext == nil else { return }
        var updated = workout
        var changed = false
        for index in updated.sections.indices
        where updated.sections[index].mode == .timed && updated.sections[index].slots.isEmpty {
            updated.sections[index].slots = updated.sections[index].effectiveSlots
            changed = true
        }
        if changed {
            store.updateWorkout(updated)
        }
    }


    private func openBrowser(
        _ target: BuilderBrowserTarget,
        bundleMode: Bool = false
    ) {
        browserTarget = target
        browserStartsInBundleMode = bundleMode
        databaseStore.reload()
        showBrowserSheet = true
    }

    private func setControlsExpanded(_ expanded: Bool) {
        guard editorControlsExpanded != expanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
            editorControlsExpanded = expanded
        }
    }

    private func setSummaryPinned(_ pinned: Bool) {
        guard chrome.summaryPinned != pinned else { return }
        chrome.summaryPinned = pinned
    }

    private func editorDidScroll(_ scroll: ScrollingChromeScroll) {
        if editorControlsExpanded, ScrollingChromeCollapse.shouldCollapse(scroll) { setControlsExpanded(false) }
        setSummaryPinned(chrome.pinsSummary(at: scroll.offset))
    }

    private func formatCompactDuration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func updateDuration(_ target: DurationEditTarget, seconds: Int, isTimerEnabled: Bool?) {
        switch target.kind {
        case .slot(let sectionID, let slotID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[index].duration = max(5, seconds)
                section.slots = slots
                if let isTimerEnabled { section.isTimerEnabled = isTimerEnabled }
            }
        case .drop(let sectionID, let slotID, let dropID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
                      let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) else { return }
                slots[slotIndex].drops[dropIndex].duration = max(5, seconds)
                section.slots = slots
                if let isTimerEnabled { section.isTimerEnabled = isTimerEnabled }
            }
        case .rest(let restTarget):
            mutateRestRow(restTarget) { row in
                row.duration = max(0, seconds)
            }
        }
    }

    private func setTimerEnabled(_ isTimerEnabled: Bool, in sectionID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { $0.isTimerEnabled = isTimerEnabled }
        }
    }

    private func mutateRestRow(_ target: RestTarget, _ mutate: (inout RestRow) -> Void) {
        mutateSection(id: target.sectionID) { section in
            if target.isBig {
                var row = section.bigRestRow ?? RestRow(
                    id: section.id,
                    kind: .big,
                    duration: section.customRestAfter ?? workout.restBetweenSections
                )
                mutate(&row)
                section.bigRestRow = row
                section.customRestAfter = row.duration
                return
            }

            var slots = section.effectiveSlots
            guard let slotID = target.slotID,
                  let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }

            if let dropID = target.dropID,
               let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) {
                let drop = slots[slotIndex].drops[dropIndex]
                var row = RestRow(id: drop.id, kind: .normal, duration: drop.restAfter)
                mutate(&row)
                slots[slotIndex].drops[dropIndex].restAfter = row.duration
            } else {
                var row = slots[slotIndex].restRow ?? RestRow(
                    id: slots[slotIndex].id,
                    kind: .normal,
                    duration: slots[slotIndex].restAfter
                )
                mutate(&row)
                slots[slotIndex].restRow = row
                slots[slotIndex].restAfter = row.duration
            }
            section.slots = slots
        }
    }

    private func restRowID(for target: RestTarget) -> UUID? {
        guard let section = workout.sections.first(where: { $0.id == target.sectionID }) else { return nil }
        if target.isBig {
            return section.bigRestRow?.id ?? section.id
        }
        if let dropID = target.dropID { return dropID }
        guard let slot = section.effectiveSlots.first(where: { $0.id == target.slotID }) else { return nil }
        return slot.restRow?.id ?? slot.id
    }

    private func updateRestContent(_ target: RestNoteTarget, content: RestContent) {
        animateEditor {
            mutateRestRow(target.target) { row in
                if let index = row.contents.firstIndex(where: { $0.id == content.id }) {
                    row.contents[index] = content
                } else {
                    row.contents.append(content)
                }
            }
            expandedSectionIDs.insert(target.target.sectionID)
            if let restID = restRowID(for: target.target) {
                expandedRestRowIDs.insert(restID)
            }
        }
    }

    private func removeRestContent(_ target: RestTarget, contentID: UUID) {
        animateEditor {
            mutateRestRow(target) { row in
                row.contents.removeAll { $0.id == contentID }
            }
        }
    }

    private func addSlot(in sectionID: UUID) {
        var insertedSlotID: UUID?
        animateEditor {
            mutateSection(id: sectionID) { section in
                if section.mode == .bundle {
                    var values = section.bundleSets
                    guard let source = values.last else { return }
                    var added = source.duplicated()
                    added.name = "Set \(values.count + 1)"
                    values.append(added)
                    section.slots = values
                    section.sets = values.count
                    return
                }
                var slots = section.effectiveSlots
                guard let source = slots.last else { return }

                if let previousIndex = slots.indices.last {
                    let previousID = slots[previousIndex].id
                    var rest = slots[previousIndex].restRow ?? RestRow(
                        id: previousID,
                        kind: .normal
                    )
                    rest.duration = max(0, section.restBetweenSets)
                    slots[previousIndex].restAfter = rest.duration
                    slots[previousIndex].restRow = rest
                }

                var newSlot = source
                newSlot.id = UUID()
                newSlot.prepareTime = nil
                newSlot.drops = []
                newSlot.children = []
                newSlot.restExercisePageIDs = []
                newSlot.restAfter = 0
                newSlot.restRow = nil
                slots.append(newSlot)
                insertedSlotID = newSlot.id
                section.slots = slots
                section.sets = slots.count
            }
            expandedSectionIDs.insert(sectionID)
            if let insertedSlotID {
                pendingScrollTargetID = .set(insertedSlotID)
            }
        }
    }

    private func requestSlotRemoval(_ slot: SetSlot, from section: Section) {
        let slots = section.effectiveSlots
        guard let index = slots.firstIndex(where: { $0.id == slot.id }) else { return }
        guard slots.count > 1 else {
            sectionToDelete = section
            showingDeleteAlert = true
            return
        }
        removeSlot(in: section.id, at: index)
    }

    private func removeDrop(sectionID: UUID, slotID: UUID, dropID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[slotIndex].drops.removeAll { $0.id == dropID }
                section.slots = slots
            }
        }
    }

    private func removeRestRow(_ target: RestTarget) {
        let restID = restRowID(for: target)
        animateEditor {
            mutateSection(id: target.sectionID) { section in
                if target.isBig {
                    var row = section.bigRestRow ?? RestRow(
                        id: section.id,
                        kind: .big,
                        duration: section.customRestAfter ?? workout.restBetweenSections
                    )
                    row.duration = 0
                    row.contents.removeAll()
                    row.exercisePageIDs = []
                    section.bigRestRow = row
                    section.customRestAfter = 0
                    return
                }

                var slots = section.effectiveSlots
                guard let slotID = target.slotID,
                      let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }

                if let dropID = target.dropID,
                   let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) {
                    slots[slotIndex].drops[dropIndex].restAfter = 0
                } else {
                    slots[slotIndex].restAfter = 0
                    slots[slotIndex].restRow = nil
                    slots[slotIndex].restExercisePageIDs = []
                }
                section.slots = slots
            }
            if let restID {
                expandedRestRowIDs.remove(restID)
            }
        }
    }

    private func disablePreparation(in sectionID: UUID, slotID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[index].prepareTime = 0
                section.slots = slots
            }
        }
    }

    private func enablePreparation(in sectionID: UUID, slotID: UUID) {
        animateEditor {
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[index].prepareTime = nil
                section.slots = slots
            }
        }
    }

    private func clearRestExercise(target: RestTarget) {
        setRestExercisePageIDs([], for: target)
    }

    private func removeRestExercise(_ pageID: UUID, target: RestTarget) {
        setRestExercisePageIDs(RestExercise.removing(pageID, from: restExercisePageIDs(for: target)), for: target)
    }

    private func makeDefaultRestExercise(_ pageID: UUID, target: RestTarget) {
        setRestExercisePageIDs(RestExercise.making(pageID, defaultIn: restExercisePageIDs(for: target)), for: target)
    }

    private func setRestExercisePageIDs(_ ids: [UUID], for target: RestTarget) {
        animateEditor {
            if target.isBig {
                mutateRestRow(target) { $0.exercisePageIDs = ids }
                return
            }
            guard let slotID = target.slotID else { return }
            mutateSection(id: target.sectionID) { section in
                var slots = section.effectiveSlots
                guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[index].restExercisePageIDs = ids
                section.slots = slots
            }
        }
    }

    private func restExercisePageIDs(for target: RestTarget) -> [UUID] {
        guard target.dropID == nil,
              let section = workout.sections.first(where: { $0.id == target.sectionID }) else { return [] }
        if target.isBig { return section.bigRestRow?.exercisePageIDs ?? [] }
        guard let slotID = target.slotID else { return [] }
        return section.effectiveSlots.first(where: { $0.id == slotID })?.restExercisePageIDs ?? []
    }

    private func restSeconds(for target: RestTarget) -> Int {
        guard let section = workout.sections.first(where: { $0.id == target.sectionID }) else { return 0 }
        if target.isBig {
            return section.bigRestRow?.duration ?? section.customRestAfter ?? workout.restBetweenSections
        }
        let slots = section.effectiveSlots
        if let dropID = target.dropID {
            return slots.flatMap(\.drops).first(where: { $0.id == dropID })?.restAfter ?? 0
        }
        return slots.first(where: { $0.id == target.slotID })?.playbackRest ?? 0
    }

    private func restExerciseLimit(for target: BuilderBrowserTarget) -> Int? {
        switch target {
        case .setRestExercise(let sectionID, let slotID):
            return restSeconds(for: RestTarget(sectionID: sectionID, slotID: slotID, isBig: false))
        case .bigRestExercise(let sectionID):
            return restSeconds(for: RestTarget(sectionID: sectionID, slotID: nil, isBig: true))
        default:
            return nil
        }
    }

    private func restExerciseSubtitle(target: RestTarget, pageID: UUID) -> String {
        let ids = restExercisePageIDs(for: target)
        var subtitle = "Rest exercise"
        if ids.count > 1 {
            subtitle = (ids.first == pageID ? "Default" : "Choice") + " · " + subtitle
        }
        if let page = databaseStore.page(id: pageID), !RestExercise.fits(page, restSeconds: restSeconds(for: target)) {
            subtitle += " · longer than this rest"
        }
        return subtitle
    }

}

private let workoutDetailScrollSpace = "workout-detail-scroll"

/// Whether the full summary has scrolled away. Only the compact bar observes it, so crossing the threshold while
/// scrolling never re-renders the rows.
final class WorkoutEditorChromeState: ObservableObject {
    @Published var summaryPinned = false
    var headerHeight: CGFloat = 0
    var summaryHeight: CGFloat = 0

    func pinsSummary(at offset: CGFloat) -> Bool {
        guard headerHeight > 0, summaryHeight > 0 else { return false }
        let line = headerHeight + summaryHeight - 8
        return summaryPinned ? offset > line - 12 : offset > line
    }
}

private struct WorkoutCompactSummaryOverlay<Bar: View>: View {
    @ObservedObject var state: WorkoutEditorChromeState
    let isEnabled: Bool
    @ViewBuilder let bar: () -> Bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shows = state.summaryPinned && isEnabled
        ZStack(alignment: .top) {
            if shows {
                bar()
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(reduceMotion ? EverMotion.opacityOnly : EverMotion.state, value: shows)
    }
}

struct PendingSectionConfig {
    var name: String
    var pageID: UUID?
    var sourcePages: [ExercisePage] = []
    var bundleSources: [WorkoutBundleSource] = []
    var duration: Int
    var sets: Int
    var repCount: Int?
    var restAfter: Int
    var restBetweenSets: Int
    var prepareTime: Int = 4
    var mode: SectionMode = .timed
    /// false: the new section's sets run until the user taps Done; `duration` is then only their estimate.
    var isTimerEnabled = true
}
private enum WorkoutAddContentType {
    case bundle
    case combo
    case workout
    case bike
    case runWalk
}

private struct SavedWorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    let excludingWorkoutID: UUID
    let onSelect: (Workout) -> Void

    private var savedWorkouts: [Workout] {
        store.workouts
            .filter {
                $0.id != excludingWorkoutID &&
                store.canNestWorkout($0.id, in: excludingWorkoutID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedWorkouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(savedWorkouts) { savedWorkout in
                                Button {
                                    onSelect(savedWorkout)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: savedWorkout.type.iconName)
                                            .font(.title3)
                                            .foregroundColor(Color(hex: savedWorkout.colorHex))
                                            .frame(width: 42, height: 42)
                                            .background(Theme.surface2)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(savedWorkout.name)
                                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(savedWorkout.sections.count) sections · \(formatDuration(savedWorkout.totalDuration))")
                                                .font(TimeMasterFont.caption())
                                                .foregroundColor(Theme.textSecondary)
                                        }

                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Add Saved Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .font(TimeMasterFont.body())
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 58))
                .foregroundColor(Theme.textSecondary)
            Text("No saved workouts yet")
                .font(TimeMasterFont.black(22, relativeTo: .title2))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Create a workout first, then add it here as a nested section.")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                dismiss()
                NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
            } label: {
                Text("Create New Workout")
                    .font(TimeMasterFont.black(17, relativeTo: .headline))
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes > 0 ? "\(minutes) min" : "\(max(0, seconds)) sec"
    }
}

private enum BuilderBrowserTarget {
    case newSection
    case addDrop(UUID, UUID)
    case setRestExercise(UUID, UUID)
    case bigRestExercise(UUID)
    case restStretch(RestTarget)
    case addExamples(UUID)
}

private struct RestTarget {
    let sectionID: UUID
    let slotID: UUID?
    let dropID: UUID?
    let isBig: Bool

    init(sectionID: UUID, slotID: UUID?, dropID: UUID? = nil, isBig: Bool) {
        self.sectionID = sectionID
        self.slotID = slotID
        self.dropID = dropID
        self.isBig = isBig
    }
}

private enum DurationEditKind {
    case slot(UUID, UUID)
    case drop(UUID, UUID, UUID)
    case rest(RestTarget)
}

private struct DurationEditTarget: Identifiable {
    let id = UUID()
    let title: String
    let seconds: Int
    let kind: DurationEditKind
    /// The section's timing, for set and drop rows: the sheet then also offers Timer / Until Done. nil for rests.
    var isTimerEnabled: Bool? = nil
}

private struct RestNoteTarget: Identifiable {
    let id = UUID()
    let target: RestTarget
    let contentID: UUID?
    let text: String
}


private struct DurationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialSeconds: Int
    /// Saves the seconds, and the section's timing when the sheet offered it.
    let onSave: (Int, Bool?) -> Void
    private let offersTiming: Bool
    @State private var seconds: Int
    @State private var isTimerEnabled: Bool

    init(title: String, seconds: Int, isTimerEnabled: Bool? = nil, onSave: @escaping (Int, Bool?) -> Void) {
        self.title = title
        self.initialSeconds = seconds
        self.onSave = onSave
        offersTiming = isTimerEnabled != nil
        _seconds = State(initialValue: seconds)
        _isTimerEnabled = State(initialValue: isTimerEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if offersTiming {
                    VStack(spacing: 8) {
                        SectionTimingPicker(isTimerEnabled: $isTimerEnabled)
                        Text(isTimerEnabled
                             ? "Every set of this section counts down."
                             : "Every set of this section runs until you tap Done.")
                            .font(TimeMasterFont.caption())
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                DurationPickerView(seconds: $seconds, range: 5...3600, step: 5)
                Text(offersTiming && !isTimerEnabled
                     ? "Estimated time for this row, used for the workout's total."
                     : "Changes apply to this row only.")
                    .font(TimeMasterFont.caption())
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Save") {
                    onSave(seconds, offersTiming ? isTimerEnabled : nil)
                    dismiss()
                }
                                 }
            }
        }
        .font(TimeMasterFont.body())
    }
}

private struct RestNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialText: String
    let onSave: (String) -> Void
    @State private var text: String

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Write a short cue for this rest interval.")
                    .font(TimeMasterFont.caption())
                    .foregroundColor(Theme.textSecondary)
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Rest Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Save") {
                    onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                                 }
            }
        }
        .font(TimeMasterFont.body())
    }
}

private struct RestSeparatorRow: View {
    @Binding var rest: Int
    let defaultRest: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text("Rest")
                .font(TimeMasterFont.caption())
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Button {
                if rest >= 5 { rest -= 5 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest > 0 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest <= 0)
            .buttonStyle(.plain)
            Text("\(rest)s")
                .font(TimeMasterFont.black(12, relativeTo: .caption).monospacedDigit())
                .foregroundColor(rest == defaultRest ? Theme.textSecondary : .white)
                .frame(minWidth: 32)
            Button {
                if rest < 300 { rest += 5 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest < 300 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest >= 300)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.surface2.opacity(0.6))
    }
}

private struct SlotDropDelegate: DropDelegate {
    let sourceID: UUID?
    let targetID: UUID
    let move: (UUID?, UUID) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        move(sourceID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        finish()
        return true
    }
}

/// Reorders sections by dragging their heads on the Mac, where they live in a stack rather than a list.
private struct SectionDropDelegate: DropDelegate {
    let sourceID: UUID?
    let targetID: UUID
    let move: (UUID, UUID) -> Void
    let finish: () -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceID, sourceID != targetID else { return }
        move(sourceID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: sourceID == nil ? .forbidden : .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { finish() }
        return sourceID != nil
    }
}

// MARK: - WorkoutSettingsView

private struct WorkoutSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    @ObservedObject var musicManager = MusicManager.shared

    let workoutID: UUID

    @State private var restBetweenSections: Int
    @State private var colorHex: String
    @State private var selectedTrackIndices: Set<Int>
    @State private var useGlobalLibrary: Bool

    @State private var coverStyle: WorkoutCoverStyle
    @State private var coverFilename: String?
    @State private var showingCoverImporter = false
    init(workoutID: UUID, store: WorkoutStore) {
        self.workoutID = workoutID
        let w = store.workouts.first(where: { $0.id == workoutID }) ?? Workout(name: "")
        _restBetweenSections = State(initialValue: w.restBetweenSections)
        _colorHex = State(initialValue: w.colorHex)
        _selectedTrackIndices = State(initialValue: {
            var set = Set<Int>()
            for filename in w.musicTrackFilenames {
                if let idx = MusicManager.shared.trackFilenames.firstIndex(of: filename) {
                    set.insert(idx)
                }
            }
            return set
        }())
        _useGlobalLibrary = State(initialValue: w.musicTrackFilenames.isEmpty)
        _coverStyle = State(initialValue: w.coverStyle)
        _coverFilename = State(initialValue: w.imageFilename)
    }

    private var workout: Workout {
        store.workouts.first(where: { $0.id == workoutID }) ?? Workout(name: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        restSection
                        colorSection
                        coverSection
                        musicSection
                        infoSection
                    }
                    .padding(16)
                }
            }
            .timeMasterNavigationTitle("Workout Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white)
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Save") { saveSettings() }
                    .foregroundColor(.white)
                                 }
            }
        }
        .font(TimeMasterFont.body())
    }

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest Between Sections")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(Theme.textPrimary)
            HStack {
                Text("\(restBetweenSections)s")
                    .font(TimeMasterFont.black(22, relativeTo: .title2).monospacedDigit())
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $restBetweenSections, in: 0...300, step: 5).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
            Text("Default rest applied between sections unless overridden per-section.")
                .font(TimeMasterFont.caption())
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon Color")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(Theme.textPrimary)
            IconColorPicker(selectedHex: $colorHex)
        }
    }

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Cover")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(Theme.textPrimary)

            Picker("Cover style", selection: $coverStyle) {
                ForEach(WorkoutCoverStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if coverStyle == .customImage {
                HStack(spacing: 12) {
                    AsyncCoverImage(
                        url: coverFilename.map { PhotoManager.shared.photoURL(for: $0) },
                        fallbackIcon: workout.type.iconName,
                        fallbackColor: Color(hex: workout.type.colorHex),
                        height: 64,
                        contentMode: .fill,
                        overlayGradient: false
                    )
                    .frame(width: 82, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Choose image") {
                        showingCoverImporter = true
                    }
                    .buttonStyle(TimeMasterActionButtonStyle())
                    .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }
                .fileImporter(
                    isPresented: $showingCoverImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    importCover(result)
                }
            }
        }
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Music")
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(Theme.textPrimary)
            if musicManager.trackFilenames.isEmpty {
                Text("No music tracks added. Add tracks in Settings → Background Music.")
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundColor(Theme.textSecondary)
            } else {
                Toggle("Use entire music library", isOn: Binding(
                    get: { useGlobalLibrary },
                    set: { newValue in
                        useGlobalLibrary = newValue
                        if newValue { selectedTrackIndices.removeAll() }
                    }
                ))
                .tint(.white)

                VStack(spacing: 6) {
                    ForEach(Array(musicManager.trackFilenames.enumerated()), id: \.offset) { index, filename in
                        HStack(spacing: 12) {
                            Image(systemName: selectedTrackIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedTrackIndices.contains(index) ? .white : Color.white.opacity(0.28))
                             Text(musicManager.displayName(for: filename))
                                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            useGlobalLibrary = false
                            if selectedTrackIndices.contains(index) {
                                selectedTrackIndices.remove(index)
                            } else {
                                selectedTrackIndices.insert(index)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                Text("Turn this off to choose a specific playlist for this workout.")
                    .font(TimeMasterFont.caption())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(label: "Type", value: workout.type.name)
            infoRow(label: "Sections", value: "\(workout.sections.count)")
            infoRow(label: "Total Duration", value: formatDuration(workout.totalDuration))
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textPrimary)
        }
        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private func importCover(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else { return }

        #if os(iOS)
        guard let image = UIImage(data: data) else { return }
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return }
        #endif

        if let filename = PhotoManager.shared.savePhoto(image) {
            coverFilename = filename
            coverStyle = .customImage
        }
    }

    private func saveSettings() {
        var w = workout
        w.restBetweenSections = restBetweenSections
        w.colorHex = colorHex
        w.coverStyle = coverStyle
        w.imageFilename = coverFilename
        w.musicTrackFilenames = useGlobalLibrary ? [] : selectedTrackIndices.sorted().map {
            musicManager.trackFilenames[$0]
        }
        store.updateWorkout(w)
        dismiss()
    }
}


#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Morning HIIT", sections: [
            Section(name: "Burpees",  duration: 45),
            Section(name: "Push-ups", duration: 30)
        ]))
    }
    .environmentObject(WorkoutStore())
    .preferredColorScheme(.dark)
}
