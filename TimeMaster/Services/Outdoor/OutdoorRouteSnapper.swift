#if os(iOS)
import Foundation
import CoreLocation

struct SnappedPosition {
    var coordinate: CLLocationCoordinate2D
    var progress: Double // 0...1 along route
    var distanceAlongRouteMeters: Double
    var distanceToRouteMeters: Double
}

enum OutdoorRouteSnapper {
    /// Basic snap using segment projection. Sufficient for first version (plan).
    static func snap(location: CLLocation, to route: [OutdoorTrackPoint], radiusMeters: Double = 30) -> SnappedPosition? {
        guard route.count >= 2 else { return nil }
        let pt = location.coordinate
        var best: (coord: CLLocationCoordinate2D, prog: Double, distAlong: Double, off: Double) = (route[0].coordinate, 0, 0, .greatestFiniteMagnitude)
        var cumDist: Double = 0
        for i in 0..<(route.count - 1) {
            let a = route[i].coordinate
            let b = route[i+1].coordinate
            let segLen = distance(a, b)
            let (proj, t, off) = project(pt, onto: a, b)
            let thisAlong = cumDist + t * segLen
            if off < best.off {
                best = (proj, (cumDist + t * segLen) / max(totalLength(route), 0.001), thisAlong, off)
            }
            cumDist += segLen
        }
        if best.off <= radiusMeters {
            return SnappedPosition(coordinate: best.coord, progress: best.prog, distanceAlongRouteMeters: best.distAlong, distanceToRouteMeters: best.off)
        }
        return nil
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB)
    }

    private static func totalLength(_ route: [OutdoorTrackPoint]) -> Double {
        var d: Double = 0
        for i in 0..<(route.count-1) {
            d += distance(route[i].coordinate, route[i+1].coordinate)
        }
        return d
    }

    // project p onto segment ab; return (proj coord, t 0-1, off dist)
    private static func project(_ p: CLLocationCoordinate2D, onto a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> (CLLocationCoordinate2D, Double, Double) {
        let ax = a.longitude, ay = a.latitude
        let bx = b.longitude, by = b.latitude
        let px = p.longitude, py = p.latitude
        let dx = bx - ax, dy = by - ay
        let len2 = dx*dx + dy*dy
        if len2 == 0 { return (a, 0, distance(p, a)) }
        var t = ((px - ax)*dx + (py - ay)*dy) / len2
        t = max(0, min(1, t))
        let qx = ax + t * dx
        let qy = ay + t * dy
        let q = CLLocationCoordinate2D(latitude: qy, longitude: qx)
        return (q, t, distance(p, q))
    }
}

private extension OutdoorTrackPoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
#endif
