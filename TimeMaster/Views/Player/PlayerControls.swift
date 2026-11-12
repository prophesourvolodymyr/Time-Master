import SwiftUI

struct PlayerCounter: View {
    let seconds: Int
    var size: CGFloat = 84
    var phase: WorkoutPhase = .active
    var isPaused = false

    var body: some View {
        Text(PlayerTime.counter(seconds))
            .font(TimeMasterFont.black(size, relativeTo: .largeTitle))
            .foregroundColor(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase.playerSpokenName)
            .accessibilityValue(isPaused ? "Paused, \(PlayerTime.spoken(seconds)) left" : "\(PlayerTime.spoken(seconds)) left")
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct PlayerPlayButton: View {
    let isPaused: Bool
    let action: () -> Void
    var diameter: CGFloat = 68

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: diameter * 0.35))
                .foregroundColor(.black)
                .frame(width: diameter, height: diameter)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                .modifier(PlayerSymbolTransition())
        }
        .keyNavTarget(shape: .circle)
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }
}

struct PlayerSymbolTransition: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.contentTransition(.symbolEffect(.replace))
        } else {
            content
        }
    }
}

struct PlayerTransportButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void
    var size: CGFloat = 48

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .bold))
                .playerGlassCircle(size: size)
        }
        .keyNavTarget(shape: .circle)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}
