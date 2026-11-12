import SwiftUI
import AVFoundation

#if os(iOS)
private typealias PlatformImage = UIImage
#elseif os(macOS)
private typealias PlatformImage = NSImage
#endif

extension Image {
    #if os(iOS)
    static func platformImg(_ image: UIImage) -> Image { Image(uiImage: image) }
    #elseif os(macOS)
    static func platformImg(_ image: NSImage) -> Image { Image(nsImage: image) }
    #endif
}

struct WorkoutPlayerView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore
    @ObservedObject private var musicLibrary = MusicLibraryStore.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var workout: Workout

    // Navigation
    @State private var currentSectionIndex  = 0
    @State private var currentSetIndex      = 0   // current exercise within the section's playback queue
    @State private var playbackBySection: [UUID: [SetSlot]] = [:]
    @State private var setStartsBySection: [UUID: Set<Int>] = [:]
    @State private var dropIDs: Set<UUID> = []
    @State private var bundleOrders: [String: [UUID]] = [:]
    @State private var timeRemaining        = 0
    @State private var isPaused             = false

    // Phase flags (only one true at a time)
    @State private var isSetRest            = false
    @State private var isSectionRest        = false
    @State private var isWarmUp             = false
    @State private var isPreparation        = false
    @State private var showingWarmUpPicker  = true
    @State private var workoutCompleted     = false

    @State private var timerGeneration = UUID()
    @State private var timer: Timer?
    @State private var startTime: Date = Date()
    @State private var showingCloseConfirmation = false
    @State private var nextMotivationIn: Int = 0
    @State private var autoSaveCounter = 0
    @State private var elapsedSeconds = 0
    @State private var didInitFromResume = false
    #if os(iOS)
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var nowPlayingStarted = false
    @State private var liveArtworkNames: [String: String] = [:]
    @State private var liveArtworkRequests: Set<String> = []
    #endif

    // Music
    @StateObject private var musicSession = WorkoutMusicSession()
    @State private var showMusicChooser = false
    @State private var musicChooserIsAutomatic = false
    @State private var offeredMusicContinuation = false
    @State private var musicStarted = false
    @State private var showWorkoutManagement = false
    @State private var playerHeaderBottom: CGFloat = 0

    // Settings
    @AppStorage("extra_rest_seconds") private var extraRestSeconds: Int = 15

    // Warm-up
    @State private var warmUpDuration = 60

    // Media
    @State private var currentMediaIndex        = 0
    @State private var mediaViewerCatalog: WorkoutMediaCatalog?
    @State private var mediaViewerIndex = 0
    @State private var mediaViewerOpensEditor = false
    @State private var showMediaViewer = false

    // Media overlay and rest adjustment
    @State private var showMediaOverlay = false
    @State private var overlayMediaItem: MediaItem?
    #if os(iOS)
    @State private var overlayImage: UIImage?
    #elseif os(macOS)
    @State private var overlayImage: NSImage?
    #endif
    @State private var restExtensionTotal = 0
    @State private var restExtensionText = ""

    // Page overlay
    @State private var showPageOverlay = false
    @State private var overlayPageID: UUID?
    @State private var overlayPageName = ""
    @State private var showBundleReorder = false

    init(workout: Workout) {
        _workout = State(initialValue: workout)
    }

    // MARK: - Computed

    private var currentSection: Section? {
        guard currentSectionIndex < workout.sections.count else { return nil }
        return workout.sections[currentSectionIndex]
    }

    private var currentSlot: SetSlot? {
        guard let section = currentSection else { return nil }
        return playbackSlots(for: section)[safe: currentSetIndex]
    }

    private var isBundleSection: Bool { currentSection?.mode == .bundle }

    private var isBundleActive: Bool {
        isBundleSection && !isWarmUp && !isPreparation && !isSetRest && !isSectionRest
    }

    private var restSlot: SetSlot? {
        guard isSetRest, let section = currentSection else { return nil }
        return playbackSlots(for: section)[safe: max(0, currentSetIndex - 1)]
    }

    private var livePhase: WorkoutPhase {
        isWarmUp ? .warmUp : isPreparation ? .prepare : isSetRest ? .setRest : isSectionRest ? .sectionRest : .active
    }

    private var phaseDuration: Int {
        switch livePhase {
        case .warmUp: warmUpDuration
        case .prepare: currentSlot.map { currentSection?.preparationTime(for: $0) ?? 0 } ?? 0
        case .active: currentSlot?.duration ?? 0
        case .setRest: restSlot?.playbackRest ?? 0
        case .sectionRest: currentSection.map(sectionRestDuration) ?? 0
        }
    }

    private var currentItem: PlayerQueueItem? {
        guard let section = currentSection, let slot = currentSlot else { return nil }
        return queueItem(for: slot, in: section)
    }

    private var upNextItem: PlayerQueueItem? {
        guard !workoutCompleted else { return nil }
        switch livePhase {
        case .warmUp: return item(atSection: 0, slot: 0)
        case .setRest: return item(atSection: currentSectionIndex, slot: currentSetIndex)
        case .sectionRest: return item(atSection: currentSectionIndex + 1, slot: 0)
        case .prepare, .active:
            guard let position = nextPosition(afterSection: currentSectionIndex, slot: currentSetIndex) else { return nil }
            return item(atSection: position.section, slot: position.slot)
        }
    }

    private var isLastExercise: Bool {
        nextPosition(afterSection: currentSectionIndex, slot: currentSetIndex) == nil
    }

    private var nextExerciseName: String? { upNextItem?.name }

    private var mainSetProgress: (index: Int, count: Int) {
        guard let section = currentSection else { return (0, 1) }
        let slots = playbackSlots(for: section)
        var count = 0
        var index = 0
        for (position, slot) in slots.enumerated() where !dropIDs.contains(slot.id) {
            count += 1
            if position <= currentSetIndex { index = count - 1 }
        }
        return (index, max(1, count))
    }

    private var bundleRoundProgress: (index: Int, count: Int) {
        guard let section = currentSection else { return (0, 1) }
        let starts = (setStartsBySection[section.id] ?? [0]).sorted()
        let index = max(0, starts.lastIndex { $0 <= currentSetIndex } ?? 0)
        return (index, max(1, starts.count))
    }

    private var canGoBack: Bool { !isWarmUp && !showingWarmUpPicker }

    private func openPageOverlay(id: UUID?, name: String) {
        guard let id else { return }
        overlayPageID = id
        overlayPageName = name
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            showPageOverlay = true
        }
    }

    private func openPreview(_ item: PlayerQueueItem) {
        if let id = item.pageID {
            openPageOverlay(id: id, name: item.name)
        } else if let media = item.mediaItem {
            overlayMediaItem = media
            overlayImage = PhotoManager.shared.thumbnail(for: media)
            showMediaOverlay = true
        }
    }

    private var liveContext: WorkoutLiveContext {
        WorkoutLiveContext(
            progress: WorkoutLiveProgress(
                sectionID: currentSection?.id, slotID: (isSetRest ? restSlot : currentSlot)?.id,
                phase: livePhase, remaining: timeRemaining, phaseDuration: phaseDuration,
                elapsed: elapsedSeconds, isPaused: isPaused
            ),
            music: musicSession,
            onPause: { if isPaused { resumeTimer() } else { pauseTimer() } },
            onStop: stopWorkout,
            onOpenMusic: toggleOverlayMusic
        )
    }

    private func reconcileLiveWorkout(_ workouts: [Workout]) {
        guard let updated = workouts.first(where: { $0.id == workout.id }) else { return }
        let sectionID = currentSection?.id
        let slotID = currentSlot?.id
        let restingSlotID = restSlot?.id
        let oldDuration = phaseDuration
        let oldPageID = currentSlot?.exercisePageID
        let musicChanged = updated.musicTimeline != workout.musicTimeline
        workout = updated
        refreshPlaybackSequences()
        if musicChanged && musicStarted {
            musicSession.updateTimeline(updated.musicTimeline ?? .init())
        }
        guard !showingWarmUpPicker, !workoutCompleted, !isWarmUp else { return }
        guard !updated.sections.isEmpty else { stopWorkout(); return }
        if let sectionIndex = updated.sections.firstIndex(where: { $0.id == sectionID }) {
            currentSectionIndex = sectionIndex
            let slots = playbackSlots(for: updated.sections[sectionIndex])
            var retainedPhase = true
            if isSetRest, let restIndex = slots.firstIndex(where: { $0.id == restingSlotID }), restIndex + 1 < slots.count {
                currentSetIndex = restIndex + 1
            } else if let slotIndex = slots.firstIndex(where: { $0.id == slotID }) {
                currentSetIndex = slotIndex
                if isSetRest { beginCurrentSet(); retainedPhase = false }
            } else {
                currentSetIndex = min(currentSetIndex, max(0, slots.count - 1))
                if !isSectionRest { beginCurrentSet(); retainedPhase = false }
            }
            if retainedPhase { timeRemaining = max(0, timeRemaining + phaseDuration - oldDuration) }
        } else {
            currentSectionIndex = min(currentSectionIndex, updated.sections.count - 1)
            currentSetIndex = 0
            beginCurrentSet()
        }
        if oldPageID != currentSlot?.exercisePageID { currentMediaIndex = 0 }
        saveResumeState()
    }

    // MARK: - Body

    var body: some View {
        contentLayer
            .font(TimeMasterFont.body())
            .accessibilityHidden(showWorkoutManagement || showPageOverlay)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { backgroundLayer }
            .overlay {
                if musicStarted && musicSession.activeClip != nil && !workoutCompleted && !showWorkoutManagement && !showPageOverlay {
                    GeometryReader { geometry in
                        WorkoutFloatingMusicControls(session: musicSession, library: musicLibrary, onOpenTimeline: toggleOverlayMusic)
                            .padding(.top, max(0, playerHeaderBottom - geometry.frame(in: .global).minY))
                    }
                }
            }
            .interactiveDismissDisabled()
            .slotNavigationInteractionDisabled(true)
            .onReceive(store.$workouts, perform: reconcileLiveWorkout)
            .onAppear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = true
                #endif
                AudioManager.shared.activateSession()
                WorkoutHaptics.shared.prepare()
                refreshPlaybackSequences()
                tryResumeState()
            }
            .onChange(of: currentSectionIndex) { _ in
                currentMediaIndex = 0
            }
            .onDisappear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = false
                #endif
                timer?.invalidate()
                AudioManager.shared.stopSpeaking()
                endBackgroundTask()
                musicSession.stop()
                musicStarted = false
                #if os(iOS)
                WorkoutNowPlayingController.shared.end()
                nowPlayingStarted = false
                if !workoutCompleted {
                    WorkoutLiveActivityController.shared.end(completed: false, elapsedSeconds: elapsedSeconds)
                }
                #endif
                if !workoutCompleted {
                    WorkoutLiveSession.shared.finish(completed: false, elapsedSeconds: elapsedSeconds)
                }
            }
            .onReceive(WorkoutLiveSession.shared.commands) { handleMenuBarCommand($0) }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                saveResumeState()
                beginBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                endBackgroundTask()
                reconcileAfterInterruption()
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutLiveActivityCommand)) { notification in
                handleLiveActivityCommand(notification.userInfo?["command"] as? String)
            }
            #endif
            .alert("Stop Workout?", isPresented: $showingCloseConfirmation) {
                Button("Continue", role: .cancel) {}
                Button("Stop", role: .destructive) { stopWorkout() }
            } message: {
                Text("Your progress will be lost.")
            }
            .overlay {
                if showMediaOverlay, let item = overlayMediaItem {
                    mediaOverlayView(item: item)
                }
            }
            .overlay {
                if showWorkoutManagement {
                    NavigationStack {
                        WorkoutDetailView(workout: workout, liveContext: liveContext) {
                            showWorkoutManagement = false
                        }
                        .environmentObject(musicLibrary)
                    }
                    .background(Theme.background)
                    .keyNavHost()
                    .transition(.opacity)
                }
            }
            .overlay {
                if showPageOverlay, let pageID = overlayPageID {
                    WorkoutAttachmentBrowser(workout: workout, pageID: pageID, liveContext: liveContext) {
                        showPageOverlay = false
                        overlayPageID = nil
                        overlayPageName = ""
                    }
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showWorkoutManagement)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showPageOverlay)
            .sheet(isPresented: $showBundleReorder) {
                if let section = currentSection {
                    BundleEditorSheet(section: section) { updated in
                        store.updateSection(in: workout, section: updated)
                    }
                }
            }
            .mediaViewerCover(isPresented: $showMediaViewer) {
                if let catalog = mediaViewerCatalog {
                    PageMediaGallery(
                        urls: catalog.urls,
                        selectedIndex: $mediaViewerIndex,
                        isPresented: $showMediaViewer,
                        comments: catalog.comments,
                        onSaveComment: { url, text in
                            try catalog.save(text, for: url, databaseStore: databaseStore, notes: MediaNotesStore.shared)
                        },
                        opensEditor: mediaViewerOpensEditor,
                        notesAssets: { catalog.assets(for: $0, databaseStore: databaseStore, notes: MediaNotesStore.shared) },
                        workout: workout,
                        liveContext: liveContext,
                        databasePageID: { catalog.pageID(for: $0) ?? catalog.firstPageID }
                    )
                    .environmentObject(databaseStore)
                    .environmentObject(store)
                    .keyNavHost()
                }
            }
            .sheet(isPresented: $showMusicChooser) {
                WorkoutMusicPlaybackSheet(
                    workout: workout,
                    isContinuationPrompt: musicChooserIsAutomatic,
                    library: musicLibrary,
                    session: musicSession
                )
            }
            .onChange(of: musicSession.exhausted) { _ in offerMusicContinuation() }
            .onChange(of: isMusicContinuationRest) { eligible in
                if eligible { offerMusicContinuation() }
                else if musicChooserIsAutomatic { showMusicChooser = false }
            }
            .alert("Music Unavailable", isPresented: Binding(
                get: { musicSession.error != nil },
                set: { if !$0 { musicSession.error = nil } }
            )) {
                Button("OK", role: .cancel) { musicSession.error = nil }
            } message: { Text(musicSession.error ?? "") }
    }

    // MARK: - Content routing

    @ViewBuilder
    private var contentLayer: some View {
        if workoutCompleted {
            PlayerCompletedView(
                workoutName: workout.name,
                elapsedSeconds: elapsedSeconds,
                exerciseCount: playbackBySection.values.reduce(0) { $0 + $1.count },
                sectionCount: workout.sections.count,
                onDone: { dismiss() }
            )
        } else if showingWarmUpPicker {
            warmUpPickerView
        } else if isWarmUp {
            warmUpView
        } else if isPreparation {
            preparationView
        } else if isSetRest || isSectionRest {
            restView
        } else {
            activeSectionView
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black
            if let url = (workoutCompleted ? nil : (upNextItemForBackdrop ?? currentItem)?.coverURL) {
                AsyncCoverImage(url: url, fallbackIcon: "", height: 400, overlayGradient: false)
                    .scaleEffect(2.6)
                    .blur(radius: 28)
                    .opacity(0.4)
                    .id(url)
                    .transition(.opacity)
            }
            Color.black.opacity(0.5)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: currentItem?.coverURL)
    }

    private var upNextItemForBackdrop: PlayerQueueItem? {
        guard !showingWarmUpPicker, isWarmUp || isSetRest || isSectionRest else { return nil }
        return upNextItem
    }

    // MARK: - Shared chrome

    private var topBar: some View {
        HStack(spacing: 10) {
            closeButton(confirmed: !showingWarmUpPicker)
            Spacer(minLength: 0)
            musicButton
            if isBundleSection && !showingWarmUpPicker {
                Button { showBundleReorder = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .keyNavTarget(shape: .circle)
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Bundle order and settings")
            }
            if !showingWarmUpPicker {
                PlayerSectionBadge(current: currentSectionIndex, count: workout.sections.count)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func closeButton(confirmed: Bool) -> some View {
        Button {
            if confirmed { showingCloseConfirmation = true } else { dismiss() }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
        .keyNavTarget(shape: .circle)
        .accessibilityLabel("Close workout")
    }

    private var musicButton: some View {
        HStack(spacing: 6) {
            if !showingWarmUpPicker {
                Button { showWorkoutManagement = true } label: {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .keyNavTarget(shape: .circle)
                .accessibilityLabel("Manage active workout")
                .accessibilityValue("Section \(currentSectionIndex + 1) of \(workout.sections.count)")
            }
            Button(action: toggleOverlayMusic) {
                Image(systemName: musicSession.isPlaying ? "music.note" : "music.note.list")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(musicSession.isPlaying ? 0.25 : 0.12), in: Circle())
            }
            .keyNavTarget(shape: .circle)
            .accessibilityLabel("Choose workout music")
            .accessibilityValue(musicSession.title ?? "Silence")
        }
        .foregroundStyle(.white)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { playerHeaderBottom = $0 }
    }

    private func togglePause() {
        if isPaused { resumeTimer() } else { pauseTimer() }
    }

    private var controlsRow: some View {
        HStack(spacing: 28) {
            PlayerTransportButton(symbol: "backward.end.fill", label: isBundleSection ? "Previous exercise" : "Previous", isEnabled: canGoBack, action: goBack)
            PlayerPlayButton(isPaused: isPaused, action: togglePause)
            PlayerTransportButton(symbol: "forward.end.fill", label: isBundleSection ? "Next exercise" : "Next", action: skipCurrentPhase)
        }
    }

    private func skipButton(_ title: String, width: CGFloat = 180, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TimeMasterFont.black(17, relativeTo: .headline))
                .foregroundColor(.black)
                .frame(width: width, height: 48)
                .background(Color.white)
                .cornerRadius(14)
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(title)
    }

    private var finishChip: some View {
        Image(systemName: "flag.checkered")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: 50, height: 50)
            .background(.white.opacity(0.1), in: Circle())
            .accessibilityLabel("Last exercise of the workout")
    }

    // MARK: - Warm-up picker

    private var warmUpPickerView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 24) {
                        TimeMasterPageTitle("Warm Up", size: 42, relativeTo: .title)
                            .foregroundStyle(.white)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            warmUpButton(value: 0, label: "Skip")
                            warmUpButton(value: 30, label: "0:30")
                            warmUpButton(value: 60, label: "1:00")
                            warmUpButton(value: 90, label: "1:30")
                            warmUpButton(value: 120, label: "2:00")
                            warmUpButton(value: 180, label: "3:00")
                        }
                        Button {
                            showingWarmUpPicker = false
                            if warmUpDuration > 0 { startWarmUp() } else { startWorkout() }
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: 480)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, geometry.size.height - 72))
                }
            }
        }
    }

    private func warmUpButton(value: Int, label: String) -> some View {
        Button { warmUpDuration = value } label: {
            Text(label)
                .font(warmUpDuration == value
                      ? TimeMasterFont.black(15, relativeTo: .subheadline)
                      : TimeMasterFont.body(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundColor(warmUpDuration == value ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(warmUpDuration == value ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(12)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
        .accessibilityLabel(value == 0 ? "No warm-up" : "\(value) seconds warm-up")
        .accessibilityAddTraits(warmUpDuration == value ? .isSelected : [])
    }

    // MARK: - Warm-up and preparation

    private var warmUpView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                    PlayerPhaseCaption(phase: .warmUp)
                    breakCounter
                    PlayerPlayButton(isPaused: isPaused, action: togglePause).padding(.top, 6)
                    skipButton("Skip Warm Up", action: skipWarmUp).padding(.top, 8)
                    upNextCard(upNextItem).padding(.top, 10)
                }
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var preparationView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                    PlayerPhaseCaption(phase: .prepare)
                    breakCounter
                    PlayerPlayButton(isPaused: isPaused, action: togglePause).padding(.top, 6)
                    skipButton("Skip Preparation", action: skipPreparation).padding(.top, 8)
                    upNextCard(currentItem, label: "Get ready").padding(.top, 10)
                    if isBundleSection { stageStrip(section: currentSection, index: currentSetIndex) }
                }
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Active section

    private var activeSectionView: some View {
        Group {
            if isBundleActive {
                bundleSectionView
            } else {
                timedSectionView
            }
        }
    }

    private var timedSectionView: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            VStack(spacing: compact ? 8 : 14) {
                topBar
                mediaCarousel
                titleBlock
                PlayerCounter(seconds: timeRemaining, size: compact ? 56 : 68, phase: .active, isPaused: isPaused)
                    .frame(maxWidth: .infinity)
                controlsRow
                nextPill
                    .frame(minHeight: 50)
            }
            .padding(.bottom, 10)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var titleBlock: some View {
        let progress = mainSetProgress
        return VStack(spacing: 8) {
            if let section = currentSection, let pageID = currentSlot?.exercisePageID ?? section.pageID {
                Button {
                    openPageOverlay(id: pageID, name: currentSlot?.displayName ?? section.name)
                } label: {
                    HStack(spacing: 6) {
                        Text(currentSlot?.displayName ?? section.name)
                            .font(TimeMasterFont.black(26, relativeTo: .title2))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "book.pages")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .accessibilityHidden(true)
                    }
                }
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityHint("Opens the exercise page")
            } else {
                Text(currentSlot?.displayName ?? currentSection?.name ?? "")
                    .font(TimeMasterFont.black(26, relativeTo: .title2))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 32)
            }
            HStack(spacing: 14) {
                if progress.count > 1 {
                    PlayerSetDots(count: progress.count, current: progress.index)
                }
                if let item = currentItem {
                    PlayerItemFacts(item: item, showsDuration: false)
                }
            }
        }
    }

    @ViewBuilder
    private var nextPill: some View {
        if let next = upNextItem {
            PlayerNextPill(item: next) { openPreview(next) }
        } else if isLastExercise {
            finishChip
        }
    }

    private var bundleSectionView: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let section = currentSection {
                        let rounds = bundleRoundProgress
                        let following = nextPosition(afterSection: currentSectionIndex, slot: currentSetIndex)
                        PlayerBundleStage(
                            items: queueItems(for: section),
                            currentIndex: currentSetIndex,
                            setStarts: setStartsBySection[section.id] ?? [],
                            isRandom: section.bundleOrder == .random,
                            next: following.flatMap { item(atSection: $0.section, slot: $0.slot) },
                            isFinal: following == nil,
                            onOpen: openPreview,
                            onJump: jump(to:)
                        )
                        if rounds.count > 1 {
                            HStack(spacing: 10) {
                                Image(systemName: "repeat").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                                    .accessibilityHidden(true)
                                PlayerSetDots(count: rounds.count, current: rounds.index, noun: "Round")
                            }
                        }
                    }
                    PlayerCounter(seconds: timeRemaining, size: 64, phase: .active, isPaused: isPaused)
                        .frame(maxWidth: .infinity)
                    controlsRow
                }
                .frame(maxWidth: 560)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rest

    private var restView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    PlayerPhaseCaption(phase: livePhase)
                    if isSetRest, !isBundleSection {
                        let progress = mainSetProgress
                        PlayerSetDots(count: progress.count, current: min(progress.count - 1, progress.index))
                            .padding(.vertical, 4)
                    }
                    if isSetRest, let slot = restSlot, let pageID = slot.restExercisePageID, let page = databaseStore.page(id: pageID) {
                        Button {
                            openPageOverlay(id: pageID, name: page.title)
                        } label: {
                            Label("Rest exercise: \(page.title)", systemImage: "figure.cooldown")
                                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                                .lineLimit(1)
                        }
                        .buttonStyle(TimeMasterActionButtonStyle())
                    }
                    if !restExtensionText.isEmpty {
                        Text(restExtensionText)
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline).monospacedDigit())
                            .foregroundColor(.white)
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                    breakCounter
                    PlayerPlayButton(isPaused: isPaused, action: togglePause).padding(.top, 4)
                    HStack(spacing: 12) {
                        restAdjustButton(seconds: extraRestSeconds)
                        restAdjustButton(seconds: extraRestSeconds * 2)
                        skipButton("Skip Rest", width: 100, action: skipRest)
                    }
                    .padding(.top, 6)
                    upNextCard(upNextItem).padding(.top, 10)
                    if isBundleSection {
                        if isSetRest { stageStrip(section: currentSection, index: currentSetIndex) }
                        else if currentSectionIndex + 1 < workout.sections.count {
                            stageStrip(section: workout.sections[currentSectionIndex + 1], index: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var breakCounter: some View {
        PlayerCounter(seconds: timeRemaining, size: 84, phase: livePhase, isPaused: isPaused)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
                if livePhase == .setRest || livePhase == .sectionRest { restPickerMenu }
            }
    }

    @ViewBuilder
    private func upNextCard(_ item: PlayerQueueItem?, label: String = "Up next") -> some View {
        if let item {
            PlayerUpNextCard(item: item, label: label) { openPreview(item) }
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func stageStrip(section: Section?, index: Int) -> some View {
        if let section {
            PlayerQueueStrip(
                items: queueItems(for: section), currentIndex: index,
                setStarts: setStartsBySection[section.id] ?? [], isRandom: section.bundleOrder == .random,
                onJump: jump(to:), onOpen: openPreview
            )
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
        }
    }

    private var restPickerMenu: some View {
        Group {
            Button { extendRest(by: 15) } label: {
                Label("+15 seconds", systemImage: "plus")
            }
            Button { extendRest(by: 30) } label: {
                Label("+30 seconds", systemImage: "plus")
            }
            Button { extendRest(by: 60) } label: {
                Label("+60 seconds", systemImage: "plus")
            }
        }
    }

    private func restAdjustButton(seconds: Int) -> some View {
        let canExtend = restExtensionTotal + seconds <= 120
        return Button { extendRest(by: seconds) } label: {
            Text("+\(seconds)s")
                .font(TimeMasterFont.black(14, relativeTo: .subheadline).monospacedDigit())
                .frame(width: 56)
        }
        .buttonStyle(TimeMasterActionButtonStyle())
        .disabled(!canExtend)
        .accessibilityLabel("Add \(seconds) seconds of rest")
    }

    private func extendRest(by seconds: Int) {
        guard restExtensionTotal + seconds <= 120 else { return }
        restExtensionTotal += seconds
        timeRemaining += seconds
        saveResumeState()
        WorkoutHaptics.shared.play(.adjust)
        restExtensionText = "+\(seconds) seconds"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                restExtensionText = ""
            }
        }
    }

    // MARK: - Media carousel

    @ViewBuilder
    private var mediaCarousel: some View {
        let catalog = currentMediaCatalog
        if !catalog.entries.isEmpty {
            WorkoutMediaPager(
                entries: catalog.entries,
                comments: catalog.comments,
                index: $currentMediaIndex,
                onOpen: { openMediaViewer(catalog, index: $0, opensEditor: false) },
                onSwipeUp: { openMediaViewer(catalog, index: $0, opensEditor: true) },
                isPaused: isPaused
            )
        } else {
            Spacer(minLength: 0)
        }
    }

    private var currentMediaCatalog: WorkoutMediaCatalog {
        WorkoutMediaCatalog(
            pageIDs: [currentSlot?.exercisePageID ?? currentSection?.pageID].compactMap { $0 },
            sections: currentSection.map { [$0] } ?? [],
            databaseStore: databaseStore,
            notes: MediaNotesStore.shared,
            sectionMediaFirst: true
        )
    }

    private func openMediaViewer(_ catalog: WorkoutMediaCatalog, index: Int, opensEditor: Bool) {
        mediaViewerCatalog = catalog
        mediaViewerIndex = min(max(0, index), max(0, catalog.entries.count - 1))
        mediaViewerOpensEditor = opensEditor
        showMediaViewer = true
    }

    // MARK: - Queue items

    private func mediaURL(_ item: MediaItem) -> URL {
        item.type == .video ? PhotoManager.shared.videoURL(for: item.filename) : PhotoManager.shared.photoURL(for: item.filename)
    }

    private func queueItem(for slot: SetSlot, in section: Section) -> PlayerQueueItem {
        let pageID = slot.exercisePageID ?? (section.mode == .timed ? section.pageID : nil)
        let page = pageID.flatMap { databaseStore.page(id: $0) }
        let media = slot.exercisePageID == nil ? section.mediaItems.first : nil
        return PlayerQueueItem(
            id: slot.id,
            name: slot.displayName,
            pageID: pageID,
            mediaItem: pageID == nil ? media : nil,
            coverURL: page?.coverImageURL ?? media.map(mediaURL),
            symbol: page?.effectiveWorkoutType?.iconName ?? workout.type.iconName,
            duration: slot.duration,
            repCount: slot.repCount ?? section.repCount,
            isDrop: dropIDs.contains(slot.id)
        )
    }

    private func queueItems(for section: Section) -> [PlayerQueueItem] {
        playbackSlots(for: section).map { queueItem(for: $0, in: section) }
    }

    private func item(atSection sectionIndex: Int, slot slotIndex: Int) -> PlayerQueueItem? {
        guard workout.sections.indices.contains(sectionIndex) else { return nil }
        let section = workout.sections[sectionIndex]
        guard let slot = playbackSlots(for: section)[safe: slotIndex] else { return nil }
        return queueItem(for: slot, in: section)
    }

    private func nextPosition(afterSection sectionIndex: Int, slot slotIndex: Int) -> (section: Int, slot: Int)? {
        guard workout.sections.indices.contains(sectionIndex) else { return nil }
        if slotIndex + 1 < playbackSlots(for: workout.sections[sectionIndex]).count { return (sectionIndex, slotIndex + 1) }
        var next = sectionIndex + 1
        while workout.sections.indices.contains(next) {
            if !playbackSlots(for: workout.sections[next]).isEmpty { return (next, 0) }
            next += 1
        }
        return nil
    }

    // MARK: - Timer Logic

    private func playbackSlots(for section: Section) -> [SetSlot] {
        playbackBySection[section.id] ?? section.playbackSlots()
    }

    private func refreshPlaybackSequences() {
        let expanded = store.flattenedWorkout(workout)
        var sequences: [UUID: [SetSlot]] = [:]
        var starts: [UUID: Set<Int>] = [:]
        var drops: Set<UUID> = []
        for section in expanded.sections {
            if section.mode == .bundle {
                if section.bundleOrder == .random {
                    let exercises = section.bundleSets.flatMap(\.leafExercises)
                    let valid = Set(exercises.map(\.id))
                    let retained = (bundleOrders[section.id.uuidString] ?? []).filter { valid.contains($0) }
                    let known = Set(retained)
                    let newIDs = exercises.filter { !known.contains($0.id) }.map(\.id).shuffled()
                    bundleOrders[section.id.uuidString] = retained + newIDs
                } else {
                    bundleOrders.removeValue(forKey: section.id.uuidString)
                }
                sequences[section.id] = section.playbackSlots(order: bundleOrders[section.id.uuidString])
                var index = 0
                var setStarts: Set<Int> = []
                for set in section.bundleSets {
                    setStarts.insert(index)
                    for exercise in set.leafExercises {
                        index += 1 + exercise.drops.count
                        drops.formUnion(exercise.drops.map(\.id))
                    }
                }
                starts[section.id] = setStarts
            } else {
                sequences[section.id] = section.playbackSlots()
                drops.formUnion(section.effectiveSlots.flatMap(\.drops).map(\.id))
            }
        }
        playbackBySection = sequences
        setStartsBySection = starts
        dropIDs = drops
    }

    private func sectionRestDuration(_ section: Section) -> Int {
        section.bigRestRow?.duration ?? section.customRestAfter ?? workout.restBetweenSections
    }

    private func speakPhase(_ text: String) {
        AudioManager.shared.stopSpeaking()
        guard !isPaused, isWarmUp || currentSection?.mode != .bundle || currentSection?.bundleVoiceEnabled == true else { return }
        AudioManager.shared.speak(text)
    }

    private func restartCurrentExercise() {
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        beginCurrentSet()
    }

    private func startWorkout() {
        AudioManager.shared.stopSpeaking()
        refreshPlaybackSequences()
        startTime = Date()
        currentSectionIndex = 0
        currentSetIndex = 0
        isSetRest = false
        isSectionRest = false
        isWarmUp = false
        isPreparation = false
        resetMotivationTimer()
        musicStarted = true
        offeredMusicContinuation = false
        Task { await musicSession.start(workout: workout, library: musicLibrary, paused: isPaused) }
        beginCurrentSet()
    }

    private func startWarmUp() {
        isWarmUp = true
        isPreparation = false
        timeRemaining = warmUpDuration
        WorkoutHaptics.shared.play(.warmUpStart)
        speakPhase("Warm up")
        startTimer()
    }

    private func skipWarmUp() {
        timer?.invalidate()
        isWarmUp = false
        startWorkout()
    }

    private func beginCurrentSet() {
        AudioManager.shared.stopSpeaking()
        guard let section = currentSection, let slot = currentSlot else {
            completeWorkout()
            return
        }

        isSetRest = false
        isSectionRest = false
        if section.preparationTime(for: slot) > 0 {
            startPreparation()
        } else {
            finishPreparation()
        }
    }

    private func startPreparation() {
        guard let section = currentSection, let slot = currentSlot else {
            completeWorkout()
            return
        }

        isWarmUp = false
        isSetRest = false
        isSectionRest = false
        isPreparation = true
        timeRemaining = section.preparationTime(for: slot)
        WorkoutHaptics.shared.play(.prepareStart)
        speakPhase("Preparation")
        startTimer()
    }

    private func finishPreparation() {
        guard let section = currentSection else {
            completeWorkout()
            return
        }

        isPreparation = false
        timeRemaining = currentSlot?.duration ?? section.duration
        WorkoutHaptics.shared.play(.exerciseStart)
        speakPhase(currentSlot?.displayName ?? section.name)
        startTimer()
    }

    private func skipPreparation() {
        timer?.invalidate()
        finishPreparation()
    }

    private func startTimer() {
        timer?.invalidate()
        timerGeneration = UUID()
        let generation = timerGeneration
        saveResumeState()
        guard timeRemaining > 0 else { finishCurrentTimerPhase(); return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if generation == timerGeneration && !isPaused { tick() }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            finishCurrentTimerPhase()
            return
        }

        timeRemaining -= 1
        elapsedSeconds += 1
        if timeRemaining <= 3 && timeRemaining >= 1 {
            AudioManager.shared.playCountdownBeep()
            WorkoutHaptics.shared.play(.countdownTick)
        }
        if !isSetRest && !isSectionRest && !isWarmUp && !isPreparation && !isBundleActive {
            tickMotivation()
            checkTimeAnnouncement()
        }
        autoSaveCounter += 1
        if autoSaveCounter >= 5 {
            autoSaveCounter = 0
            saveResumeState()
        }
        publishLiveState()
        if timeRemaining == 0 {
            finishCurrentTimerPhase()
        }
    }

    private func finishCurrentTimerPhase() {
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        if isWarmUp {
            isWarmUp = false
            startWorkout()
        } else if isPreparation {
            finishPreparation()
        } else if isSetRest {
            endSetRest()
        } else if isSectionRest {
            advanceToNextSection()
        } else {
            endWorkPeriod()
        }
    }

    // MARK: - System surfaces

    private func saveResumeState() {
        WorkoutResumeManager.shared.saveState(
            workoutId: workout.id,
            workoutName: workout.name,
            currentSectionIndex: currentSectionIndex,
            currentSetIndex: currentSetIndex,
            timeRemaining: timeRemaining,
            elapsedSeconds: elapsedSeconds,
            phase: livePhase,
            isPaused: isPaused,
            musicCheckpoint: musicSession.checkpoint,
            bundleOrders: bundleOrders
        )
        publishLiveState()
        #if os(iOS)
        syncLiveActivity()
        syncNowPlaying()
        #endif
    }

    private func liveTitles(for phase: WorkoutPhase) -> (title: String, nextTitle: String?) {
        let exerciseName = currentSlot?.displayName ?? currentSection?.name ?? ""
        switch phase {
        case .warmUp: return ("Warm up", exerciseName)
        case .prepare: return ("Get ready", exerciseName)
        case .active: return (exerciseName, nextExerciseName)
        case .setRest: return ("Rest", exerciseName)
        case .sectionRest: return ("Rest", workout.sections[safe: currentSectionIndex + 1]?.name)
        }
    }

    private func liveActivitySubtitle(for phase: WorkoutPhase) -> String {
        guard phase != .warmUp, let section = currentSection else { return "" }
        var parts: [String] = []
        if phase != .sectionRest {
            if section.mode == .bundle {
                let count = playbackSlots(for: section).count
                if count > 1 { parts.append("Exercise \(min(currentSetIndex + 1, count)) of \(count)") }
            } else {
                let progress = mainSetProgress
                if progress.count > 1 { parts.append("Set \(progress.index + 1) of \(progress.count)") }
            }
        }
        if workout.sections.count > 1 {
            let sectionNumber = currentSectionIndex + (phase == .sectionRest ? 2 : 1)
            parts.append("Section \(sectionNumber) of \(workout.sections.count)")
        }
        return parts.joined(separator: " · ")
    }

    private func publishLiveState() {
        guard !showingWarmUpPicker, !workoutCompleted else { return }
        let phase = livePhase
        let titles = liveTitles(for: phase)
        WorkoutLiveSession.shared.publish(
            WorkoutLiveState(
                workoutID: workout.id,
                workoutName: workout.name,
                colorHex: workout.colorHex,
                phase: phase,
                title: titles.title.isEmpty ? workout.name : titles.title,
                subtitle: liveActivitySubtitle(for: phase),
                isPaused: isPaused,
                remainingSeconds: max(0, timeRemaining),
                phaseDuration: max(0, phaseDuration),
                sectionIndex: currentSectionIndex,
                sectionCount: workout.sections.count,
                elapsedSeconds: max(0, elapsedSeconds),
                totalSeconds: workout.totalDuration,
                nextTitle: titles.nextTitle.flatMap { $0.isEmpty ? nil : $0 },
                startedAt: startTime
            )
        )
    }

    private func handleMenuBarCommand(_ command: WorkoutLiveSession.Command) {
        guard !workoutCompleted, !showingWarmUpPicker else { return }
        switch command {
        case .togglePause:
            if isPaused { resumeTimer() } else { pauseTimer() }
        case .skipPhase:
            skipCurrentPhase()
        case .endWorkout:
            stopWorkout()
            return
        }
        publishLiveState()
    }

    #if os(iOS)
    private func syncLiveActivity() {
        guard !showingWarmUpPicker, !workoutCompleted, let section = currentSection else { return }
        let phase = livePhase
        let titles = liveTitles(for: phase)
        let isRest = phase == .setRest || phase == .sectionRest
        let slotCount = playbackSlots(for: section).count
        let mainProgress = mainSetProgress
        let count = section.mode == .bundle ? slotCount : mainProgress.count
        var index = section.mode == .bundle ? currentSetIndex + 1 : mainProgress.index + 1
        if phase == .setRest { index = max(1, index - 1) }
        if phase == .sectionRest { index = count }
        let current = (phase == .active || phase == .prepare) ? currentItem : nil
        let next = upNextItem
        WorkoutLiveActivityController.shared.sync(
            WorkoutLiveActivitySnapshot(
                workoutID: workout.id,
                workoutName: workout.name,
                colorHex: workout.colorHex,
                phase: phase,
                title: titles.title,
                subtitle: liveActivitySubtitle(for: phase),
                isPaused: isPaused,
                remainingSeconds: timeRemaining,
                phaseDuration: phaseDuration,
                elapsedSeconds: elapsedSeconds,
                nextTitle: titles.nextTitle,
                startedAt: startTime,
                itemIndex: phase == .warmUp ? nil : index,
                itemCount: phase == .warmUp ? nil : count,
                sectionIndex: currentSectionIndex,
                sectionCount: workout.sections.count,
                isBundle: section.mode == .bundle,
                nextKind: liveNextKind(for: phase, hasNext: next != nil),
                artworkName: isRest ? nil : liveArtworkName(for: current?.coverURL),
                nextArtworkName: liveArtworkName(for: next?.coverURL)
            )
        )
    }

    private func liveNextKind(for phase: WorkoutPhase, hasNext: Bool) -> String? {
        guard hasNext else { return "finish" }
        switch phase {
        case .warmUp, .setRest: return "exercise"
        case .sectionRest: return "section"
        case .prepare, .active:
            guard let position = nextPosition(afterSection: currentSectionIndex, slot: currentSetIndex) else { return "finish" }
            return position.section == currentSectionIndex ? "exercise" : "section"
        }
    }

    private func liveArtworkName(for url: URL?) -> String? {
        guard let url else { return nil }
        if let name = liveArtworkNames[url.path] { return name }
        guard !liveArtworkRequests.contains(url.path) else { return nil }
        liveArtworkRequests.insert(url.path)
        Task.detached(priority: .utility) {
            let image = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: 240)
            guard let data = image?.jpegData(compressionQuality: 0.72),
                  let name = WorkoutLiveActivityArtwork.store(jpeg: data, key: url.deletingPathExtension().lastPathComponent) else { return }
            await MainActor.run {
                liveArtworkNames[url.path] = name
                syncLiveActivity()
            }
        }
        return nil
    }

    private func syncNowPlaying() {
        guard WorkoutNowPlayingController.isSupported, !showingWarmUpPicker, !workoutCompleted else { return }
        if !nowPlayingStarted {
            nowPlayingStarted = true
            WorkoutNowPlayingController.shared.begin { handleRemoteCommand($0) }
        }
        let phase = livePhase
        let titles = liveTitles(for: phase)
        let artworkItem = phase == .setRest || phase == .sectionRest || phase == .warmUp ? upNextItem : currentItem
        var album = liveActivitySubtitle(for: phase)
        if phase != .active, let next = titles.nextTitle, !next.isEmpty {
            album = album.isEmpty ? next : "\(next) · \(album)"
        } else if let next = titles.nextTitle, !next.isEmpty {
            album = album.isEmpty ? "Next: \(next)" : "\(album) · Next: \(next)"
        }
        WorkoutNowPlayingController.shared.update(
            WorkoutNowPlayingSnapshot(
                title: titles.title.isEmpty ? workout.name : titles.title,
                artist: workout.name,
                album: album,
                phaseDuration: max(1, phaseDuration),
                elapsedInPhase: max(0, phaseDuration - timeRemaining),
                isPaused: isPaused,
                artworkURL: artworkItem?.coverURL
            )
        )
    }

    private func handleLiveActivityCommand(_ command: String?) {
        guard !workoutCompleted, !showingWarmUpPicker else { return }
        if !isPaused, UIApplication.shared.applicationState != .active {
            reconcileAfterInterruption()
            guard !workoutCompleted else { return }
        }
        switch command {
        case "togglePause": if isPaused { resumeTimer() } else { pauseTimer() }
        case "skipPhase": skipCurrentPhase()
        default: break
        }
    }

    private func handleRemoteCommand(_ command: WorkoutRemoteCommand) {
        guard !workoutCompleted, !showingWarmUpPicker else { return }
        switch command {
        case .pause: if !isPaused { pauseTimer() }
        case .resume: if isPaused { resumeTimer() }
        case .toggle: if isPaused { resumeTimer() } else { pauseTimer() }
        case .next: skipCurrentPhase()
        case .previous: goBack()
        case .skip(let seconds): moveTime(by: seconds)
        case .seek(let position): seek(toElapsed: position)
        }
    }
    #endif

    // MARK: - Resume and reconcile

    private func tryResumeState() {
        guard !didInitFromResume,
              let state = WorkoutResumeManager.shared.resumeState,
              state.workoutId == workout.id
        else { return }
        didInitFromResume = true
        restore(from: state)
    }

    /// iOS can suspend a normal app at any time, especially on devices without
    /// Live Activities. Reconstructing from the timestamped checkpoint keeps the
    /// workout honest without promising background execution that iOS cannot give.
    private func reconcileAfterInterruption() {
        guard !workoutCompleted,
              let state = WorkoutResumeManager.shared.resumeState,
              state.workoutId == workout.id
        else { return }
        restore(from: state)
    }

    private func restore(from savedCheckpoint: ResumeState) {
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        bundleOrders = savedCheckpoint.bundleOrders ?? [:]
        refreshPlaybackSequences()
        var checkpoint = savedCheckpoint
        if checkpoint.bundleOrders == nil, checkpoint.phase == .active,
           let section = workout.sections[safe: checkpoint.currentSectionIndex], section.mode == .bundle,
           checkpoint.timeRemaining == 0 {
            checkpoint.timeRemaining = playbackSlots(for: section)[safe: checkpoint.currentSetIndex]?.duration ?? section.duration
            checkpoint.savedAt = Date()
        }
        let state = reconciledState(from: checkpoint)
        showingWarmUpPicker = false
        currentSectionIndex = state.currentSectionIndex
        currentSetIndex = state.currentSetIndex
        timeRemaining = state.timeRemaining
        elapsedSeconds = state.elapsedSeconds
        isPaused = state.isPaused
        startTime = Date().addingTimeInterval(-TimeInterval(state.elapsedSeconds))
        isWarmUp = false
        isPreparation = false
        isSetRest = false
        isSectionRest = false
        restExtensionTotal = 0
        switch state.phase {
        case .warmUp:
            isWarmUp = true
        case .prepare:
            isPreparation = true
        case .setRest:
            isSetRest = true
        case .sectionRest:
            isSectionRest = true
        case .active:
            break
        }
        guard !workoutCompleted else {
            completeWorkout()
            return
        }
        currentMediaIndex = 0
        resetMotivationTimer()
        if !musicStarted && !isWarmUp {
            musicStarted = true
            let musicElapsed = checkpoint.musicCheckpoint.map {
                $0.cursor.elapsed + Double(max(0, state.elapsedSeconds - checkpoint.elapsedSeconds))
            } ?? Double(state.elapsedSeconds)
            Task {
                await musicSession.start(workout: workout, library: musicLibrary,
                                         checkpoint: checkpoint.musicCheckpoint, paused: state.isPaused,
                                         elapsed: musicElapsed)
            }
        }
        if !isPaused {
            startTimer()
        }
        saveResumeState()
    }

    private func reconciledState(from checkpoint: ResumeState) -> ResumeState {
        var state = checkpoint
        guard !checkpoint.isPaused else { return state }
        var elapsedToConsume = max(0, Int(Date().timeIntervalSince(checkpoint.savedAt)))
        guard elapsedToConsume > 0 else { return state }

        while elapsedToConsume > 0 {
            if state.timeRemaining > elapsedToConsume {
                state.timeRemaining -= elapsedToConsume
                state.elapsedSeconds += elapsedToConsume
                elapsedToConsume = 0
                break
            }

            let consumed = max(0, state.timeRemaining)
            state.elapsedSeconds += consumed
            elapsedToConsume -= consumed
            guard advanceReconciledPhase(&state) else {
                workoutCompleted = true
                break
            }
        }
        state.savedAt = Date()
        return state
    }

    private func configureReconciledCurrentSet(_ state: inout ResumeState) -> Bool {
        guard workout.sections.indices.contains(state.currentSectionIndex) else { return false }
        let section = workout.sections[state.currentSectionIndex]
        guard let slot = playbackSlots(for: section)[safe: state.currentSetIndex] else { return false }

        let preparationTime = section.preparationTime(for: slot)
        if preparationTime > 0 {
            state.phase = .prepare
            state.timeRemaining = preparationTime
        } else {
            state.phase = .active
            state.timeRemaining = slot.duration
        }
        return true
    }

    /// Advances a checkpoint without scheduling a Timer or speaking audio. It is
    /// deliberately the same state machine used by the visible timer.
    private func advanceReconciledPhase(_ state: inout ResumeState) -> Bool {
        switch state.phase {
        case .warmUp:
            state.currentSectionIndex = 0
            state.currentSetIndex = 0
            return configureReconciledCurrentSet(&state)
        case .prepare:
            guard workout.sections.indices.contains(state.currentSectionIndex) else { return false }
            let section = workout.sections[state.currentSectionIndex]
            guard let slot = playbackSlots(for: section)[safe: state.currentSetIndex] else { return false }
            state.phase = .active
            state.timeRemaining = slot.duration
            return true
        case .setRest:
            return configureReconciledCurrentSet(&state)
        case .active:
            guard workout.sections.indices.contains(state.currentSectionIndex) else { return false }
            let section = workout.sections[state.currentSectionIndex]
            let slots = playbackSlots(for: section)
            if state.currentSetIndex + 1 < slots.count {
                let rest = slots[safe: state.currentSetIndex]?.playbackRest ?? 0
                state.currentSetIndex += 1
                if rest > 0 {
                    state.phase = .setRest
                    state.timeRemaining = rest
                    return true
                }
                return configureReconciledCurrentSet(&state)
            }
            state.currentSetIndex = 0
            if state.currentSectionIndex + 1 >= workout.sections.count { return false }
            let rest = sectionRestDuration(section)
            if rest > 0 {
                state.phase = .sectionRest
                state.timeRemaining = rest
                return true
            }
            state.currentSectionIndex += 1
            return configureReconciledCurrentSet(&state)
        case .sectionRest:
            state.currentSectionIndex += 1
            state.currentSetIndex = 0
            return configureReconciledCurrentSet(&state)
        }
    }

    // MARK: - Phase transitions

    /// Called when the work timer for an exercise reaches zero.
    private func endWorkPeriod() {
        guard let section = currentSection else { return }
        AudioManager.shared.stopSpeaking()
        let slots = playbackSlots(for: section)
        if currentSetIndex + 1 < slots.count {
            let restDuration = currentSlot?.playbackRest ?? 0
            currentSetIndex += 1
            isPreparation = false
            if restDuration > 0 {
                isSetRest = true
                restExtensionTotal = 0
                timeRemaining = restDuration
                WorkoutHaptics.shared.play(.restStart)
                speakPhase("Rest")
                startTimer()
            } else {
                beginCurrentSet()
            }
        } else {
            currentSetIndex = 0
            let restDuration = sectionRestDuration(section)
            let hasNextSection = currentSectionIndex + 1 < workout.sections.count
            if restDuration > 0 && hasNextSection {
                isSectionRest = true
                restExtensionTotal = 0
                timeRemaining = restDuration
                WorkoutHaptics.shared.play(.sectionStart)
                speakPhase("Rest")
                startTimer()
            } else {
                advanceToNextSection()
            }
        }
    }

    private func endSetRest() {
        isSetRest = false
        beginCurrentSet()
    }

    private func skipRest() {
        timer?.invalidate()
        if isSetRest {
            endSetRest()
        } else {
            advanceToNextSection()
        }
    }

    private func skipCurrentPhase() {
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        if isWarmUp {
            skipWarmUp()
        } else if isPreparation {
            skipPreparation()
        } else if isSetRest || isSectionRest {
            skipRest()
        } else {
            endWorkPeriod()
        }
    }

    private func jump(to index: Int) {
        guard !workoutCompleted, !showingWarmUpPicker, let section = currentSection,
              playbackSlots(for: section).indices.contains(index) else { return }
        guard !(index == currentSetIndex && (isBundleActive || isPreparation)) else { return }
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        currentSetIndex = index
        isSetRest = false
        isSectionRest = false
        isPreparation = false
        isWarmUp = false
        beginCurrentSet()
    }

    private func goBack() {
        guard canGoBack, !workoutCompleted, let section = currentSection else { return }
        let slots = playbackSlots(for: section)
        switch livePhase {
        case .active, .prepare:
            let elapsedInPhase = phaseDuration - timeRemaining
            if elapsedInPhase > 3 || currentSetIndex == 0 { restartCurrentExercise() } else { jump(to: currentSetIndex - 1) }
        case .setRest:
            jump(to: max(0, currentSetIndex - 1))
        case .sectionRest:
            jump(to: max(0, slots.count - 1))
        case .warmUp:
            break
        }
    }

    private func moveTime(by seconds: Int) {
        guard !showingWarmUpPicker, !workoutCompleted else { return }
        if seconds >= 0 {
            if seconds < timeRemaining {
                timeRemaining -= seconds
                elapsedSeconds += seconds
                saveResumeState()
            } else {
                skipCurrentPhase()
            }
        } else {
            let back = -seconds
            if timeRemaining >= phaseDuration {
                goBack()
            } else {
                timeRemaining = min(phaseDuration, timeRemaining + back)
                saveResumeState()
            }
        }
    }

    private func seek(toElapsed position: Int) {
        guard !showingWarmUpPicker, !workoutCompleted, phaseDuration > 0 else { return }
        let target = max(1, min(phaseDuration, phaseDuration - position))
        guard target != timeRemaining else { return }
        elapsedSeconds += max(0, timeRemaining - target)
        timeRemaining = target
        saveResumeState()
    }

    private func advanceToNextSection() {
        currentSetIndex = 0
        isSectionRest = false
        isSetRest = false
        isPreparation = false
        currentSectionIndex += 1
        if currentSectionIndex >= workout.sections.count {
            completeWorkout()
        } else {
            beginCurrentSet()
        }
    }

    private func completeWorkout() {
        timer?.invalidate()
        AudioManager.shared.stopSpeaking()
        musicSession.stop()
        workoutCompleted = true
        showWorkoutManagement = false
        showPageOverlay = false
        showMusicChooser = false
        WorkoutResumeManager.shared.clearResumeState()
        #if os(iOS)
        WorkoutNowPlayingController.shared.end()
        nowPlayingStarted = false
        WorkoutLiveActivityController.shared.end(completed: true, elapsedSeconds: elapsedSeconds)
        #endif
        WorkoutLiveSession.shared.finish(completed: true, elapsedSeconds: elapsedSeconds)
        WorkoutHaptics.shared.play(.complete)
        AudioManager.shared.speak("Congratulations! Incredible work!")
        let entry = WorkoutHistoryEntry(
            workoutId:         workout.id,
            workoutName:       workout.name,
            durationCompleted: Int(Date().timeIntervalSince(startTime)),
            workoutType:       workout.type
        )
        store.addHistoryEntry(entry)
    }

    private func pauseTimer()  {
        isPaused = true
        AudioManager.shared.stopSpeaking()
        WorkoutHaptics.shared.play(.pause)
        saveResumeState()
        musicSession.setPaused(true)
    }

    private func toggleOverlayMusic() {
        musicChooserIsAutomatic = false
        showMusicChooser = true
    }

    private func resumeTimer() {
        isPaused = false
        WorkoutHaptics.shared.play(.resume)
        startTimer()
        musicSession.setPaused(false)
    }

    private func stopWorkout() {
        timer?.invalidate()
        musicSession.stop()
        AudioManager.shared.stopSpeaking()
        if elapsedSeconds >= 180 {
            let entry = WorkoutHistoryEntry(
                workoutId: workout.id,
                workoutName: workout.name,
                durationCompleted: workout.totalDuration,
                workoutType: workout.type,
                isPartial: true,
                elapsedSeconds: elapsedSeconds
            )
            store.addHistoryEntry(entry)
        }
        WorkoutResumeManager.shared.clearResumeState()
        #if os(iOS)
        WorkoutNowPlayingController.shared.end()
        nowPlayingStarted = false
        WorkoutLiveActivityController.shared.end(completed: false, elapsedSeconds: elapsedSeconds)
        #endif
        WorkoutLiveSession.shared.finish(completed: false, elapsedSeconds: elapsedSeconds)
        dismiss()
    }

    // MARK: - Music continuation

    private var isMusicContinuationRest: Bool {
        isSectionRest || (isSetRest && (restSlot?.restRow?.kind == .big || (restSlot?.restAfter ?? 0) >= 60))
    }

    private func offerMusicContinuation() {
        guard musicSession.exhausted, !musicSession.isManual, isMusicContinuationRest,
              !offeredMusicContinuation, !showMusicChooser, !workoutCompleted else { return }
        offeredMusicContinuation = true
        musicChooserIsAutomatic = true
        showMusicChooser = true
    }

    // MARK: - Motivation

    private func resetMotivationTimer() {
        guard MotivationManager.shared.isEnabled else { return }
        let base = MotivationManager.shared.interval
        nextMotivationIn = base + Int.random(in: 0...(base / 2))
    }

    private func tickMotivation() {
        guard MotivationManager.shared.isEnabled else { return }
        nextMotivationIn -= 1
        if nextMotivationIn <= 0 {
            AudioManager.shared.speak(MotivationManager.shared.randomQuote())
            resetMotivationTimer()
        }
    }

    /// Announces the time remaining at 75%, 50%, and 25% of the section duration.
    /// Skips very short sections (< 8 s) and milestones that would clash with the
    /// 3-second countdown beep (milestone ≤ 3).
    private func checkTimeAnnouncement() {
        guard let section = currentSection else { return }
        let total = currentSlot?.duration ?? section.duration
        guard total >= 8 else { return }
        let quarter = total / 4
        guard quarter > 3 else { return }
        let milestones: Set<Int> = [quarter, quarter * 2, quarter * 3]
        guard milestones.contains(timeRemaining) else { return }
        let text: String
        if timeRemaining >= 60 {
            let m = timeRemaining / 60
            let s = timeRemaining % 60
            text = s > 0 ? "\(m):\(String(format: "%02d", s))" : "\(m) minute\(m == 1 ? "" : "s")"
        } else {
            text = "\(timeRemaining)"
        }
        AudioManager.shared.speak(text)
    }

    // MARK: - Helpers

    #if os(iOS)
    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WorkoutTimer") {
            self.saveResumeState()
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    #elseif os(macOS)
    private func beginBackgroundTask() {}
    private func endBackgroundTask() {}
    #endif

    // MARK: - Media overlay

    @ViewBuilder
    private func mediaOverlayView(item: MediaItem) -> some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            if item.type == .photo, let img = overlayImage {
                Image.platformImg(img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if item.type == .video {
                let url = PhotoManager.shared.videoURL(for: item.filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    PlayerOverlayVideo(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Text(PlayerTime.counter(timeRemaining))
                        .font(TimeMasterFont.black(20, relativeTo: .title3).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissMediaOverlay)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: dismissMediaOverlay)
        .keyNavHost()
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeOut(duration: 0.3), value: showMediaOverlay)
    }

    private func dismissMediaOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            showMediaOverlay = false
            overlayMediaItem = nil
            overlayImage = nil
        }
    }
}

extension View {
    @ViewBuilder
    func workoutPlayerPage<Content: View>(
        item: Binding<Workout?>,
        @ViewBuilder content: @escaping (Workout) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item) { workout in
            content(workout).interactiveDismissDisabled()
        }
        #else
        sheet(item: item) { workout in
            content(workout).interactiveDismissDisabled().keyNavHost()
        }
        #endif
    }
}

#Preview {
    WorkoutPlayerView(workout: Workout(name: "Test", sections: [
        Section(name: "Burpees",  duration: 30, sets: 3, restBetweenSets: 10),
        Section(name: "Push-ups", duration: 30)
    ]))
    .environmentObject(WorkoutStore())
}
