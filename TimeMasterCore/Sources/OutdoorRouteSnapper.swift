import CoreLocation
import Foundation

public struct SnappedPosition {
    public var coordinate: CLLocationCoordinate2D
    public var progress: Double
    public var distanceAlongRouteMeters: Double
    public var distanceToRouteMeters: Double

    public init(
        coordinate: CLLocationCoordinate2D,
        progress: Double,
        distanceAlongRouteMeters: Double,
        distanceToRouteMeters: Double
    ) {
        self.coordinate = coordinate
        self.progress = progress
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
        self.distanceToRouteMeters = distanceToRouteMeters
    }
}

public enum OutdoorRouteSnapper {
    public static func snap(
        location: CLLocation,
        to route: [OutdoorTrackPoint],
        radiusMeters: Double = 30
    ) -> SnappedPosition? {
        guard route.count >= 2 else { return nil }

        let point = location.coordinate
        var best: (
            coordinate: CLLocationCoordinate2D,
            progress: Double,
            distanceAlong: Double,
            offset: Double
        ) = (route[0].coordinate, 0, 0, .greatestFiniteMagnitude)
        var distanceAlongRoute = 0.0
        let routeLength = max(totalLength(route), 0.001)

        for index in 0..<(route.count - 1) {
            let start = route[index].coordinate
            let end = route[index + 1].coordinate
            let segmentLength = distance(start, end)
            let (projection, fraction, offset) = project(point, onto: start, end)
            let projectedDistance = distanceAlongRoute + fraction * segmentLength

            if offset < best.offset {
                best = (
                    projection,
                    projectedDistance / routeLength,
                    projectedDistance,
                    offset
                )
            }
            distanceAlongRoute += segmentLength
        }

        guard best.offset <= radiusMeters else { return nil }
        return SnappedPosition(
            coordinate: best.coordinate,
            progress: best.progress,
            distanceAlongRouteMeters: best.distanceAlong,
            distanceToRouteMeters: best.offset
        )
    }

    private static func distance(_ start: CLLocationCoordinate2D, _ end: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    private static func totalLength(_ route: [OutdoorTrackPoint]) -> Double {
        guard route.count >= 2 else { return 0 }
        return (0..<(route.count - 1)).reduce(0) { total, index in
            total + distance(route[index].coordinate, route[index + 1].coordinate)
        }
    }

    private static func project(
        _ point: CLLocationCoordinate2D,
        onto start: CLLocationCoordinate2D,
        _ end: CLLocationCoordinate2D
    ) -> (CLLocationCoordinate2D, Double, Double) {
        let startX = start.longitude
        let startY = start.latitude
        let endX = end.longitude
        let endY = end.latitude
        let pointX = point.longitude
        let pointY = point.latitude
        let deltaX = endX - startX
        let deltaY = endY - startY
        let lengthSquared = deltaX * deltaX + deltaY * deltaY

        guard lengthSquared != 0 else {
            return (start, 0, distance(point, start))
        }

        let rawFraction = ((pointX - startX) * deltaX + (pointY - startY) * deltaY) / lengthSquared
        let fraction = max(0, min(1, rawFraction))
        let projection = CLLocationCoordinate2D(
            latitude: startY + fraction * deltaY,
            longitude: startX + fraction * deltaX
        )
        return (projection, fraction, distance(point, projection))
    }
}

private extension OutdoorTrackPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
