import SwiftUI
import AVFoundation
import AVKit


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
    @State private var currentSetIndex      = 0   // current set within the section
    @State private var timeRemaining        = 0
    @State private var isPaused             = false

    // Phase flags (only one true at a time)
    @State private var isSetRest            = false  // rest between sets of the same section
    @State private var isSectionRest        = false  // rest between sections
    @State private var isWarmUp             = false
    @State private var isPreparation        = false
    @State private var showingWarmUpPicker  = true
    @State private var workoutCompleted     = false

    // Timer
    @State private var timer: Timer?
    @State private var startTime: Date = Date()
    @State private var showingCloseConfirmation = false
    @State private var nextMotivationIn: Int = 0   // countdown to next quote
    @State private var autoSaveCounter = 0
    @State private var elapsedSeconds = 0
    @State private var didInitFromResume = false
    #if os(iOS)
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
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
    @State private var loadedMedia: [MediaItem] = []
    #if os(iOS)
    @State private var mediaImages: [UIImage?]  = []
    #elseif os(macOS)
    @State private var mediaImages: [NSImage?]  = []
    #endif
    @State private var currentMediaIndex        = 0
    @State private var videoPlayer: AVQueuePlayer?
    @State private var videoLooper: AVPlayerLooper?

    // F03-B: Media overlay & rest adjustment
    @State private var showMediaOverlay = false
    @State private var overlayMediaItem: MediaItem?
    #if os(iOS)
    @State private var overlayImage: UIImage?
    #elseif os(macOS)
    @State private var overlayImage: NSImage?
    #endif
    @State private var restExtensionTotal = 0
    @State private var restExtensionFlash = false
    @State private var restExtensionText = ""
    @State private var showRestPicker = false
    @State private var nextSectionMedia: [MediaItem] = []
    #if os(iOS)
    @State private var nextSectionImages: [UIImage?] = []
    #elseif os(macOS)
    @State private var nextSectionImages: [NSImage?] = []
    #endif

    // F02-A-d: Page overlay
    @State private var showPageOverlay = false
    @State private var overlayPageID: UUID?
    @State private var overlayPageName = ""
    @State private var showBundleInlinePreview = false
    @State private var bundleMediaIndex = 0
    @State private var showBundleMediaViewer = false
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
        return section.effectiveSlots[safe: currentSetIndex]
    }

    private var isBundleActive: Bool {
        currentSection?.mode == .bundle && !isWarmUp && !isPreparation && !isSetRest && !isSectionRest
    }

    private var nextExerciseName: String? {
        if let section = currentSection,
           section.mode == .bundle,
           let next = section.effectiveSlots[safe: currentSetIndex + 1] {
            return next.name
        }
        return workout.sections[safe: currentSectionIndex + 1]?.name
    }

    private var restSlot: SetSlot? {
        guard isSetRest, let section = currentSection else { return nil }
        return section.effectiveSlots[safe: max(0, currentSetIndex - 1)]
    }

    private func openPageOverlay(id: UUID?, name: String) {
        guard let id else { return }
        overlayPageID = id
        overlayPageName = name
        withAnimation(.easeOut(duration: 0.3)) {
            showPageOverlay = true
        }
    }

    private var livePhase: WorkoutPhase {
        isWarmUp ? .warmUp : isPreparation ? .prepare : isSetRest ? .setRest : isSectionRest ? .sectionRest : .active
    }

    private var phaseDuration: Int {
        switch livePhase {
        case .warmUp: warmUpDuration
        case .prepare: currentSlot.map { currentSection?.preparationTime(for: $0) ?? 0 } ?? 0
        case .active: currentSection?.mode == .bundle ? 0 : (currentSlot?.duration ?? 0)
        case .setRest: restSlot?.restAfter ?? currentSection?.restBetweenSets ?? 0
        case .sectionRest: currentSection?.customRestAfter ?? workout.restBetweenSections
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
        let oldMedia = currentSection?.mediaItems
        let oldPageID = currentSlot?.exercisePageID
        let musicChanged = updated.musicTimeline != workout.musicTimeline
        workout = updated
        if musicChanged && musicStarted {
            musicSession.updateTimeline(updated.musicTimeline ?? .init())
        }
        guard !showingWarmUpPicker, !workoutCompleted, !isWarmUp else { return }
        guard !updated.sections.isEmpty else { stopWorkout(); return }
        if let sectionIndex = updated.sections.firstIndex(where: { $0.id == sectionID }) {
            currentSectionIndex = sectionIndex
            let slots = updated.sections[sectionIndex].effectiveSlots
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
        if oldMedia != currentSection?.mediaItems || oldPageID != currentSlot?.exercisePageID { loadCurrentMedia() }
        saveResumeState()
    }
    // MARK: - Body

    var body: some View {
        contentLayer
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
                loadCurrentMedia()
                tryResumeState()
            }
            .onChange(of: currentSectionIndex) { _ in
                currentMediaIndex = 0
                loadCurrentMedia()
            }
             .onChange(of: currentMediaIndex) { _ in
                 setupVideoIfNeeded()
             }
            .onChange(of: currentSetIndex) { _ in
                showBundleInlinePreview = false
            }
            .onDisappear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = false
                #endif
                timer?.invalidate()
                stopVideo()
                endBackgroundTask()
                musicSession.stop()
                musicStarted = false
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                saveResumeState()
                beginBackgroundTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                endBackgroundTask()
                reconcileAfterInterruption()
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
                BundleReorderSheet(
                    slots: currentSection?.effectiveSlots ?? [],
                    onMove: moveBundleSlots
                )
            }
            .sheet(isPresented: $showBundleMediaViewer) {
                if let page = currentSlot.flatMap({ slot in
                    slot.exercisePageID.flatMap { databaseStore.page(id: $0) }
                }) {
                    PageMediaGallery(
                        urls: page.mediaURLs,
                        selectedIndex: $bundleMediaIndex,
                        isPresented: $showBundleMediaViewer,
                        comments: page.mediaCommentsByURL,
                        onSaveComment: nil
                    )
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
            completedView
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
            if currentMediaIndex < mediaImages.count,
               let img = mediaImages[currentMediaIndex] {
                Image.platformImg(img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.2)
                    .blur(radius: 24)
                    .opacity(0.45)
            }
            Color.black.opacity(0.5)
        }
        .ignoresSafeArea()
    }

    // MARK: - Warm-Up Picker

    private var warmUpPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton(confirmed: false)
                Spacer()
                musicButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Warm Up")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Choose your warm-up duration")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        warmUpButton(value: 30,  label: "30 sec")
                        warmUpButton(value: 60,  label: "1 min")
                        warmUpButton(value: 90,  label: "1:30")
                    }
                    HStack(spacing: 10) {
                        warmUpButton(value: 120, label: "2 min")
                        warmUpButton(value: 180, label: "3 min")
                        Color.clear.frame(maxWidth: .infinity).frame(height: 52)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button {
                        showingWarmUpPicker = false
                        startWarmUp()
                    } label: {
                        Text("Start Warm Up")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                    Button {
                        showingWarmUpPicker = false
                        startWorkout()
                    } label: {
                        Text("Skip Warm Up")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func warmUpButton(value: Int, label: String) -> some View {
        Button { warmUpDuration = value } label: {
            Text(label)
                .font(.system(size: 15, weight: warmUpDuration == value ? .bold : .regular))
                .foregroundColor(warmUpDuration == value ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(warmUpDuration == value ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(12)
        }
    }

    // MARK: - Warm-Up Countdown

    private var warmUpView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton(confirmed: true)
                Spacer()
                musicButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 18) {
                Text("WARM UP")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.5))

                Text(formatTime(timeRemaining))
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                pausePlayButton.padding(.top, 6)

                Button { skipWarmUp() } label: {
                    Text("Skip Warm Up")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 180, height: 48)
                        .background(Color.white)
                        .cornerRadius(14)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var preparationView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton(confirmed: true)
                Spacer()
                musicButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 18) {
                Text("PREPARATION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.5))

                Text(currentSlot?.name ?? currentSection?.name ?? "")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(formatTime(timeRemaining))
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                pausePlayButton.padding(.top, 6)

                Button { skipPreparation() } label: {
                    Text("Skip Preparation")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 180, height: 48)
                        .background(Color.white)
                        .cornerRadius(14)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Section

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
        VStack(spacing: 0) {
            // Top bar
            HStack {
                closeButton(confirmed: true)
                Spacer()
                musicButton
                skipSectionButton
                sectionBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                mediaCarousel

                // Section name + sets indicator
                VStack(spacing: 6) {
                    if let section = currentSection, let pageID = currentSlot?.exercisePageID ?? section.pageID {
                        Button {
                            openPageOverlay(id: pageID, name: currentSlot?.name ?? section.name)
                        } label: {
                            HStack(spacing: 6) {
                                Text(currentSlot?.name ?? section.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "book.pages")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 32)
                    } else {
                        Text(currentSlot?.name ?? currentSection?.name ?? "")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 32)
                    }

                    if let section = currentSection, section.slotCount > 1 {
                        VStack(spacing: 2) {
                            Text("Set \(currentSetIndex + 1) / \(section.slotCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                            if let reps = currentSlot?.repCount ?? section.repCount {
                                Text("\(reps) reps")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    } else if let section = currentSection, let reps = currentSlot?.repCount ?? section.repCount {
                        Text("\(reps) reps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Text(formatTime(timeRemaining))
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                pausePlayButton.padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bundleSectionView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton(confirmed: true)
                Spacer()
                musicButton
                sectionBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 18) {
                Text("BUNDLE · SELF-PACED")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.55))

                if let slot = currentSlot {
                    VStack(spacing: 12) {
                        Button {
                            showBundleInlinePreview.toggle()
                        } label: {
                            VStack(spacing: 12) {
                                bundleCover(for: slot)
                                Text(slot.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                if let pageID = slot.exercisePageID,
                                   let page = databaseStore.page(id: pageID),
                                   !page.manifest.markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(String(page.manifest.markdownBody
                                        .replacingOccurrences(of: "#", with: "")
                                        .prefix(140)))
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.65))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }
                                Label(
                                    showBundleInlinePreview ? "Hide Preview" : "Preview Media",
                                    systemImage: showBundleInlinePreview ? "chevron.up" : "photo"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(28)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(24)
                        }
                        .buttonStyle(.plain)

                        if showBundleInlinePreview,
                           let pageID = slot.exercisePageID,
                           let page = databaseStore.page(id: pageID) {
                            if page.hasMedia {
                                PageMediaGalleryGrid(urls: page.mediaURLs, comments: page.mediaCommentsByURL) { index in
                                    bundleMediaIndex = index
                                    showBundleMediaViewer = true
                                }
                                .padding(.horizontal, 8)
                            } else {
                                Text("This exercise has no media yet.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        if slot.exercisePageID != nil {
                            Button {
                                openPageOverlay(id: slot.exercisePageID, name: slot.name)
                            } label: {
                                Label("Open Page", systemImage: "book.pages")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("\(currentSetIndex + 1) / \(currentSection?.slotCount ?? 1)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white.opacity(0.65))

                Button {
                    endWorkPeriod()
                } label: {
                    Label(
                        currentSetIndex + 1 < (currentSection?.slotCount ?? 1) ? "Next Technique" : "Complete Bundle",
                        systemImage: "arrow.right.circle.fill"
                    )
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(14)
                }

                Button {
                    showBundleReorder = true
                } label: {
                    Label("Reorder Techniques", systemImage: "line.3.horizontal")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width > 0, currentSetIndex > 0 {
                        currentSetIndex -= 1
                    } else if value.translation.width < 0 {
                        endWorkPeriod()
                    }
                }
        )
    }

    @ViewBuilder
    private func bundleCover(for slot: SetSlot) -> some View {
        if let pageID = slot.exercisePageID,
           let page = databaseStore.page(id: pageID),
           let url = page.coverImageURL {
            AsyncCoverImage(
                url: url,
                fallbackIcon: page.effectiveWorkoutType?.iconName ?? (page.isContainer ? "folder.fill" : "figure.run"),
                fallbackColor: Color(hex: page.effectiveWorkoutType?.colorHex ?? "FFFFFF"),
                height: 150,
                overlayGradient: false
            )
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let pageID = slot.exercisePageID, let page = databaseStore.page(id: pageID) {
            bundleFallbackCover(page: page)
        } else {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 42))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func bundleFallbackCover(page: ExercisePage) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: page.effectiveWorkoutType?.colorHex ?? "FFFFFF").opacity(0.22))
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .overlay {
                Image(systemName: page.effectiveWorkoutType?.iconName ?? (page.isContainer ? "folder.fill" : "figure.run"))
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.7))
            }
    }

    private var sectionBadge: some View {
        Text("\(currentSectionIndex + 1) / \(workout.sections.count)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18))
            .cornerRadius(10)
    }

    // MARK: - Media Carousel

    @ViewBuilder
    private var mediaCarousel: some View {
        if !loadedMedia.isEmpty {
            VStack(spacing: 8) {
                ZStack {
                    mediaCarouselContent
                    if loadedMedia.count > 1 { mediaArrows }
                }
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)

                if loadedMedia.count > 1 { mediaDots }
            }
        }
    }

    @ViewBuilder
    private var mediaCarouselContent: some View {
        if let item = loadedMedia[safe: currentMediaIndex] {
            if item.type == .video, let player = videoPlayer {
                    VideoPlayer(player: player)
                        .frame(width: 260, height: 260)
                        .onTapGesture {
                        if let pageID = currentSlot?.exercisePageID ?? currentSection?.pageID {
                            openPageOverlay(id: pageID, name: currentSlot?.name ?? currentSection?.name ?? item.filename)
                        } else {
                            overlayMediaItem = item
                            showMediaOverlay = true
                        }
                    }
            } else if let outer = mediaImages[safe: currentMediaIndex], let img = outer {
                Image.platformImg(img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 260)
                    .onTapGesture {
                        if let pageID = currentSlot?.exercisePageID ?? currentSection?.pageID {
                            openPageOverlay(id: pageID, name: currentSlot?.name ?? currentSection?.name ?? item.filename)
                        } else {
                            overlayMediaItem = item
                            overlayImage = img
                            showMediaOverlay = true
                        }
                    }
            }
        }
    }

    private var mediaArrows: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMediaIndex = max(0, currentMediaIndex - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .opacity(currentMediaIndex > 0 ? 1 : 0.3)
            .disabled(currentMediaIndex == 0)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMediaIndex = min(loadedMedia.count - 1, currentMediaIndex + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .opacity(currentMediaIndex < loadedMedia.count - 1 ? 1 : 0.3)
            .disabled(currentMediaIndex == loadedMedia.count - 1)
        }
        .padding(.horizontal, 8)
    }

    private var mediaDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<loadedMedia.count, id: \.self) { i in
                let isActive  = i == currentMediaIndex
                let isVideo   = loadedMedia[i].type == .video
                Capsule()
                    .fill(isActive ? Color.white : Color.white.opacity(0.35))
                    .frame(
                        width:  isVideo ? (isActive ? 18 : 12) : (isActive ? 7 : 5),
                        height: isActive ? 7 : 5
                    )
                    .animation(.easeInOut(duration: 0.15), value: currentMediaIndex)
            }
        }
    }

    // MARK: - Rest View (shared for set-rest and section-rest)

    private var restView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton(confirmed: true)
                Spacer()
                musicButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Text(isSetRest ? "REST BETWEEN SETS" : "REST")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.5))

                restContextLabel

                if let slot = restSlot,
                   let pageID = slot.restExercisePageID,
                   let page = databaseStore.page(id: pageID) {
                    Button {
                        openPageOverlay(id: pageID, name: page.title)
                    } label: {
                        Label("Rest exercise: \(page.title)", systemImage: "figure.cooldown")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle())
                }

            if !restExtensionText.isEmpty {
                Text(restExtensionText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

                Text(formatTime(timeRemaining))
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .contextMenu { restPickerMenu }

                pausePlayButton.padding(.top, 4)

                nextSectionPreview

                HStack(spacing: 12) {
                    restAdjustButton(seconds: 15)
                    restAdjustButton(seconds: 30)

                    Button { skipRest() } label: {
                        Text("Skip Rest")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: 100, height: 48)
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                }
                .padding(.top, 6)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { restExtensionTotal = 0 }
    }

    @ViewBuilder
    private var restContextLabel: some View {
        if isSetRest, let section = currentSection {
            Text("Set \(currentSetIndex) of \(section.slotCount)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        } else if isSectionRest, currentSectionIndex + 1 < workout.sections.count {
            Text("Next: \(workout.sections[currentSectionIndex + 1].name)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var nextSectionPreview: some View {
        if isSectionRest, currentSectionIndex + 1 < workout.sections.count {
            let nextSection = workout.sections[currentSectionIndex + 1]
            if let firstItem = nextSection.mediaItems.first,
               let idx = nextSectionImages.firstIndex(where: { $0 != nil }),
               let img = nextSectionImages[idx] {
                Image.platformImg(img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.35))
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
                    .opacity(0.5)
                    .onTapGesture {
                        overlayMediaItem = firstItem
                        overlayImage = img
                        showMediaOverlay = true
                    }
            } else if nextSection.mediaItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Workout Almost Done")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(width: 200, height: 200)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            }
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
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 56)
        }
        .buttonStyle(TimeMasterActionButtonStyle())
        .disabled(!canExtend)
    }

    private func extendRest(by seconds: Int) {
        guard restExtensionTotal + seconds <= 120 else { return }
        restExtensionTotal += seconds
        timeRemaining += seconds
        restExtensionText = "+\(seconds) seconds"
        withAnimation(.easeInOut(duration: 0.3)) {
            restExtensionFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                restExtensionText = ""
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Workout Complete!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Great job finishing \(workout.name).")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button { dismiss() } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 60))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ConfettiView()
        }
    }

    // MARK: - Shared UI

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
    }

    private var pausePlayButton: some View {
        Button {
            if isPaused { resumeTimer() } else { pauseTimer() }
        } label: {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 68, height: 68)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
    }

    private var skipSectionButton: some View {
        Button {
            skipCurrentPhase()
        } label: {
            Image(systemName: "forward.end.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
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
                .accessibilityLabel("Manage active workout")
                .accessibilityValue("Exercise \(currentSectionIndex + 1) of \(workout.sections.count)")
            }
            Button(action: toggleOverlayMusic) {
                Image(systemName: musicSession.isPlaying ? "music.note" : "music.note.list")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(musicSession.isPlaying ? 0.25 : 0.12), in: Circle())
            }
            .accessibilityLabel("Choose workout music")
            .accessibilityValue(musicSession.title ?? "Silence")
        }
        .foregroundStyle(.white)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { playerHeaderBottom = $0 }
    }

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

    // MARK: - Timer Logic

    private func startWorkout() {
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
        AudioManager.shared.speak("Warm up")
        startTimer()
    }

    private func skipWarmUp() {
        timer?.invalidate()
        isWarmUp = false
        startWorkout()
    }

    private func beginCurrentSet() {
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
        AudioManager.shared.speak("Preparation")
        startTimer()
    }

    private func finishPreparation() {
        guard let section = currentSection else {
            completeWorkout()
            return
        }

        isPreparation = false
        timeRemaining = section.mode == .bundle
            ? 0
            : (currentSlot?.duration ?? section.duration)
        AudioManager.shared.speak(currentSlot?.name ?? section.name)
        startTimer()
    }

    private func skipPreparation() {
        timer?.invalidate()
        finishPreparation()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused { tick() }
        }
    }

    private func tick() {
        if isBundleActive {
            elapsedSeconds += 1
            autoSaveCounter += 1
            if autoSaveCounter >= 5 {
                autoSaveCounter = 0
                saveResumeState()
            }
            return
        }

        guard timeRemaining > 0 else {
            finishCurrentTimerPhase()
            return
        }

        timeRemaining -= 1
        elapsedSeconds += 1
        if timeRemaining <= 3 && timeRemaining >= 1 {
            AudioManager.shared.playCountdownBeep()
        }
        if !isSetRest && !isSectionRest && !isWarmUp && !isPreparation {
            tickMotivation()
            checkTimeAnnouncement()
        }
        autoSaveCounter += 1
        if autoSaveCounter >= 5 {
            autoSaveCounter = 0
            saveResumeState()
        }
        if timeRemaining == 0 {
            finishCurrentTimerPhase()
        }
    }

    private func finishCurrentTimerPhase() {
        timer?.invalidate()
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

    private func saveResumeState() {
        let phase: WorkoutPhase = isWarmUp ? .warmUp
            : isPreparation ? .prepare
            : isSetRest ? .setRest
            : isSectionRest ? .sectionRest
            : .active
        WorkoutResumeManager.shared.saveState(
            workoutId: workout.id,
            workoutName: workout.name,
            currentSectionIndex: currentSectionIndex,
            currentSetIndex: currentSetIndex,
            timeRemaining: timeRemaining,
            elapsedSeconds: elapsedSeconds,
            phase: phase,
            isPaused: isPaused,
            musicCheckpoint: musicSession.checkpoint
        )
    }

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

    private func restore(from checkpoint: ResumeState) {
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
        loadCurrentMedia()
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
        if isSelfPacedBundle(state) {
            state.savedAt = Date()
            return state
        }
        var elapsedToConsume = max(0, Int(Date().timeIntervalSince(checkpoint.savedAt)))
        guard elapsedToConsume > 0 else { return state }

        while elapsedToConsume > 0 {
            if isSelfPacedBundle(state) {
                break
            }
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

    private func isSelfPacedBundle(_ state: ResumeState) -> Bool {
        workout.sections.indices.contains(state.currentSectionIndex)
            && workout.sections[state.currentSectionIndex].mode == .bundle
            && state.phase == .active
    }

    private func configureReconciledCurrentSet(_ state: inout ResumeState) -> Bool {
        guard workout.sections.indices.contains(state.currentSectionIndex) else { return false }
        let section = workout.sections[state.currentSectionIndex]
        guard let slot = section.effectiveSlots[safe: state.currentSetIndex] else { return false }

        let preparationTime = section.preparationTime(for: slot)
        if preparationTime > 0 {
            state.phase = .prepare
            state.timeRemaining = preparationTime
        } else {
            state.phase = .active
            state.timeRemaining = section.mode == .bundle ? 0 : slot.duration
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
            guard let slot = section.effectiveSlots[safe: state.currentSetIndex] else { return false }
            state.phase = .active
            state.timeRemaining = section.mode == .bundle ? 0 : slot.duration
            return true
        case .setRest:
            return configureReconciledCurrentSet(&state)
        case .active:
            guard workout.sections.indices.contains(state.currentSectionIndex) else { return false }
            let section = workout.sections[state.currentSectionIndex]
            if section.mode == .bundle { return false }
            if state.currentSetIndex + 1 < section.slotCount {
                state.currentSetIndex += 1
                state.phase = .setRest
                state.timeRemaining = section.effectiveSlots[safe: state.currentSetIndex - 1]?.restAfter ?? section.restBetweenSets
                return true
            }
            state.currentSetIndex = 0
            if state.currentSectionIndex + 1 >= workout.sections.count { return false }
            let rest = section.customRestAfter ?? workout.restBetweenSections
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

    private func moveBundleSlots(from source: IndexSet, to destination: Int) {
        guard workout.sections.indices.contains(currentSectionIndex),
              workout.sections[currentSectionIndex].mode == .bundle else { return }

        var updated = workout
        var slots = updated.sections[currentSectionIndex].effectiveSlots
        slots.move(fromOffsets: source, toOffset: destination)
        updated.sections[currentSectionIndex].slots = slots
        updated.sections[currentSectionIndex].sets = slots.count
        store.updateWorkout(updated)
    }

    /// Called when the work timer for a set reaches zero.
    private func endWorkPeriod() {
        guard let section = currentSection else { return }
        if section.mode == .bundle {
            if currentSetIndex + 1 < section.slotCount {
                currentSetIndex += 1
                beginCurrentSet()
            } else {
                currentSetIndex = 0
                advanceToNextSection()
            }
        } else if currentSetIndex + 1 < section.slotCount {
            // More sets remaining — rest between sets
            currentSetIndex += 1
            isPreparation = false
            isSetRest = true
            timeRemaining = section.effectiveSlots[safe: currentSetIndex - 1]?.restAfter ?? section.restBetweenSets
            AudioManager.shared.speak("Rest")
            startTimer()
        } else {
            // All sets done — inter-section rest (or skip if last section)
            currentSetIndex = 0
            let restDuration = section.customRestAfter ?? workout.restBetweenSections
            let hasNextSection = currentSectionIndex + 1 < workout.sections.count
            if restDuration > 0 && hasNextSection {
                isSectionRest = true
                timeRemaining = restDuration
                preloadNextSectionMedia()
                AudioManager.shared.speak("Rest")
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
        stopVideo()
        musicSession.stop()
        workoutCompleted = true
        showWorkoutManagement = false
        showPageOverlay = false
        showMusicChooser = false
        WorkoutResumeManager.shared.clearResumeState()
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
        videoPlayer?.pause()
        musicSession.setPaused(true)
    }

    private func toggleOverlayMusic() {
        musicChooserIsAutomatic = false
        showMusicChooser = true
    }

    private func resumeTimer() {
        isPaused = false
        musicSession.setPaused(false)
        if let item = loadedMedia[safe: currentMediaIndex], item.type == .video {
            videoPlayer?.play()
        }
    }

    private func stopWorkout() {
        timer?.invalidate()
        stopVideo()
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
        dismiss()
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
        // Speak natural time: "45" or "1:30"
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

    // MARK: - Media Loading

    private func loadCurrentMedia() {
        guard let section = currentSection else {
            loadedMedia = []
            mediaImages = []
            currentMediaIndex = 0
            stopVideo()
            return
        }
        loadedMedia = section.mediaItems
        currentMediaIndex = 0
        // Load thumbnails async
        let items = section.mediaItems
        Task.detached {
            #if os(iOS)
            var images: [UIImage?] = []
            for item in items {
                images.append(PhotoManager.shared.thumbnail(for: item))
            }
            #elseif os(macOS)
            var images: [NSImage?] = []
            for item in items {
                images.append(PhotoManager.shared.thumbnail(for: item))
            }
            #endif
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.mediaImages = images
                }
                self.setupVideoIfNeeded()
            }
        }
    }

    private func setupVideoIfNeeded() {
        stopVideo()
        guard let item = loadedMedia[safe: currentMediaIndex], item.type == .video else { return }
        let url = PhotoManager.shared.videoURL(for: item.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        // Configure audio session so video audio mixes with TTS
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let playerItem = AVPlayerItem(url: url)
        let player     = AVQueuePlayer(items: [playerItem])
        let looper     = AVPlayerLooper(player: player, templateItem: playerItem)
        videoPlayer = player
        videoLooper = looper
        if !isPaused { player.play() }
    }

    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer?.removeAllItems()
        videoLooper = nil
        videoPlayer = nil
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : String(format: "%02d", secs)
    }

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

    // MARK: - F03-B: Media Overlay

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
                    OverlayVideoPlayerView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
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
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                showMediaOverlay = false
                overlayMediaItem = nil
                overlayImage = nil
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeOut(duration: 0.3), value: showMediaOverlay)
    }

    private func preloadNextSectionMedia() {
        guard currentSectionIndex + 1 < workout.sections.count else { return }
        let nextSection = workout.sections[currentSectionIndex + 1]
        let items = nextSection.mediaItems
        nextSectionMedia = items
        nextSectionImages = Array(repeating: nil, count: items.count)
        Task.detached {
            #if os(iOS)
            var images: [UIImage?] = []
            for item in items {
                images.append(PhotoManager.shared.thumbnail(for: item))
            }
            #elseif os(macOS)
            var images: [NSImage?] = []
            for item in items {
                images.append(PhotoManager.shared.thumbnail(for: item))
            }
            #endif
            await MainActor.run {
                self.nextSectionImages = images
            }
        }
    }
}

// MARK: - Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let drift: CGFloat
    let delay: Double
    let duration: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let initialRotation: Double
    let finalRotation: Double

    static func random(screenWidth: CGFloat) -> ConfettiParticle {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .white,
            Color(red: 1, green: 0.4, blue: 0.7)
        ]
        let shapeType = Int.random(in: 0...2)
        let w: CGFloat
        let h: CGFloat
        let cr: CGFloat
        switch shapeType {
        case 0:  w = CGFloat.random(in: 8...14);  h = CGFloat.random(in: 6...10);  cr = 2
        case 1:  let s = CGFloat.random(in: 6...10); w = s; h = s; cr = s / 2
        default: w = CGFloat.random(in: 10...16); h = CGFloat.random(in: 2...4);   cr = 1
        }
        return ConfettiParticle(
            startX:          CGFloat.random(in: 0...screenWidth),
            drift:            CGFloat.random(in: -80...80),
            delay:            Double.random(in: 0...1.5),
            duration:         Double.random(in: 2.5...4.0),
            color:            colors.randomElement()!,
            width:            w,
            height:           h,
            cornerRadius:     cr,
            initialRotation:  Double.random(in: 0...360),
            finalRotation:    Double.random(in: 360...1080)
        )
    }
}

private struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var y: CGFloat = -50
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: particle.cornerRadius)
            .fill(particle.color)
            .frame(width: particle.width, height: particle.height)
            .rotationEffect(.degrees(rotation))
            .position(x: particle.startX + xDrift, y: y)
            .opacity(opacity)
            .onAppear {
                rotation = particle.initialRotation
                withAnimation(
                    Animation.easeIn(duration: particle.duration)
                        .delay(particle.delay)
                ) {
                    y      = screenHeight + 50
                    xDrift = particle.drift
                    rotation = particle.finalRotation
                }
                withAnimation(
                    Animation.linear(duration: 0.5)
                        .delay(particle.delay + particle.duration - 0.5)
                ) {
                    opacity = 0
                }
            }
    }
}

private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                ConfettiPieceView(particle: p, screenHeight: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            #if os(iOS)
            let screenW = UIScreen.main.bounds.width
            #elseif os(macOS)
            let screenW = NSScreen.main?.frame.width ?? 800
            #endif
            particles = (0..<120).map { _ in
                ConfettiParticle.random(screenWidth: screenW)
            }
        }
    }
}

private struct BundleReorderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let slots: [SetSlot]
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(slots) { slot in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(slot.name)
                                .font(.headline)
                            Text("Technique \(slots.firstIndex(where: { $0.id == slot.id }).map { $0 + 1 } ?? 0)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onMove(perform: onMove)
            }
            .navigationTitle("Reorder Techniques")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                #if os(iOS)
                AppToolbar.item(placement: .primaryAction) {
                    EditButton()
                }
                #endif
            }
        }
    }
}

// MARK: - F03-B: Overlay Video Player

private struct OverlayVideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
        p.play()
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        player = p
        loopObserver = obs
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
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
            content(workout).interactiveDismissDisabled()
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
