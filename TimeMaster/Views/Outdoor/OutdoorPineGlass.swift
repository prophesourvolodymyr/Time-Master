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
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        identity: String,
        namespace: Namespace.ID,
        cornerRadius: CGFloat,
        flat: Bool = false,
        interactive: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.identity = identity
        self.namespace = namespace
        self.cornerRadius = cornerRadius
        self.flat = flat
        self.interactive = interactive
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
                OutdoorFrostedGlassBackground()
                RoundedRectangle(cornerRadius: flat ? 0 : cornerRadius, style: .continuous)
                    .fill(Theme.surface.opacity(0.20))
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
        let tintOpacity = prominent ? 0.58 : 0.46
        return material(
            configuration.label
                .padding(.horizontal, circular ? 0 : 8)
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
        RoundedRectangle(cornerRadius: circular ? minimumSize / 2 : 14, style: .continuous)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        OutdoorCornerGrip()
            .stroke(Color.white.opacity(drag.isDragging ? 1 : 0.78), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag.handleBend)))
            .offset(
                x: reduceMotion ? 0 : drag.handleBias * 0.35,
                y: reduceMotion ? 0 : drag.handleBend * 0.35
            )
            .scaleEffect(reduceMotion ? 1 : appeared ? (drag.isDragging ? 1.08 : 1) : 0.7, anchor: .topTrailing)
            .shadow(color: .white.opacity(drag.isDragging ? 0.36 : 0), radius: 4)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.72),
                value: drag.isDragging
            )
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.66)) {
                    appeared = true
                }
            }
    }
}

private struct OutdoorCornerGrip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        return path
    }
}


#endif
