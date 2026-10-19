import CoreGraphics

struct ReachabilityGeometry {
    static let controlSize: CGFloat = 48
    static let shelfHeight: CGFloat = 152
    static let revealDistance: CGFloat = 96

    static func accepts(start: CGPoint, translation: CGSize, in bounds: CGRect) -> Bool {
        guard bounds.width > 0, bounds.height > shelfHeight,
              start.x >= bounds.minX + bounds.width * 0.58,
              start.x < bounds.maxX - 32,
              start.y > bounds.minY + 64,
              start.y < bounds.maxY - 44,
              translation.width < -8 else { return false }
        let slope = abs(translation.height / translation.width)
        return slope >= 0.12 && slope <= 0.58
    }

    static func progress(translation: CGSize) -> CGFloat {
        min(1, max(0, -translation.width / revealDistance))
    }

    static func shouldOpen(translation: CGSize, velocity: CGPoint) -> Bool {
        let distance = -translation.width
        return distance >= revealDistance * 0.62
            || (distance >= 28 && velocity.x < -420)
    }

    static func anchorY(_ requested: CGFloat, height: CGFloat) -> CGFloat {
        let half = min(shelfHeight / 2, height / 2)
        return min(max(requested, half), max(half, height - half))
    }

    static func step(width: CGFloat) -> CGFloat {
        max(controlSize + 20, min(92, width / 4))
    }

    static func settledIndex(current: Int, translation: CGFloat, step: CGFloat, count: Int) -> Int {
        guard count > 0, step > 0 else { return 0 }
        return min(count - 1, max(0, current - Int((translation / step).rounded())))
    }

    static func curveY(x: CGFloat, width: CGFloat) -> CGFloat {
        let normalized = min(1, max(-1, (x - width / 2) / max(1, width / 2)))
        return shelfHeight * (0.30 + 0.20 * normalized * normalized)
    }
}
