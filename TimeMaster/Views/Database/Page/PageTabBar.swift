import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
/// ⌥⌘← and ⌥⌘→ on the Mac: the tab before or after the selected one of a page's `TmaxTabBar`. Plain arrows stay with
/// keyboard navigation, which reaches every tab like any other button; the keys rest while a text field has the
/// keyboard.
struct PageTabStepKeys: View {
    let tabs: [PageTab]
    let selection: PageTab
    let isEnabled: Bool
    let onSelect: (PageTab) -> Void

    var body: some View {
        ZStack {
            Button("Previous tab") { step(-1) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Next tab") { step(1) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
        }
        .disabled(!isEnabled)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func step(_ delta: Int) {
        if let responder = NSApp.keyWindow?.firstResponder, responder is NSText || responder is NSTextField { return }
        guard let index = tabs.firstIndex(of: selection), tabs.indices.contains(index + delta) else { return }
        onSelect(tabs[index + delta])
    }
}
#endif
