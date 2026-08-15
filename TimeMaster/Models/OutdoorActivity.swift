import Foundation
import TimeMasterCore

enum OutdoorActivityKind: String, Codable, CaseIterable, Identifiable {
    case runWalk
    case bike

    var id: String { rawValue }
    var displayName: String { self == .runWalk ? "Run & Walk" : "Bike" }
    var iconName: String { self == .runWalk ? "figure.run" : "bicycle" }
    var defaultTitle: String { displayName }

    init(core: TimeMasterCore.OutdoorActivityKind) {
        self = core == .runWalk ? .runWalk : .bike
    }

    var coreValue: TimeMasterCore.OutdoorActivityKind {
        switch self {
        case .runWalk: .runWalk
        case .bike: .bike
        }
    }
}

enum OutdoorRecordingState: String, Codable, Equatable {
    case recording
    case manualPaused
    case autoPaused
    case finished

    init(core: TimeMasterCore.OutdoorRecordingState) {
        self = OutdoorRecordingState(rawValue: core.rawValue) ?? .finished
    }

    var coreValue: TimeMasterCore.OutdoorRecordingState {
        TimeMasterCore.OutdoorRecordingState(rawValue: rawValue) ?? .finished
    }
}

struct OutdoorTrackPoint: Codable, Equatable, Identifiable {
    var id: Date { timestamp }
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var elevationMeters: Double?
    var horizontalAccuracyMeters: Double
    var speedMetersPerSecond: Double?
    var state: OutdoorRecordingState

    init(timestamp: Date, latitude: Double, longitude: Double, elevationMeters: Double? = nil, horizontalAccuracyMeters: Double, speedMetersPerSecond: Double? = nil, state: OutdoorRecordingState) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.state = state
    }

    init(core: TimeMasterCore.OutdoorTrackPoint) {
        self.init(timestamp: core.timestamp, latitude: core.latitude, longitude: core.longitude, elevationMeters: core.elevationMeters, horizontalAccuracyMeters: core.horizontalAccuracyMeters, speedMetersPerSecond: core.speedMetersPerSecond, state: OutdoorRecordingState(core: core.state))
    }

    var coreValue: TimeMasterCore.OutdoorTrackPoint {
        TimeMasterCore.OutdoorTrackPoint(timestamp: timestamp, latitude: latitude, longitude: longitude, elevationMeters: elevationMeters, horizontalAccuracyMeters: horizontalAccuracyMeters, speedMetersPerSecond: speedMetersPerSecond, state: state.coreValue)
    }
}

struct OutdoorPauseInterval: Codable, Equatable, Identifiable {
    var id: String
    var startedAt: Date
    var endedAt: Date?
    var automatic: Bool


    init(id: String = UUID().uuidString, startedAt: Date, endedAt: Date? = nil, automatic: Bool) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.automatic = automatic
    }
    init(core: TimeMasterCore.OutdoorPauseInterval) {
        id = core.id
        startedAt = core.startedAt
        endedAt = core.endedAt
        automatic = core.automatic
    }

    var coreValue: TimeMasterCore.OutdoorPauseInterval {
        TimeMasterCore.OutdoorPauseInterval(id: id, startedAt: startedAt, endedAt: endedAt, automatic: automatic)
    }
}

struct OutdoorLap: Codable, Equatable, Identifiable {
    var id: String
    var number: Int
    var timestamp: Date
    var elapsedSeconds: Int
    var distanceMeters: Double

    init(id: String = UUID().uuidString, number: Int, timestamp: Date, elapsedSeconds: Int, distanceMeters: Double) {
        self.id = id
        self.number = number
        self.timestamp = timestamp
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.distanceMeters = max(0, distanceMeters)
    }

    init(core: TimeMasterCore.OutdoorLap) {
        id = core.id
        number = core.number
        timestamp = core.timestamp
        elapsedSeconds = core.elapsedSeconds
        distanceMeters = core.distanceMeters
    }

    var coreValue: TimeMasterCore.OutdoorLap {
        TimeMasterCore.OutdoorLap(id: id, number: number, timestamp: timestamp, elapsedSeconds: elapsedSeconds, distanceMeters: distanceMeters)
    }
}

struct OutdoorActivity: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: OutdoorActivityKind
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int
    var movingSeconds: Int
    var distanceMeters: Double
    var averageSpeedMetersPerSecond: Double?
    var maxSpeedMetersPerSecond: Double?
    var timeTargetSeconds: Int?
    var pauseIntervals: [OutdoorPauseInterval]
    var laps: [OutdoorLap]
    var trackPointCount: Int
    var recordingState: OutdoorRecordingState
    var finished: Bool
    var plannedRouteID: String?

    init(core: TimeMasterCore.OutdoorActivityManifest) throws {
        guard let id = UUID(uuidString: core.id) else { throw OutdoorActivityConversionError.invalidIdentifier(core.id) }
        self.id = id
        kind = OutdoorActivityKind(core: core.kind)
        title = core.title
        startedAt = core.startedAt
        endedAt = core.endedAt
        elapsedSeconds = core.elapsedSeconds
        movingSeconds = core.movingSeconds
        distanceMeters = core.distanceMeters
        averageSpeedMetersPerSecond = core.averageSpeedMetersPerSecond
        maxSpeedMetersPerSecond = core.maxSpeedMetersPerSecond
        timeTargetSeconds = core.timeTargetSeconds
        pauseIntervals = core.pauseIntervals.map(OutdoorPauseInterval.init)
        laps = core.laps.map(OutdoorLap.init)
        trackPointCount = core.trackPointCount
        recordingState = OutdoorRecordingState(core: core.recordingState)
        finished = core.finished
        plannedRouteID = core.plannedRouteID
    }

    init(id: UUID = UUID(), kind: OutdoorActivityKind, title: String? = nil, startedAt: Date = Date(), timeTargetSeconds: Int? = nil) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.startedAt = startedAt
        endedAt = nil
        elapsedSeconds = 0
        movingSeconds = 0
        distanceMeters = 0
        averageSpeedMetersPerSecond = nil
        maxSpeedMetersPerSecond = nil
        self.timeTargetSeconds = timeTargetSeconds.flatMap { $0 > 0 ? $0 : nil }
        pauseIntervals = []
        laps = []
        trackPointCount = 0
        recordingState = .recording
        finished = false
        plannedRouteID = nil
    }

    var coreValue: TimeMasterCore.OutdoorActivityManifest {
        TimeMasterCore.OutdoorActivityManifest(id: id.uuidString, kind: kind.coreValue, title: title, startedAt: startedAt, endedAt: endedAt, elapsedSeconds: elapsedSeconds, movingSeconds: movingSeconds, distanceMeters: distanceMeters, averageSpeedMetersPerSecond: averageSpeedMetersPerSecond, maxSpeedMetersPerSecond: maxSpeedMetersPerSecond, timeTargetSeconds: timeTargetSeconds, pauseIntervals: pauseIntervals.map(\.coreValue), laps: laps.map(\.coreValue), trackPointCount: trackPointCount, recordingState: recordingState.coreValue, finished: finished, plannedRouteID: plannedRouteID)
    }
}

enum OutdoorActivityConversionError: Error, LocalizedError {
    case invalidIdentifier(String)

    var errorDescription: String? {
        switch self { case .invalidIdentifier(let value): "Invalid outdoor activity identifier: \(value)" }
    }
}
