import SwiftUI

enum TmaxMenuMetrics {
    static let lift: CGFloat = 8
    static let maximumRadius: CGFloat = 22
    static let corner: CGFloat = 24
    static let rowHeight: CGFloat = 48
    static let minimumWidth: CGFloat = 210
    static let blurSigma: CGFloat = 4.5
}

struct TmaxMenuCurrentKey: Hashable {}

extension View {
    @ViewBuilder
    func tmaxMenuCurrent(_ isCurrent: Bool = true) -> some View {
        if isCurrent {
            id(TmaxMenuCurrentKey())
        } else {
            self
        }
    }
}

struct TmaxMenuSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    #if os(iOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 6)
            content
        }
    }
    #else
    var body: some View {
        SwiftUI.Section(title) { content }
    }
    #endif
}

final class TmaxMenuNavigator: ObservableObject {
    @Published private(set) var stack: [AnyView] = []
    private var navigated = false

    func push(_ view: AnyView) {
        navigated = true
        stack.append(view)
    }

    func pop() {
        navigated = true
        if !stack.isEmpty { stack.removeLast() }
    }

    func consumeNavigation() -> Bool {
        defer { navigated = false }
        return navigated
    }
}

private struct TmaxMenuNavigatorKey: EnvironmentKey {
    static let defaultValue: TmaxMenuNavigator? = nil
}

extension EnvironmentValues {
    var tmaxMenuNavigator: TmaxMenuNavigator? {
        get { self[TmaxMenuNavigatorKey.self] }
        set { self[TmaxMenuNavigatorKey.self] = newValue }
    }
}

struct TmaxSubmenu<Content: View, Label: View>: View {
    private let content: Content
    private let label: Label

    @Environment(\.tmaxMenuNavigator) private var navigator

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        if let navigator {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    navigator.push(AnyView(content))
                }
            } label: {
                HStack(spacing: 10) {
                    label
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        } else {
            Menu {
                content
            } label: {
                label
            }
        }
    }
}

#if os(iOS)
import UIKit

struct TmaxMenu<Content: View, Label: View>: View {
    private let cornerRadius: CGFloat?
    private let inset: CGFloat
    private let content: Content
    private let label: Label

    @State private var isOpen = false
    @State private var lift = TmaxMenuMetrics.lift
    @State private var anchor = TmaxMenuAnchorBox()

    init(
        cornerRadius: CGFloat? = nil,
        inset: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.cornerRadius = cornerRadius
        self.inset = inset
        self.content = content()
        self.label = label()
    }

    var body: some View {
        Button(action: open) {
            label
        }
        .environment(\.everBouncePops, false)
        .everBounce(isOpen, in: Rectangle(), kind: .lift(lift), lights: false)
        .background(TmaxMenuAnchor(box: anchor))
    }

    private func open() {
        guard !isOpen, !TmaxMenuPresenter.shared.isPresenting,
              let view = anchor.view, let window = view.window, let scene = window.windowScene else { return }
        let frame = view.convert(view.bounds, to: nil).insetBy(dx: inset, dy: inset)
        guard frame.width > 1, frame.height > 1 else { return }
        lift = view.isInsideBar ? 0 : TmaxMenuMetrics.lift
        let backdrop = TmaxMenuBackdrop.capture(window)
        isOpen = true
        TmaxMenuPresenter.shared.present(
            TmaxMenuRequest(
                anchor: frame,
                container: window.bounds.size,
                safeInsets: window.safeAreaInsets,
                cornerRadius: cornerRadius ?? min(frame.height / 2, TmaxMenuMetrics.maximumRadius),
                lift: lift,
                interfaceStyle: view.traitCollection.userInterfaceStyle,
                scene: scene,
                backdrop: backdrop,
                content: AnyView(content)
            ),
            onClose: { isOpen = false }
        )
    }
}

final class TmaxMenuAnchorBox {
    weak var view: UIView?
}

private struct TmaxMenuAnchor: UIViewRepresentable {
    let box: TmaxMenuAnchorBox

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        box.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        box.view = view
    }
}

private extension UIView {
    var isInsideBar: Bool {
        var current = superview
        while let view = current {
            if view is UINavigationBar || view is UIToolbar { return true }
            current = view.superview
        }
        return false
    }
}

struct TmaxMenuRequest {
    let anchor: CGRect
    let container: CGSize
    let safeInsets: UIEdgeInsets
    let cornerRadius: CGFloat
    let lift: CGFloat
    let interfaceStyle: UIUserInterfaceStyle
    let scene: UIWindowScene
    let backdrop: UIImage?
    let content: AnyView
}

@MainActor
final class TmaxMenuSession: ObservableObject {
    @Published private(set) var isShown = false
    var onClose: (() -> Void)?
    var onFinish: (() -> Void)?
    private var isClosing = false

    func appear() {
        guard !isShown, !isClosing else { return }
        isShown = true
    }

    func dismiss(animated: Bool = true) {
        guard !isClosing else { return }
        isClosing = true
        isShown = false
        onClose?()
        let delay = animated ? 0.34 : 0.0
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.onFinish?()
        }
    }
}

@MainActor
final class TmaxMenuPresenter {
    static let shared = TmaxMenuPresenter()

    private var window: UIWindow?

    var isPresenting: Bool { window != nil }

    func present(_ request: TmaxMenuRequest, onClose: @escaping () -> Void) {
        guard window == nil else { return }
        let session = TmaxMenuSession()
        session.onClose = onClose
        session.onFinish = { [weak self] in self?.tearDown() }
        let host = UIHostingController(rootView: TmaxMenuOverlay(request: request, session: session))
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: request.scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.overrideUserInterfaceStyle = request.interfaceStyle
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    private func tearDown() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        window?.isHidden = true
        window = nil
    }
}
#else
struct TmaxMenu<Content: View, Label: View>: View {
    private let content: Content
    private let label: Label

    init(
        cornerRadius: CGFloat? = nil,
        inset: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        Menu {
            content
        } label: {
            label
        }
    }
}
#endif
