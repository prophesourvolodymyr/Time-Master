#if os(macOS)
import SwiftUI

/// The ring's look: the only file of the folder that names the app's design tokens (copy the rest unchanged).
/// Like the app's own focus ring it is drawn inside the target's outline, so no clipping container (scroll view,
/// toolbar, list) ever cuts it.
enum KeyNavStyle {
    static let ringColor = Theme.toolbarOrange
    static let ringWidth: CGFloat = 2
    /// Hairline just inside the ring, so it also reads on accent-filled buttons.
    static let contrastColor = Theme.background.opacity(0.85)
    static let contrastWidth: CGFloat = 1
    /// Ring opacity on the primary target the user is inside.
    static let enteredOpacity = 0.4
}
#endif
