import Foundation

struct OutdoorMetrics: Equatable {
    var distanceMeters: Double
    var elapsedSeconds: Int
    var movingSeconds: Int
    var averageSpeedMetersPerSecond: Double?
    var maxSpeedMetersPerSecond: Double?
}

enum OutdoorMetricsCalculator {
    static func distanceMeters(from first: OutdoorTrackPoint, to second: OutdoorTrackPoint) -> Double {
        guard first.latitude.isFinite, first.longitude.isFinite, second.latitude.isFinite, second.longitude.isFinite else { return 0 }
        let radius = 6_371_000.0
        let lat1 = first.latitude * .pi / 180
        let lat2 = second.latitude * .pi / 180
        let dLat = (second.latitude - first.latitude) * .pi / 180
        let dLon = (second.longitude - first.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    static func aggregate(points: [OutdoorTrackPoint], pauses: [OutdoorPauseInterval]) -> OutdoorMetrics {
        guard let first = points.first else {
            return OutdoorMetrics(distanceMeters: 0, elapsedSeconds: 0, movingSeconds: 0, averageSpeedMetersPerSecond: nil, maxSpeedMetersPerSecond: nil)
        }
        var distance = 0.0
        var moving = 0.0
        var maxSpeed: Double?
        var previous = first
        for point in points.dropFirst() {
            let delta = point.timestamp.timeIntervalSince(previous.timestamp)
            guard delta >= 0 else { continue }
            let segmentDistance = distanceMeters(from: previous, to: point)
            let speed = segmentDistance / max(delta, 0.001)
            if speed <= 70 {
                distance += segmentDistance
                if point.state == .recording || previous.state == .recording {
                    moving += delta
                }
                maxSpeed = max(maxSpeed ?? 0, point.speedMetersPerSecond ?? speed)
            }
            previous = point
        }
        let elapsed = max(0, Int((previous.timestamp.timeIntervalSince(first.timestamp)).rounded()))
        let pausedSeconds = pauses.reduce(0.0) { partial, pause in
            guard let endedAt = pause.endedAt else { return partial }
            return partial + max(0, endedAt.timeIntervalSince(pause.startedAt))
        }
        let movingSeconds = max(0, min(elapsed, Int((moving - pausedSeconds).rounded())))
        let average = movingSeconds > 0 ? distance / Double(movingSeconds) : nil
        return OutdoorMetrics(distanceMeters: distance, elapsedSeconds: elapsed, movingSeconds: movingSeconds, averageSpeedMetersPerSecond: average, maxSpeedMetersPerSecond: maxSpeed)
    }
}
