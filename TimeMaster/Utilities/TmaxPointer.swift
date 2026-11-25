import SwiftUI
#if os(macOS)
import AppKit
#endif

extension View {
    /// The pointing hand over what can be clicked, on the Mac. Nothing on iPhone and iPad, and nothing while disabled.
    func tmaxPointer(_ isActive: Bool = true) -> some View {
        modifier(TmaxPointerModifier(isActive: isActive))
    }
}

private struct TmaxPointerModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            content.pointerStyle(isActive && isEnabled ? .link : nil)
        } else {
            content.modifier(TmaxLegacyPointer(isActive: isActive && isEnabled))
        }
        #else
        content
        #endif
    }
}

#if os(macOS)
private struct TmaxLegacyPointer: ViewModifier {
    let isActive: Bool
    @State private var inside = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard isActive else { return }
                if hovering, !inside {
                    NSCursor.pointingHand.push()
                    inside = true
                } else if !hovering, inside {
                    NSCursor.pop()
                    inside = false
                }
            }
            .onDisappear {
                if inside {
                    NSCursor.pop()
                    inside = false
                }
            }
    }
}
#endif
