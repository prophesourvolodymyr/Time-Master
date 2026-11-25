#if os(iOS)
import SwiftUI
import UIKit
import CoreImage

enum TmaxMenuPalette {
    static let card = Color(hex: "242424")
    static let edge = Color.white.opacity(0.14)
    static let divider = Color.white.opacity(0.08)
    static let pressed = Color.white.opacity(0.10)
    static let veil = Theme.background.opacity(0.55)
}

struct TmaxMenuLayout {
    let size: CGSize
    let origin: CGPoint
    let anchorPoint: UnitPoint
    let hole: CGRect
    let holeRadius: CGFloat

    init(request: TmaxMenuRequest, natural: CGSize) {
        let margin: CGFloat = 16
        let gap: CGFloat = 10
        let anchor = request.anchor
        let longest = max(anchor.width, anchor.height, 1)
        let growth = request.lift > 0 ? min(EverBounceMotion.maximumGrowth, request.lift / longest) : 0
        let scale = 1 + growth
        let holeMargin: CGFloat = 3
        let hole = CGRect(
            x: anchor.midX - anchor.width * scale / 2 - holeMargin,
            y: anchor.midY - anchor.height * scale / 2 - holeMargin,
            width: anchor.width * scale + holeMargin * 2,
            height: anchor.height * scale + holeMargin * 2
        )
        let maxWidth = request.container.width - margin * 2
        let width = min(max(natural.width, TmaxMenuMetrics.minimumWidth), maxWidth)
        let topLimit = request.safeInsets.top + margin
        let bottomLimit = request.container.height - request.safeInsets.bottom - margin
        let spaceBelow = bottomLimit - (hole.maxY + gap)
        let spaceAbove = (hole.minY - gap) - topLimit
        let isBelow = natural.height <= spaceBelow || spaceBelow >= spaceAbove
        let room = max(isBelow ? spaceBelow : spaceAbove, 120)
        let height = min(natural.height, room)
        let y = isBelow ? hole.maxY + gap : hole.minY - gap - height
        let isTrailing = anchor.midX > request.container.width / 2
        let preferred = isTrailing ? hole.maxX - width : hole.minX
        let x = min(max(preferred, margin), request.container.width - margin - width)

        self.size = CGSize(width: width, height: height)
        self.origin = CGPoint(x: x, y: y)
        self.anchorPoint = UnitPoint(x: min(max((anchor.midX - x) / width, 0), 1), y: isBelow ? 0 : 1)
        self.hole = hole
        self.holeRadius = request.cornerRadius * scale + holeMargin
    }
}

struct TmaxMenuHole: Shape {
    let hole: CGRect
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

struct TmaxMenuOverlay: View {
    let request: TmaxMenuRequest
    @ObservedObject var session: TmaxMenuSession

    @State private var natural: CGSize = .zero
    @StateObject private var navigator = TmaxMenuNavigator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = TmaxMenuLayout(request: request, natural: natural)
        ZStack(alignment: .topLeading) {
            veil(layout)
            card(layout)
        }
        .frame(width: request.container.width, height: request.container.height, alignment: .topLeading)
        .ignoresSafeArea()
        .onChange(of: natural) { size in
            guard size.width > 0, size.height > 0, !session.isShown else { return }
            AppInteractionHaptics.shared.menuOpened()
            session.appear()
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !session.isShown else { return }
                if natural.height > 0 {
                    session.appear()
                } else {
                    session.dismiss(animated: false)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            session.dismiss(animated: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            session.dismiss(animated: false)
        }
        .accessibilityAction(.escape) { session.dismiss() }
    }

    private func veil(_ layout: TmaxMenuLayout) -> some View {
        ZStack {
            if let backdrop = request.backdrop {
                Image(uiImage: backdrop)
                    .resizable()
                    .interpolation(.high)
            }
            TmaxMenuPalette.veil
        }
        .frame(width: request.container.width, height: request.container.height)
        .mask {
            TmaxMenuHole(hole: layout.hole, radius: layout.holeRadius)
                .fill(style: FillStyle(eoFill: true))
        }
        .opacity(session.isShown ? 1 : 0)
        .animation(.easeOut(duration: 0.22), value: session.isShown)
        .background(Color.clear.contentShape(Rectangle()))
        .contentShape(Rectangle())
        .onTapGesture { session.dismiss() }
        .accessibilityHidden(true)
    }

    private func card(_ layout: TmaxMenuLayout) -> some View {
        TmaxMenuCard(
            content: request.content,
            navigator: navigator,
            natural: $natural,
            size: layout.size,
            onSelect: {
                AppInteractionHaptics.shared.selectionChanged()
                session.dismiss()
            }
        )
        .scaleEffect(reduceMotion || session.isShown ? 1 : 0.4, anchor: layout.anchorPoint)
        .opacity(session.isShown ? 1 : 0)
        .animation(
            session.isShown ? .spring(response: 0.38, dampingFraction: 0.78) : .easeIn(duration: 0.16),
            value: session.isShown
        )
        .position(x: layout.origin.x + layout.size.width / 2, y: layout.origin.y + layout.size.height / 2)
        .animation(session.isShown && !reduceMotion ? .spring(response: 0.32, dampingFraction: 0.86) : nil, value: natural)
    }
}

private struct TmaxMenuSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct TmaxMenuCard: View {
    let content: AnyView
    @ObservedObject var navigator: TmaxMenuNavigator
    @Binding var natural: CGSize
    let size: CGSize
    let onSelect: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TmaxMenuMetrics.corner, style: .continuous)
        let measured = natural.width > 0
        let scrolls = measured && natural.height > size.height + 0.5
        Group {
            if scrolls {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        stack
                    }
                    .onAppear { proxy.scrollTo(TmaxMenuCurrentKey(), anchor: .center) }
                }
            } else {
                stack
            }
        }
        .frame(width: measured ? size.width : nil, height: measured ? size.height : nil)
        .background(shape.fill(TmaxMenuPalette.card))
        .clipShape(shape)
        .overlay(shape.strokeBorder(TmaxMenuPalette.edge, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 28, y: 12)
        .background(alignment: .topLeading) {
            stack
                .fixedSize()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: TmaxMenuSizeKey.self, value: proxy.size)
                    }
                )
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onPreferenceChange(TmaxMenuSizeKey.self) { size in
            if size.width > 0, size != natural { natural = size }
        }
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let top = navigator.stack.last {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        navigator.pop()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.toolbarOrange)
                        Text("Back")
                        Spacer(minLength: 0)
                    }
                }
                top
            } else {
                content
            }
        }
        .environment(\.tmaxMenuNavigator, navigator)
        .environment(\.tmaxMenuSelect, onSelect)
        .buttonStyle(TmaxMenuRowStyle())
        .menuStyle(.button)
        .labelStyle(TmaxMenuLabelStyle())
        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
        .foregroundStyle(Theme.textPrimary)
        .frame(minWidth: TmaxMenuMetrics.minimumWidth, alignment: .leading)
    }
}

private struct TmaxMenuSelectKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var tmaxMenuSelect: (() -> Void)? {
        get { self[TmaxMenuSelectKey.self] }
        set { self[TmaxMenuSelectKey.self] = newValue }
    }
}

struct TmaxMenuRowStyle: PrimitiveButtonStyle {
    @Environment(\.tmaxMenuNavigator) private var navigator
    @Environment(\.tmaxMenuSelect) private var select

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
            if navigator?.consumeNavigation() != true { select?() }
        } label: {
            configuration.label
        }
        .buttonStyle(TmaxMenuRowFace())
    }
}

private struct TmaxMenuRowFace: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
            .foregroundStyle(configuration.role == .destructive ? Color(hex: "FF453A") : Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: TmaxMenuMetrics.rowHeight, alignment: .leading)
            .background(configuration.isPressed ? TmaxMenuPalette.pressed : Color.clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(TmaxMenuPalette.divider)
                    .frame(height: 0.5)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct TmaxMenuLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.title
            Spacer(minLength: 12)
            configuration.icon
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
        }
    }
}

@MainActor
enum TmaxMenuBackdrop {
    private static let context = CIContext()

    static func capture(_ window: UIWindow) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        let snapshot = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        guard let input = CIImage(image: snapshot) else { return nil }
        let blurred = input.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(TmaxMenuMetrics.blurSigma))
            .cropped(to: input.extent)
        guard let output = context.createCGImage(blurred, from: input.extent) else { return nil }
        return UIImage(cgImage: output)
    }
}
#endif
