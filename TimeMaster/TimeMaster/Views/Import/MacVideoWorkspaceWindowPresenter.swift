#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class MacVideoWorkspaceWindowPresenter {
    static let shared = MacVideoWorkspaceWindowPresenter()

    private var controllers: [UUID: MacVideoWorkspaceWindowController] = [:]
    private var cascadePoint = NSPoint.zero

    private init() {}

    @discardableResult
    func presentImport(databaseStore: DatabaseStore, workoutStore: WorkoutStore) -> UUID {
        present(sources: [], databaseStore: databaseStore, workoutStore: workoutStore)
    }

    @discardableResult
    func present(sources: [MacVideoSource], databaseStore: DatabaseStore, workoutStore: WorkoutStore) -> UUID {
        let id = UUID()
        let controller = MacVideoWorkspaceWindowController(
            sources: sources,
            databaseStore: databaseStore,
            workoutStore: workoutStore,
            onReleased: { [weak self] in self?.controllers.removeValue(forKey: id) }
        )
        controllers[id] = controller
        if let window = controller.window {
            if cascadePoint == .zero { window.center() }
            cascadePoint = window.cascadeTopLeft(from: cascadePoint == .zero
                ? NSPoint(x: window.frame.minX, y: window.frame.maxY) : cascadePoint)
        }
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return id
    }
}

@MainActor
private final class MacVideoWorkspaceWindowController: NSWindowController, NSWindowDelegate {
    private let model: MacVideoWorkspaceModel
    private var onReleased: (() -> Void)?

    init(sources: [MacVideoSource], databaseStore: DatabaseStore, workoutStore: WorkoutStore, onReleased: @escaping () -> Void) {
        model = MacVideoWorkspaceModel(sources: sources)
        self.onReleased = onReleased
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Import Videos"
        window.minSize = NSSize(width: 1180, height: 660)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.backgroundColor = NSColor(Theme.background)
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: MacVideoWorkspaceRoot(
            model: model,
            databaseStore: databaseStore,
            workoutStore: workoutStore,
            onClose: { [weak self] in self?.close() }
        ))
    }

    required init?(coder: NSCoder) { nil }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard model.isBusy else { return true }
        let alert = NSAlert()
        alert.messageText = "A video is still exporting or saving"
        alert.informativeText = "Wait for it to finish before closing this window."
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: sender)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        model.close()
        window?.contentViewController = nil
        let released = onReleased
        onReleased = nil
        released?()
    }
}

private struct MacVideoWorkspaceRoot: View {
    @ObservedObject var model: MacVideoWorkspaceModel
    let databaseStore: DatabaseStore
    let workoutStore: WorkoutStore
    let onClose: () -> Void

    var body: some View {
        MacVideoWorkspaceView(model: model, onClose: onClose)
            .environmentObject(databaseStore)
            .environmentObject(workoutStore)
            .preferredColorScheme(.dark)
            .font(TimeMasterFont.body())
    }
}
#endif
