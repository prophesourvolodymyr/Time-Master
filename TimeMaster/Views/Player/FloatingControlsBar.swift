import SwiftUI

struct FloatingControlsBar: View {
    let sectionName: String
    let sectionIndex: Int
    let totalSections: Int
    let timeRemaining: Int
    let elapsedSeconds: Int
    let isPaused: Bool
    let isTimerEnabled: Bool
    let isRest: Bool
    let isMusicPlaying: Bool
    let nextExerciseName: String?
    let onPause: () -> Void
    let onMusicToggle: () -> Void
    let onStop: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @State private var showingStopConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            dismissButton
            Spacer(minLength: 8)
            infoCenter
            Spacer(minLength: 8)
            controlsGroup
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .alert("Stop Workout?", isPresented: $showingStopConfirmation) {
            Button("Continue", role: .cancel) {}
            Button("Stop", role: .destructive) { onStop() }
        } message: {
            Text("Your progress will be lost.")
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private var infoCenter: some View {
        VStack(spacing: 1) {
            Text(sectionName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            if isTimerEnabled {
                Text(isRest ? formatTime(timeRemaining) : formatTime(timeRemaining))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("\(sectionIndex + 1) of \(totalSections)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
            if let nextExerciseName {
                Text("Next: \(nextExerciseName)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controlsGroup: some View {
        HStack(spacing: 6) {
            Button(action: onMusicToggle) {
                Image(systemName: isMusicPlaying ? "music.note" : "music.note.slash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(isMusicPlaying ? Color.white.opacity(0.28) : Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Button(action: onPause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Button(action: { showingStopConfirmation = true }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Button(action: onSkip) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : String(format: "%02d", secs)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            FloatingControlsBar(
                sectionName: "Burpees",
                sectionIndex: 2,
                totalSections: 5,
                timeRemaining: 45,
                elapsedSeconds: 120,
                isPaused: false,
                isTimerEnabled: true,
                isRest: false,
                isMusicPlaying: false,
                nextExerciseName: "Shoulder Press",
                onPause: {},
                onMusicToggle: {},
                onStop: {},
                onSkip: {},
                onDismiss: {}
            )
            Spacer()
        }
    }
}
