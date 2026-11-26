import CoreGraphics

/// Swipes from the edges of a page at the root of the bar: from the left edge rightward brings in the page before it
/// on the bar, from the right edge leftward the page after it. Mostly sideways only, and never past either end.
enum SlotPageSwipeGeometry {
    struct Swipe: Equatable {
        /// Index on the bar of the page coming in.
        var neighbour: Int
        /// +1 when it comes from the right (the next page), -1 from the left (the previous page).
        var direction: CGFloat
        /// How far it has come in, from 0 to 1.
        var fraction: CGFloat
    }

    static let edgeWidth: CGFloat = 28

    static func swipe(index: Int, count: Int, start: CGPoint, translation: CGSize, width: CGFloat) -> Swipe? {
        guard width > 0, translation.width.isFinite, translation.height.isFinite,
              abs(translation.width) > abs(translation.height) * 1.7 else { return nil }
        let direction: CGFloat
        if start.x <= edgeWidth, translation.width > 0 {
            direction = -1
        } else if start.x >= width - edgeWidth, translation.width < 0 {
            direction = 1
        } else {
            return nil
        }
        let neighbour = index + Int(direction)
        guard neighbour >= 0, neighbour < count else { return nil }
        return Swipe(neighbour: neighbour, direction: direction, fraction: min(1, abs(translation.width) / width))
    }

    /// The page the swipe lands on when the finger lifts, or nil when it falls back.
    static func destination(index: Int, count: Int, start: CGPoint, translation: CGSize,
                            projectedWidth: CGFloat, width: CGFloat) -> Int? {
        guard let swipe = swipe(index: index, count: count, start: start, translation: translation, width: width),
              projectedWidth.isFinite, projectedWidth * -swipe.direction > width * 0.25 else { return nil }
        return swipe.neighbour
    }
}
