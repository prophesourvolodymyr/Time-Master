import SwiftUI

struct WorkoutLiveProgress {
    let sectionID: UUID?
    let slotID: UUID?
    let phase: WorkoutPhase
    let remaining: Int
    let phaseDuration: Int
    let elapsed: Int
    let isPaused: Bool

    var fraction: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remaining) / Double(phaseDuration)))
    }
}

struct WorkoutLiveContext {
    let progress: WorkoutLiveProgress
    let music: WorkoutMusicSession
    let onPause: () -> Void
    let onStop: () -> Void
    let onOpenMusic: () -> Void
}

struct FloatingControlsBar: View {
    let workoutName: String
    let context: WorkoutLiveContext
    @ObservedObject var library: MusicLibraryStore
    @ObservedObject private var music: WorkoutMusicSession
    @State private var confirmingStop = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    init(workoutName: String, context: WorkoutLiveContext, library: MusicLibraryStore) {
        self.workoutName = workoutName
        self.context = context
        self.library = library
        self.music = context.music
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    workoutControls
                    if music.timeline?.clips.isEmpty == false {
                        Divider()
                        musicControls
                    }
                }
            } else {
                HStack(spacing: 6) {
                    workoutControls
                    if music.timeline?.clips.isEmpty == false {
                        Divider().frame(height: controlSize / 2)
                        musicControls
                    }
                }
            }
        }
        .font(TimeMasterFont.body())
        .padding(4)
        .modifier(WorkoutFloatingSurface())
        .alert("Stop Workout?", isPresented: $confirmingStop) {
            Button("Continue", role: .cancel) {}
            Button("Stop", role: .destructive, action: context.onStop)
        }
    }

    private var workoutControls: some View {
        HStack(spacing: 0) {
            Button { confirmingStop = true } label: {
                Image(systemName: "stop.fill").frame(width: controlSize, height: controlSize)
            }
            .keyNavTarget(shape: .circle)
            .accessibilityLabel("Stop workout")
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutName).font(TimeMasterFont.black(12, relativeTo: .caption)).lineLimit(1)
                Text(musicTimestamp(Double(context.progress.remaining > 0 ? context.progress.remaining : context.progress.elapsed)))
                    .font(TimeMasterFont.micro().monospacedDigit()).foregroundStyle(Theme.textSecondary)
            }
            .frame(minWidth: controlSize, maxWidth: .infinity, alignment: .leading)
            Button(action: context.onPause) {
                Image(systemName: context.progress.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: controlSize, height: controlSize)
            }
            .keyNavTarget(shape: .circle)
            .accessibilityLabel(context.progress.isPaused ? "Resume workout" : "Pause workout")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
    }

    private var musicControls: some View {
        HStack(spacing: 0) {
            Button(action: context.onOpenMusic) {
                WorkoutMusicCover(artwork: music.artwork(in: library), size: controlSize * 0.6, circular: false)
                    .frame(width: controlSize, height: controlSize)
            }
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Open live music timeline")
            .accessibilityValue(music.title ?? "No music playing")
            WorkoutMusicTransportButtons(session: music)
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutFloatingControlsOverlay: ViewModifier {
    let workoutName: String
    let context: WorkoutLiveContext?
    let library: MusicLibraryStore
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    func body(content: Content) -> some View {
        content.overlay {
            if let context {
                let hasMusic = context.music.timeline?.clips.isEmpty == false
                WorkoutFloatingWidget(width: controlSize * (hasMusic ? 7 : 5)) {
                    FloatingControlsBar(workoutName: workoutName, context: context, library: library)
                }
            }
        }
    }
}

struct WorkoutFloatingSurface: ViewModifier {
    var circular = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var radius: CGFloat = 14

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: circular ? radius * 4 : radius, style: .continuous)
        if reduceTransparency {
            content.background(Theme.surface2, in: shape)
        } else {
            content.background(.thinMaterial, in: shape)
                .shadow(color: .black.opacity(0.2), radius: radius * 0.6, y: radius * 0.2)
        }
    }
}
