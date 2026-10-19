import SwiftUI

struct EverPillTabLabel: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: EverSpacing.x1) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(TimeMasterFont.rowTitle())
        .padding(.horizontal, EverSpacing.x4)
        .padding(.vertical, EverSpacing.x3)
        .foregroundStyle(isSelected ? EverColor.onAccent : EverColor.textSecondary)
        .background(isSelected ? EverColor.accent : EverColor.surfaceSecondary, in: Capsule())
        .frame(minHeight: EverLayout.minimumTouchTarget)
    }
}

struct EverPillTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(EverSpecularButtonEffect(
                isPressed: configuration.isPressed,
                isEnabled: isEnabled,
                radius: 999,
                isLightBase: isSelected
            ))
    }
}
