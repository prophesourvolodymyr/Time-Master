#if os(iOS)
import SwiftUI
import UIKit

struct OutdoorFrostedGlassBackground: UIViewRepresentable {
    let style: UIBlurEffect.Style

    init(style: UIBlurEffect.Style = .systemMaterialDark) {
        self.style = style
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

struct OutdoorPineGlassSurface<Content: View>: View {
    let identity: String
    let namespace: Namespace.ID
    let cornerRadius: CGFloat
    let flat: Bool
    let interactive: Bool
    let solid: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        identity: String,
        namespace: Namespace.ID,
        cornerRadius: CGFloat,
        flat: Bool = false,
        interactive: Bool = true,
        solid: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.identity = identity
        self.namespace = namespace
        self.cornerRadius = cornerRadius
        self.flat = flat
        self.interactive = interactive
        self.solid = solid
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
        .background(solid ? Theme.surface : .clear)
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
                if !solid { OutdoorFrostedGlassBackground() }
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .fill(Theme.surface.opacity(solid ? 1 : 0.20))
            }
            .clipShape(RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(solid ? 0 : 0.14), lineWidth: 1)
            }
    }

}
struct OutdoorPineButtonStyle: ButtonStyle {
    let prominent: Bool
    let circular: Bool
    let minimumSize: CGFloat
    let expansion: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(prominent: Bool = false, circular: Bool = false, minimumSize: CGFloat = 44, expansion: CGFloat = 1) {
        self.prominent = prominent
        self.circular = circular
        self.minimumSize = minimumSize
        self.expansion = min(1, max(0, expansion))
    }

    func makeBody(configuration: Configuration) -> some View {
        let tintOpacity = prominent ? 0.58 : 0.46
        return material(
            configuration.label
                .padding(.horizontal, circular ? 0 : 8 * expansion)
                .frame(width: circular ? minimumSize : nil, height: circular ? minimumSize : nil)
                .frame(minWidth: minimumSize, minHeight: minimumSize)
                .foregroundStyle(Theme.textPrimary)
                .background {
                    shape
                        .fill(
                            reduceTransparency
                                ? Theme.toolbarOrange.opacity(0.9)
                                : Theme.toolbarOrange.opacity(tintOpacity)
                        )
                }
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(reduceTransparency ? 0.32 : 0.18),
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
            content
                .glassEffect(
                    .regular.tint(Theme.toolbarOrange).interactive(),
                    in: shape
                )
        } else {
            content
                .background {
                    OutdoorFrostedGlassBackground()
                    shape.fill(Theme.toolbarOrange.opacity(0.24))
                }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: circular ? minimumSize / 2 : minimumSize / 2 + (14 - minimumSize / 2) * expansion, style: .continuous)
    }
}

struct OutdoorPineIconAction: View {
    let symbol: String
    let label: String
    var role: ButtonRole?
    var prominent = false
    var size: CGFloat = 44
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.system(size: max(15, size * 0.36), weight: .semibold))
        }
        .buttonStyle(OutdoorPineButtonStyle(prominent: prominent, circular: true, minimumSize: max(44, size)))
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

struct OutdoorPineTileAction: View {
    let symbol: String
    let title: String
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 23, weight: .semibold))
                        .frame(width: 32, height: 30)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.surface, in: Capsule())
                            .offset(x: 12, y: -6)
                    }
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
        }
        .buttonStyle(OutdoorPineButtonStyle())
        .accessibilityLabel(title)
    }
}

struct OutdoorPinePrimaryAction: View {
    let title: String
    let symbol: String
    var loading = false
    var disabled = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(OutdoorPineButtonStyle(prominent: true))
        .disabled(disabled)
        .accessibilityIdentifier(identifier)
    }
}

struct OutdoorPineConnectedActions<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(iOS 26, *), !reduceTransparency {
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 8, content: content)
            }
        } else {
            HStack(spacing: 8, content: content)
        }
    }
}

struct OutdoorPaneHeader<Leading: View, Handle: View, Accessory: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let handle: () -> Handle
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        ZStack {
            handle()
            HStack {
                leading()
                Spacer(minLength: 0)
                accessory()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 6)
    }
}

@MainActor
final class OutdoorPanePresentation: ObservableObject {
    weak var view: UIView?

    var height: CGFloat? {
        guard let view, view.window != nil else { return nil }
        let height = (view.layer.presentation() ?? view.layer).bounds.height
        return height > 0 ? height : nil
    }
}

struct OutdoorPanePresentationProbe: UIViewRepresentable {
    let presentation: OutdoorPanePresentation

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        presentation.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}

struct OutdoorElasticHandle: View {
    let drag: OutdoorPineDragState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OutdoorHandleCurve(
            bend: reduceMotion ? 0 : drag.handleBend,
            bias: reduceMotion ? 0 : drag.handleBias
        )
        .stroke(Color.white.opacity(drag.isDragging ? 1 : 0.74), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .frame(width: 54, height: 18)
        .scaleEffect(x: !reduceMotion && drag.isDragging ? 1.08 : 1, y: 1)
        .shadow(color: .white.opacity(drag.isDragging ? 0.32 : 0), radius: 4)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.76),
            value: drag.isDragging
        )
        .accessibilityHidden(true)
    }
}

private struct OutdoorHandleCurve: Shape {
    var bend: CGFloat
    var bias: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bend, bias) }
        set { bend = newValue.first; bias = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX + bias, y: rect.midY + bend * 2)
        )
        return path
    }
}

struct OutdoorCornerResizeHandle: View {
    let drag: OutdoorPineDragState
    let collapseProgress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = min(1, max(0, collapseProgress))
        ZStack {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .opacity(1 - progress)
                .scaleEffect(1 - progress * 0.12)
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .opacity(progress)
                .scaleEffect(0.88 + progress * 0.12)
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(Theme.textPrimary)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag.handleBend) * 0.5))
        .scaleEffect(reduceMotion || !drag.isDragging ? 1 : 1.06)
        .frame(width: 44, height: 44)
        .background(Theme.surface2.opacity(drag.isDragging ? 0.92 : 0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(drag.isDragging ? 0.30 : 0.14), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .animation(reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.9), value: drag.isDragging)
    }
}



#endif
