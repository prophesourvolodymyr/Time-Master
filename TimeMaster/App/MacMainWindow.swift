#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum MacMainWindow {
    static var openAction: (() -> Void)?
    private(set) static weak var window: NSWindow?

    static var hasHiddenWindow: Bool {
        guard let window else { return false }
        return !window.isVisible && !window.isMiniaturized
    }

    static func register(_ newWindow: NSWindow) {
        window = newWindow
    }

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let openAction {
            openAction()
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }
}

final class TmaxAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag, MacMainWindow.hasHiddenWindow else { return true }
        MacMainWindow.show()
        return false
    }
}

struct MacMainWindowGuard: ViewModifier {
    func body(content: Content) -> some View {
        content.background(MacMainWindowProbe().frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true))
    }
}

private struct MacMainWindowProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe {
        Probe()
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.attach()
    }

    static func dismantleNSView(_ view: Probe, coordinator: ()) {
        view.detach()
    }

    final class Probe: NSView {
        private var closeGuard: WindowCloseGuard?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        func attach() {
            guard let window else { return }
            MacMainWindow.register(window)
            if closeGuard?.window !== window {
                closeGuard?.restore()
                closeGuard = WindowCloseGuard(window: window)
            }
        }

        func detach() {
            closeGuard?.restore()
            closeGuard = nil
        }
    }
}

private final class WindowCloseGuard: NSObject, NSWindowDelegate {
    weak var window: NSWindow?
    private weak var original: NSWindowDelegate?

    init(window: NSWindow) {
        self.window = window
        original = window.delegate
        super.init()
        window.delegate = self
    }

    func restore() {
        guard let window, window.delegate === self else { return }
        window.delegate = original
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if WorkoutLiveSession.shared.isActive {
            sender.orderOut(nil)
            return false
        }
        return original?.windowShouldClose?(sender) ?? true
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
#endif
