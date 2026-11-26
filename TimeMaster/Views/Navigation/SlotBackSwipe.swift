// SlotBackSwipe.swift
//
// Swiping right from the left edge goes back on every pushed page. SwiftUI turns the system's back swipe off whenever a
// page hides the system back button, and the app's pages hide it to draw their own; the swipe is turned back on for
// pages that still show a way back on the leading side, and stays off while something immersive holds the screen.

#if os(iOS)
import UIKit
import ObjectiveC

@MainActor
enum SlotBackSwipe {
    /// Set while the page on screen asks the navigation to stand down (a match, a player, an editor).
    static var isBlocked = false

    private static var proxyKey: UInt8 = 0

    /// Called for a touch near the left edge: readies the back swipe of the stack under `view`.
    static func prepare(for view: UIView?) {
        guard let navigation = navigationController(of: view), navigation.viewControllers.count > 1,
              let recognizer = navigation.interactivePopGestureRecognizer else { return }
        if !(recognizer.delegate is Proxy) {
            let proxy = Proxy(navigation: navigation, original: recognizer.delegate)
            objc_setAssociatedObject(navigation, &proxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            recognizer.delegate = proxy
        }
        if !recognizer.isEnabled { recognizer.isEnabled = true }
    }

    private static func navigationController(of view: UIView?) -> UINavigationController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let navigation = current as? UINavigationController { return navigation }
            responder = current.next
        }
        return nil
    }

    /// Decides the back swipe in place of the system's delegate and hands it every other question.
    private final class Proxy: NSObject, UIGestureRecognizerDelegate {
        weak var navigation: UINavigationController?
        weak var original: UIGestureRecognizerDelegate?

        init(navigation: UINavigationController, original: UIGestureRecognizerDelegate?) {
            self.navigation = navigation
            self.original = original
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let blocked = MainActor.assumeIsolated { SlotBackSwipe.isBlocked }
            guard !blocked, let navigation, navigation.viewControllers.count > 1,
                  navigation.transitionCoordinator == nil,
                  let item = navigation.topViewController?.navigationItem else { return false }
            guard item.hidesBackButton else {
                return original?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
            }
            return item.leftBarButtonItem != nil || !(item.leftBarButtonItems ?? []).isEmpty
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || original?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
        }
    }
}
#endif
