#if os(macOS)
import AppKit
import SwiftUI

// MARK: - Host

/// `keyNavHost()` / `keyNavAccessoryHost()`: a registry for the targets below, attached to its window.
struct KeyNavHostModifier: ViewModifier {
    let kind: KeyNavController.Kind
    let onPageStep: ((Int) -> Void)?

    @Environment(\.keyNavController) private var outer
    @StateObject private var controller = KeyNavController()

    func body(content: Content) -> some View {
        controller.kind = kind
        controller.parent = outer
        controller.onPageStep = onPageStep
        let registry = controller
        return content
            .environment(\.keyNavController, controller)
            .environment(\.keyNavParent, nil)
            .environment(\.keyNavRole, .automatic)
            .environment(\.keyNavShape, nil)
            .background(KeyNavHostAnchor(controller: controller))
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: CoordinateSpace.global)
            } action: { frame in
                registry.hostFrame = frame
            }
    }
}

/// An AppKit view covering the host: tells the registry its window, and maps the host's SwiftUI frame to it.
private struct KeyNavHostAnchor: NSViewRepresentable {
    let controller: KeyNavController

    func makeNSView(context: Context) -> KeyNavAnchorView {
        let view = KeyNavAnchorView()
        view.controller = controller
        return view
    }

    func updateNSView(_ view: KeyNavAnchorView, context: Context) {
        guard view.controller !== controller else { return }
        view.controller = controller
        view.reattach()
    }

    static func dismantleNSView(_ view: KeyNavAnchorView, coordinator: ()) {
        view.controller?.attach(window: nil, anchor: nil)
    }
}

final class KeyNavAnchorView: NSView {
    weak var controller: KeyNavController?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reattach()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func reattach() {
        controller?.attach(window: window, anchor: window == nil ? nil : self)
    }
}

// MARK: - Targets

/// Registers a target (frame, role, action) with the nearest host and draws its ring.
struct KeyNavTargetModifier: ViewModifier {
    let id: AnyHashable?
    let role: KeyNavRole
    /// Explicit outline; `nil` takes `keyNavShape` from the environment, else `fallbackShape`.
    let shape: KeyNavShape?
    let fallbackShape: KeyNavShape
    let action: (() -> Void)?

    @Environment(\.keyNavController) private var controller
    @Environment(\.keyNavRole) private var inheritedRole
    @Environment(\.keyNavParent) private var inheritedParent
    @Environment(\.keyNavShape) private var inheritedShape
    @Environment(\.isEnabled) private var isEnabled
    @StateObject private var box = KeyNavTargetBox()

    func body(content: Content) -> some View {
        let resolvedRole = role == .automatic ? inheritedRole : role
        let registry = resolvedRole == .excluded ? nil : controller
        let parent = resolvedRole == .primary ? nil : inheritedParent
        let outline = shape ?? inheritedShape ?? fallbackShape
        let isTarget = registry != nil
        box.explicitID = id
        box.parentKey = parent
        box.isEnabled = isEnabled
        box.action = action
        if box.isOnScreen { box.attach(to: registry) }
        return content
            .environment(\.keyNavRole, resolvedRole == .excluded ? .excluded : .automatic)
            .environment(\.keyNavParent, isTarget && parent == nil ? box.key : inheritedParent)
            .environment(\.keyNavShape, nil)
            .overlay {
                if isTarget {
                    KeyNavRingOverlay(model: box.ringModel, shape: outline)
                }
            }
            .onGeometryChange(for: KeyNavPlacement.self) { proxy in
                isTarget ? KeyNavPlacement(proxy) : KeyNavPlacement()
            } action: { placement in
                box.placement = placement
            }
            .onAppear {
                box.isOnScreen = true
                box.attach(to: registry)
            }
            .onDisappear {
                box.isOnScreen = false
                box.attach(to: nil)
            }
    }
}

/// The focus ring, drawn just inside the target's outline (dim while the user is inside the target).
private struct KeyNavRingOverlay: View {
    @ObservedObject var model: KeyNavRingModel
    let shape: KeyNavShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch model.ring {
            case .focused:
                ZStack {
                    KeyNavRingShape(shape: shape)
                        .strokeBorder(KeyNavStyle.ringColor, lineWidth: KeyNavStyle.ringWidth)
                    KeyNavRingShape(shape: shape)
                        .inset(by: KeyNavStyle.ringWidth)
                        .strokeBorder(KeyNavStyle.contrastColor, lineWidth: KeyNavStyle.contrastWidth)
                }
                .transition(.opacity)
            case .entered:
                KeyNavRingShape(shape: shape)
                    .strokeBorder(KeyNavStyle.ringColor.opacity(KeyNavStyle.enteredOpacity), lineWidth: KeyNavStyle.ringWidth)
                    .transition(.opacity)
            case .none:
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.ring)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A target's outline, inset by `insetAmount` (corner radii shrink with it, so insets stay concentric).
struct KeyNavRingShape: InsettableShape {
    var shape: KeyNavShape
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        switch shape {
        case .roundedRectangle(let cornerRadius):
            return RoundedRectangle(cornerRadius: max(0, cornerRadius - insetAmount), style: .continuous)
                .path(in: frame)
        case .capsule:
            return Capsule(style: .continuous).path(in: frame)
        case .circle:
            return Circle().path(in: frame)
        }
    }

    func inset(by amount: CGFloat) -> KeyNavRingShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Obstructions and yields

/// `keyNavObstruction()`: reports the chrome's frame to the host.
struct KeyNavObstructionModifier: ViewModifier {
    @Environment(\.keyNavController) private var controller
    @State private var token = UUID()

    func body(content: Content) -> some View {
        let registry = controller
        let token = token
        return content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: CoordinateSpace.global)
            } action: { frame in
                registry?.setObstruction(token, frame: frame)
            }
            .onDisappear {
                registry?.setObstruction(token, frame: nil)
            }
    }
}

/// `keyNavYield(_:)`: while active and on screen, the host leaves its keys alone.
struct KeyNavYieldModifier: ViewModifier {
    let active: Bool

    @Environment(\.keyNavController) private var controller
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { controller?.setYield(token, active: active) }
            .onChange(of: active) { _, isActive in controller?.setYield(token, active: isActive) }
            .onDisappear { controller?.setYield(token, active: false) }
    }
}
#endif
