import SwiftUI

/// iPhone: swipe a to-do right to make it a sub-to-do of the one above, left to bring it back a level. The row follows
/// the finger a little and shows what the swipe will do. (On the Mac it is Tab and Shift-Tab.)
struct TodoSwipeModifier: ViewModifier {
    let canIndent: Bool
    let canOutdent: Bool
    let onIndent: () -> Void
    let onOutdent: () -> Void

    #if os(iOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private let commitDistance: CGFloat = 56

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: offset >= 0 ? .leading : .trailing) {
                Image(systemName: offset >= 0 ? "increase.indent" : "decrease.indent")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .opacity(min(1, abs(offset) / commitDistance))
                    .padding(.horizontal, 8)
                    .accessibilityHidden(true)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 18, coordinateSpace: .local)
                    .onChanged { value in
                        let width = value.translation.width
                        guard abs(width) > abs(value.translation.height) * 1.6 else { return }
                        if width > 0 && canIndent {
                            offset = min(width, 120) * 0.55
                        } else if width < 0 && canOutdent {
                            offset = max(width, -120) * 0.55
                        }
                    }
                    .onEnded { value in
                        let width = value.translation.width
                        let vertical = abs(value.translation.height)
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                        guard abs(width) > vertical * 1.6 else { return }
                        if width > commitDistance && canIndent {
                            EverHaptic.selection()
                            onIndent()
                        } else if width < -commitDistance && canOutdent {
                            EverHaptic.selection()
                            onOutdent()
                        }
                    }
            )
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}
