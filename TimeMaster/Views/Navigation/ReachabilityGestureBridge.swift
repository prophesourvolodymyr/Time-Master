#if os(iOS)
import SwiftUI
import UIKit

struct ReachabilityGestureBridge: UIViewRepresentable {
    var enabled: Bool
    var onChange: (CGPoint, CGSize, Bool) -> Void
    var onEnd: (CGSize, CGPoint, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.onWindowChanged = { [weak coordinator = context.coordinator] probe in
            coordinator?.attach(to: probe)
        }
        context.coordinator.probe = view
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        context.coordinator.parent = self
        context.coordinator.recognizer.isEnabled = enabled
    }

    static func dismantleUIView(_ uiView: Probe, coordinator: Coordinator) {
        coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
        uiView.onWindowChanged = nil
    }

    final class Probe: UIView {
        var onWindowChanged: ((Probe) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ReachabilityGestureBridge
        weak var probe: Probe?
        lazy var recognizer: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            pan.cancelsTouchesInView = true
            return pan
        }()

        init(_ parent: ReachabilityGestureBridge) {
            self.parent = parent
        }

        func attach(to probe: Probe) {
            self.probe = probe
            recognizer.view?.removeGestureRecognizer(recognizer)
            probe.window?.addGestureRecognizer(recognizer)
            recognizer.isEnabled = parent.enabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.enabled, let probe, let window = probe.window,
                  !hasPresentation(window.rootViewController) else { return false }
            let translation = recognizer.translation(in: probe)
            let location = recognizer.location(in: probe)
            let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            return ReachabilityGeometry.accepts(start: start,
                translation: CGSize(width: translation.x, height: translation.y), in: probe.bounds)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }

        private func hasPresentation(_ controller: UIViewController?) -> Bool {
            guard let controller else { return false }
            return controller.presentedViewController != nil || controller.children.contains { hasPresentation($0) }
        }

        @objc private func panned() {
            guard let probe else { return }
            let offset = recognizer.translation(in: probe)
            let translation = CGSize(width: offset.x, height: offset.y)
            switch recognizer.state {
            case .began, .changed:
                parent.onChange(recognizer.location(in: probe), translation, recognizer.state == .began)
            case .ended:
                parent.onEnd(translation, recognizer.velocity(in: probe), false)
            case .cancelled, .failed:
                parent.onEnd(translation, .zero, true)
            default:
                break
            }
        }
    }
}
#endif
