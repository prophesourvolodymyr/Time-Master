import SwiftUI
import TimeMasterCore

struct WorkoutMusicPlaybackSheet: View {
    let workout: Workout
    let isContinuationPrompt: Bool
    @ObservedObject var library: MusicLibraryStore
    @ObservedObject var session: WorkoutMusicSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var workoutStore: WorkoutStore
    @ObservedObject private var manager = MusicManager.shared
    @State private var sidebarOpen = false
    @State private var repeatSelection = false
    @State private var wasSilencedBeforePreview = false

    private var currentWorkout: Workout {
        var current = workoutStore.workouts.first { $0.id == workout.id } ?? workout
        if session.isManual || current.musicTimeline == nil { current.musicTimeline = session.timeline }
        return current
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isContinuationPrompt {
                    Text("Your configured music has finished. Add music, repeat a selection, or continue in silence.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .padding()
                }
                WorkoutMusicTimelineView(
                    workout: currentWorkout,
                    library: library,
                    onChange: { configuration in
                        var updated = currentWorkout
                        updated.musicTimeline = configuration
                        workoutStore.updateWorkout(updated)
                    },
                    onClose: { dismiss() },
                    showsSidebar: sidebarOpen,
                    playhead: session.elapsed,
                    onPreviewChange: { previewing in
                        if previewing {
                            wasSilencedBeforePreview = session.isSilenced
                            session.silence()
                        } else if !wasSilencedBeforePreview && session.isSilenced {
                            session.togglePlayback()
                        }
                    }
                )
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        WorkoutMusicCover(artwork: session.artwork(in: library), size: 44, rotates: session.isPlaying)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title ?? (session.exhausted ? "Music finished" : "No music playing"))
                                .font(.headline).lineLimit(1)
                            Text(session.isSilenced ? "Music stopped · workout continues" : musicTimestamp(session.elapsed))
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        WorkoutMusicTransportButtons(session: session)
                    }
                    Slider(value: $manager.volume, in: 0...1) { Text("Music volume") }
                        .accessibilityLabel("Music volume")
                    HStack {
                        if session.isManual && session.hasTimeline {
                            Button("Return to timeline", action: session.returnToTimeline)
                        }
                        Spacer()
                        Menu {
                            Toggle("Repeat selection", isOn: $repeatSelection)
                            ForEach(library.items) { item in
                                Button(item.title) { session.play(item.musicClip(), repeatMusic: repeatSelection) }
                                    .disabled(item.totalDuration <= 0)
                            }
                        } label: {
                            Label("Play a selection", systemImage: "music.note.list")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Theme.surface)
            }
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .navigationTitle("Live Music")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.iconItem(placement: .primaryAction) { Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) {
                        sidebarOpen.toggle()
                    }
                } label: { Image(systemName: "sidebar.right") }
                .accessibilityLabel(sidebarOpen ? "Hide music sidebar" : "Show music sidebar")
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .task { await library.refreshLocalDurations() }
    }
}

struct WorkoutMusicTransportButtons: View {
    @ObservedObject var session: WorkoutMusicSession
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: session.togglePlayback) {
                Image(systemName: session.isSilenced ? "play.fill" : "stop.fill")
                    .frame(width: controlSize, height: controlSize)
            }
            .accessibilityLabel(session.isSilenced ? "Resume music" : "Stop music")
            if session.isPlaylist {
                Button(action: session.skipForward) {
                    Image(systemName: "forward.end.fill")
                        .frame(width: controlSize, height: controlSize)
                }
                .disabled(!session.canSkipForward)
                .accessibilityLabel("Next playlist track")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
    }
}

struct WorkoutFloatingMusicControls: View {
    @ObservedObject var session: WorkoutMusicSession
    @ObservedObject var library: MusicLibraryStore
    let onOpenTimeline: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapsed = false
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    var body: some View {
        HStack {
            if collapsed { Spacer(minLength: 0) }
            Group {
                if collapsed {
                    Button { setCollapsed(false) } label: {
                        cover.padding(8)
                    }
                    .accessibilityLabel("Expand music controls")
                } else {
                    HStack(spacing: 4) {
                        Button(action: onOpenTimeline) {
                            HStack(spacing: 10) {
                                cover
                                Text(session.title ?? session.activeClip?.title ?? "Music")
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: controlSize)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Open live music timeline")
                        WorkoutMusicTransportButtons(session: session)
                        Button(action: onOpenTimeline) {
                            Image(systemName: "music.note.list")
                                .frame(width: controlSize, height: controlSize)
                        }
                        .accessibilityLabel("Open live music timeline")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                        if value.translation.height > 30 && value.translation.height > abs(value.translation.width) {
                            setCollapsed(true)
                        }
                    })
                }
            }
            .modifier(WorkoutFloatingSurface(circular: collapsed))
            .contextMenu {
                Button("Minimize", systemImage: "chevron.down") { setCollapsed(true) }
            }
            .accessibilityAction(named: "Collapse music controls") { setCollapsed(true) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var cover: some View {
        WorkoutMusicCover(artwork: session.artwork(in: library), size: controlSize * 0.75, circular: false)
    }

    private func setCollapsed(_ value: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) {
            collapsed = value
        }
    }
}

struct WorkoutMusicCover: View {
    let artwork: MusicArtworkReference?
    var isCollection = false
    let size: CGFloat
    var rotates = false
    var circular = true
    var tracks: [MusicCollectionTrack] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var rotating = false

    private var shouldRotate: Bool { rotates && !reduceMotion && scenePhase == .active }

    var body: some View {
        let mosaic = isCollection && !tracks.isEmpty
        let shape = RoundedRectangle(cornerRadius: circular && !mosaic ? size / 2 : size * 0.045, style: .continuous)
        ZStack {
            shape.fill(Theme.surface2)
            if mosaic {
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    ForEach(0..<2) { row in
                        GridRow {
                            ForEach(0..<2) { column in
                                let index = row * 2 + column
                                artworkImage(index < tracks.count ? tracks[index].artwork : nil, size: (size - 1) / 2)
                            }
                        }
                    }
                }
            } else {
                artworkImage(artwork, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.textSecondary.opacity(0.2), lineWidth: 0.5))
        .rotationEffect(.degrees(rotating ? 360 : 0))
        .animation(shouldRotate ? .linear(duration: 18).repeatForever(autoreverses: false) : nil, value: rotating)
        .task(id: shouldRotate) { rotating = shouldRotate }
        .accessibilityHidden(true)
    }

    private func artworkImage(_ reference: MusicArtworkReference?, size: CGFloat) -> some View {
        let url: URL? = if let filename = reference?.localFilename {
            filename.hasPrefix("/") ? URL(fileURLWithPath: filename)
                : MusicManager.shared.localMusicDirectoryURL.appendingPathComponent(filename)
        } else {
            reference?.remoteURL
        }
        return ZStack {
            Theme.surface2
            if let url {
                AsyncCoverImage(url: url, fallbackIcon: "music.note", height: size, overlayGradient: false)
                    .id(url)
            } else {
                Image(systemName: reference?.placeholderSystemImage ?? (isCollection ? "square.stack" : "music.note"))
                    .font(.system(size: size * 0.42, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

struct WorkoutMusicPreviewSheet: View {
    let item: MusicLibraryItem
    @ObservedObject private var manager = MusicManager.shared
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title) private var coverSize: CGFloat = 304
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44
    @State private var error: String?

    private var track: MusicCollectionTrack? {
        item.tracks.first { $0.localReference?.filename == manager.currentFilename }
    }

    private var duration: Double { track?.duration ?? item.totalDuration }
    private var subtitle: String {
        if item.isCollection { return item.title }
        return manager.currentTrack?.artist ?? item.source.provider?.displayName ?? "On this device"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        WorkoutMusicCover(
                            artwork: track?.artwork ?? item.artwork,
                            isCollection: item.isCollection,
                            size: min(coverSize, max(0, geometry.size.width - 48), max(0, geometry.size.height * 0.38)),
                            circular: false
                        )
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(manager.currentTrack?.title ?? item.title)
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if let error {
                            Text(error).font(.callout).foregroundStyle(Theme.textSecondary)
                        } else {
                            playbackControls
                        }
                    }
                    .frame(maxWidth: coverSize)
                    .padding(24)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
                }
            }
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .navigationTitle("Music Preview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.iconItem(placement: .confirmationAction) { Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Close music preview")
                                 }
            }
        }
        .tint(Theme.textPrimary)
        .preferredColorScheme(.dark)
        .task {
            if case .unavailable(let reason) = manager.play(item) {
                switch reason {
                case .missingLocalFile: error = "This track's local audio file is missing."
                case .providerUnavailable(let provider): error = "\(provider.displayName) is not configured for playback on this device."
                case .unsupportedSource: error = "This source cannot be played."
                case .noPlayableSource: error = "This item has no playable audio."
                }
            }
        }
        .onDisappear { manager.stopPlayback() }
    }

    private var playbackControls: some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                Slider(value: Binding(get: { manager.playbackProgress }, set: { manager.seek(to: $0) }), in: 0...1)
                    .accessibilityLabel("Playback position")
                HStack {
                    Text(musicTimestamp(duration * manager.playbackProgress))
                    Spacer()
                    Text("−\(musicTimestamp(duration * (1 - manager.playbackProgress)))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .accessibilityElement(children: .combine)
            }

            HStack {
                Button(action: manager.skipBackward) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .frame(width: controlSize, height: controlSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous track")
                Spacer()
                Button(action: manager.togglePlayback) {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .frame(width: controlSize * 1.5, height: controlSize * 1.5)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(manager.isPlaying ? "Pause preview" : "Play preview")
                Spacer()
                Button(action: manager.skipForward) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .frame(width: controlSize, height: controlSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Next track")
                .disabled(!item.isCollection || item.tracks.count < 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, controlSize * 0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Music volume")
                    .font(.caption)
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill").font(.footnote)
                    Slider(value: $manager.volume, in: 0...1)
                        .accessibilityLabel("Preview volume")
                    Image(systemName: "speaker.wave.3.fill").font(.footnote)
                }
            }
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct MusicMarqueeText: View {
    let text: String
    let font: Font

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var lineHeight: CGFloat = 15
    @State private var textWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var isMoving = false
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if shouldMove {
                    HStack(spacing: 18) {
                        titleText
                        titleText
                    }
                    .offset(x: isMoving ? -(textWidth + 18) : 0)
                } else {
                    titleText
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .mask {
                if shouldMove {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.08),
                                .init(color: .white, location: 0.92), .init(color: .clear, location: 1)],
                        startPoint: .leading, endPoint: .trailing
                    )
                } else {
                    Rectangle()
                }
            }
            .onAppear {
                isVisible = true
                viewportWidth = proxy.size.width
                updateMovement()
            }
            .onChange(of: proxy.size.width) { newWidth in
                viewportWidth = newWidth
                updateMovement()
            }
        }
        .frame(height: lineHeight)
        .background {
            titleText.hidden()
                .background {
                    GeometryReader { measurement in
                        Color.clear.preference(key: MusicTextWidthKey.self, value: measurement.size.width)
                    }
                }
        }
        .onPreferenceChange(MusicTextWidthKey.self) { width in
            textWidth = width
            updateMovement()
        }
        .onChange(of: reduceMotion) { _ in updateMovement() }
        .onChange(of: scenePhase) { _ in updateMovement() }
        .onDisappear { isVisible = false; isMoving = false }
        .animation(
            shouldMove ? .linear(duration: max(4, (textWidth + 18) / 20)).delay(1).repeatForever(autoreverses: false) : nil,
            value: isMoving
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }

    private var titleText: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var shouldMove: Bool {
        isVisible && !reduceMotion && scenePhase == .active && textWidth > viewportWidth + 1
    }

    private func updateMovement() { isMoving = shouldMove }
}

private struct MusicTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
