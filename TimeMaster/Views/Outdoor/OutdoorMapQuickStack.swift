#if os(iOS)
import SwiftUI

struct OutdoorMapQuickStack: View {
    let opacity: CGFloat
    let onSelect: (OutdoorUpperQuickFeature) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 8) {
            quickButton(.map, systemImage: "map", label: "Open map quick pane")
            quickButton(.trophy, systemImage: "trophy", label: "Open trophy quick pane")
            quickButton(.settings, systemImage: "gearshape", label: "Open settings quick pane")
        }
        .opacity(opacity)
        .allowsHitTesting(opacity > 0.05)
    }

    private func quickButton(_ feature: OutdoorUpperQuickFeature, systemImage: String, label: String) -> some View {
        Button {
            onSelect(feature)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(
                    Theme.surface.opacity(reduceTransparency ? 0.98 : 0.74),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(OutdoorMapQuickButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(label)
        .accessibilityHint("Opens the shared upper quick pane from this control.")
    }

}

private struct OutdoorMapQuickButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.white.opacity(0.055) : .clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.92)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
#endif
