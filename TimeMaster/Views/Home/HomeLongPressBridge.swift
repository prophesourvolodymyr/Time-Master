#if os(iOS)
import SwiftUI
import UIKit

struct HomeLongPressBridge: UIViewRepresentable {
    var enabled: Bool
    var onPress: () -> Void

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

    func updateUIView(_ view: Probe, context: Context) {
        context.coordinator.parent = self
        context.coordinator.recognizer.isEnabled = enabled
    }

    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) {
        coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
        view.onWindowChanged = nil
    }

    final class Probe: UIView {
        var onWindowChanged: ((Probe) -> Void)?

        var isHiddenInTree: Bool {
            var current: UIView? = self
            while let view = current {
                if view.isHidden || view.alpha < 0.01 { return true }
                current = view.superview
            }
            return false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HomeLongPressBridge
        weak var probe: Probe?
        lazy var recognizer: UILongPressGestureRecognizer = {
            let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
            press.minimumPressDuration = 0.6
            press.allowableMovement = 10
            press.numberOfTouchesRequired = 1
            press.cancelsTouchesInView = false
            press.delaysTouchesBegan = false
            press.delaysTouchesEnded = false
            press.delegate = self
            return press
        }()

        init(_ parent: HomeLongPressBridge) {
            self.parent = parent
        }

        func attach(to probe: Probe) {
            self.probe = probe
            recognizer.view?.removeGestureRecognizer(recognizer)
            probe.window?.addGestureRecognizer(recognizer)
            recognizer.isEnabled = parent.enabled
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.enabled, let probe, let window = probe.window, !probe.isHiddenInTree,
                  !hasPresentation(window.rootViewController) else { return false }
            return probe.bounds.contains(gestureRecognizer.location(in: probe))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func hasPresentation(_ controller: UIViewController?) -> Bool {
            guard let controller else { return false }
            return controller.presentedViewController != nil || controller.children.contains { hasPresentation($0) }
        }

        @objc private func pressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            parent.onPress()
        }
    }
}
#endif
