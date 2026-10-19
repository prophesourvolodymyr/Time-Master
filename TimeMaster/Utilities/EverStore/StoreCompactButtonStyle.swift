import SwiftUI

struct StoreCompactButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isPrimary = true
    var minimumHeight: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TimeMasterFont.rowTitle())
            .padding(.horizontal, EverSpacing.x4)
            .padding(.vertical, EverSpacing.x2)
            .frame(minWidth: EverLayout.minimumTouchTarget * 1.5, minHeight: minimumHeight)
            .foregroundStyle(isEnabled ? (isPrimary ? EverColor.onAccent : EverColor.textPrimary) : EverColor.disabledContent)
            .background(isEnabled ? (isPrimary ? EverColor.accent : EverColor.background) : EverColor.disabledSurface, in: Capsule())
            .modifier(EverSpecularButtonEffect(isPressed: configuration.isPressed, isEnabled: isEnabled, radius: 999, isLightBase: isPrimary))
            .frame(minHeight: EverLayout.minimumTouchTarget)
    }
}
