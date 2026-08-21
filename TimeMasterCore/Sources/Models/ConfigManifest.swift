import Foundation

public enum OutdoorUnitSystem: String, Codable, Equatable, CaseIterable {
    case metric
    case imperial
}

public enum OutdoorGPSAccuracy: String, Codable, Equatable, CaseIterable {
    case precise
    case balanced
}

public enum OutdoorElevationSource: String, Codable, Equatable, CaseIterable {
    case hybrid
    case gps
    case barometer
}

public enum OutdoorAudioCues: String, Codable, Equatable, CaseIterable {
    case off
    case quiet
    case normal
}

public enum OutdoorExportFormat: String, Codable, Equatable, CaseIterable {
    case gpx
    case fit
}

public struct OutdoorRecordingPreferences: Codable, Equatable {
    public var unitSystem: OutdoorUnitSystem
    public var autoPause: Bool
    public var keepScreenAwake: Bool
    public var gpsAccuracy: OutdoorGPSAccuracy
    public var elevationSource: OutdoorElevationSource
    public var speedSmoothing: Bool
    public var autoDownloadRouteArea: Bool
    public var weatherInfo: Bool
    public var audioCues: OutdoorAudioCues
    public var defaultVisibility: OutdoorActivityVisibility
    public var hideStartFinish: Bool
    public var endpointPrivacyMeters: Int
    public var allowComments: Bool
    public var showPlayerTracks: Bool
    public var haptics: Bool
    public var exportFormat: OutdoorExportFormat

    public init(
        unitSystem: OutdoorUnitSystem = .metric,
        autoPause: Bool = true,
        keepScreenAwake: Bool = false,
        gpsAccuracy: OutdoorGPSAccuracy = .precise,
        elevationSource: OutdoorElevationSource = .hybrid,
        speedSmoothing: Bool = true,
        autoDownloadRouteArea: Bool = false,
        weatherInfo: Bool = true,
        audioCues: OutdoorAudioCues = .quiet,
        defaultVisibility: OutdoorActivityVisibility = .privateVisibility,
        hideStartFinish: Bool = true,
        endpointPrivacyMeters: Int = 200,
        allowComments: Bool = true,
        showPlayerTracks: Bool = true,
        haptics: Bool = true,
        exportFormat: OutdoorExportFormat = .gpx
    ) {
        self.unitSystem = unitSystem
        self.autoPause = autoPause
        self.keepScreenAwake = keepScreenAwake
        self.gpsAccuracy = gpsAccuracy
        self.elevationSource = elevationSource
        self.speedSmoothing = speedSmoothing
        self.autoDownloadRouteArea = autoDownloadRouteArea
        self.weatherInfo = weatherInfo
        self.audioCues = audioCues
        self.defaultVisibility = defaultVisibility
        self.hideStartFinish = hideStartFinish
        self.endpointPrivacyMeters = OutdoorActivityManifest.clampedEndpointPrivacyMeters(endpointPrivacyMeters)
        self.allowComments = allowComments
        self.showPlayerTracks = showPlayerTracks
        self.haptics = haptics
        self.exportFormat = exportFormat
    }

    private enum CodingKeys: String, CodingKey {
        case unitSystem, autoPause, keepScreenAwake, gpsAccuracy, elevationSource, speedSmoothing
        case autoDownloadRouteArea, weatherInfo, audioCues, defaultVisibility, hideStartFinish
        case endpointPrivacyMeters, allowComments, showPlayerTracks, haptics, exportFormat
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            unitSystem: (try? c.decode(OutdoorUnitSystem.self, forKey: .unitSystem)) ?? .metric,
            autoPause: try c.decodeIfPresent(Bool.self, forKey: .autoPause) ?? true,
            keepScreenAwake: try c.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? false,
            gpsAccuracy: (try? c.decode(OutdoorGPSAccuracy.self, forKey: .gpsAccuracy)) ?? .precise,
            elevationSource: (try? c.decode(OutdoorElevationSource.self, forKey: .elevationSource)) ?? .hybrid,
            speedSmoothing: try c.decodeIfPresent(Bool.self, forKey: .speedSmoothing) ?? true,
            autoDownloadRouteArea: try c.decodeIfPresent(Bool.self, forKey: .autoDownloadRouteArea) ?? false,
            weatherInfo: try c.decodeIfPresent(Bool.self, forKey: .weatherInfo) ?? true,
            audioCues: (try? c.decode(OutdoorAudioCues.self, forKey: .audioCues)) ?? .quiet,
            defaultVisibility: (try? c.decode(OutdoorActivityVisibility.self, forKey: .defaultVisibility)) ?? .privateVisibility,
            hideStartFinish: try c.decodeIfPresent(Bool.self, forKey: .hideStartFinish) ?? true,
            endpointPrivacyMeters: try c.decodeIfPresent(Int.self, forKey: .endpointPrivacyMeters) ?? 200,
            allowComments: try c.decodeIfPresent(Bool.self, forKey: .allowComments) ?? true,
            showPlayerTracks: try c.decodeIfPresent(Bool.self, forKey: .showPlayerTracks) ?? true,
            haptics: try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true,
            exportFormat: (try? c.decode(OutdoorExportFormat.self, forKey: .exportFormat)) ?? .gpx
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(unitSystem, forKey: .unitSystem)
        try c.encode(autoPause, forKey: .autoPause)
        try c.encode(keepScreenAwake, forKey: .keepScreenAwake)
        try c.encode(gpsAccuracy, forKey: .gpsAccuracy)
        try c.encode(elevationSource, forKey: .elevationSource)
        try c.encode(speedSmoothing, forKey: .speedSmoothing)
        try c.encode(autoDownloadRouteArea, forKey: .autoDownloadRouteArea)
        try c.encode(weatherInfo, forKey: .weatherInfo)
        try c.encode(audioCues, forKey: .audioCues)
        try c.encode(defaultVisibility, forKey: .defaultVisibility)
        try c.encode(hideStartFinish, forKey: .hideStartFinish)
        try c.encode(endpointPrivacyMeters, forKey: .endpointPrivacyMeters)
        try c.encode(allowComments, forKey: .allowComments)
        try c.encode(showPlayerTracks, forKey: .showPlayerTracks)
        try c.encode(haptics, forKey: .haptics)
        try c.encode(exportFormat, forKey: .exportFormat)
    }
}

public struct TimeOfDayManifest: Codable, Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

public struct TypeScheduleManifest: Codable, Equatable {
    public var id: String
    public var folderID: String
    public var type: WorkoutType
    public var daysOfWeek: [Int]
    public var startDate: Date
    public var durationMonths: Int
    public var weeklyGoal: Int
    public var startTime: TimeOfDayManifest?
    public var durationMinutes: Int?
    public var endedAt: Date?

    public init(
        id: String = UUID().uuidString,
        folderID: String,
        type: WorkoutType,
        daysOfWeek: [Int] = [],
        startDate: Date = Date(),
        durationMonths: Int = 3,
        weeklyGoal: Int = 4,
        startTime: TimeOfDayManifest? = nil,
        durationMinutes: Int? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.folderID = folderID
        self.type = type
        self.daysOfWeek = daysOfWeek
        self.startDate = startDate
        self.durationMonths = durationMonths
        self.weeklyGoal = weeklyGoal
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.endedAt = endedAt
    }
}

public struct ConfigManifest: Codable, Equatable {
    public var customWorkoutTypes: [WorkoutType]
    public var weeklyGoal: Int
    public var restDays: [String]
    public var trainingDays: [Int]
    public var trainingStartDate: Date
    public var trainingDurationMonths: Int
    public var typeSchedules: [TypeScheduleManifest]
    public var outdoorRecording: OutdoorRecordingPreferences?

    public var kind: String { "config" }

    public init(
        customWorkoutTypes: [WorkoutType] = [],
        weeklyGoal: Int = 4,
        restDays: [String] = [],
        trainingDays: [Int] = [],
        trainingStartDate: Date = Date(),
        trainingDurationMonths: Int = 3,
        typeSchedules: [TypeScheduleManifest] = [],
        outdoorRecording: OutdoorRecordingPreferences? = nil
    ) {
        self.customWorkoutTypes = customWorkoutTypes
        self.weeklyGoal = max(1, min(7, weeklyGoal))
        self.restDays = restDays
        self.trainingDays = trainingDays
        self.trainingStartDate = trainingStartDate
        self.trainingDurationMonths = trainingDurationMonths
        self.typeSchedules = typeSchedules
        self.outdoorRecording = outdoorRecording
    }
 
    private enum CodingKeys: String, CodingKey {
        case customWorkoutTypes, weeklyGoal, restDays, trainingDays, trainingStartDate
        case trainingDurationMonths, typeSchedules, outdoorRecording
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            customWorkoutTypes: try c.decodeIfPresent([WorkoutType].self, forKey: .customWorkoutTypes) ?? [],
            weeklyGoal: try c.decodeIfPresent(Int.self, forKey: .weeklyGoal) ?? 4,
            restDays: try c.decodeIfPresent([String].self, forKey: .restDays) ?? [],
            trainingDays: try c.decodeIfPresent([Int].self, forKey: .trainingDays) ?? [],
            trainingStartDate: try c.decodeIfPresent(Date.self, forKey: .trainingStartDate) ?? Date(),
            trainingDurationMonths: try c.decodeIfPresent(Int.self, forKey: .trainingDurationMonths) ?? 3,
            typeSchedules: try c.decodeIfPresent([TypeScheduleManifest].self, forKey: .typeSchedules) ?? [],
            outdoorRecording: try c.decodeIfPresent(OutdoorRecordingPreferences.self, forKey: .outdoorRecording)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(customWorkoutTypes, forKey: .customWorkoutTypes)
        try c.encode(weeklyGoal, forKey: .weeklyGoal)
        try c.encode(restDays, forKey: .restDays)
        try c.encode(trainingDays, forKey: .trainingDays)
        try c.encode(trainingStartDate, forKey: .trainingStartDate)
        try c.encode(trainingDurationMonths, forKey: .trainingDurationMonths)
        try c.encode(typeSchedules, forKey: .typeSchedules)
        try c.encodeIfPresent(outdoorRecording, forKey: .outdoorRecording)
    }
}
