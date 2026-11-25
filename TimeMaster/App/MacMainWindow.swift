#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum MacMainWindow {
    private struct WeakWindow {
        weak var window: NSWindow?
    }

    static var openAction: (() -> Void)?
    private(set) static weak var window: NSWindow?
    private static var windows: [UUID: WeakWindow] = [:]
    private static var lastKey: WeakWindow?
    private static var keyObserver: NSObjectProtocol?

    static var hasHiddenWindow: Bool {
        guard let window else { return false }
        return !window.isVisible && !window.isMiniaturized
    }

    static func register(_ newWindow: NSWindow) {
        window = newWindow
    }

    /// Ties a window to the id its root view carries, so a command meant for one window can find it.
    static func bind(_ token: UUID, to window: NSWindow) {
        windows[token] = WeakWindow(window: window)
        guard keyObserver == nil else { return }
        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { note in
            guard let key = note.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                if windows.values.contains(where: { $0.window === key }) { lastKey = WeakWindow(window: key) }
            }
        }
    }

    static func unbind(_ token: UUID) {
        windows[token] = nil
    }

    /// Whether `token`'s window is the one a command should act on: the only Tmax window, or the key one, or the one
    /// that was key last.
    static func isFront(_ token: UUID?) -> Bool {
        guard let token else { return true }
        windows = windows.filter { $0.value.window != nil }
        guard windows.count > 1, let mine = windows[token]?.window else { return true }
        if let key = NSApp.keyWindow, windows.values.contains(where: { $0.window === key }) { return key === mine }
        if let last = lastKey?.window { return last === mine }
        return true
    }

    private static var frontWindow: NSWindow? {
        if let key = NSApp.keyWindow, windows.values.contains(where: { $0.window === key }) { return key }
        return lastKey?.window ?? window
    }

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let target = frontWindow {
            if target.isMiniaturized { target.deminiaturize(nil) }
            target.makeKeyAndOrderFront(nil)
        } else if let openAction {
            openAction()
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }

    static func openNewWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let openAction {
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

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "New Window", action: #selector(openNewWindow), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openNewWindow() {
        MainActor.assumeIsolated { MacMainWindow.openNewWindow() }
    }
}

private struct MacWindowTokenKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var macWindowToken: UUID? {
        get { self[MacWindowTokenKey.self] }
        set { self[MacWindowTokenKey.self] = newValue }
    }
}

struct MacWindowTokenBinder: ViewModifier {
    let token: UUID

    func body(content: Content) -> some View {
        content
            .environment(\.macWindowToken, token)
            .background(MacWindowTokenProbe(token: token).frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true))
    }
}

private struct MacWindowTokenProbe: NSViewRepresentable {
    let token: UUID

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.token = token
        return view
    }

    func updateNSView(_ view: Probe, context: Context) {
        view.token = token
        view.bind()
    }

    static func dismantleNSView(_ view: Probe, coordinator: ()) {
        MacMainWindow.unbind(view.token)
    }

    final class Probe: NSView {
        var token = UUID()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            bind()
        }

        func bind() {
            guard let window else { return }
            MacMainWindow.bind(token, to: window)
        }
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
