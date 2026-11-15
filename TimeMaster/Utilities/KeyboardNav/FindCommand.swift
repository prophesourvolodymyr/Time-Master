import SwiftUI
#if os(macOS)
import AppKit

/// Command-F opens the search of the page on screen. A page with a search registers a handler while it is shown; the
/// newest handler that can open its search takes the key. With no taker the key goes on (a text view's own find bar).
@MainActor
final class FindCommandCenter {
    static let shared = FindCommandCenter()

    private var handlers: [(id: UUID, open: () -> Bool)] = []
    private var monitor: Any?

    func register(_ id: UUID, open: @escaping () -> Bool) {
        handlers.removeAll { $0.id == id }
        handlers.append((id, open))
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let taken = MainActor.assumeIsolated { FindCommandCenter.shared.handle(event) }
            return taken ? nil : event
        }
    }

    func unregister(_ id: UUID) {
        handlers.removeAll { $0.id == id }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "f" else { return false }
        if let text = event.window?.firstResponder as? NSTextView, !text.isFieldEditor, text.usesFindBar || text.usesFindPanel {
            return false
        }
        return handlers.reversed().contains { $0.open() }
    }
}
#endif

private struct FindCommandModifier: ViewModifier {
    let open: () -> Bool
    #if os(macOS)
    @State private var id = UUID()
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onAppear { FindCommandCenter.shared.register(id, open: open) }
            .onDisappear { FindCommandCenter.shared.unregister(id) }
        #else
        content
        #endif
    }
}

extension View {
    /// On the Mac, Command-F runs `open` while this view is on screen. Return false when the search cannot open now
    /// (for example while another screen is pushed on top), so the key goes to the next taker.
    func findCommand(_ open: @escaping () -> Bool) -> some View {
        modifier(FindCommandModifier(open: open))
    }
}
