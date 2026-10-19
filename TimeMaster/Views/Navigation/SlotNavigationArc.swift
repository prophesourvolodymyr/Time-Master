// SlotNavigationArc.swift
//
// The shallow arc the navigation surface and its hairline follow. Part of the
// CarouselNavigation component from the SwiftComponentLibrary, copied into the app.

import SwiftUI

struct SlotArcShape: Shape {
    let edgeExtension: CGFloat
    var placement: SlotNavigationPlacement = .bottom
    let curveOffset: CGFloat
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        SlotArcGeometry.surfacePath(in: rect, edgeExtension: edgeExtension, curveOffset: curveOffset, expansion: expansion, placement: placement)
    }
}

struct SlotArcLineShape: Shape {
    let curveOffset: CGFloat
    var placement: SlotNavigationPlacement = .bottom
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        SlotArcGeometry.linePath(in: rect, curveOffset: curveOffset, expansion: expansion, placement: placement)
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

    static func linePath(in rect: CGRect, curveOffset: CGFloat, expansion: CGFloat, placement: SlotNavigationPlacement = .bottom) -> Path {
        let startY = placedY(curveY(at: rect.minX, in: rect, curveOffset: curveOffset, expansion: expansion), in: rect, placement: placement)
        let endY = placedY(curveY(at: rect.maxX, in: rect, curveOffset: curveOffset, expansion: expansion), in: rect, placement: placement)
        let controlY = placedY(rect.minY + (rect.height * controlHeightRatio + curveOffset) * expansion, in: rect, placement: placement)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: controlY),
            control2: CGPoint(x: rect.minX + rect.width * 0.75, y: controlY)
        )
        return path
    }

    static func surfacePath(in rect: CGRect, edgeExtension: CGFloat, curveOffset: CGFloat, expansion: CGFloat, placement: SlotNavigationPlacement = .bottom) -> Path {
        let line = linePath(in: rect, curveOffset: curveOffset, expansion: expansion, placement: placement)
        let startY = placedY(curveY(at: rect.minX, in: rect, curveOffset: curveOffset, expansion: expansion), in: rect, placement: placement)
        let edgeY = placement == .bottom ? rect.maxY + max(0, edgeExtension) : rect.minY - max(0, edgeExtension)
        var path = line
        path.addLine(to: CGPoint(x: rect.maxX, y: edgeY))
        path.addLine(to: CGPoint(x: rect.minX, y: edgeY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.closeSubpath()
        return path
    }

    private static func placedY(_ y: CGFloat, in rect: CGRect, placement: SlotNavigationPlacement) -> CGFloat {
        placement == .bottom ? y : rect.minY + rect.maxY - y
    }
}
