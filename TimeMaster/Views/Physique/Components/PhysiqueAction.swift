import SwiftUI

struct PhysiqueAction: View {
    let title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var disabled = false
    var prominent = true
    let action: () -> Void
    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: ProfileStyle.spacing * 0.75) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .font(TimeMasterFont.label())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PhysiqueActionButtonStyle(prominent: prominent))
        .disabled(disabled)
    }
}

private struct PhysiqueActionButtonStyle: ButtonStyle {
    let prominent: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let isPrimary = prominent && configuration.role == nil
        let isDestructive = configuration.role == .destructive
        let shape = RoundedRectangle(cornerRadius: ProfileStyle.spacing, style: .continuous)

        configuration.label
            .foregroundStyle(isDestructive ? Color.red : isPrimary ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.vertical, ProfileStyle.spacing)
            #if os(macOS)
            .frame(minHeight: ProfileStyle.touchTarget)
            #else
            .frame(minHeight: ProfileStyle.touchTarget + 8)
            #endif
            .background(shape.fill(isPrimary ? Theme.toolbarOrange : Theme.surface2))
            .overlay {
                shape.strokeBorder(
                    isDestructive ? Color.red.opacity(contrast == .increased ? 1 : 0.8)
                        : Theme.textPrimary.opacity(contrast == .increased ? 0.5 : isPrimary ? 0 : 0.16),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                if isFocused {
                    shape.inset(by: -4)
                        .strokeBorder(Theme.textPrimary, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .background(SlotNavigationContentClearanceReader(primaryAction: prominent && configuration.role != .cancel))
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: ProfileStyle.spacing))
    }
}

extension View {
    func physiqueToolbarTarget(shape: KeyNavShape = .capsule, action: (() -> Void)? = nil) -> some View {
        keyNavTarget(shape: shape, action: action).keyNavAccessoryHost()
    }
}
