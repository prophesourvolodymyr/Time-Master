import SwiftUI
import TimeMasterCore

struct WorkoutMusicPlaybackSheet: View {
    let workout: Workout
    let isContinuationPrompt: Bool
    @ObservedObject var library: MusicLibraryStore
    @ObservedObject var session: WorkoutMusicSession
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = MusicManager.shared
    @State private var repeatSelection = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            List {
                if isContinuationPrompt {
                    SwiftUI.Section {
                        Text("Your configured music has finished. Choose music to continue or repeat, or stay in silence.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }.listRowBackground(Theme.surface)
                }
                SwiftUI.Section {
                    if let title = session.title {
                        Label(title, systemImage: session.isPlaying ? "waveform" : "music.note")
                    }
                    Toggle("Repeat selected music", isOn: $repeatSelection)
                    Slider(value: $manager.volume, in: 0...1) {
                        Text("Music volume")
                    }
                    .accessibilityLabel("Music volume")
                    if session.hasTimeline {
                        Button("Use workout timeline", systemImage: "timeline.selection") {
                            session.returnToTimeline()
                            dismiss()
                        }
                    }
                    Button("Stay in silence", systemImage: "speaker.slash") {
                        session.silence()
                        dismiss()
                    }
                }.listRowBackground(Theme.surface)

                if let configuration = workout.musicTimeline, !configuration.clips.isEmpty {
                    SwiftUI.Section("Assigned timeline music") {
                        ForEach(configuration.clips) { clip in
                            musicButton(clip)
                        }
                    }.listRowBackground(Theme.surface)
                }
                SwiftUI.Section("Workout music from Settings") {
                    ForEach(library.assignedMusic(for: workout)) { item in
                        musicButton(item.musicClip())
                    }
                    if library.assignedMusic(for: workout).isEmpty {
                        Text("No music assigned in Settings.").foregroundStyle(Theme.textSecondary)
                    }
                }.listRowBackground(Theme.surface)
                SwiftUI.Section {
                    DisclosureGroup("Choose different music", isExpanded: $showLibrary) {
                        ForEach(library.items) { item in
                            musicButton(item.musicClip())
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle(isContinuationPrompt ? "Continue with Music?" : "Workout Music")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .task { await library.refreshLocalDurations() }
    }

    private func musicButton(_ clip: WorkoutMusicClip) -> some View {
        Button {
            session.play(clip, repeatMusic: repeatSelection)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: clip.tracks.count > 1 ? "square.grid.2x2" : "opticaldisc")
                Text(clip.title).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(clip.sourceDuration > 0 ? musicTimestamp(clip.sourceDuration) : "Unavailable")
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
            }.padding(.vertical, 6)
        }
        .disabled(clip.sourceDuration <= 0)
    }
}

struct WorkoutMusicCover: View {
    let artwork: MusicArtworkReference?
    var isCollection = false
    let size: CGFloat

    private var artworkURL: URL? {
        if let filename = artwork?.localFilename {
            return filename.hasPrefix("/") ? URL(fileURLWithPath: filename)
                : MusicManager.shared.localMusicDirectoryURL.appendingPathComponent(filename)
        }
        return artwork?.remoteURL
    }

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface2)
            if let url = artworkURL {
                AsyncCoverImage(url: url, fallbackIcon: "music.note", height: size, overlayGradient: false)
                    .id(url)
            } else {
                Image(systemName: artwork?.placeholderSystemImage ?? (isCollection ? "square.stack" : "music.note"))
                    .font(.system(size: size * 0.42, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.textSecondary.opacity(0.35), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct WorkoutMusicPreviewSheet: View {
    let item: MusicLibraryItem
    @ObservedObject private var manager = MusicManager.shared
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .title) private var coverSize: CGFloat = 192
    @State private var error: String?

    private var track: MusicCollectionTrack? {
        item.tracks.first { $0.localReference?.filename == manager.currentFilename }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WorkoutMusicCover(artwork: track?.artwork ?? item.artwork,
                                      isCollection: item.isCollection, size: coverSize)
                    VStack(spacing: 4) {
                        Text(manager.currentTrack?.title ?? item.title)
                            .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                        if item.isCollection {
                            Text(item.title).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if let error {
                        Text(error).font(.callout).foregroundStyle(Theme.textSecondary)
                    } else {
                        VStack(spacing: 4) {
                            Slider(value: Binding(get: { manager.playbackProgress }, set: { manager.seek(to: $0) }), in: 0...1)
                                .accessibilityLabel("Playback position")
                            HStack {
                                Text(musicTimestamp((track?.duration ?? item.totalDuration) * manager.playbackProgress))
                                Spacer()
                                Text(musicTimestamp(track?.duration ?? item.totalDuration))
                            }
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                        }
                        HStack(spacing: 32) {
                            Button(action: manager.skipBackward) {
                                Image(systemName: "backward.end.fill").frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }.accessibilityLabel("Previous track")
                            Button(action: manager.togglePlayback) {
                                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title).frame(width: 56, height: 56)
                                    .contentShape(Rectangle())
                            }.accessibilityLabel(manager.isPlaying ? "Pause preview" : "Play preview")
                            Button(action: manager.skipForward) {
                                Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }.accessibilityLabel("Next track")
                        }
                        .font(.title3).buttonStyle(.plain)
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $manager.volume, in: 0...1)
                                .accessibilityLabel("Preview volume")
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
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
}
