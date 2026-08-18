import SwiftUI

struct SlotNavigationArcShape: Shape {
    let bottomExtension: CGFloat
    let curveOffset: CGFloat

    init(bottomExtension: CGFloat = 0, curveOffset: CGFloat = 0) {
        self.bottomExtension = max(0, bottomExtension)
        self.curveOffset = curveOffset
    }

    func path(in rect: CGRect) -> Path {
        SlotNavigationArcGeometry.surfacePath(
            in: rect,
            bottomExtension: bottomExtension,
            curveOffset: curveOffset
        )
    }
}

struct SlotNavigationArcLineShape: Shape {
    let curveOffset: CGFloat

    init(curveOffset: CGFloat = 0) {
        self.curveOffset = curveOffset
    }

    func path(in rect: CGRect) -> Path {
        SlotNavigationArcGeometry.linePath(in: rect, curveOffset: curveOffset)
    }
}

struct SlotNavigationArcInnerLineShape: Shape {
    let curveOffset: CGFloat

    init(curveOffset: CGFloat = 0) {
        self.curveOffset = curveOffset
    }

    func path(in rect: CGRect) -> Path {
        let inset = min(max(rect.width * 0.075, 18), 36)
        let innerRect = CGRect(
            x: rect.minX + inset,
            y: rect.minY,
            width: max(rect.width - inset * 2, 1),
            height: rect.height
        )
        return SlotNavigationArcGeometry.linePath(
            in: innerRect,
            curveOffset: curveOffset + 3
        )
    }
}

enum SlotNavigationArcGeometry {
    private static let edgeHeightRatio: CGFloat = 0.72
    private static let controlHeightRatio: CGFloat = 0.12

    static func curveY(
        at x: CGFloat,
        in rect: CGRect,
        curveOffset: CGFloat = 0
    ) -> CGFloat {
        guard rect.width > 0 else { return rect.midY }

        let localX = min(max(x - rect.minX, 0), rect.width)
        let t = localX / rect.width
        let inverseT = 1 - t
        let edgeY = rect.height * edgeHeightRatio + curveOffset
        let controlY = rect.height * controlHeightRatio + curveOffset

        return rect.minY +
            inverseT * inverseT * inverseT * edgeY +
            3 * inverseT * inverseT * t * controlY +
            3 * inverseT * t * t * controlY +
            t * t * t * edgeY
    }

    static func linePath(
        in rect: CGRect,
        curveOffset: CGFloat = 0
    ) -> Path {
        let startY = curveY(at: rect.minX, in: rect, curveOffset: curveOffset)
        let endY = curveY(at: rect.maxX, in: rect, curveOffset: curveOffset)
        let controlY = rect.minY + rect.height * controlHeightRatio + curveOffset

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: controlY),
            control2: CGPoint(x: rect.minX + rect.width * 0.75, y: controlY)
        )
        return path
    }

    static func surfacePath(
        in rect: CGRect,
        bottomExtension: CGFloat = 0,
        curveOffset: CGFloat = 0
    ) -> Path {
        let line = linePath(in: rect, curveOffset: curveOffset)
        let startY = curveY(at: rect.minX, in: rect, curveOffset: curveOffset)
        let bottomY = rect.maxY + max(0, bottomExtension)

        var path = line
        path.addLine(to: CGPoint(x: rect.maxX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.closeSubpath()
        return path
    }
}
