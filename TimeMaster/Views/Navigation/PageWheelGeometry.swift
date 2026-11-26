// PageWheelGeometry.swift
//
// Where the page wheel's slices sit and how the bar's arc becomes the wheel. Angles run clockwise from twelve o'clock
// in radians. A rotation counts slices: the slice whose index equals the rotation sits at the top, under the pointer.

import CoreGraphics

struct PageWheelGeometry: Equatable {
    var count: Int
    var center: CGPoint
    var radius: CGFloat
    var hubRadius: CGFloat
    /// Angle between two neighbouring slices: the full circle shared out once the wheel has formed, less while the arc
    /// is still turning into it.
    var spacing: CGFloat

    init(count: Int, center: CGPoint, radius: CGFloat, hubRadius: CGFloat, spacing: CGFloat? = nil) {
        self.count = max(0, count)
        self.center = center
        self.radius = max(0, radius)
        self.hubRadius = max(0, min(hubRadius, radius))
        self.spacing = spacing ?? Self.fullSpacing(count: count)
    }

    static func fullSpacing(count: Int) -> CGFloat {
        2 * .pi / CGFloat(max(count, 1))
    }

    static func wrap(_ index: Int, count: Int) -> Int {
        count > 0 ? ((index % count) + count) % count : 0
    }

    /// Signed place of slice `index` from the top for `rotation`, wrapped into the half of the wheel around the top.
    func offset(of index: Int, rotation: CGFloat) -> CGFloat {
        guard count > 0, rotation.isFinite else { return 0 }
        let total = CGFloat(count)
        var place = (CGFloat(index) - rotation).truncatingRemainder(dividingBy: total)
        if place >= total / 2 {
            place -= total
        } else if place < -total / 2 {
            place += total
        }
        return place
    }

    func angle(of index: Int, rotation: CGFloat) -> CGFloat {
        offset(of: index, rotation: rotation) * spacing
    }

    func point(angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(x: center.x + sin(angle) * distance, y: center.y - cos(angle) * distance)
    }

    /// Clockwise angle of `point` around the centre, 0 straight up, in (-π, π].
    func angle(of point: CGPoint) -> CGFloat {
        atan2(point.x - center.x, center.y - point.y)
    }

    func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - center.x, point.y - center.y)
    }

    /// The slice in the direction of `point`; nil on the hub, where a press means the slice at the top.
    func slice(at point: CGPoint, rotation: CGFloat) -> Int? {
        guard count > 0, distance(to: point) > hubRadius else { return nil }
        let place = angle(of: point) / spacing + rotation
        guard place.isFinite else { return nil }
        return Self.wrap(Int(place.rounded()), count: count)
    }

    func top(rotation: CGFloat) -> Int {
        guard rotation.isFinite else { return 0 }
        return Self.wrap(Int(rotation.rounded()), count: count)
    }

    /// The rotation nearest `rotation` that brings slice `index` to the top.
    func rotation(bringing index: Int, near rotation: CGFloat) -> CGFloat {
        rotation + offset(of: index, rotation: rotation)
    }

    /// How far the wheel turned, in slices, while a finger travelled from `start` to `end` around the centre. Turning
    /// clockwise brings the slices before the top one up, so the rotation falls.
    func slices(turnedFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        guard spacing > 0 else { return 0 }
        var delta = angle(of: end) - angle(of: start)
        if delta > .pi {
            delta -= 2 * .pi
        } else if delta <= -.pi {
            delta += 2 * .pi
        }
        return -delta / spacing
    }
}

/// The bar's arc becoming the wheel. The arc line is the top of a large circle centred below the screen; as `progress`
/// runs from 0 to 1 that circle shrinks and rises into the wheel in the middle of the screen, and the pages sitting on
/// the arc spread around it, so the bar itself turns into the wheel under the finger.
struct PageWheelMorph: Equatable {
    var count: Int
    /// The circle through the arc line, in the wheel's coordinate space.
    var arcCenter: CGPoint
    var arcRadius: CGFloat
    /// Distance between two pages along the arc.
    var arcPitch: CGFloat
    /// How far below the arc line the pages sit on the bar.
    var arcInset: CGFloat
    var wheelCenter: CGPoint
    var wheelRadius: CGFloat
    static let hubRatio: CGFloat = 0.34

    /// The circle through both ends of an arc `width` wide whose line sags `sag` points from its ends to its peak at
    /// `peak` (the middle of the line).
    static func arcCircle(width: CGFloat, peak: CGPoint, sag: CGFloat) -> (center: CGPoint, radius: CGFloat) {
        let half = max(1, width / 2)
        let rise = max(1, sag)
        let radius = (half * half + rise * rise) / (2 * rise)
        return (CGPoint(x: peak.x, y: peak.y + radius), radius)
    }

    func geometry(at progress: CGFloat) -> PageWheelGeometry {
        let amount = min(max(progress.isFinite ? progress : 0, 0), 1)
        let eased = amount * amount * (3 - 2 * amount)
        let arcTop = arcCenter.y - arcRadius
        let wheelTop = wheelCenter.y - wheelRadius
        let top = arcTop + (wheelTop - arcTop) * eased
        let ratio = max(0.0001, wheelRadius / max(arcRadius, 1))
        let radius = max(1, arcRadius) * pow(ratio, eased)
        let x = arcCenter.x + (wheelCenter.x - arcCenter.x) * eased
        let arcSpacing = arcPitch / max(1, arcRadius - arcInset)
        let full = PageWheelGeometry.fullSpacing(count: count)
        let spacing = arcSpacing + (full - arcSpacing) * eased
        return PageWheelGeometry(
            count: count,
            center: CGPoint(x: x, y: top + radius),
            radius: radius,
            hubRadius: radius * Self.hubRatio * eased,
            spacing: spacing
        )
    }

    /// How far from the centre a page's icon sits: just under the arc line on the bar, in the middle of its slice on
    /// the wheel.
    func itemDistance(in geometry: PageWheelGeometry, progress: CGFloat) -> CGFloat {
        let amount = min(max(progress.isFinite ? progress : 0, 0), 1)
        let onWheel = geometry.hubRadius + (geometry.radius - geometry.hubRadius) * 0.56
        let onArc = geometry.radius - arcInset
        return onArc + (onWheel - onArc) * amount
    }
}
