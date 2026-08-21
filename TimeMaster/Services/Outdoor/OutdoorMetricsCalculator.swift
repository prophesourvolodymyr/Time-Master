import Foundation

struct OutdoorMetrics: Equatable {
    var distanceMeters: Double
    var elapsedSeconds: Int
    var movingSeconds: Int
    var averageSpeedMetersPerSecond: Double?
    var maxSpeedMetersPerSecond: Double?
    var paceSecondsPerKilometer: Double?
    var elevationGainMeters: Double?
    var highestElevationMeters: Double?

    var averagePaceSecondsPerKilometer: Double? { paceSecondsPerKilometer }

    init(
        distanceMeters: Double,
        elapsedSeconds: Int,
        movingSeconds: Int,
        averageSpeedMetersPerSecond: Double?,
        maxSpeedMetersPerSecond: Double?,
        paceSecondsPerKilometer: Double? = nil,
        elevationGainMeters: Double? = nil,
        highestElevationMeters: Double? = nil
    ) {
        self.distanceMeters = max(0, distanceMeters)
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.movingSeconds = max(0, min(self.elapsedSeconds, movingSeconds))
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.maxSpeedMetersPerSecond = maxSpeedMetersPerSecond
        self.paceSecondsPerKilometer = paceSecondsPerKilometer
        self.elevationGainMeters = elevationGainMeters
        self.highestElevationMeters = highestElevationMeters
    }
}

enum OutdoorMetricsCalculator {
    static let defaultMaximumHorizontalAccuracyMeters = 100.0
    static let preciseMaximumHorizontalAccuracyMeters = 25.0
    static let defaultMinimumMovementMeters = 3.0
    static let defaultMaximumPlausibleSpeedMetersPerSecond = 70.0
    static let defaultElevationNoiseThresholdMeters = 1.5

    static func distanceMeters(from first: OutdoorTrackPoint, to second: OutdoorTrackPoint) -> Double {
        guard isValidCoordinate(first.latitude, first.longitude),
              isValidCoordinate(second.latitude, second.longitude) else { return 0 }
        let radius = 6_371_000.0
        let lat1 = first.latitude * .pi / 180
        let lat2 = second.latitude * .pi / 180
        let dLat = (second.latitude - first.latitude) * .pi / 180
        let dLon = (second.longitude - first.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(sqrt(max(0, a)), sqrt(max(0, 1 - a)))
    }

    static func isValidLocationPoint(
        _ point: OutdoorTrackPoint,
        maximumHorizontalAccuracyMeters: Double = defaultMaximumHorizontalAccuracyMeters,
        maximumPlausibleSpeedMetersPerSecond: Double = defaultMaximumPlausibleSpeedMetersPerSecond
    ) -> Bool {
        guard isValidCoordinate(point.latitude, point.longitude),
              point.timestamp.timeIntervalSinceReferenceDate.isFinite,
              point.horizontalAccuracyMeters.isFinite,
              point.horizontalAccuracyMeters >= 0,
              point.horizontalAccuracyMeters <= maximumHorizontalAccuracyMeters else { return false }
        if let speed = point.speedMetersPerSecond {
            guard speed.isFinite, speed >= 0, speed <= maximumPlausibleSpeedMetersPerSecond else { return false }
        }
        if let elevation = point.elevationMeters {
            guard elevation.isFinite else { return false }
        }
        return true
    }

    static func accepts(
        _ point: OutdoorTrackPoint,
        after previous: OutdoorTrackPoint?,
        maximumHorizontalAccuracyMeters: Double = defaultMaximumHorizontalAccuracyMeters,
        minimumMovementMeters: Double = defaultMinimumMovementMeters,
        maximumPlausibleSpeedMetersPerSecond: Double = defaultMaximumPlausibleSpeedMetersPerSecond
    ) -> Bool {
        guard isValidLocationPoint(
            point,
            maximumHorizontalAccuracyMeters: maximumHorizontalAccuracyMeters,
            maximumPlausibleSpeedMetersPerSecond: maximumPlausibleSpeedMetersPerSecond
        ) else { return false }
        guard point.state == .recording else { return false }
        guard let previous else { return true }
        guard isValidLocationPoint(
            previous,
            maximumHorizontalAccuracyMeters: maximumHorizontalAccuracyMeters,
            maximumPlausibleSpeedMetersPerSecond: maximumPlausibleSpeedMetersPerSecond
        ) else { return false }
        let delta = point.timestamp.timeIntervalSince(previous.timestamp)
        guard delta > 0, delta.isFinite else { return false }
        let movement = distanceMeters(from: previous, to: point)
        guard movement >= max(0, minimumMovementMeters) else { return false }
        let derivedSpeed = movement / delta
        guard derivedSpeed.isFinite,
              derivedSpeed <= maximumPlausibleSpeedMetersPerSecond else { return false }
        let reportedSpeed = point.speedMetersPerSecond ?? derivedSpeed
        return reportedSpeed.isFinite && reportedSpeed >= 0
            && reportedSpeed <= maximumPlausibleSpeedMetersPerSecond
    }

    static func aggregate(
        points: [OutdoorTrackPoint],
        pauses: [OutdoorPauseInterval],
        maximumHorizontalAccuracyMeters: Double = defaultMaximumHorizontalAccuracyMeters,
        minimumMovementMeters: Double = defaultMinimumMovementMeters,
        maximumPlausibleSpeedMetersPerSecond: Double = defaultMaximumPlausibleSpeedMetersPerSecond,
        elevationNoiseThresholdMeters: Double = defaultElevationNoiseThresholdMeters
    ) -> OutdoorMetrics {
        var firstTimelineDate: Date?
        var lastTimelineDate: Date?
        var previousTimelinePoint: OutdoorTrackPoint?
        var previousRecordingPoint: OutdoorTrackPoint?
        var distance = 0.0
        var moving = 0.0
        var maxSpeed: Double?
        var elevationGain = 0.0
        var highestElevation: Double?
        var hasElevation = false

        for point in points {
            guard isValidLocationPoint(
                point,
                maximumHorizontalAccuracyMeters: maximumHorizontalAccuracyMeters,
                maximumPlausibleSpeedMetersPerSecond: maximumPlausibleSpeedMetersPerSecond
            ) else { continue }
            guard let previousTimeline = previousTimelinePoint else {
                firstTimelineDate = point.timestamp
                lastTimelineDate = point.timestamp
                previousTimelinePoint = point
                if point.state == .recording {
                    previousRecordingPoint = point
                    if let elevation = point.elevationMeters {
                        highestElevation = elevation
                        hasElevation = true
                    }
                }
                continue
            }
            guard point.timestamp > previousTimeline.timestamp else { continue }
            lastTimelineDate = point.timestamp
            previousTimelinePoint = point

            guard point.state == .recording else {
                previousRecordingPoint = nil
                continue
            }
            guard let previousRecording = previousRecordingPoint else {
                selfUpdateHighest(&highestElevation, point: point, hasElevation: &hasElevation)
                previousRecordingPoint = point
                continue
            }
            let delta = point.timestamp.timeIntervalSince(previousRecording.timestamp)
            let segmentDistance = distanceMeters(from: previousRecording, to: point)
            let threshold = max(0, minimumMovementMeters)
            guard delta > 0, delta.isFinite, segmentDistance >= threshold else { continue }
            let derivedSpeed = segmentDistance / delta
            guard derivedSpeed.isFinite, derivedSpeed <= maximumPlausibleSpeedMetersPerSecond else { continue }
            let reportedSpeed = point.speedMetersPerSecond ?? derivedSpeed
            guard reportedSpeed.isFinite, reportedSpeed >= 0,
                  reportedSpeed <= maximumPlausibleSpeedMetersPerSecond else { continue }
            let pauseOverlap = pauseDuration(
                from: previousRecording.timestamp,
                to: point.timestamp,
                pauses: pauses
            )
            guard pauseOverlap == 0 else {
                selfUpdateHighest(&highestElevation, point: point, hasElevation: &hasElevation)
                previousRecordingPoint = point
                continue
            }
            distance += segmentDistance
            moving += delta
            maxSpeed = max(maxSpeed ?? 0, max(derivedSpeed, reportedSpeed))
            if let previousElevation = previousRecording.elevationMeters,
               let currentElevation = point.elevationMeters,
               previousElevation.isFinite, currentElevation.isFinite {
                hasElevation = true
                let change = currentElevation - previousElevation
                if change > max(0, elevationNoiseThresholdMeters) {
                    elevationGain += change
                }
            }
            selfUpdateHighest(&highestElevation, point: point, hasElevation: &hasElevation)
            previousRecordingPoint = point
        }

        if let firstTimelineDate {
            for pause in pauses {
                if let end = pause.endedAt, end > (lastTimelineDate ?? firstTimelineDate) {
                    lastTimelineDate = end
                }
            }
        }
        let elapsed = firstTimelineDate.flatMap { first in
            lastTimelineDate.map { last in max(0, Int(last.timeIntervalSince(first).rounded())) }
        } ?? 0
        let movingSeconds = max(0, min(elapsed, Int(moving.rounded())))
        let averageSpeed = movingSeconds > 0 ? distance / Double(movingSeconds) : nil
        let pace = distance >= 10 && moving > 0 ? moving / distance * 1_000 : nil
        return OutdoorMetrics(
            distanceMeters: distance,
            elapsedSeconds: elapsed,
            movingSeconds: movingSeconds,
            averageSpeedMetersPerSecond: averageSpeed,
            maxSpeedMetersPerSecond: maxSpeed,
            paceSecondsPerKilometer: pace,
            elevationGainMeters: hasElevation ? elevationGain : nil,
            highestElevationMeters: highestElevation
        )
    }

    private static func isValidCoordinate(_ latitude: Double, _ longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    private static func pauseDuration(from start: Date, to end: Date, pauses: [OutdoorPauseInterval]) -> Double {
        guard end > start else { return 0 }
        return pauses.reduce(0) { result, pause in
            let pauseEnd = pause.endedAt ?? end
            let overlapStart = max(start, pause.startedAt)
            let overlapEnd = min(end, pauseEnd)
            return result + max(0, overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    private static func selfUpdateHighest(
        _ highest: inout Double?,
        point: OutdoorTrackPoint,
        hasElevation: inout Bool
    ) {
        guard let elevation = point.elevationMeters, elevation.isFinite else { return }
        hasElevation = true
        highest = max(highest ?? elevation, elevation)
    }
}
