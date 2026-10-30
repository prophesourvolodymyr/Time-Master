import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EverPopupDismissAction {
    var action: (() -> Void)?

    func callAsFunction(or fallback: () -> Void) {
        if let action { action() } else { fallback() }
    }
}

private struct EverPopupDismissKey: EnvironmentKey {
    static let defaultValue = EverPopupDismissAction()
}

private struct EverPopupCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var everPopupDismiss: EverPopupDismissAction {
        get { self[EverPopupDismissKey.self] }
        set { self[EverPopupDismissKey.self] = newValue }
    }

    var everPopupCompact: Bool {
        get { self[EverPopupCompactKey.self] }
        set { self[EverPopupCompactKey.self] = newValue }
    }
}

extension View {
    func everPopup<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if os(macOS)
        modifier(EverMacPopupPresentation(isPresented: isPresented, onDismiss: onDismiss, popup: content))
#else
        background {
            EverPopupPresenter(isPresented: isPresented, onDismiss: onDismiss, popup: content)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
#endif
    }

    func everPopup<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        everPopup(
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            onDismiss: onDismiss
        ) {
            if let value = item.wrappedValue { content(value) }
        }
    }
}

#if canImport(UIKit)
private struct EverPopupPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder var popup: () -> Content

    func makeUIViewController(context: Context) -> PresenterController {
        PresenterController()
    }

    func updateUIViewController(_ controller: PresenterController, context: Context) {
        let root = isPresented
            ? AnyView(popup().everPageOpening(from: .bottom)
                .environment(\.everPopupStepMotion, controller.stepMotion)
                .environment(\.everPopupDismiss, EverPopupDismissAction(action: { [weak controller] in
                    isPresented = false
                    controller?.requestDismiss(completion: onDismiss)
                }))
                .environment(\.self, context.environment))
            : nil
        controller.synchronize(isPresented: isPresented, root: root, onDismiss: onDismiss)
    }

    static func dismantleUIViewController(_ controller: PresenterController, coordinator: ()) {
        controller.teardown()
    }

    final class PresenterController: UIViewController, UIAdaptivePresentationControllerDelegate {
        private var popup: UIHostingController<AnyView>?
        private var root: AnyView?
        private var dismissalCompletion: (() -> Void)?
        private var wantsPresentation = false
        private var isTransitioning = false
        private var isDismantled = false
        let stepMotion = EverPopupStepMotion()

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            reconcile()
        }

        func synchronize(isPresented: Bool, root: AnyView?, onDismiss: (() -> Void)?) {
            guard !isDismantled else { return }
            wantsPresentation = isPresented
            if let root { self.root = root }
            if !isPresented, dismissalCompletion == nil { dismissalCompletion = onDismiss }
            reconcile()
        }

        func teardown() {
            isDismantled = true
            wantsPresentation = false
            root = nil
            stepMotion.stop()
            dismissalCompletion = nil
            dismissPopup(notify: false)
        }

        func requestDismiss(completion: (() -> Void)?) {
            wantsPresentation = false
            if let completion { dismissalCompletion = completion }
            reconcile()
        }

        private func reconcile() {
            if wantsPresentation, !isDismantled {
                presentPopup()
            } else {
                dismissPopup()
            }
        }

        private func presentPopup() {
            guard let root else { return }
            if let popup {
                if !popup.isBeingDismissed { popup.rootView = root }
                return
            }
            guard viewIfLoaded?.window != nil, !isTransitioning else { return }

            var presenter = view.window?.rootViewController ?? self
            while let presented = presenter.presentedViewController {
                if presented.isBeingDismissed || presented.isBeingPresented {
                    presented.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
                        self?.reconcile()
                    }
                    return
                }
                presenter = presented
            }

            stepMotion.host = nil
            let hosting = UIHostingController(rootView: root)
            hosting.view.backgroundColor = .clear
            stepMotion.host = hosting.view
            hosting.view.accessibilityViewIsModal = true
            hosting.modalPresentationStyle = .overFullScreen
            hosting.modalTransitionStyle = .crossDissolve
            hosting.isModalInPresentation = true
            hosting.presentationController?.delegate = self
            popup = hosting
            isTransitioning = true
            presenter.present(hosting, animated: false) { [weak self] in
                guard let self else { return }
                self.isTransitioning = false
                self.reconcile()
            }
        }

        private func dismissPopup(notify: Bool = true) {
            guard let popup else { return }
            stepMotion.stop()
            guard !isTransitioning else { return }
            if popup.isBeingDismissed {
                popup.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self, weak popup] _ in
                    guard let popup else { return }
                    self?.finishDismissal(of: popup, notify: notify)
                }
                return
            }

            isTransitioning = true
            popup.dismiss(animated: true) { [weak self, weak popup] in
                guard let popup else { return }
                self?.finishDismissal(of: popup, notify: notify)
            }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard let popup, presentationController.presentedViewController === popup else { return }
            finishDismissal(of: popup, notify: true)
        }

        private func finishDismissal(of dismissedPopup: UIHostingController<AnyView>, notify: Bool) {
            guard popup === dismissedPopup else { return }
            popup = nil
            isTransitioning = false
            if notify {
                let completion = dismissalCompletion
                dismissalCompletion = nil
                completion?()
            }
            reconcile()
        }
    }
}
#elseif os(macOS)
private struct EverMacPopupPresentation<Popup: View>: ViewModifier {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder var popup: () -> Popup

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            EverMacPopupSheet(isPresented: $isPresented, popup: popup)
                .frame(minWidth: EverLayout.popupMaximumWidth,
                       idealWidth: EverLayout.popupMaximumWidth,
                       maxWidth: EverLayout.maximumReadableWidth)
                .interactiveDismissDisabled()
        }
    }
}

private struct EverMacPopupSheet<Popup: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var popup: () -> Popup
    @State private var stepMotion = EverPopupStepMotion()

    var body: some View {
        EverMacPopupHost(isPresented: $isPresented, stepMotion: stepMotion, popup: popup)
            .background(Theme.background.ignoresSafeArea())
            .presentationBackground(Theme.background)
    }
}

private struct EverMacPopupHost<Popup: View>: NSViewControllerRepresentable {
    @Binding var isPresented: Bool
    let stepMotion: EverPopupStepMotion
    @ViewBuilder var popup: () -> Popup

    func makeCoordinator() -> EverPopupStepMotion { stepMotion }

    func makeNSViewController(context: Context) -> NSHostingController<AnyView> {
        let hosting = NSHostingController(rootView: root(environment: context.environment))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.sizingOptions = [.preferredContentSize]
        stepMotion.host = hosting.view
        return hosting
    }

    func updateNSViewController(_ hosting: NSHostingController<AnyView>, context: Context) {
        hosting.rootView = root(environment: context.environment)
        stepMotion.host = hosting.view
    }

    static func dismantleNSViewController(_ hosting: NSHostingController<AnyView>, coordinator: EverPopupStepMotion) {
        coordinator.stop()
        coordinator.host = nil
    }

    private func root(environment: EnvironmentValues) -> AnyView {
        AnyView(popup()
            .everPageOpening(from: .bottom)
            .keyNavHost()
            .environment(\.everPopupStepMotion, stepMotion)
            .environment(\.everPopupDismiss, EverPopupDismissAction(action: {
                stepMotion.stop()
                isPresented = false
            }))
            .environment(\.self, environment))
    }
}
#endif
