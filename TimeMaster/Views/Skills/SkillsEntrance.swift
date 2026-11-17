import SwiftUI

/// The Skills page's entrance, in the app's page motion: what the page shows when it opens rises a little and fades
/// in, section after section and card after card, a short beat apart, on the spring of the app's state changes. With
/// Reduce Motion it only fades, all at once. The rise is an offset, so nothing is measured and the layout never moves.
struct SkillsEntrance: ViewModifier {
    let isShown: Bool
    /// The section's place on the page.
    let section: Int
    /// The place inside the section: 0 for its header, then 1, 2, … for its cards.
    let position: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let rise: CGFloat = 16

    /// A beat per section and a shorter one per card before this one, both capped, so even a long page is in within
    /// half a second.
    static func delay(section: Int, position: Int) -> Double {
        Double(min(max(section, 0), 4)) * 0.06 + Double(min(max(position, 0), 6)) * 0.03
    }

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : Self.rise)
            .animation(
                reduceMotion ? EverMotion.opacityOnly : EverMotion.state.delay(Self.delay(section: section, position: position)),
                value: isShown
            )
            .allowsHitTesting(isShown)
    }
}

extension View {
    func skillsEntrance(_ isShown: Bool, section: Int, position: Int = 0) -> some View {
        modifier(SkillsEntrance(isShown: isShown, section: section, position: position))
    }
}
