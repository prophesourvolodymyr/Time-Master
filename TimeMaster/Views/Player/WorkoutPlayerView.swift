import SwiftUI
import AVFoundation
import AVKit

struct WorkoutPlayerView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) var dismiss

    let workout: Workout

    // Navigation
    @State private var currentSectionIndex  = 0
    @State private var currentSetIndex      = 0   // current set within the section
    @State private var timeRemaining        = 0
    @State private var isPaused             = false

    // Phase flags (only one true at a time)
    @State private var isSetRest            = false  // rest between sets of the same section
    @State private var isSectionRest        = false  // rest between sections
    @State private var isWarmUp             = false
    @State private var showingWarmUpPicker  = true
    @State private var workoutCompleted     = false

    // Timer
    @State private var timer: Timer?
    @State private var startTime: Date = Date()
    @State private var showingCloseConfirmation = false
    @State private var nextMotivationIn: Int = 0   // countdown to next quote

    // Music
    @ObservedObject private var musicManager = MusicManager.shared

    // Settings
    @AppStorage("extra_rest_seconds") private var extraRestSeconds: Int = 15

    // Warm-up
    @State private var warmUpDuration = 60

    // Media
    @State private var loadedMedia: [MediaItem] = []
    @State private var mediaImages: [UIImage?]  = []
    @State private var currentMediaIndex        = 0
    @State private var videoPlayer: AVQueuePlayer?
    @State private var videoLooper: AVPlayerLooper?

    // MARK: - Computed

    private var currentSection: Section? {
        guard currentSectionIndex < workout.sections.count else { return nil }
        return workout.sections[currentSectionIndex]
    }

    // MARK: - Body

    var body: some View {
        contentLayer
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { backgroundLayer }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                AudioManager.shared.activateSession()
                loadCurrentMedia()
            }
            .onChange(of: currentSectionIndex) { _ in
                currentMediaIndex = 0
                loadCurrentMedia()
            }
            .onChange(of: currentMediaIndex) { _ in
                setupVideoIfNeeded()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                timer?.invalidate()
                stopVideo()
            }
            .alert("Stop Workout?", isPresented: $showingCloseConfirmation) {
                Button("Continue", role: .cancel) {}
                Button("Stop", role: .destructive) { stopWorkout() }
            } message: {
                Text("Your progress will be lost.")
            }
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
                Image(uiImage: img)
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

    // MARK: - Active Section

    private var activeSectionView: some View {
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
                    Text(currentSection?.name ?? "")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 32)

                    if let section = currentSection, section.sets > 1 {
                        Text("Set \(currentSetIndex + 1) / \(section.sets)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
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
            } else if let outer = mediaImages[safe: currentMediaIndex], let img = outer {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 260)
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

            VStack(spacing: 14) {
                Text(isSetRest ? "REST BETWEEN SETS" : "REST")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.5))

                restContextLabel

                Text(formatTime(timeRemaining))
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                pausePlayButton.padding(.top, 4)

                HStack(spacing: 12) {
                    Button { skipRest() } label: {
                        Text("Skip Rest")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: 140, height: 48)
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                    Button { timeRemaining += extraRestSeconds } label: {
                        Text("+\(extraRestSeconds)s")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 84, height: 48)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(14)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var restContextLabel: some View {
        if isSetRest, let section = currentSection {
            Text("Set \(currentSetIndex) of \(section.sets)")
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                }
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
            timer?.invalidate()
            endWorkPeriod()
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
        let hasTracks = !musicManager.trackFilenames.isEmpty
        return Button {
            guard hasTracks else { return }
            MusicManager.shared.togglePlayback()
        } label: {
            Image(systemName: musicManager.isPlaying ? "music.note" : "music.note.list")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(hasTracks ? .white : .white.opacity(0.25))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(
                    hasTracks ? (musicManager.isPlaying ? 0.25 : 0.12) : 0.06
                ))
                .clipShape(Circle())
        }
    }

    // MARK: - Timer Logic

    private func startWorkout() {
        startTime = Date()
        currentSectionIndex = 0
        currentSetIndex     = 0
        isSetRest           = false
        isSectionRest       = false
        isWarmUp            = false
        resetMotivationTimer()
        if !workout.musicTrackFilenames.isEmpty {
            MusicManager.shared.startPlayback(tracks: workout.musicTrackFilenames)
        }
        if let section = currentSection {
            timeRemaining = section.duration
            AudioManager.shared.speak(section.name)
            startTimer()
        }
    }

    private func startWarmUp() {
        isWarmUp = true
        timeRemaining = warmUpDuration
        AudioManager.shared.speak("Warm up")
        startTimer()
    }

    private func skipWarmUp() {
        timer?.invalidate()
        isWarmUp = false
        startWorkout()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused { tick() }
        }
    }

    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
            if timeRemaining <= 3 && timeRemaining >= 1 {
                AudioManager.shared.playCountdownBeep()
            }
            // Fire motivational quote and time callout during active work (not rest/warm-up)
            if !isSetRest && !isSectionRest && !isWarmUp {
                tickMotivation()
                checkTimeAnnouncement()
            }
        } else {
            timer?.invalidate()
            if isWarmUp {
                isWarmUp = false
                startWorkout()
            } else if isSetRest {
                endSetRest()
            } else if isSectionRest {
                advanceToNextSection()
            } else {
                endWorkPeriod()
            }
        }
    }

    /// Called when the work timer for a set reaches zero.
    private func endWorkPeriod() {
        guard let section = currentSection else { return }
        if currentSetIndex + 1 < section.sets {
            // More sets remaining — rest between sets
            currentSetIndex += 1
            isSetRest     = true
            timeRemaining = section.restBetweenSets
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
                AudioManager.shared.speak("Rest")
                startTimer()
            } else {
                advanceToNextSection()
            }
        }
    }

    private func endSetRest() {
        isSetRest = false
        if let section = currentSection {
            timeRemaining = section.duration
            AudioManager.shared.speak(section.name)
            startTimer()
        }
    }

    private func skipRest() {
        timer?.invalidate()
        if isSetRest {
            endSetRest()
        } else {
            advanceToNextSection()
        }
    }

    private func advanceToNextSection() {
        currentSetIndex = 0
        isSectionRest   = false
        isSetRest       = false
        currentSectionIndex += 1
        if currentSectionIndex >= workout.sections.count {
            completeWorkout()
        } else if let section = currentSection {
            timeRemaining = section.duration
            AudioManager.shared.speak(section.name)
            startTimer()
        }
    }

    private func completeWorkout() {
        timer?.invalidate()
        stopVideo()
        MusicManager.shared.stopPlayback()
        workoutCompleted = true
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
    }
    private func resumeTimer() {
        isPaused = false
        if let item = loadedMedia[safe: currentMediaIndex], item.type == .video {
            videoPlayer?.play()
        }
    }

    private func stopWorkout() {
        timer?.invalidate()
        stopVideo()
        MusicManager.shared.stopPlayback()
        AudioManager.shared.stopSpeaking()
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
        let total = section.duration
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
            var images: [UIImage?] = []
            for item in items {
                images.append(PhotoManager.shared.thumbnail(for: item))
            }
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let playerItem = AVPlayerItem(url: url)
        let player     = AVQueuePlayer(items: [playerItem])
        let looper     = AVPlayerLooper(player: player, templateItem: playerItem)
        videoPlayer = player
        videoLooper = looper
        if !isPaused { player.play() }
    }

    private func stopVideo() {
        videoPlayer?.pause()
        videoLooper = nil
        videoPlayer = nil
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : String(format: "%02d", secs)
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
            particles = (0..<120).map { _ in
                ConfettiParticle.random(screenWidth: UIScreen.main.bounds.width)
            }
        }
    }
}

#Preview {
    WorkoutPlayerView(workout: Workout(name: "Test", sections: [
        Section(name: "Burpees",  duration: 30, sets: 3, restBetweenSets: 10),
        Section(name: "Push-ups", duration: 30)
    ]))
    .environmentObject(WorkoutStore())
}
