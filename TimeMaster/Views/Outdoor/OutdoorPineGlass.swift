#if os(iOS)
import SwiftUI

struct OutdoorPineGlassSurface<Content: View>: View {
    let identity: String
    let namespace: Namespace.ID
    let cornerRadius: CGFloat
    let flat: Bool
    let interactive: Bool
    let isMapInteracting: Bool
    let liveGlassEnabled: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        identity: String,
        namespace: Namespace.ID,
        cornerRadius: CGFloat,
        flat: Bool = false,
        interactive: Bool = true,
        isMapInteracting: Bool = false,
        liveGlassEnabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.identity = identity
        self.namespace = namespace
        self.cornerRadius = cornerRadius
        self.flat = flat
        self.interactive = interactive
        self.isMapInteracting = isMapInteracting
        self.liveGlassEnabled = liveGlassEnabled
        self.content = content
    }

    var body: some View {
        if reduceTransparency {
            opaqueSurface
        } else if #available(iOS 26.0, *) {
            nativeSurface
        } else {
            fallbackSurface
        }
    }

    private var opaqueSurface: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .fill(Theme.surface.opacity(0.98))
            }
            .clipShape(RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
    }

    @available(iOS 26.0, *)
    private var nativeSurface: some View {
        GlassEffectContainer(spacing: 18) {
            glassContent
                .glassEffectID(identity, in: namespace)
        }
        .clipShape(RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous))
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var glassContent: some View {
        if interactive {
            content()
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: flat ? 0 : cornerRadius)
                )
        } else {
            content()
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: flat ? 0 : cornerRadius)
                )
        }
    }

    private var fallbackSurface: some View {
        content()
            .background {
                if liveGlassEnabled && !isMapInteracting {
                    TimeMasterLiquidGlassBackground(
                        cornerRadius: flat ? 0 : cornerRadius,
                        isInteractive: interactive
                    )
                } else {
                    RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                        .fill(Theme.surface.opacity(0.92))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
}

}
struct OutdoorPineButtonStyle: ButtonStyle {
    let prominent: Bool
    let circular: Bool
    let minimumSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(prominent: Bool = false, circular: Bool = false, minimumSize: CGFloat = 44) {
        self.prominent = prominent
        self.circular = circular
        self.minimumSize = minimumSize
    }

    func makeBody(configuration: Configuration) -> some View {
        material(
            configuration.label
                .frame(minWidth: minimumSize, minHeight: minimumSize)
                .foregroundStyle(prominent ? Theme.background : Theme.textPrimary)
                .background {
                    shape
                        .fill(prominent ? Theme.restAccent : Color.white.opacity(reduceTransparency ? 0.16 : 0.08))
                }
                .overlay {
                    shape.strokeBorder(
                        prominent ? Color.white.opacity(0.42) : Color.white.opacity(reduceTransparency ? 0.28 : 0.14),
                        lineWidth: 1
                    )
                }
        )
        .clipShape(shape)
        .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.94)
        .opacity(configuration.isPressed ? 0.86 : 1)
        .animation(
            reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.88),
            value: configuration.isPressed
        )
        .contentShape(shape)
    }

    @ViewBuilder
    private func material<Content: View>(_ content: Content) -> some View {
        if reduceTransparency {
            content
        } else if #available(iOS 26.0, *) {
            if prominent {
                content.glassEffect(
                    .regular.tint(Theme.restAccent).interactive(),
                    in: shape
                )
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .background {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.surface.opacity(0.42))
                }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: circular ? minimumSize / 2 : 14, style: .continuous)
    }
}

struct OutdoorPineHandle<Drag: Gesture>: View {
    let label: String
    let value: String
    let onAdjust: (AccessibilityAdjustmentDirection) -> Void
    let onDrag: Drag

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.74))
            .frame(width: 54, height: 5)
            .frame(width: 132, height: 48)
            .contentShape(Rectangle())
            .gesture(onDrag)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction(onAdjust)
    }
}

#endif
