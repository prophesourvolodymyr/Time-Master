#if os(macOS)
import AVFoundation
import AppKit
import SwiftUI

@MainActor
enum MacVideoSaveWindowPresenter {
    private static var controllers: [UUID: MacVideoSaveWindowController] = [:]

    @discardableResult
    static func present(
        draft: MacVideoDraft,
        asset: AVURLAsset,
        databaseStore: DatabaseStore,
        workoutStore: WorkoutStore,
        onDraftRenamed: @escaping (String) -> Void,
        onSaved: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) -> NSWindow {
        let id = UUID()
        let controller = MacVideoSaveWindowController(
            draft: draft,
            asset: asset,
            databaseStore: databaseStore,
            workoutStore: workoutStore,
            onDraftRenamed: onDraftRenamed,
            onSaved: onSaved,
            onClose: onClose,
            onReleased: { controllers.removeValue(forKey: id) }
        )
        controllers[id] = controller
        let window = controller.window!
        let origin = NSPoint(x: CGFloat(40 * (controllers.count % 6)), y: CGFloat(-40 * (controllers.count % 6)))
        window.center()
        window.setFrameOrigin(NSPoint(x: window.frame.minX + origin.x, y: window.frame.minY + origin.y))
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}

@MainActor
private final class MacVideoSaveWindowController: NSWindowController, NSWindowDelegate {
    private var onClose: (() -> Void)?
    private var onReleased: (() -> Void)?

    init(
        draft: MacVideoDraft,
        asset: AVURLAsset,
        databaseStore: DatabaseStore,
        workoutStore: WorkoutStore,
        onDraftRenamed: @escaping (String) -> Void,
        onSaved: @escaping (String) -> Void,
        onClose: @escaping () -> Void,
        onReleased: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.onReleased = onReleased
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Save Media"
        window.minSize = NSSize(width: 500, height: 480)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(Theme.background)
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: MacVideoSavePopover(
            draft: draft,
            asset: asset,
            onDraftRenamed: onDraftRenamed,
            onSaved: onSaved,
            onClose: { [weak self] in self?.close() }
        )
        .environmentObject(databaseStore)
        .environmentObject(workoutStore)
        .preferredColorScheme(.dark)
        .font(TimeMasterFont.body()))
    }

    required init?(coder: NSCoder) { nil }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        let closed = onClose
        onClose = nil
        let released = onReleased
        onReleased = nil
        closed?()
        released?()
    }
}
#endif
