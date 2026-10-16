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
