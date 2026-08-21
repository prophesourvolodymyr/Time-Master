import Foundation

public enum OutdoorActivityKind: String, Codable, Equatable {
    case run
    case walk
    case runWalk
    case bike

    public var defaultTitle: String {
        switch self {
        case .run: "Run"
        case .walk: "Walk"
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

public enum OutdoorActivityVisibility: String, Codable, Equatable {
    case privateVisibility = "private"
    case publicVisibility = "public"
}

public struct OutdoorTrackPoint: Codable, Equatable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var elevationMeters: Double?
    public var horizontalAccuracyMeters: Double
    public var verticalAccuracyMeters: Double?
    public var barometricRelativeAltitudeMeters: Double?
    public var speedMetersPerSecond: Double?
    public var state: OutdoorRecordingState

    public init(
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

public struct OutdoorPlayedTrackEvent: Codable, Equatable, Identifiable {
    public var id: String
    public var timestamp: Date
    public var trackID: String
    public var title: String
    public var artist: String?
    public var artworkReference: String?

    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        trackID: String,
        title: String,
        artist: String? = nil,
        artworkReference: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.artworkReference = artworkReference
    }
}


public struct OutdoorActivityManifest: Codable, Equatable, Identifiable {
    public static let currentSchemaVersion = 3

    public var id: String
    public var schemaVersion: Int
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
    public var elevationGainMeters: Double?
    public var highestElevationMeters: Double?
    public var averagePaceSecondsPerKilometer: Double?
    public var establishedAt: Date?
    public var visibility: OutdoorActivityVisibility
    public var starred: Bool
    public var publicDescription: String
    public var tags: [String]
    public var allowComments: Bool
    public var hideStartFinish: Bool
    public var endpointPrivacyMeters: Int
    public var showPlayerTracks: Bool
    public var hasPublicMetadata: Bool
    public var playedTracks: [OutdoorPlayedTrackEvent]

    public init(
        id: String = UUID().uuidString,
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
        schemaVersion: Int = OutdoorActivityManifest.currentSchemaVersion,
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
        self.endpointPrivacyMeters = Self.clampedEndpointPrivacyMeters(endpointPrivacyMeters)
        self.showPlayerTracks = showPlayerTracks
        self.hasPublicMetadata = hasPublicMetadata
        self.playedTracks = playedTracks
    }

    public static func clampedEndpointPrivacyMeters(_ value: Int) -> Int {
        let allowed = [100, 200, 500]
        return allowed.min {
            let leftDistance = abs($0 - value)
            let rightDistance = abs($1 - value)
            if leftDistance == rightDistance {
                return $0 > $1
            }
            return leftDistance < rightDistance
        } ?? 200
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, kind, title, startedAt, endedAt, elapsedSeconds, movingSeconds, distanceMeters
        case averageSpeedMetersPerSecond, maxSpeedMetersPerSecond, timeTargetSeconds, pauseIntervals, laps
        case trackPointCount, recordingState, finished, plannedRouteID, elevationGainMeters, highestElevationMeters
        case averagePaceSecondsPerKilometer, establishedAt, visibility, starred, publicDescription, tags
        case allowComments, hideStartFinish, endpointPrivacyMeters, showPlayerTracks, hasPublicMetadata
        case playedTracks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let isLegacy = decodedSchemaVersion < Self.currentSchemaVersion
        let finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
        let endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        let startedAt = try c.decode(Date.self, forKey: .startedAt)
        let establishedAt: Date?
        if isLegacy && finished {
            establishedAt = endedAt ?? startedAt
        } else {
            establishedAt = try c.decodeIfPresent(Date.self, forKey: .establishedAt)
        }

        self.init(
            id: try c.decode(String.self, forKey: .id),
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
            schemaVersion: decodedSchemaVersion,
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

    public func encode(to encoder: Encoder) throws {
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
}
