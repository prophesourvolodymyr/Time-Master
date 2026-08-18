import SwiftUI

struct SlotNavigationArcShape: Shape {
    let bottomExtension: CGFloat

    init(bottomExtension: CGFloat = 0) {
        self.bottomExtension = max(0, bottomExtension)
    }

    func path(in rect: CGRect) -> Path {
        SlotNavigationArcGeometry.surfacePath(in: rect, bottomExtension: bottomExtension)
    }
}

struct SlotNavigationArcLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        SlotNavigationArcGeometry.linePath(in: rect)
    }
}

enum SlotNavigationArcGeometry {
    private static let edgeHeightRatio: CGFloat = 0.72
    private static let controlHeightRatio: CGFloat = 0.12

    static func curveY(at x: CGFloat, in rect: CGRect) -> CGFloat {
        guard rect.width > 0 else { return rect.midY }

        let localX = min(max(x - rect.minX, 0), rect.width)
        let t = localX / rect.width
        let inverseT = 1 - t
        let edgeY = rect.height * edgeHeightRatio
        let controlY = rect.height * controlHeightRatio

        return rect.minY +
            inverseT * inverseT * inverseT * edgeY +
            3 * inverseT * inverseT * t * controlY +
            3 * inverseT * t * t * controlY +
            t * t * t * edgeY
    }

    static func linePath(in rect: CGRect) -> Path {
        let startY = curveY(at: rect.minX, in: rect)
        let endY = curveY(at: rect.maxX, in: rect)
        let controlY = rect.minY + rect.height * controlHeightRatio

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: controlY),
            control2: CGPoint(x: rect.minX + rect.width * 0.75, y: controlY)
        )
        return path
    }

    static func surfacePath(in rect: CGRect, bottomExtension: CGFloat = 0) -> Path {
        let line = linePath(in: rect)
        let startY = curveY(at: rect.minX, in: rect)
        let bottomY = rect.maxY + max(0, bottomExtension)

        var path = line
        path.addLine(to: CGPoint(x: rect.maxX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.closeSubpath()
        return path
    }
}
