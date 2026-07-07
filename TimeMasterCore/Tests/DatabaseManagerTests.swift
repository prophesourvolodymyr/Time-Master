import XCTest
@testable import TimeMasterCore

final class DatabaseManagerTests: XCTestCase {
    var db: DatabaseManager!
    var fs: FileSystemHelper!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fs = FileSystemHelper(dataRoot: tempDir)
        db = DatabaseManager(fs: fs)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testBootstrapCreatesAllDirectories() throws {
        let root = try db.bootstrapIfNeeded()
        XCTAssertTrue(fs.directoryExists(at: root))
        XCTAssertTrue(fs.directoryExists(at: fs.exercisesDatabaseDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.workoutsDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.mediaDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.workspaceDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.knowledgeDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.skillsDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.configDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.historyDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.musicDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.backupsDirectory))
        XCTAssertTrue(fs.directoryExists(at: fs.trashDirectory))
        XCTAssertTrue(fs.fileExists(at: fs.schemaURL))
        XCTAssertTrue(fs.fileExists(at: fs.agentsURL))
        XCTAssertTrue(fs.fileExists(at: fs.skillsDirectory.appendingPathComponent("create-exercise.md")))
        XCTAssertTrue(fs.fileExists(at: fs.skillsDirectory.appendingPathComponent("build-workout.md")))
        XCTAssertTrue(fs.fileExists(at: fs.skillsDirectory.appendingPathComponent("search-database.md")))
        XCTAssertTrue(fs.fileExists(at: fs.knowledgeDirectory.appendingPathComponent("fitness-philosophy.md")))
        XCTAssertTrue(fs.fileExists(at: fs.knowledgeDirectory.appendingPathComponent("nutrition-rules.md")))
        XCTAssertTrue(fs.fileExists(at: fs.knowledgeDirectory.appendingPathComponent("recovery-protocols.md")))
    }

    func testBootstrapAgentsContent() throws {
        try db.bootstrapIfNeeded()
        let data = try fs.readRawData(from: fs.agentsURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(content.contains("TimeMaster Data Directory"))
        XCTAssertTrue(content.contains("schema.json"))
        XCTAssertTrue(content.contains("timemaster-tool"))
        XCTAssertTrue(content.contains("Workspace"))
        XCTAssertTrue(content.contains("Exercises Database"))
        XCTAssertTrue(content.contains("create-exercise"))
        XCTAssertTrue(content.contains("search-exercises"))
        XCTAssertTrue(content.contains("skills/"))
    }

    func testBootstrapKnowledgeFilesHaveContent() throws {
        try db.bootstrapIfNeeded()
        let healthURL = fs.knowledgeDirectory.appendingPathComponent("fitness-philosophy.md")
        let data = try fs.readRawData(from: healthURL)
        let content = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(content.contains("# Fitness Philosophy"))
    }

    func testBootstrapDoesNotOverwriteExistingFiles() throws {
        try db.bootstrapIfNeeded()

        let agentsData = try fs.readRawData(from: fs.agentsURL)
        let skillData = try fs.readRawData(from: fs.skillsDirectory.appendingPathComponent("create-exercise.md"))

        try db.bootstrapIfNeeded()

        let agentsData2 = try fs.readRawData(from: fs.agentsURL)
        let skillData2 = try fs.readRawData(from: fs.skillsDirectory.appendingPathComponent("create-exercise.md"))

        XCTAssertEqual(agentsData, agentsData2)
        XCTAssertEqual(skillData, skillData2)
    }

    func testBootstrapIdempotent() throws {
        try db.bootstrapIfNeeded()
        try db.bootstrapIfNeeded()
        XCTAssertTrue(fs.directoryExists(at: fs.dataRoot))
    }

    func testCreateAndGetExercise() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        let manifest = ExerciseManifest(
            id: id,
            name: "Test Push-up",
            details: "Keep core tight",
            duration: 30,
            restAfter: 10
        )
        try db.createExercise(id: id, manifest: manifest)

        let fetched = try db.getExercise(id: id)
        XCTAssertEqual(fetched.name, "Test Push-up")
        XCTAssertEqual(fetched.details, "Keep core tight")
        XCTAssertEqual(fetched.duration, 30)
        XCTAssertEqual(fetched.restAfter, 10)

        let folder = fs.exercisesDatabaseDirectory.appendingPathComponent(id)
        XCTAssertTrue(fs.directoryExists(at: folder))
        let manifestURL = folder.appendingPathComponent("manifest.json")
        XCTAssertTrue(fs.fileExists(at: manifestURL))
        let guideURL = folder.appendingPathComponent("guide.md")
        XCTAssertTrue(fs.fileExists(at: guideURL))
    }

    func testDeleteExerciseMovesToTrash() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        let manifest = ExerciseManifest(id: id, name: "Test Delete")
        try db.createExercise(id: id, manifest: manifest)

        try db.deleteExercise(id: id)

        let folder = fs.exercisesDatabaseDirectory.appendingPathComponent(id)
        XCTAssertFalse(fs.directoryExists(at: folder))

        let trashContents = try fs.listDirectory(fs.trashDirectory)
        XCTAssertEqual(trashContents.count, 1)
        XCTAssertTrue(trashContents[0].lastPathComponent.contains(id))
    }

    func testSearchExercisesByName() throws {
        try db.bootstrapIfNeeded()
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let id3 = UUID().uuidString

        try db.createExercise(id: id1, manifest: ExerciseManifest(id: id1, name: "Push-up Standard"))
        try db.createExercise(id: id2, manifest: ExerciseManifest(id: id2, name: "Squat Bodyweight"))
        try db.createExercise(id: id3, manifest: ExerciseManifest(id: id3, name: "Push-up Diamond"))

        let results = try db.searchExercises(query: "push")
        XCTAssertEqual(results.count, 2)

        let squatResults = try db.searchExercises(query: "squat")
        XCTAssertEqual(squatResults.count, 1)

        let allResults = try db.searchExercises(query: "")
        XCTAssertEqual(allResults.count, 3)
    }

    func testSearchExercisesByType() throws {
        try db.bootstrapIfNeeded()
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString

        try db.createExercise(id: id1, manifest: ExerciseManifest(
            id: id1, name: "Push-up", workoutType: .strength
        ))
        try db.createExercise(id: id2, manifest: ExerciseManifest(
            id: id2, name: "Sprint", workoutType: .cardio
        ))

        let strengthResults = try db.searchExercises(query: "", type: .strength)
        XCTAssertEqual(strengthResults.count, 1)
        XCTAssertEqual(strengthResults[0].manifest.name, "Push-up")

        let cardioResults = try db.searchExercises(query: "", type: .cardio)
        XCTAssertEqual(cardioResults.count, 1)
        XCTAssertEqual(cardioResults[0].manifest.name, "Sprint")
    }

    func testCreateAndListWorkouts() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        let manifest = WorkoutManifest(
            id: id,
            name: "Morning HIIT",
            type: .hiit,
            sections: [
                WorkoutSectionManifest(exerciseID: "ex1", name: "Jump Squats", duration: 60),
                WorkoutSectionManifest(exerciseID: "ex2", name: "Burpees", duration: 45),
            ],
            colorHex: "FF2D55"
        )
        try db.createWorkout(id: id, manifest: manifest)

        let workouts = try db.listWorkouts()
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].name, "Morning HIIT")
        XCTAssertEqual(workouts[0].sections.count, 2)
    }

    func testHistoryAppendAndRead() throws {
        try db.bootstrapIfNeeded()
        let entry1 = HistoryEntry(
            workoutId: "w1",
            workoutName: "Morning HIIT",
            durationCompleted: 1200,
            workoutType: .hiit
        )
        let entry2 = HistoryEntry(
            workoutId: "w2",
            workoutName: "Evening Yoga",
            durationCompleted: 1800,
            workoutType: .yoga
        )
        try db.appendHistoryEntry(entry1)
        try db.appendHistoryEntry(entry2)

        let entries = try db.readHistory()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].workoutName, "Morning HIIT")
        XCTAssertEqual(entries[1].workoutName, "Evening Yoga")
    }

    func testConfigSaveAndLoad() throws {
        try db.bootstrapIfNeeded()
        let config = ConfigManifest(
            customWorkoutTypes: [
                WorkoutType(id: "custom1", name: "Calisthenics", iconName: "figure.strengthtraining.traditional", colorHex: "FF9500")
            ],
            weeklyGoal: 5,
            restDays: ["2025-01-01", "2025-01-02"],
            trainingDays: [1, 3, 5]
        )
        try db.saveConfig(config)

        let loaded = try db.loadConfig()
        XCTAssertEqual(loaded.weeklyGoal, 5)
        XCTAssertEqual(loaded.customWorkoutTypes.count, 1)
        XCTAssertEqual(loaded.customWorkoutTypes[0].name, "Calisthenics")
        XCTAssertEqual(loaded.restDays.count, 2)
        XCTAssertEqual(loaded.trainingDays, [1, 3, 5])
    }

    func testExternalFolderDoesNotCauseErrors() throws {
        try db.bootstrapIfNeeded()
        let externalFolder = fs.exercisesDatabaseDirectory.appendingPathComponent("random_junk")
        try FileManager.default.createDirectory(at: externalFolder, withIntermediateDirectories: true)
        try "not a manifest".write(to: externalFolder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let results = try db.listFolders()
        XCTAssertTrue(results.allSatisfy { $0.name != "random_junk" || $0.hasManifest == false })
    }

    func testNestedFolderCreation() throws {
        try db.bootstrapIfNeeded()

        _ = try db.createFolder(name: "Upper Body", parentPath: nil)
        _ = try db.createFolder(name: "Push", parentPath: "Upper Body")

        let roots = try db.listFolders(parentPath: nil)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].name, "Upper Body")

        let children = try db.listFolders(parentPath: "Upper Body")
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0].name, "Push")
    }

    func testNestedExerciseCreation() throws {
        try db.bootstrapIfNeeded()

        _ = try db.createFolder(name: "Core", parentPath: nil)
        let id = UUID().uuidString
        let manifest = ExerciseManifest(id: id, name: "Plank", duration: 45)
        try db.createExercise(id: id, manifest: manifest, parentPath: "Core")

        let fetched = try db.getExercise(id: id, parentPath: "Core")
        XCTAssertEqual(fetched.name, "Plank")
        XCTAssertEqual(fetched.duration, 45)
    }

    func testExerciseUpdateBacksUpOldManifest() throws {
        try db.bootstrapIfNeeded()
        let id = UUID().uuidString
        let v1 = ExerciseManifest(id: id, name: "V1", duration: 30)
        try db.createExercise(id: id, manifest: v1)

        let v2 = ExerciseManifest(id: id, name: "V2", duration: 60)
        try db.updateExercise(id: id, manifest: v2)

        let fetched = try db.getExercise(id: id)
        XCTAssertEqual(fetched.name, "V2")
        XCTAssertEqual(fetched.duration, 60)

        let trashContents = try fs.listDirectory(fs.trashDirectory, skipNonSchema: false)
        XCTAssertFalse(trashContents.isEmpty, "Trash should contain backed-up manifest")
    }

    func testStatsWithNoHistoryReturnsZeros() throws {
        try db.bootstrapIfNeeded()
        let stats = try db.getStats()
        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.streak, 0)
        XCTAssertEqual(stats.bestStreak, 0)
        XCTAssertEqual(stats.totalDuration, 0)
    }

    func testStatsWithHistory() throws {
        try db.bootstrapIfNeeded()
        let today = Date()
        let yesterday = today.addingTimeInterval(-86400)

        try db.appendHistoryEntry(HistoryEntry(
            workoutId: "w1", workoutName: "W1",
            completedAt: today, durationCompleted: 600, workoutType: .hiit
        ))
        try db.appendHistoryEntry(HistoryEntry(
            workoutId: "w2", workoutName: "W2",
            completedAt: yesterday, durationCompleted: 300, workoutType: .hiit
        ))

        let stats = try db.getStats()
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.totalDuration, 900)
        XCTAssertTrue(stats.streak >= 1)
    }

    func testApprovalGateFlow() throws {
        try db.bootstrapIfNeeded()
        let approvalID = db.approveWrite(
            operation: .createExercise,
            targetName: "Test Exercise",
            targetID: "test-123",
            preview: "Will create exercise folder with manifest.json and guide.md"
        )

        let confirmed = db.confirmApproval(id: approvalID)
        XCTAssertNotNil(confirmed)
        XCTAssertEqual(confirmed?.operation, .createExercise)
        XCTAssertEqual(confirmed?.targetName, "Test Exercise")

        let alreadyGone = db.confirmApproval(id: approvalID)
        XCTAssertNil(alreadyGone)
    }

    func testImportMedia() throws {
        try db.bootstrapIfNeeded()
        let sourceFile = tempDir.appendingPathComponent("source.jpg")
        try "test image".write(to: sourceFile, atomically: true, encoding: .utf8)

        let filename = try db.importMedia(from: sourceFile)
        XCTAssertTrue(filename.hasSuffix(".jpg") || filename.contains("."))
        let destFile = fs.mediaDirectory.appendingPathComponent(filename)
        XCTAssertTrue(fs.fileExists(at: destFile))
    }
}
