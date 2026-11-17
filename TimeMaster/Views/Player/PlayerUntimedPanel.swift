import SwiftUI

/// The face of an untimed set: its reps large, a smaller count-up stopwatch, and the big Done button that ends it.
struct PlayerUntimedPanel: View {
    let repCount: Int?
    let elapsed: Int
    let isPaused: Bool
    var compact = false
    var isEnabled = true
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if let repCount {
                VStack(spacing: 0) {
                    Text("\(repCount)")
                        .font(TimeMasterFont.black(compact ? 64 : 84, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    caption(repCount == 1 ? "REP" : "REPS")
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(repCount == 1 ? "1 rep" : "\(repCount) reps")
                .accessibilityIdentifier("player.reps")
            } else {
                caption("UNTIL DONE")
                    .accessibilityHidden(true)
            }
            stopwatch
            Button(action: onDone) {
                Label("Done", systemImage: "checkmark")
                    .font(TimeMasterFont.black(compact ? 20 : 22, relativeTo: .title3))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: compact ? 60 : 68, fillsWidth: true))
            .keyboardShortcut(.defaultAction)
            .disabled(!isEnabled)
            .frame(maxWidth: 360)
            .padding(.horizontal, 32)
            .padding(.top, compact ? 2 : 6)
            .accessibilityHint("Ends this set")
            .accessibilityIdentifier("player.done")
        }
        .frame(maxWidth: .infinity)
    }

    private var stopwatch: some View {
        let size: CGFloat = repCount == nil ? (compact ? 40 : 48) : (compact ? 20 : 24)
        return Label(PlayerTime.clock(elapsed), systemImage: "stopwatch")
            .labelStyle(PlayerFactLabelStyle())
            .font(TimeMasterFont.black(size, relativeTo: .title2).monospacedDigit())
            .foregroundStyle(.white.opacity(isPaused ? 0.45 : 0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time in this set, until done")
            .accessibilityValue(isPaused ? "Paused, \(PlayerTime.spoken(elapsed))" : PlayerTime.spoken(elapsed))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("player.elapsed")
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(TimeMasterFont.black(12, relativeTo: .caption))
            .tracking(5)
            .foregroundStyle(.white.opacity(0.5))
    }
}
