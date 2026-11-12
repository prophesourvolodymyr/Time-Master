#if os(iOS)
import SwiftUI
import UIKit


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
                if !solid { TimeMasterFrostedGlassBackground() }
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
        .buttonStyle(TimeMasterActionButtonStyle(prominent: prominent, circular: true, minimumSize: max(44, size)))
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
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.surface, in: Capsule())
                            .offset(x: 12, y: -6)
                    }
                }
                Text(title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
        }
        .buttonStyle(TimeMasterActionButtonStyle())
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
                    TmaxLoadingIndicator(size: 18)
                } else {
                    Image(systemName: symbol)
                        .font(.headline)
                }
                Text(title)
                    .font(TimeMasterFont.sectionTitle())
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
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

enum OutdoorPaneMotion {
    static func page(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 1, blendDuration: 0.12)
    }
}

final class OutdoorPaneDirection {
    private(set) var forward = true
    private var key: AnyHashable?
    private var depth = 0

    func track(_ key: AnyHashable, depth: Int) {
        if let current = self.key, current != key {
            forward = depth >= self.depth
        }
        self.key = key
        self.depth = depth
    }
}

private struct OutdoorPaneSlide: ViewModifier {
    enum Role { case identity, insertion, removal }
    let role: Role
    let direction: OutdoorPaneDirection
    let width: CGFloat

    func body(content: Content) -> some View {
        let forward = direction.forward
        let covered = (role == .insertion && !forward) || (role == .removal && forward)
        content
            .offset(x: offset(forward: forward))
            .opacity(role != .identity && covered ? 0 : 1)
    }

    private func offset(forward: Bool) -> CGFloat {
        switch role {
        case .identity: return 0
        case .insertion: return forward ? width : -width * 0.3
        case .removal: return forward ? -width * 0.3 : width
        }
    }
}

struct OutdoorPanePager<Key: Hashable, Content: View>: View {
    let key: Key
    let depth: Int
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var direction = OutdoorPaneDirection()

    var body: some View {
        let _ = direction.track(AnyHashable(key), depth: depth)
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .id(key)
                    .zIndex(Double(depth))
                    .transition(transition(width: proxy.size.width))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .clipped()
    }

    private func transition(width: CGFloat) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let width = max(width, 1)
        return .asymmetric(
            insertion: .modifier(
                active: OutdoorPaneSlide(role: .insertion, direction: direction, width: width),
                identity: OutdoorPaneSlide(role: .identity, direction: direction, width: width)
            ),
            removal: .modifier(
                active: OutdoorPaneSlide(role: .removal, direction: direction, width: width),
                identity: OutdoorPaneSlide(role: .identity, direction: direction, width: width)
            )
        )
    }
}

struct OutdoorPaneLabeledAction: View {
    let symbol: String
    let title: String
    var accessibilityTitle: String?
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
        }
        .buttonStyle(OutdoorPaneLabeledButtonStyle(title: title, prominent: prominent))
        .accessibilityLabel(accessibilityTitle ?? title)
    }
}

private struct OutdoorPaneLabeledButtonStyle: ButtonStyle {
    let title: String
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 5) {
            TimeMasterActionButtonStyle(prominent: prominent, circular: true, minimumSize: 44)
                .makeBody(configuration: configuration)
            Text(title)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(minWidth: 60)
        .contentShape(Rectangle())
    }
}

struct OutdoorPaneStatusTile<Actions: View>: View {
    let symbol: String
    let title: String
    var detail: String?
    var loading = false
    var stacksActions = false
    @ViewBuilder let actions: () -> Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDetail = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Theme.toolbarOrange.opacity(0.16))
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Theme.toolbarOrange.opacity(0.36), lineWidth: 1)
                    if loading {
                        TmaxLoadingIndicator(size: 22)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                }
                .frame(width: 50, height: 50)
                .accessibilityHidden(true)
                Text(title)
                    .font(TimeMasterFont.rowTitle())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if detail != nil {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) { showsDetail.toggle() }
                    } label: {
                        Image(systemName: showsDetail ? "chevron.up.circle.fill" : "info.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsDetail ? "Hide details" : "Show details")
                }
                if !stacksActions, Actions.self != EmptyView.self {
                    actions()
                }
            }
            if showsDetail, let detail {
                Text(detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .transition(.opacity)
            }
            if stacksActions, Actions.self != EmptyView.self {
                HStack(alignment: .top, spacing: 16) { actions() }
                    .padding(.leading, 62)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color.black.opacity(0.24)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
    }
}

struct OutdoorPaneSectionHeader: View {
    let title: String
    let symbol: String
    var count: Int?
    var onShowAll: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            if let count, count > 0 {
                Text(count.formatted())
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .accessibilityLabel("\(count.formatted()) routes")
            }
            Spacer(minLength: 8)
            if let onShowAll {
                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text("All")
                            .font(TimeMasterFont.black(13, relativeTo: .footnote))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show all \(title)")
            }
        }
        .frame(minHeight: 32)
    }
}

#endif
