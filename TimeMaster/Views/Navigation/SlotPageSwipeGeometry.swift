import CoreGraphics

enum SlotPageSwipeGeometry {
    static func progress(index: Int, start: CGPoint, translation: CGSize, width: CGFloat) -> CGFloat? {
        guard width > 0, index > 0,
              start.x <= 28 || start.x >= width - 28,
              translation.width > abs(translation.height) * 1.7 else { return nil }
        return CGFloat(index) - min(1, translation.width / width)
    }

    static func destination(index: Int, translation: CGSize, projectedWidth: CGFloat, width: CGFloat) -> Int? {
        guard width > 0, index > 0,
              translation.width > abs(translation.height) * 1.7,
              projectedWidth > width * 0.25 else { return nil }
        return index - 1
    }
}
