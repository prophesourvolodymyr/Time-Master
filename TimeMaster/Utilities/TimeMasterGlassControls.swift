import SwiftUI

#if os(iOS)
import UIKit

struct TimeMasterFrostedGlassBackground: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterialDark

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}
#endif

struct TimeMasterGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool
    var tint: Color = Theme.toolbarOrange
    var tintOpacity: Double = 0.46

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        material(content.background(shape.fill(tint.opacity(tintOpacity))))
            .overlay {
                shape.strokeBorder(
                    .white.opacity(reduceTransparency || contrast == .increased ? 0.32 : 0.18),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .clipShape(shape)
    }

    @ViewBuilder
    private func material<Surface: View>(_ content: Surface) -> some View {
        if reduceTransparency {
            content.background(shape.fill(Theme.surface))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            let glass = isInteractive
                ? Glass.regular.tint(tint).interactive()
                : Glass.regular.tint(tint)
            content.glassEffect(glass, in: shape)
        } else {
            content.background {
                #if os(iOS)
                TimeMasterFrostedGlassBackground()
                #else
                shape.fill(.regularMaterial)
                #endif
                shape.fill(tint.opacity(0.24))
            }
        }
    }
}

struct TimeMasterActionFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || !isPressed || !isEnabled ? 1 : 0.94)
            .opacity(isEnabled ? (isPressed ? 0.86 : 1) : 0.45)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88),
                value: isPressed
            )
    }
}

struct TimeMasterActionButtonStyle: ButtonStyle {
    let prominent: Bool
    let circular: Bool
    let minimumSize: CGFloat
    let expansion: CGFloat
    let fillsWidth: Bool
    let horizontalPadding: CGFloat

    @Environment(\.isFocused) private var isFocused

    init(
        prominent: Bool = false,
        circular: Bool = false,
        minimumSize: CGFloat = 44,
        expansion: CGFloat = 1,
        fillsWidth: Bool = false,
        horizontalPadding: CGFloat = 14
    ) {
        self.prominent = prominent
        self.circular = circular
        self.minimumSize = minimumSize
        self.expansion = min(1, max(0, expansion))
        self.fillsWidth = fillsWidth
        self.horizontalPadding = horizontalPadding
    }

    func makeBody(configuration: Configuration) -> some View {
        let radius = circular ? minimumSize / 2
            : minimumSize / 2 + (Theme.controlCornerRadius - minimumSize / 2) * expansion
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let hitMinimum = max(44, minimumSize)
        configuration.label
            .padding(.horizontal, circular ? 0 : horizontalPadding * expansion)
            .frame(width: circular ? minimumSize : nil, height: circular ? minimumSize : nil)
            .frame(
                minWidth: minimumSize,
                maxWidth: fillsWidth && !circular ? .infinity : nil,
                minHeight: minimumSize
            )
            .foregroundStyle(Theme.textPrimary)
            .modifier(TimeMasterGlassSurface(
                cornerRadius: radius,
                isInteractive: true,
                tint: configuration.role == .destructive ? .red : Theme.toolbarOrange,
                tintOpacity: prominent ? 0.58 : 0.46
            ))
            .overlay {
                if isFocused {
                    shape.strokeBorder(.white.opacity(0.75), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .background(SlotNavigationContentClearanceReader(primaryAction: prominent))
            .contentShape(shape)
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .frame(minWidth: hitMinimum, minHeight: hitMinimum)
            .contentShape(Rectangle())
    }
}
