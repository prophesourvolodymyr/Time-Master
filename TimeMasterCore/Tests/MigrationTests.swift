import XCTest
@testable import TimeMasterCore

private struct SeedWorkoutType: Codable {
    var id: String
    var name: String
    var iconName: String
    var colorHex: String
}

private struct SeedSection: Codable {
    var id: String
    var name: String
    var duration: Int
    var isTimerEnabled: Bool
    var sets: Int
    var restBetweenSets: Int
    var prepareTime: Int
    var customRestAfter: Int?
    var photoFilenames: [String]
}

private struct SeedWorkout: Codable {
    var id: String
    var name: String
    var type: SeedWorkoutType
    var sections: [SeedSection]
    var createdAt: TimeInterval
    var restBetweenSections: Int
    var colorHex: String
    var imageFilename: String?
    var musicTrackFilenames: [String]
}

private struct SeedHistoryEntry: Codable {
    var id: String
    var workoutId: String
    var workoutName: String
    var completedAt: TimeInterval
    var durationCompleted: Int
    var workoutType: SeedWorkoutType
    var isPartial: Bool
    var elapsedSeconds: Int
}

private struct SeedFolder: Codable {
    var id: String
    var name: String
    var colorHex: String
    var workoutType: SeedWorkoutType?
    var subfolders: [SeedFolder]
    var exercises: [SeedExercise]
    var notes: [SeedNote]
}

private struct SeedExercise: Codable {
    var id: String
    var name: String
    var details: String
    var duration: Int
    var restAfter: Int
    var photoFilenames: [String]
}

private struct SeedNote: Codable {
    var id: String
    var title: String
    var body: String
    var createdAt: TimeInterval
}

private struct SeedSchedule: Codable {
    var id: String
    var folderID: String
    var type: SeedWorkoutType
    var daysOfWeek: [Int]
    var startDate: TimeInterval
    var durationMonths: Int
    var weeklyGoal: Int
}

final class MigrationTests: XCTestCase {
    var db: DatabaseManager!
    var fs: FileSystemHelper!
    var tempDir: URL!
    var migrationManager: MigrationManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fs = FileSystemHelper(dataRoot: tempDir)
        db = DatabaseManager(fs: fs)
        migrationManager = MigrationManager(db: db)

        let keys = ["workouts", "workout_history", "exercise_database_v2",
                     "exercise_database_root_exercises_v1", "exercise_database_root_notes_v1",
                     "custom_workout_types", "workout_rest_days", "workout_weekly_goal",
                     "workout_type_schedules", "training_days", "training_start_date",
                     "training_duration_months"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.timemaster.tests")
        super.tearDown()
    }

    // MARK: - Helper: write test data to UserDefaults

    private func seedWorkoutData() {
        let now = Date().timeIntervalSinceReferenceDate
        let type = SeedWorkoutType(id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55")
        let section = SeedSection(
            id: UUID().uuidString,
            name: "Jump Squats",
            duration: 60,
            isTimerEnabled: true,
            sets: 1,
            restBetweenSets: 10,
            prepareTime: 4,
            customRestAfter: nil,
            photoFilenames: ["photo1.jpg"]
        )
        let workout = SeedWorkout(
            id: UUID().uuidString,
            name: "Test HIIT",
            type: type,
            sections: [section],
            createdAt: now,
            restBetweenSections: 30,
            colorHex: "FFFFFF",
            imageFilename: nil,
            musicTrackFilenames: ["track1.mp3"]
        )
        let data = try! JSONEncoder().encode([workout])
        UserDefaults.standard.set(data, forKey: "workouts")
    }

    private func seedHistoryData() {
        let now = Date().timeIntervalSinceReferenceDate
        let type = SeedWorkoutType(id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55")
        let entry = SeedHistoryEntry(
            id: UUID().uuidString,
            workoutId: UUID().uuidString,
            workoutName: "Test HIIT",
            completedAt: now,
            durationCompleted: 1200,
            workoutType: type,
            isPartial: false,
            elapsedSeconds: 0
        )
        let data = try! JSONEncoder().encode([entry])
        UserDefaults.standard.set(data, forKey: "workout_history")
    }

    private func seedFolderData() {
        let ex = SeedExercise(
            id: UUID().uuidString,
            name: "Push-ups",
            details: "Keep core tight",
            duration: 30,
            restAfter: 10,
            photoFilenames: []
        )
        let folder = SeedFolder(
            id: UUID().uuidString,
            name: "Upper Body",
            colorHex: "FFFFFF",
            workoutType: nil,
            subfolders: [],
            exercises: [ex],
            notes: []
        )
        let data = try! JSONEncoder().encode([folder])
        UserDefaults.standard.set(data, forKey: "exercise_database_v2")
    }

    private func seedCustomTypesData() {
        let t = SeedWorkoutType(id: "Calisthenics", name: "Calisthenics", iconName: "figure.strengthtraining.traditional", colorHex: "FF9500")
        let data = try! JSONEncoder().encode([t])
        UserDefaults.standard.set(data, forKey: "custom_workout_types")
    }

    private func seedConfigData() {
        UserDefaults.standard.set(try! JSONEncoder().encode(["2025-07-04"]), forKey: "workout_rest_days")
        UserDefaults.standard.set(try! JSONEncoder().encode(5), forKey: "workout_weekly_goal")
        UserDefaults.standard.set(try! JSONEncoder().encode([1, 3, 5]), forKey: "training_days")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "training_start_date")
        UserDefaults.standard.set(3, forKey: "training_duration_months")

        let now = Date().timeIntervalSinceReferenceDate
        let scheduleType = SeedWorkoutType(id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55")
        let schedule = SeedSchedule(
            id: UUID().uuidString,
            folderID: UUID().uuidString,
            type: scheduleType,
            daysOfWeek: [1, 3],
            startDate: now,
            durationMonths: 3,
            weeklyGoal: 4
        )
        let data = try! JSONEncoder().encode([schedule])
        UserDefaults.standard.set(data, forKey: "workout_type_schedules")
    }

    // MARK: - Tests

    func testMigrationMarkerInitiallyFalse() {
        XCTAssertFalse(migrationManager.isComplete)
    }

    func testMigrationFromEmptyDefaultsProducesZeroSummary() throws {
        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.workoutsMigrated, 0)
        XCTAssertEqual(summary.exercisesMigrated, 0)
        XCTAssertEqual(summary.historyMigrated, 0)
        XCTAssertEqual(summary.foldersMigrated, 0)
        XCTAssertTrue(summary.configMigrated)
    }

    func testMigrationMarkerSetAfterMigration() throws {
        try migrationManager.migrateFromUserDefaults()
        let markerURL = fs.configDirectory.appendingPathComponent(".migration_complete")
        XCTAssertTrue(fs.fileExists(at: markerURL))
    }

    func testMigrationNotRerunWhenMarkerExists() throws {
        try migrationManager.migrateFromUserDefaults()
        let markerURL = fs.configDirectory.appendingPathComponent(".migration_complete")
        XCTAssertTrue(fs.fileExists(at: markerURL))
        XCTAssertTrue(migrationManager.isComplete)
    }

    func testMigrateFromUserDefaultsSkipsWhenComplete() throws {
        seedWorkoutData()
        try migrationManager.migrateFromUserDefaults()

        seedWorkoutData()
        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.workoutsMigrated, 0)
    }

    func testWorkoutMigration() throws {
        seedWorkoutData()

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.workoutsMigrated, 1)

        let workouts = try db.listWorkouts()
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].name, "Test HIIT")
        XCTAssertEqual(workouts[0].type.id, "HIIT")
        XCTAssertEqual(workouts[0].sections.count, 1)
        XCTAssertEqual(workouts[0].sections[0].name, "Jump Squats")
        XCTAssertEqual(workouts[0].sections[0].duration, 60)
        XCTAssertEqual(workouts[0].sections[0].mediaFilenames, ["photo1.jpg"])
        XCTAssertEqual(workouts[0].musicTrackFilenames, ["track1.mp3"])
        XCTAssertEqual(workouts[0].restBetweenSections, 30)
        XCTAssertEqual(workouts[0].colorHex, "FFFFFF")

        let workoutDir = fs.workoutsDirectory.appendingPathComponent(workouts[0].id)
        XCTAssertTrue(fs.directoryExists(at: workoutDir))
        let manifestURL = workoutDir.appendingPathComponent("manifest.json")
        XCTAssertTrue(fs.fileExists(at: manifestURL))
    }

    func testHistoryMigration() throws {
        seedHistoryData()

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.historyMigrated, 1)

        let entries = try db.readHistory()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].workoutName, "Test HIIT")
        XCTAssertEqual(entries[0].durationCompleted, 1200)
        XCTAssertEqual(entries[0].workoutType.id, "HIIT")
        XCTAssertFalse(entries[0].isPartial)
    }

    func testFolderAndExerciseMigration() throws {
        seedFolderData()

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.foldersMigrated, 1)
        XCTAssertEqual(summary.exercisesMigrated, 1)

        let folders = try db.listFolders(parentPath: nil)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders[0].name, "Upper Body")

        let exercises = try db.searchAllExercises()
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises[0].name, "Push-ups")
        XCTAssertEqual(exercises[0].details, "Keep core tight")
        XCTAssertEqual(exercises[0].duration, 30)
        XCTAssertEqual(exercises[0].restAfter, 10)
    }

    func testConfigMigration() throws {
        seedCustomTypesData()
        seedConfigData()

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertTrue(summary.configMigrated)

        let config = try db.loadConfig()
        XCTAssertEqual(config.weeklyGoal, 5)
        XCTAssertEqual(config.customWorkoutTypes.count, 1)
        XCTAssertEqual(config.customWorkoutTypes[0].name, "Calisthenics")
        XCTAssertEqual(config.restDays, ["2025-07-04"])
        XCTAssertEqual(config.trainingDays, [1, 3, 5])
        XCTAssertEqual(config.typeSchedules.count, 1)
        XCTAssertEqual(config.typeSchedules[0].type.id, "HIIT")
        XCTAssertEqual(config.typeSchedules[0].daysOfWeek, [1, 3])
    }

    func testBackupCreatedDuringMigration() throws {
        seedWorkoutData()

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertNotNil(summary.backupURL)
        XCTAssertTrue(fs.fileExists(at: summary.backupURL!))
    }

    func testMigrationFromUserDefaultsIdempotent() throws {
        seedWorkoutData()
        seedHistoryData()
        seedFolderData()

        try migrationManager.migrateFromUserDefaults()

        let workoutCount = try db.listWorkouts().count
        let historyCount = try db.readHistory().count

        XCTAssertEqual(workoutCount, 1)
        XCTAssertEqual(historyCount, 1)
    }

    func testMigrationHandlesMissingKeys() throws {
        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertEqual(summary.workoutsMigrated, 0)
        XCTAssertEqual(summary.historyMigrated, 0)
        XCTAssertEqual(summary.exercisesMigrated, 0)
        XCTAssertTrue(summary.configMigrated)
    }

    func testTypeSchedulesMigration() throws {
        let now = Date().timeIntervalSinceReferenceDate
        let scheduleDict: [String: Any] = [
            "id": UUID().uuidString,
            "folderID": UUID().uuidString,
            "type": ["id": "Strength", "name": "Strength", "iconName": "dumbbell.fill", "colorHex": "FF9500"],
            "daysOfWeek": [2, 4],
            "startDate": now,
            "durationMonths": 6,
            "weeklyGoal": 3,
        ]
        let schedulesData = try! JSONSerialization.data(withJSONObject: [scheduleDict])
        UserDefaults.standard.set(schedulesData, forKey: "workout_type_schedules")

        let summary = try migrationManager.migrateFromUserDefaults()
        XCTAssertTrue(summary.configMigrated)

        let config = try db.loadConfig()
        XCTAssertEqual(config.typeSchedules.count, 1)
        XCTAssertEqual(config.typeSchedules[0].type.id, "Strength")
        XCTAssertEqual(config.typeSchedules[0].daysOfWeek, [2, 4])
        XCTAssertEqual(config.typeSchedules[0].durationMonths, 6)
        XCTAssertEqual(config.typeSchedules[0].weeklyGoal, 3)
    }

    func testWorkoutSectionWithCustomRest() throws {
        let now = Date().timeIntervalSinceReferenceDate
        let sectionDict: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Burpees",
            "duration": 45,
            "isTimerEnabled": true,
            "sets": 3,
            "restBetweenSets": 15,
            "prepareTime": 5,
            "customRestAfter": 20,
            "photoFilenames": [],
        ]
        let workoutDict: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Custom Rest Workout",
            "type": ["id": "HIIT", "name": "HIIT", "iconName": "flame.fill", "colorHex": "FF2D55"],
            "sections": [sectionDict],
            "createdAt": now,
            "restBetweenSections": 20,
            "colorHex": "FFFFFF",
            "musicTrackFilenames": [],
        ]
        let workoutsData = try! JSONSerialization.data(withJSONObject: [workoutDict])
        UserDefaults.standard.set(workoutsData, forKey: "workouts")

        try migrationManager.migrateFromUserDefaults()

        let workouts = try db.listWorkouts()
        XCTAssertEqual(workouts.count, 1)
        let section = workouts[0].sections[0]
        XCTAssertEqual(section.sets, 3)
        XCTAssertEqual(section.restBetweenSets, 15)
        XCTAssertEqual(section.prepareTime, 5)
        XCTAssertEqual(section.customRestAfter, 20)
    }
}
