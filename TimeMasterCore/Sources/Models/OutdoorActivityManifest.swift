import Foundation

public enum OutdoorActivityKind: String, Codable, Equatable {
    case runWalk
    case bike

    public var defaultTitle: String {
        switch self {
        case .runWalk: "Run & Walk"
        case .bike: "Bike"
        }
    }
}

public enum OutdoorRecordingState: String, Codable, Equatable {
    case recording
    case manualPaused
    case autoPaused
    case finished
}

public struct OutdoorTrackPoint: Codable, Equatable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var elevationMeters: Double?
    public var horizontalAccuracyMeters: Double
    public var speedMetersPerSecond: Double?
    public var state: OutdoorRecordingState

    public init(timestamp: Date, latitude: Double, longitude: Double, elevationMeters: Double? = nil, horizontalAccuracyMeters: Double, speedMetersPerSecond: Double? = nil, state: OutdoorRecordingState) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.state = state
    }
}

public struct OutdoorPauseInterval: Codable, Equatable, Identifiable {
    public var id: String
    public var startedAt: Date
    public var endedAt: Date?
    public var automatic: Bool

    public init(id: String = UUID().uuidString, startedAt: Date, endedAt: Date? = nil, automatic: Bool) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.automatic = automatic
    }
}

public struct OutdoorLap: Codable, Equatable, Identifiable {
    public var id: String
    public var number: Int
    public var timestamp: Date
    public var elapsedSeconds: Int
    public var distanceMeters: Double

    public init(id: String = UUID().uuidString, number: Int, timestamp: Date, elapsedSeconds: Int, distanceMeters: Double) {
        self.id = id
        self.number = number
        self.timestamp = timestamp
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.distanceMeters = max(0, distanceMeters)
    }
}

public struct OutdoorActivityManifest: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: OutdoorActivityKind
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    public var elapsedSeconds: Int
    public var movingSeconds: Int
    public var distanceMeters: Double
    public var averageSpeedMetersPerSecond: Double?
    public var maxSpeedMetersPerSecond: Double?
    public var timeTargetSeconds: Int?
    public var pauseIntervals: [OutdoorPauseInterval]
    public var laps: [OutdoorLap]
    public var trackPointCount: Int
    public var recordingState: OutdoorRecordingState
    public var finished: Bool
    public var plannedRouteID: String?

    public init(id: String = UUID().uuidString, kind: OutdoorActivityKind, title: String? = nil, startedAt: Date = Date(), endedAt: Date? = nil, elapsedSeconds: Int = 0, movingSeconds: Int = 0, distanceMeters: Double = 0, averageSpeedMetersPerSecond: Double? = nil, maxSpeedMetersPerSecond: Double? = nil, timeTargetSeconds: Int? = nil, pauseIntervals: [OutdoorPauseInterval] = [], laps: [OutdoorLap] = [], trackPointCount: Int = 0, recordingState: OutdoorRecordingState = .recording, finished: Bool = false, plannedRouteID: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.movingSeconds = max(0, movingSeconds)
        self.distanceMeters = max(0, distanceMeters)
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond.map { max(0, $0) }
        self.maxSpeedMetersPerSecond = maxSpeedMetersPerSecond.map { max(0, $0) }
        self.timeTargetSeconds = timeTargetSeconds.flatMap { $0 > 0 ? $0 : nil }
        self.pauseIntervals = pauseIntervals
        self.laps = laps
        self.trackPointCount = max(0, trackPointCount)
        self.recordingState = recordingState
        self.finished = finished
        self.plannedRouteID = plannedRouteID
    }
    private enum CodingKeys: String, CodingKey {
        case id, kind, title, startedAt, endedAt, elapsedSeconds, movingSeconds, distanceMeters, averageSpeedMetersPerSecond, maxSpeedMetersPerSecond, timeTargetSeconds, pauseIntervals, laps, trackPointCount, recordingState, finished, plannedRouteID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(OutdoorActivityKind.self, forKey: .kind)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            kind: kind,
            title: try c.decodeIfPresent(String.self, forKey: .title),
            startedAt: try c.decode(Date.self, forKey: .startedAt),
            endedAt: try c.decodeIfPresent(Date.self, forKey: .endedAt),
            elapsedSeconds: try c.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0,
            movingSeconds: try c.decodeIfPresent(Int.self, forKey: .movingSeconds) ?? 0,
            distanceMeters: try c.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0,
            averageSpeedMetersPerSecond: try c.decodeIfPresent(Double.self, forKey: .averageSpeedMetersPerSecond),
            maxSpeedMetersPerSecond: try c.decodeIfPresent(Double.self, forKey: .maxSpeedMetersPerSecond),
            timeTargetSeconds: try c.decodeIfPresent(Int.self, forKey: .timeTargetSeconds),
            pauseIntervals: try c.decodeIfPresent([OutdoorPauseInterval].self, forKey: .pauseIntervals) ?? [],
            laps: try c.decodeIfPresent([OutdoorLap].self, forKey: .laps) ?? [],
            trackPointCount: try c.decodeIfPresent(Int.self, forKey: .trackPointCount) ?? 0,
            recordingState: try c.decodeIfPresent(OutdoorRecordingState.self, forKey: .recordingState) ?? .finished,
            finished: try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false,
            plannedRouteID: try c.decodeIfPresent(String.self, forKey: .plannedRouteID)
        )
    }
}
