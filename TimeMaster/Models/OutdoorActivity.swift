import Foundation
import TimeMasterCore

enum OutdoorActivityKind: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case runWalk
    case bike

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
        case .runWalk: "Run & Walk"
        case .bike: "Bike"
        }
    }

    var iconName: String {
        switch self {
        case .run, .runWalk: "figure.run"
        case .walk: "figure.walk"
        case .bike: "bicycle"
        }
    }

    var defaultTitle: String { displayName }

    init(core: TimeMasterCore.OutdoorActivityKind) {
        switch core {
        case .run: self = .run
        case .walk: self = .walk
        case .runWalk: self = .runWalk
        case .bike: self = .bike
        }
    }

    var coreValue: TimeMasterCore.OutdoorActivityKind {
        switch self {
        case .run: .run
        case .walk: .walk
        case .runWalk: .runWalk
        case .bike: .bike
        }
    }
}

typealias OutdoorActivityVisibility = TimeMasterCore.OutdoorActivityVisibility
typealias OutdoorPlayedTrackEvent = TimeMasterCore.OutdoorPlayedTrackEvent

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
    var verticalAccuracyMeters: Double?
    var barometricRelativeAltitudeMeters: Double?
    var speedMetersPerSecond: Double?
    var state: OutdoorRecordingState

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double? = nil,
        horizontalAccuracyMeters: Double,
        speedMetersPerSecond: Double? = nil,
        state: OutdoorRecordingState,
        verticalAccuracyMeters: Double? = nil,
        barometricRelativeAltitudeMeters: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.barometricRelativeAltitudeMeters = barometricRelativeAltitudeMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.state = state
    }

    init(core: TimeMasterCore.OutdoorTrackPoint) {
        self.init(
            timestamp: core.timestamp,
            latitude: core.latitude,
            longitude: core.longitude,
            elevationMeters: core.elevationMeters,
            horizontalAccuracyMeters: core.horizontalAccuracyMeters,
            speedMetersPerSecond: core.speedMetersPerSecond,
            state: OutdoorRecordingState(core: core.state),
            verticalAccuracyMeters: core.verticalAccuracyMeters,
            barometricRelativeAltitudeMeters: core.barometricRelativeAltitudeMeters
        )
    }

    var coreValue: TimeMasterCore.OutdoorTrackPoint {
        TimeMasterCore.OutdoorTrackPoint(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            elevationMeters: elevationMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            state: state.coreValue,
            verticalAccuracyMeters: verticalAccuracyMeters,
            barometricRelativeAltitudeMeters: barometricRelativeAltitudeMeters
        )
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
    var schemaVersion: Int
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
    var elevationGainMeters: Double?
    var highestElevationMeters: Double?
    var averagePaceSecondsPerKilometer: Double?
    var establishedAt: Date?
    var visibility: OutdoorActivityVisibility
    var starred: Bool
    var publicDescription: String
    var tags: [String]
    var allowComments: Bool
    var hideStartFinish: Bool
    var endpointPrivacyMeters: Int
    var showPlayerTracks: Bool
    var hasPublicMetadata: Bool
    var playedTracks: [OutdoorPlayedTrackEvent]

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, kind, title, startedAt, endedAt, elapsedSeconds, movingSeconds, distanceMeters
        case averageSpeedMetersPerSecond, maxSpeedMetersPerSecond, timeTargetSeconds, pauseIntervals, laps
        case trackPointCount, recordingState, finished, plannedRouteID, elevationGainMeters, highestElevationMeters
        case averagePaceSecondsPerKilometer, establishedAt, visibility, starred, publicDescription, tags
        case allowComments, hideStartFinish, endpointPrivacyMeters, showPlayerTracks, hasPublicMetadata
        case playedTracks
    }

    init(core: TimeMasterCore.OutdoorActivityManifest) throws {
        guard let id = UUID(uuidString: core.id) else { throw OutdoorActivityConversionError.invalidIdentifier(core.id) }
        self.init(
            id: id,
            schemaVersion: core.schemaVersion,
            kind: OutdoorActivityKind(core: core.kind),
            title: core.title,
            startedAt: core.startedAt,
            endedAt: core.endedAt,
            elapsedSeconds: core.elapsedSeconds,
            movingSeconds: core.movingSeconds,
            distanceMeters: core.distanceMeters,
            averageSpeedMetersPerSecond: core.averageSpeedMetersPerSecond,
            maxSpeedMetersPerSecond: core.maxSpeedMetersPerSecond,
            timeTargetSeconds: core.timeTargetSeconds,
            pauseIntervals: core.pauseIntervals.map(OutdoorPauseInterval.init),
            laps: core.laps.map(OutdoorLap.init),
            trackPointCount: core.trackPointCount,
            recordingState: OutdoorRecordingState(core: core.recordingState),
            finished: core.finished,
            plannedRouteID: core.plannedRouteID,
            elevationGainMeters: core.elevationGainMeters,
            highestElevationMeters: core.highestElevationMeters,
            averagePaceSecondsPerKilometer: core.averagePaceSecondsPerKilometer,
            establishedAt: core.establishedAt,
            visibility: core.visibility,
            starred: core.starred,
            publicDescription: core.publicDescription,
            tags: core.tags,
            allowComments: core.allowComments,
            hideStartFinish: core.hideStartFinish,
            endpointPrivacyMeters: core.endpointPrivacyMeters,
            showPlayerTracks: core.showPlayerTracks,
            hasPublicMetadata: core.hasPublicMetadata,
            playedTracks: core.playedTracks
        )
    }

    init(
        id: UUID = UUID(),
        schemaVersion: Int = TimeMasterCore.OutdoorActivityManifest.currentSchemaVersion,
        kind: OutdoorActivityKind,
        title: String? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        elapsedSeconds: Int = 0,
        movingSeconds: Int = 0,
        distanceMeters: Double = 0,
        averageSpeedMetersPerSecond: Double? = nil,
        maxSpeedMetersPerSecond: Double? = nil,
        timeTargetSeconds: Int? = nil,
        pauseIntervals: [OutdoorPauseInterval] = [],
        laps: [OutdoorLap] = [],
        trackPointCount: Int = 0,
        recordingState: OutdoorRecordingState = .recording,
        finished: Bool = false,
        plannedRouteID: String? = nil,
        elevationGainMeters: Double? = nil,
        highestElevationMeters: Double? = nil,
        averagePaceSecondsPerKilometer: Double? = nil,
        establishedAt: Date? = nil,
        visibility: OutdoorActivityVisibility = .privateVisibility,
        starred: Bool = false,
        publicDescription: String = "",
        tags: [String] = [],
        allowComments: Bool = true,
        hideStartFinish: Bool = true,
        endpointPrivacyMeters: Int = 200,
        showPlayerTracks: Bool = true,
        hasPublicMetadata: Bool = false,
        playedTracks: [OutdoorPlayedTrackEvent] = []
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
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
        self.elevationGainMeters = elevationGainMeters.map { max(0, $0) }
        self.highestElevationMeters = highestElevationMeters
        self.averagePaceSecondsPerKilometer = averagePaceSecondsPerKilometer.map { max(0, $0) }
        self.establishedAt = establishedAt
        self.visibility = visibility
        self.starred = starred
        self.publicDescription = publicDescription
        self.tags = tags
        self.allowComments = allowComments
        self.hideStartFinish = hideStartFinish
        self.endpointPrivacyMeters = TimeMasterCore.OutdoorActivityManifest.clampedEndpointPrivacyMeters(endpointPrivacyMeters)
        self.showPlayerTracks = showPlayerTracks
        self.hasPublicMetadata = hasPublicMetadata
        self.playedTracks = playedTracks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let startedAt = try c.decode(Date.self, forKey: .startedAt)
        let endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        let finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
        let establishedAt: Date?
        if version < TimeMasterCore.OutdoorActivityManifest.currentSchemaVersion && finished {
            establishedAt = endedAt ?? startedAt
        } else {
            establishedAt = try c.decodeIfPresent(Date.self, forKey: .establishedAt)
        }
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            schemaVersion: version,
            kind: try c.decode(OutdoorActivityKind.self, forKey: .kind),
            title: try c.decodeIfPresent(String.self, forKey: .title),
            startedAt: startedAt,
            endedAt: endedAt,
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
            finished: finished,
            plannedRouteID: try c.decodeIfPresent(String.self, forKey: .plannedRouteID),
            elevationGainMeters: try c.decodeIfPresent(Double.self, forKey: .elevationGainMeters),
            highestElevationMeters: try c.decodeIfPresent(Double.self, forKey: .highestElevationMeters),
            averagePaceSecondsPerKilometer: try c.decodeIfPresent(Double.self, forKey: .averagePaceSecondsPerKilometer),
            establishedAt: establishedAt,
            visibility: (try? c.decode(OutdoorActivityVisibility.self, forKey: .visibility)) ?? .privateVisibility,
            starred: try c.decodeIfPresent(Bool.self, forKey: .starred) ?? false,
            publicDescription: try c.decodeIfPresent(String.self, forKey: .publicDescription) ?? "",
            tags: try c.decodeIfPresent([String].self, forKey: .tags) ?? [],
            allowComments: try c.decodeIfPresent(Bool.self, forKey: .allowComments) ?? true,
            hideStartFinish: try c.decodeIfPresent(Bool.self, forKey: .hideStartFinish) ?? true,
            endpointPrivacyMeters: try c.decodeIfPresent(Int.self, forKey: .endpointPrivacyMeters) ?? 200,
            showPlayerTracks: try c.decodeIfPresent(Bool.self, forKey: .showPlayerTracks) ?? true,
            hasPublicMetadata: try c.decodeIfPresent(Bool.self, forKey: .hasPublicMetadata) ?? false,
            playedTracks: try c.decodeIfPresent([OutdoorPlayedTrackEvent].self, forKey: .playedTracks) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(kind, forKey: .kind)
        try c.encode(title, forKey: .title)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(endedAt, forKey: .endedAt)
        try c.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try c.encode(movingSeconds, forKey: .movingSeconds)
        try c.encode(distanceMeters, forKey: .distanceMeters)
        try c.encodeIfPresent(averageSpeedMetersPerSecond, forKey: .averageSpeedMetersPerSecond)
        try c.encodeIfPresent(maxSpeedMetersPerSecond, forKey: .maxSpeedMetersPerSecond)
        try c.encodeIfPresent(timeTargetSeconds, forKey: .timeTargetSeconds)
        try c.encode(pauseIntervals, forKey: .pauseIntervals)
        try c.encode(laps, forKey: .laps)
        try c.encode(trackPointCount, forKey: .trackPointCount)
        try c.encode(recordingState, forKey: .recordingState)
        try c.encode(finished, forKey: .finished)
        try c.encodeIfPresent(plannedRouteID, forKey: .plannedRouteID)
        try c.encodeIfPresent(elevationGainMeters, forKey: .elevationGainMeters)
        try c.encodeIfPresent(highestElevationMeters, forKey: .highestElevationMeters)
        try c.encodeIfPresent(averagePaceSecondsPerKilometer, forKey: .averagePaceSecondsPerKilometer)
        try c.encodeIfPresent(establishedAt, forKey: .establishedAt)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(starred, forKey: .starred)
        try c.encode(publicDescription, forKey: .publicDescription)
        try c.encode(tags, forKey: .tags)
        try c.encode(allowComments, forKey: .allowComments)
        try c.encode(hideStartFinish, forKey: .hideStartFinish)
        try c.encode(endpointPrivacyMeters, forKey: .endpointPrivacyMeters)
        try c.encode(showPlayerTracks, forKey: .showPlayerTracks)
        try c.encode(hasPublicMetadata, forKey: .hasPublicMetadata)
        try c.encode(playedTracks, forKey: .playedTracks)
    }

    var coreValue: TimeMasterCore.OutdoorActivityManifest {
        TimeMasterCore.OutdoorActivityManifest(
            id: id.uuidString,
            kind: kind.coreValue,
            title: title,
            startedAt: startedAt,
            endedAt: endedAt,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: movingSeconds,
            distanceMeters: distanceMeters,
            averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
            maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
            timeTargetSeconds: timeTargetSeconds,
            pauseIntervals: pauseIntervals.map(\.coreValue),
            laps: laps.map(\.coreValue),
            trackPointCount: trackPointCount,
            recordingState: recordingState.coreValue,
            finished: finished,
            plannedRouteID: plannedRouteID,
            schemaVersion: schemaVersion,
            elevationGainMeters: elevationGainMeters,
            highestElevationMeters: highestElevationMeters,
            averagePaceSecondsPerKilometer: averagePaceSecondsPerKilometer,
            establishedAt: establishedAt,
            visibility: visibility,
            starred: starred,
            publicDescription: publicDescription,
            tags: tags,
            allowComments: allowComments,
            hideStartFinish: hideStartFinish,
            endpointPrivacyMeters: endpointPrivacyMeters,
            showPlayerTracks: showPlayerTracks,
            hasPublicMetadata: hasPublicMetadata,
            playedTracks: playedTracks
        )
    }
}

enum OutdoorActivityConversionError: Error, LocalizedError {
    case invalidIdentifier(String)

    var errorDescription: String? {
        switch self { case .invalidIdentifier(let value): "Invalid outdoor activity identifier: \(value)" }
    }
}
