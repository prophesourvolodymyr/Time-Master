import Foundation
import ZIPFoundation
import TimeMasterCore

// MARK: - Manifest

/// Everything serialised into the backup ZIP as "manifest.json".
struct BackupManifest: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var workouts: [Workout]
    var workoutHistory: [WorkoutHistoryEntry]
    var folders: [ExerciseFolder]
    var rootNotes: [DatabaseNote]
    var rootExercises: [Exercise]
}

// MARK: - Import Summary

struct ImportSummary {
    var exercisesImported: Int = 0
    var foldersCreated: Int = 0
    var workoutsImported: Int = 0
    var historyImported: Int = 0
    var mediaImported: Int = 0
    var duplicatesSkipped: Int = 0
}

// MARK: - BackupManager

/// Handles export (pack → ZIP) and import (unZIP → file system via DatabaseManager).
final class BackupManager {

    static let shared = BackupManager()
    private init() {}

    private let fm = FileManager.default
    private let db = DatabaseManager.shared

    // MARK: - Export

    /// Snapshot of store data — must be captured on the main thread before
    /// handing off to a background task.
    struct ExportSnapshot {
        let workouts: [Workout]
        let workoutHistory: [WorkoutHistoryEntry]
        let folders: [ExerciseFolder]
        let rootNotes: [DatabaseNote]
        let rootExercises: [Exercise]
    }

    /// Call this on the main thread to capture current store state.
    func snapshot(workoutStore: WorkoutStore, databaseStore: DatabaseStore) -> ExportSnapshot {
        ExportSnapshot(
            workouts:       workoutStore.workouts,
            workoutHistory: workoutStore.historyEntries,
            folders:        databaseStore.rootFolders,
            rootNotes:      databaseStore.rootNotes,
            rootExercises:  databaseStore.rootExercises
        )
    }

    /// Builds a `.zip` archive containing all data + media.
    func export(snapshot: ExportSnapshot) throws -> URL {

        // 1. Build manifest
        let manifest = BackupManifest(
            workouts:       snapshot.workouts,
            workoutHistory: snapshot.workoutHistory,
            folders:        snapshot.folders,
            rootNotes:      snapshot.rootNotes,
            rootExercises:  snapshot.rootExercises
        )
        let manifestData = try JSONEncoder().encode(manifest)

        // 2. Prepare output path in Documents/Backups/
        let backupsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        let dateStr = Self.dateString()
        let destURL = backupsDir
            .appendingPathComponent("TimeMaster-Backup-\(dateStr).zip")
        try? fm.removeItem(at: destURL)

        // 3. Create archive
        guard let archive = Archive(url: destURL, accessMode: .create) else {
            throw BackupError.archiveCreationFailed
        }

        // 4. Add manifest.json
        try archive.addEntry(
            with: "manifest.json",
            type: .file,
            uncompressedSize: UInt32(manifestData.count),
            provider: { position, size in
                manifestData.subdata(in: Int(position) ..< Int(position) + Int(size))
            }
        )

        // 5. Collect all referenced media filenames
        let workoutMedia = collectWorkoutMediaFilenames(from: snapshot.workouts)
        let databaseMedia = collectDatabaseMediaFilenames(
            folders: snapshot.folders,
            exercises: snapshot.rootExercises
        )
        let referencedFilenames = Set(workoutMedia + databaseMedia)

        // 6. Add only referenced media files
        let photosDir = PhotoManager.shared.photosDirectoryURL
        for filename in referencedFilenames {
            let fileURL = photosDir.appendingPathComponent(filename)
            let entryName = "media/\(filename)"
            if fm.fileExists(atPath: fileURL.path) {
                let fileData = try Data(contentsOf: fileURL)
                try archive.addEntry(
                    with: entryName,
                    type: .file,
                    uncompressedSize: UInt32(fileData.count),
                    provider: { position, size in
                        fileData.subdata(in: Int(position) ..< Int(position) + Int(size))
                    }
                )
            } else {
                print("[BackupManager] Warning: referenced media file missing: \(filename)")
            }
        }

        return destURL
    }

    // MARK: - Import (file-based)

    /// Unzips the backup file and writes data to the file-system database
    /// via DatabaseManager. Stores are reloaded after import to pick up changes.
    @discardableResult
    func importBackup(
        from url: URL,
        workoutStore: WorkoutStore,
        databaseStore: DatabaseStore
    ) throws -> ImportSummary {

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        // 1. Unzip to a temp directory
        let tmpDir = fm.temporaryDirectory
            .appendingPathComponent("tm_import_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        try fm.unzipItem(at: url, to: tmpDir)

        // 2. Decode manifest
        let manifestURL = tmpDir.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw BackupError.invalidBackup
        }
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)

        // 3. Bootstrap directories
        try db.bootstrapIfNeeded()

        // 4. Import media files with UUID filenames → build mapping
        var mediaMap: [String: String] = [:]
        let mediaDir = tmpDir.appendingPathComponent("media")
        if fm.fileExists(atPath: mediaDir.path) {
            let files = (try? fm.contentsOfDirectory(
                at: mediaDir,
                includingPropertiesForKeys: nil
            )) ?? []
            for src in files {
                let original = src.lastPathComponent
                if let uuidFilename = try? db.importMedia(from: src) {
                    mediaMap[original] = uuidFilename
                }
            }
        }

        // 5. Import exercises from folder tree (recursive)
        var exercisesImported = 0
        var foldersCreated = 0
        var duplicatesSkipped = 0

        func importFolders(_ folders: [ExerciseFolder], parentPath: String?) {
            for folder in folders {
                let folderName = folder.name.replacingOccurrences(of: "/", with: "-")
                let path = parentPath.map { "\($0)/\(folderName)" } ?? folderName
                _ = try? db.createFolder(name: folderName, parentPath: parentPath)
                foldersCreated += 1

                let folderType: TimeMasterCore.WorkoutType? = folder.workoutType.map {
                    TimeMasterCore.WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
                }

                for exercise in folder.exercises {
                    let exID = exercise.id.uuidString
                    let exerciseDir = exercisesBase.appendingPathComponent("\(path)/\(exID)", isDirectory: true)
                    if fm.fileExists(atPath: exerciseDir.path) {
                        duplicatesSkipped += 1
                        continue
                    }

                    let manifest = ExerciseManifest(
                        id: exID,
                        name: exercise.name,
                        details: exercise.details,
                        duration: exercise.duration,
                        restAfter: exercise.restAfter,
                        workoutType: folderType,
                        mediaFilenames: exercise.mediaItems.map { mediaMap[$0.filename] ?? $0.filename }
                    )
                    do {
                        try db.createExercise(id: exID, manifest: manifest, parentPath: path)
                        exercisesImported += 1
                    } catch {
                        print("[BackupManager] Failed to import exercise \(exID): \(error)")
                    }
                }

                importFolders(folder.subfolders, parentPath: path)
            }
        }

        importFolders(manifest.folders, parentPath: nil)

        // 6. Import root exercises
        for exercise in manifest.rootExercises {
            let exID = exercise.id.uuidString
            let exerciseDir = exercisesBase.appendingPathComponent(exID, isDirectory: true)
            if fm.fileExists(atPath: exerciseDir.path) {
                duplicatesSkipped += 1
                continue
            }

            let manifest = ExerciseManifest(
                id: exID,
                name: exercise.name,
                details: exercise.details,
                duration: exercise.duration,
                restAfter: exercise.restAfter,
                mediaFilenames: exercise.mediaItems.map { mediaMap[$0.filename] ?? $0.filename }
            )
            do {
                try db.createExercise(id: exID, manifest: manifest)
                exercisesImported += 1
            } catch {
                print("[BackupManager] Failed to import root exercise \(exID): \(error)")
            }
        }

        // 7. Import workouts
        var workoutsImported = 0
        for workout in manifest.workouts {
            let wID = workout.id.uuidString
            let workoutDir = db.dataRoot.appendingPathComponent("Workouts/\(wID)", isDirectory: true)
            if fm.fileExists(atPath: workoutDir.path) {
                duplicatesSkipped += 1
                continue
            }

            let manifest = WorkoutManifest(
                id: wID,
                name: workout.name,
                type: TimeMasterCore.WorkoutType(
                    id: workout.type.id,
                    name: workout.type.name,
                    iconName: workout.type.iconName,
                    colorHex: workout.type.colorHex
                ),
                sections: workout.sections.map { section in
                    WorkoutSectionManifest(
                        exerciseID: "",
                        name: section.name,
                        duration: section.duration,
                        sets: section.sets,
                        restBetweenSets: section.restBetweenSets,
                        prepareTime: section.prepareTime,
                        customRestAfter: section.customRestAfter,
                        isTimerEnabled: section.isTimerEnabled,
                        mediaFilenames: section.mediaItems.map { mediaMap[$0.filename] ?? $0.filename }
                    )
                },
                musicTrackFilenames: workout.musicTrackFilenames,
                colorHex: workout.colorHex,
                createdAt: workout.createdAt,
                restBetweenSections: workout.restBetweenSections,
                imageFilename: workout.imageFilename
            )
            do {
                try db.createWorkout(id: wID, manifest: manifest)
                workoutsImported += 1
            } catch {
                print("[BackupManager] Failed to import workout \(wID): \(error)")
            }
        }

        // 8. Import history entries
        var historyImported = 0
        for entry in manifest.workoutHistory {
            let historyEntry = HistoryEntry(
                id: entry.id.uuidString,
                workoutId: entry.workoutId.uuidString,
                workoutName: entry.workoutName,
                completedAt: entry.completedAt,
                durationCompleted: entry.durationCompleted,
                workoutType: TimeMasterCore.WorkoutType(
                    id: entry.workoutType.id,
                    name: entry.workoutType.name,
                    iconName: entry.workoutType.iconName,
                    colorHex: entry.workoutType.colorHex
                ),
                isPartial: entry.isPartial,
                elapsedSeconds: entry.elapsedSeconds
            )
            do {
                try db.appendHistoryEntry(historyEntry)
                historyImported += 1
            } catch {
                print("[BackupManager] Failed to import history entry \(entry.id): \(error)")
            }
        }

        // 9. Reload stores on main thread (@Published properties)
        DispatchQueue.main.sync {
            workoutStore.reload()
            databaseStore.reload()
        }

        return ImportSummary(
            exercisesImported: exercisesImported,
            foldersCreated: foldersCreated,
            workoutsImported: workoutsImported,
            historyImported: historyImported,
            mediaImported: mediaMap.count,
            duplicatesSkipped: duplicatesSkipped
        )
    }

    private var exercisesBase: URL {
        db.exercisesDatabaseURL
    }

    // MARK: - Folder Export

    /// Exports a single folder (with optional item filtering) to Documents/Exports/<name>.zip.
    func exportFolder(
        _ folder: ExerciseFolder,
        selectedExerciseIDs: Set<UUID>,
        selectedNoteIDs: Set<UUID>,
        selectedSubfolderIDs: Set<UUID>,
        zipName: String
    ) throws -> URL {
        var exportFolder = folder
        exportFolder.exercises  = folder.exercises.filter  { selectedExerciseIDs.contains($0.id) }
        exportFolder.notes      = folder.notes.filter      { selectedNoteIDs.contains($0.id) }
        exportFolder.subfolders = folder.subfolders.filter { selectedSubfolderIDs.contains($0.id) }

        let manifest = BackupManifest(
            workouts: [], workoutHistory: [],
            folders: [exportFolder], rootNotes: [], rootExercises: []
        )
        let manifestData = try JSONEncoder().encode(manifest)

        let exportsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)
        try? fm.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let safeName: String = {
            let s = zipName.trimmingCharacters(in: .whitespaces)
                .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == " " }
                .replacingOccurrences(of: " ", with: "-")
            return s.isEmpty ? "folder-export" : s
        }()
        let destURL = exportsDir.appendingPathComponent("\(safeName).zip")
        try? fm.removeItem(at: destURL)

        guard let archive = Archive(url: destURL, accessMode: .create) else {
            throw BackupError.archiveCreationFailed
        }

        try archive.addEntry(
            with: "manifest.json",
            type: .file,
            uncompressedSize: UInt32(manifestData.count),
            provider: { position, size in
                manifestData.subdata(in: Int(position) ..< Int(position) + Int(size))
            }
        )

        let photosDir = PhotoManager.shared.photosDirectoryURL
        for filename in collectMediaFilenames(from: exportFolder) {
            let fileURL = photosDir.appendingPathComponent(filename)
            guard fm.fileExists(atPath: fileURL.path),
                  let fileData = try? Data(contentsOf: fileURL) else { continue }
            try archive.addEntry(
                with: "media/\(filename)",
                type: .file,
                uncompressedSize: UInt32(fileData.count),
                provider: { position, size in
                    fileData.subdata(in: Int(position) ..< Int(position) + Int(size))
                }
            )
        }
        return destURL
    }

    private func collectMediaFilenames(from folder: ExerciseFolder) -> [String] {
        var names: [String] = []
        for ex in folder.exercises { names.append(contentsOf: ex.mediaItems.map(\.filename)) }
        for sub in folder.subfolders { names.append(contentsOf: collectMediaFilenames(from: sub)) }
        return names
    }

    private func collectDatabaseMediaFilenames(
        folders: [ExerciseFolder],
        exercises: [Exercise]
    ) -> [String] {
        var names: [String] = []
        for ex in exercises {
            names.append(contentsOf: ex.mediaItems.map(\.filename))
        }
        for folder in folders {
            names.append(contentsOf: collectMediaFilenames(from: folder))
        }
        return names
    }

    private func collectWorkoutMediaFilenames(from workouts: [Workout]) -> [String] {
        var names: [String] = []
        for workout in workouts {
            for section in workout.sections {
                names.append(contentsOf: section.mediaItems.map(\.filename))
            }
        }
        return names
    }

    // MARK: - Helpers

    private static func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case archiveCreationFailed
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .archiveCreationFailed: return "Could not create backup archive."
        case .invalidBackup: return "The selected file is not a valid TimeMaster backup."
        }
    }
}
