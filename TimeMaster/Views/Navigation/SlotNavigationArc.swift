// SlotNavigationArc.swift
//
// The shallow arc the navigation surface and its hairline follow. Part of the
// CarouselNavigation component from the SwiftComponentLibrary, copied into the app.

import SwiftUI

struct SlotArcShape: Shape {
    let bottomExtension: CGFloat
    let curveOffset: CGFloat
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        SlotArcGeometry.surfacePath(in: rect, bottomExtension: bottomExtension, curveOffset: curveOffset, expansion: expansion)
    }
}

struct SlotArcLineShape: Shape {
    let curveOffset: CGFloat
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        SlotArcGeometry.linePath(in: rect, curveOffset: curveOffset, expansion: expansion)
    }
}

enum SlotArcGeometry {
    private static let edgeHeightRatio: CGFloat = 0.72
    private static let controlHeightRatio: CGFloat = 0.12

    static func curveY(at x: CGFloat, in rect: CGRect, curveOffset: CGFloat, expansion: CGFloat) -> CGFloat {
        guard rect.width > 0 else { return rect.midY }
        let localX = min(max(x - rect.minX, 0), rect.width)
        let t = localX / rect.width
        let inverseT = 1 - t
        let edgeY = (rect.height * edgeHeightRatio + curveOffset) * expansion
        let controlY = (rect.height * controlHeightRatio + curveOffset) * expansion
        return rect.minY
            + inverseT * inverseT * inverseT * edgeY
            + 3 * inverseT * inverseT * t * controlY
            + 3 * inverseT * t * t * controlY
            + t * t * t * edgeY
    }

    static func linePath(in rect: CGRect, curveOffset: CGFloat, expansion: CGFloat) -> Path {
        let startY = curveY(at: rect.minX, in: rect, curveOffset: curveOffset, expansion: expansion)
        let endY = curveY(at: rect.maxX, in: rect, curveOffset: curveOffset, expansion: expansion)
        let controlY = rect.minY + (rect.height * controlHeightRatio + curveOffset) * expansion
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: controlY),
            control2: CGPoint(x: rect.minX + rect.width * 0.75, y: controlY)
        )
        return path
    }

    static func surfacePath(in rect: CGRect, bottomExtension: CGFloat, curveOffset: CGFloat, expansion: CGFloat) -> Path {
        let line = linePath(in: rect, curveOffset: curveOffset, expansion: expansion)
        let startY = curveY(at: rect.minX, in: rect, curveOffset: curveOffset, expansion: expansion)
        let bottomY = rect.maxY + max(0, bottomExtension)
        var path = line
        path.addLine(to: CGPoint(x: rect.maxX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.closeSubpath()
        return path
    }
}
