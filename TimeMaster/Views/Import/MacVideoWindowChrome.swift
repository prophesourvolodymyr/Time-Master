#if os(macOS)
import AppKit
import SwiftUI

enum MacVideoWindowChrome {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("tm.mac.videoWindow")

    @MainActor
    static func apply(to window: NSWindow) {
        window.identifier = windowIdentifier
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Theme.background)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.showsBaselineSeparator = false
        window.isMovableByWindowBackground = false
    }
}

private struct MacResizeCursorModifier: ViewModifier {
    @State private var isInside = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard inside != isInside else { return }
                isInside = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                if isInside {
                    NSCursor.pop()
                    isInside = false
                }
            }
    }
}

extension View {
    func macResizeCursor() -> some View {
        modifier(MacResizeCursorModifier())
    }
}
#endif
