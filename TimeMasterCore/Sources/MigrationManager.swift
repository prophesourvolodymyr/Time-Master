import Foundation

public struct MigrationSummary {
    public let workoutsMigrated: Int
    public let exercisesMigrated: Int
    public let foldersMigrated: Int
    public let historyMigrated: Int
    public let configMigrated: Bool
    public let backupURL: URL?

    public var totalMigrated: Int {
        workoutsMigrated + exercisesMigrated + historyMigrated
    }

    public init(
        workoutsMigrated: Int = 0,
        exercisesMigrated: Int = 0,
        foldersMigrated: Int = 0,
        historyMigrated: Int = 0,
        configMigrated: Bool = false,
        backupURL: URL? = nil
    ) {
        self.workoutsMigrated = workoutsMigrated
        self.exercisesMigrated = exercisesMigrated
        self.foldersMigrated = foldersMigrated
        self.historyMigrated = historyMigrated
        self.configMigrated = configMigrated
        self.backupURL = backupURL
    }
}

public struct MigratableWorkout: Codable {
    public var id: String
    public var name: String
    public var type: MigratableWorkoutType
    public var sections: [MigratableSection]
    public var createdAt: Date
    public var restBetweenSections: Int
    public var colorHex: String
    public var imageFilename: String?
    public var musicTrackFilenames: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, type, sections, createdAt, restBetweenSections, colorHex, imageFilename, musicTrackFilenames
    }
}

public struct MigratableWorkoutType: Codable {
    public var id: String
    public var name: String
    public var iconName: String?
    public var colorHex: String?

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            id = (try? container.decode(String.self, forKey: .id)) ?? ""
            name = (try? container.decode(String.self, forKey: .name)) ?? id
            iconName = try? container.decode(String.self, forKey: .iconName)
            colorHex = try? container.decode(String.self, forKey: .colorHex)
            return
        }
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        id = rawValue
        name = rawValue
        iconName = nil
        colorHex = nil
    }

    enum CodingKeys: String, CodingKey { case id, name, iconName, colorHex }
}

public struct MigratableSection: Codable {
    public var name: String
    public var duration: Int
    public var sets: Int?
    public var restBetweenSets: Int?
    public var prepareTime: Int?
    public var customRestAfter: Int?
    public var isTimerEnabled: Bool?
    public var mediaFilenames: [String]

    enum CodingKeys: String, CodingKey {
        case name, duration, sets, restBetweenSets, prepareTime, customRestAfter, restAfter
        case isTimerEnabled, mediaItems, photoFilenames, photoFilename
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 30
        sets = try c.decodeIfPresent(Int.self, forKey: .sets)
        restBetweenSets = try c.decodeIfPresent(Int.self, forKey: .restBetweenSets)
        prepareTime = try c.decodeIfPresent(Int.self, forKey: .prepareTime)
        if let v = try c.decodeIfPresent(Int.self, forKey: .customRestAfter) {
            customRestAfter = v
        } else if let v = try c.decodeIfPresent(Int.self, forKey: .restAfter), v > 0 {
            customRestAfter = v
        } else {
            customRestAfter = nil
        }
        isTimerEnabled = try c.decodeIfPresent(Bool.self, forKey: .isTimerEnabled)

        if let items = try c.decodeIfPresent([MigratableMediaItem].self, forKey: .mediaItems) {
            mediaFilenames = items.map { $0.filename }
        } else if let filenames = try c.decodeIfPresent([String].self, forKey: .photoFilenames) {
            mediaFilenames = filenames
        } else if let single = try c.decodeIfPresent(String.self, forKey: .photoFilename) {
            mediaFilenames = [single]
        } else {
            mediaFilenames = []
        }
    }

    public func encode(to encoder: Encoder) throws {}

    struct MigratableMediaItem: Codable {
        var filename: String
    }
}

public struct MigratableHistoryEntry: Codable {
    public var id: String
    public var workoutId: String
    public var workoutName: String
    public var completedAt: Date
    public var durationCompleted: Int
    public var workoutType: MigratableWorkoutType?
    public var isPartial: Bool?
    public var elapsedSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, completedAt, durationCompleted, workoutType, isPartial, elapsedSeconds
    }
}

public struct MigratableExercise: Codable {
    public var id: String
    public var name: String
    public var details: String?
    public var duration: Int?
    public var restAfter: Int?
    public var mediaFilenames: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, details, duration, restAfter, mediaItems, photoFilenames, photoFilename
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        name = try c.decode(String.self, forKey: .name)
        details = try c.decodeIfPresent(String.self, forKey: .details)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        restAfter = try c.decodeIfPresent(Int.self, forKey: .restAfter)
        if let items = try c.decodeIfPresent([MigratableMediaItem].self, forKey: .mediaItems) {
            mediaFilenames = items.map { $0.filename }
        } else if let filenames = try c.decodeIfPresent([String].self, forKey: .photoFilenames) {
            mediaFilenames = filenames
        } else if let single = try c.decodeIfPresent(String.self, forKey: .photoFilename) {
            mediaFilenames = [single]
        } else {
            mediaFilenames = []
        }
    }

    public func encode(to encoder: Encoder) throws {}

    struct MigratableMediaItem: Codable {
        var filename: String
    }
}

public struct MigratableExerciseFolder: Codable {
    public var id: String?
    public var name: String
    public var colorHex: String?
    public var workoutType: MigratableWorkoutType?
    public var subfolders: [MigratableExerciseFolder]
    public var exercises: [MigratableExercise]

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, workoutType, subfolders, exercises
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        workoutType = try c.decodeIfPresent(MigratableWorkoutType.self, forKey: .workoutType)
        subfolders = try c.decodeIfPresent([MigratableExerciseFolder].self, forKey: .subfolders) ?? []
        exercises = try c.decodeIfPresent([MigratableExercise].self, forKey: .exercises) ?? []
    }

    public func encode(to encoder: Encoder) throws {}
}

public final class MigrationManager {
    private let db: DatabaseManager
    private let fs: FileSystemHelper
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private static let migrationMarkerName = ".migration_complete"

    public var isComplete: Bool {
        let markerURL = fs.configDirectory.appendingPathComponent(Self.migrationMarkerName)
        return fs.fileExists(at: markerURL)
    }

    public static var isMigrationComplete: Bool {
        let fs = FileSystemHelper(dataRoot: DatabaseManager.shared.dataRoot)
        let markerURL = fs.configDirectory.appendingPathComponent(migrationMarkerName)
        return fs.fileExists(at: markerURL)
    }

    public init(db: DatabaseManager) {
        self.db = db
        self.fs = FileSystemHelper(dataRoot: db.dataRoot)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted]
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func migrateFromUserDefaults() throws -> MigrationSummary {
        guard !isComplete else {
            return MigrationSummary()
        }

        let ud = UserDefaults.standard
        let udDecoder = JSONDecoder()

        let workoutsData = ud.data(forKey: "workouts")
        let historyData = ud.data(forKey: "workout_history")
        let foldersData = ud.data(forKey: "exercise_database_v2")
        let rootExercisesData = ud.data(forKey: "exercise_database_root_exercises_v1")
        let customTypesData = ud.data(forKey: "custom_workout_types")
        let restDaysData = ud.data(forKey: "workout_rest_days")
        let weeklyGoalData = ud.data(forKey: "workout_weekly_goal")
        let trainingDaysData = ud.data(forKey: "training_days")
        let trainingStartInterval = ud.double(forKey: "training_start_date")
        let trainingDuration = ud.integer(forKey: "training_duration_months")
        let typeSchedulesData = ud.data(forKey: "workout_type_schedules")

        let trainingStartValue: Double? = trainingStartInterval > 0 ? trainingStartInterval : nil
        let trainingDurationValue: Int? = trainingDuration > 0 ? trainingDuration : nil

        let summary = try migrateFrom(
            workoutsData: workoutsData,
            historyData: historyData,
            foldersData: foldersData,
            rootExercisesData: rootExercisesData,
            customTypesData: customTypesData,
            restDaysData: restDaysData,
            weeklyGoalData: weeklyGoalData,
            trainingDaysData: trainingDaysData,
            trainingStartInterval: trainingStartValue,
            trainingDuration: trainingDurationValue,
            typeSchedulesData: typeSchedulesData,
            decoder: udDecoder
        )

        try markMigrationComplete()
        return summary
    }

    @discardableResult
    public static func migrateIfNeeded() -> MigrationSummary? {
        guard !isMigrationComplete else { return nil }
        let manager = MigrationManager(db: DatabaseManager.shared)
        return try? manager.migrateFromUserDefaults()
    }

    private func markMigrationComplete() throws {
        let markerURL = fs.configDirectory.appendingPathComponent(Self.migrationMarkerName)
        let content = "\(Int(Date().timeIntervalSince1970))"
        try fs.writeAtomically(to: markerURL, data: content.data(using: .utf8)!)
    }

    @discardableResult
    public func migrateFrom(
        workoutsData: Data?,
        historyData: Data?,
        foldersData: Data?,
        rootExercisesData: Data?,
        customTypesData: Data?,
        restDaysData: Data?,
        weeklyGoalData: Data?,
        trainingDaysData: Data?,
        trainingStartInterval: Double?,
        trainingDuration: Int?,
        typeSchedulesData: Data?,
        decoder: JSONDecoder? = nil
    ) throws -> MigrationSummary {
        let activeDecoder = decoder ?? self.decoder
        try db.bootstrapIfNeeded()

        let backupTimestamp = Int(Date().timeIntervalSince1970)
        let backupURL = fs.backupsDirectory.appendingPathComponent("migration-\(backupTimestamp).json")

        var backupDict: [String: Any] = [:]

        if let data = workoutsData {
            backupDict["workouts"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = historyData {
            backupDict["history"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = foldersData {
            backupDict["folders"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = rootExercisesData {
            backupDict["rootExercises"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = customTypesData {
            backupDict["customTypes"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = restDaysData {
            backupDict["restDays"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = weeklyGoalData {
            if let obj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) {
                backupDict["weeklyGoal"] = obj
            }
        }
        if let data = trainingDaysData {
            backupDict["trainingDays"] = try JSONSerialization.jsonObject(with: data)
        }
        if let data = typeSchedulesData {
            backupDict["typeSchedules"] = try JSONSerialization.jsonObject(with: data)
        }
        if let ts = trainingStartInterval {
            backupDict["trainingStartInterval"] = ts
        }
        if let dur = trainingDuration {
            backupDict["trainingDurationMonths"] = dur
        }

        let backupData = try JSONSerialization.data(withJSONObject: backupDict, options: .prettyPrinted)
        try fs.writeAtomically(to: backupURL, data: backupData)

        var workoutsMigrated = 0
        if let data = workoutsData {
            let workouts = try activeDecoder.decode([MigratableWorkout].self, from: data)
            for w in workouts {
                let id = w.id
                let type = WorkoutType(
                    id: w.type.id,
                    name: w.type.name,
                    iconName: w.type.iconName ?? "star.fill",
                    colorHex: w.type.colorHex ?? "FFFFFF"
                )
                let sections: [WorkoutSectionManifest] = w.sections.map { s in
                    WorkoutSectionManifest(
                        exerciseID: "",
                        name: s.name,
                        duration: s.duration,
                        sets: s.sets ?? 1,
                        restBetweenSets: s.restBetweenSets ?? 10,
                        prepareTime: s.prepareTime ?? 4,
                        customRestAfter: s.customRestAfter,
                        isTimerEnabled: s.isTimerEnabled ?? true,
                        mediaFilenames: s.mediaFilenames
                    )
                }
                let manifest = WorkoutManifest(
                    id: id,
                    name: w.name,
                    type: type,
                    sections: sections,
                    musicTrackFilenames: w.musicTrackFilenames,
                    colorHex: w.colorHex,
                    createdAt: w.createdAt,
                    restBetweenSections: w.restBetweenSections,
                    imageFilename: w.imageFilename
                )
                try db.createWorkout(id: id, manifest: manifest)
                workoutsMigrated += 1
            }
        }

        var exercisesMigrated = 0
        var foldersMigrated = 0

        func migrateFolders(_ folders: [MigratableExerciseFolder], parentPath: String?) throws {
            for folder in folders {
                let folderName = folder.name.replacingOccurrences(of: "/", with: "-")
                let path = parentPath.map { "\($0)/\(folderName)" } ?? folderName
                _ = try db.createFolder(name: folderName, parentPath: parentPath)
                foldersMigrated += 1

                for exercise in folder.exercises {
                    let exID = exercise.id.isEmpty ? UUID().uuidString : exercise.id
                    let type: WorkoutType? = {
                        if let wt = folder.workoutType {
                            return WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName ?? "star.fill", colorHex: wt.colorHex ?? "FFFFFF")
                        }
                        return nil
                    }()
                    let manifest = ExerciseManifest(
                        id: exID,
                        name: exercise.name,
                        details: exercise.details ?? "",
                        duration: exercise.duration ?? 30,
                        restAfter: exercise.restAfter ?? 10,
                        workoutType: type,
                        mediaFilenames: exercise.mediaFilenames
                    )
                    try db.createExercise(id: exID, manifest: manifest, parentPath: path)
                    exercisesMigrated += 1
                }

                try migrateFolders(folder.subfolders, parentPath: path)
            }
        }

        if let data = foldersData {
            let rootFolders = try activeDecoder.decode([MigratableExerciseFolder].self, from: data)
            try migrateFolders(rootFolders, parentPath: nil)
        }

        if let data = rootExercisesData {
            let exercises = try activeDecoder.decode([MigratableExercise].self, from: data)
            for ex in exercises {
                let exID = ex.id.isEmpty ? UUID().uuidString : ex.id
                let manifest = ExerciseManifest(
                    id: exID,
                    name: ex.name,
                    details: ex.details ?? "",
                    duration: ex.duration ?? 30,
                    restAfter: ex.restAfter ?? 10,
                    mediaFilenames: ex.mediaFilenames
                )
                try db.createExercise(id: exID, manifest: manifest)
                exercisesMigrated += 1
            }
        }

        var historyMigrated = 0
        if let data = historyData {
            let entries = try activeDecoder.decode([MigratableHistoryEntry].self, from: data)
            for entry in entries {
                let historyEntry = HistoryEntry(
                    id: entry.id.isEmpty ? UUID().uuidString : entry.id,
                    workoutId: entry.workoutId,
                    workoutName: entry.workoutName,
                    completedAt: entry.completedAt,
                    durationCompleted: entry.durationCompleted,
                    workoutType: {
                        if let wt = entry.workoutType {
                            return WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName ?? "star.fill", colorHex: wt.colorHex ?? "FFFFFF")
                        }
                        return .other
                    }(),
                    isPartial: entry.isPartial ?? false,
                    elapsedSeconds: entry.elapsedSeconds ?? 0
                )
                try db.appendHistoryEntry(historyEntry)
                historyMigrated += 1
            }
        }

        var configMigrated = false
        var customTypes: [WorkoutType] = []
        if let data = customTypesData {
            let legacyTypes = try activeDecoder.decode([MigratableWorkoutType].self, from: data)
            customTypes = legacyTypes.map {
                WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName ?? "star.fill", colorHex: $0.colorHex ?? "FFFFFF")
            }
        }

        var restDays: [String] = []
        if let data = restDaysData {
            restDays = (try? activeDecoder.decode([String].self, from: data)) ?? []
        }

        var weeklyGoal = 4
        if let data = weeklyGoalData {
            weeklyGoal = (try? activeDecoder.decode(Int.self, from: data)) ?? 4
        }

        var trainingDays: [Int] = []
        if let data = trainingDaysData {
            trainingDays = (try? activeDecoder.decode([Int].self, from: data)) ?? []
        }

        let startDate = trainingStartInterval.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let duration = trainingDuration ?? 3

        var typeSchedules: [TypeScheduleManifest] = []
        if let data = typeSchedulesData {
            let legacy = try activeDecoder.decode([MigratableTypeSchedule].self, from: data)
            typeSchedules = legacy.map {
                TypeScheduleManifest(
                    id: $0.id ?? UUID().uuidString,
                    folderID: $0.folderID ?? "",
                    type: WorkoutType(id: $0.type.id, name: $0.type.name, iconName: $0.type.iconName ?? "star.fill", colorHex: $0.type.colorHex ?? "FFFFFF"),
                    daysOfWeek: $0.daysOfWeek ?? $0.daysOfWeekRaw ?? [],
                    startDate: $0.startDate ?? Date(),
                    durationMonths: $0.durationMonths ?? 3,
                    weeklyGoal: $0.weeklyGoal ?? 4
                )
            }
        }

        let config = ConfigManifest(
            customWorkoutTypes: customTypes,
            weeklyGoal: weeklyGoal,
            restDays: restDays,
            trainingDays: trainingDays,
            trainingStartDate: startDate,
            trainingDurationMonths: duration,
            typeSchedules: typeSchedules
        )
        try db.saveConfig(config)
        configMigrated = true

        return MigrationSummary(
            workoutsMigrated: workoutsMigrated,
            exercisesMigrated: exercisesMigrated,
            foldersMigrated: foldersMigrated,
            historyMigrated: historyMigrated,
            configMigrated: configMigrated,
            backupURL: backupURL
        )
    }
}

private struct MigratableTypeSchedule: Codable {
    var id: String?
    var folderID: String?
    var type: MigratableWorkoutType
    var daysOfWeek: [Int]?
    var daysOfWeekRaw: [Int]?
    var startDate: Date?
    var durationMonths: Int?
    var weeklyGoal: Int?

    enum CodingKeys: String, CodingKey {
        case id, folderID, type, daysOfWeek, startDate, durationMonths, weeklyGoal
    }
}
