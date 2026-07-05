import Foundation
import ZIPFoundation

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

// MARK: - BackupManager

/// Handles export (pack → ZIP) and import (unZIP → merge) of all app data.
final class BackupManager {

    static let shared = BackupManager()
    private init() {}

    private let fm = FileManager.default

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
    /// Pass a snapshot captured on the main thread; this method runs on any thread.
    /// Returns the URL of the file in Documents/Backups/ ready to share.
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

        // 2. Prepare output path in Documents/Backups/ (tmp/ causes share sheet failures)
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

    // MARK: - Import (merge)

    /// Unzips the backup file, merges data into stores (skips items whose UUID
    /// already exists) and copies missing media files.
    func importBackup(
        from url: URL,
        workoutStore: WorkoutStore,
        databaseStore: DatabaseStore
    ) throws {

        // Security-scoped access for files picked via fileImporter
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

        // 3. Merge on main thread (stores are @Published / ObservableObject)
        DispatchQueue.main.sync {
            mergeWorkouts(manifest.workouts, into: workoutStore)
            mergeHistory(manifest.workoutHistory, into: workoutStore)
            mergeFolders(manifest.folders, into: databaseStore)
            mergeRootExercises(manifest.rootExercises, into: databaseStore)
            mergeRootNotes(manifest.rootNotes, into: databaseStore)
        }

        // 4. Copy media files (skip existing)
        let photosDir = PhotoManager.shared.photosDirectoryURL
        if !fm.fileExists(atPath: photosDir.path) {
            try fm.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }
        let mediaDir = tmpDir.appendingPathComponent("media")
        if fm.fileExists(atPath: mediaDir.path) {
            let files = (try? fm.contentsOfDirectory(
                at: mediaDir,
                includingPropertiesForKeys: nil
            )) ?? []
            for src in files {
                let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                if !fm.fileExists(atPath: dest.path) {
                    try fm.copyItem(at: src, to: dest)
                }
            }
        }

        // 5. Persist merged state — reload on main thread so @Published updates are safe
        DispatchQueue.main.sync {
            workoutStore.reload()
            databaseStore.reload()
        }
    }

    // MARK: - Merge helpers

    private func mergeWorkouts(_ incoming: [Workout], into store: WorkoutStore) {
        let existing = Set(store.workouts.map(\.id))
        let newOnes = incoming.filter { !existing.contains($0.id) }
        guard !newOnes.isEmpty else { return }
        store.workouts.append(contentsOf: newOnes)
        // Persist via reflection-free approach: write directly to UserDefaults
        saveToUserDefaults(store.workouts, key: "workouts")
    }

    private func mergeHistory(_ incoming: [WorkoutHistoryEntry], into store: WorkoutStore) {
        let existing = Set(store.historyEntries.map(\.id))
        let newOnes = incoming.filter { !existing.contains($0.id) }
        guard !newOnes.isEmpty else { return }
        store.historyEntries.append(contentsOf: newOnes)
        store.historyEntries.sort { $0.completedAt > $1.completedAt }
        saveToUserDefaults(store.historyEntries, key: "workout_history")
    }

    private func mergeFolders(_ incoming: [ExerciseFolder], into store: DatabaseStore) {
        var folders = store.rootFolders
        mergeExerciseFolderArray(&folders, with: incoming)
        store.rootFolders = folders
        saveToUserDefaults(folders, key: "exercise_database_v2")
    }

    private func mergeExerciseFolderArray(
        _ existing: inout [ExerciseFolder],
        with incoming: [ExerciseFolder]
    ) {
        let existingIDs = Set(existing.map(\.id))
        for folder in incoming {
            if existingIDs.contains(folder.id) {
                // Recurse into subfolders of the matching existing folder
                if let idx = existing.firstIndex(where: { $0.id == folder.id }) {
                    mergeExerciseFolderArray(&existing[idx].subfolders, with: folder.subfolders)
                    // Merge exercises inside this folder
                    let existingExIDs = Set(existing[idx].exercises.map(\.id))
                    let newEx = folder.exercises.filter { !existingExIDs.contains($0.id) }
                    existing[idx].exercises.append(contentsOf: newEx)
                    // Merge notes inside this folder
                    let existingNoteIDs = Set(existing[idx].notes.map(\.id))
                    let newNotes = folder.notes.filter { !existingNoteIDs.contains($0.id) }
                    existing[idx].notes.append(contentsOf: newNotes)
                }
            } else {
                existing.append(folder)
            }
        }
    }

    private func mergeRootExercises(_ incoming: [Exercise], into store: DatabaseStore) {
        let existing = Set(store.rootExercises.map(\.id))
        let newOnes = incoming.filter { !existing.contains($0.id) }
        guard !newOnes.isEmpty else { return }
        store.rootExercises.append(contentsOf: newOnes)
        saveToUserDefaults(store.rootExercises, key: "exercise_database_root_exercises_v1")
    }

    private func mergeRootNotes(_ incoming: [DatabaseNote], into store: DatabaseStore) {
        let existing = Set(store.rootNotes.map(\.id))
        let newOnes = incoming.filter { !existing.contains($0.id) }
        guard !newOnes.isEmpty else { return }
        store.rootNotes.append(contentsOf: newOnes)
        saveToUserDefaults(store.rootNotes, key: "exercise_database_root_notes_v1")
    }

    private func saveToUserDefaults<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Folder Export

    /// Exports a single folder (with optional item filtering) to Documents/Exports/<name>.zip.
    /// Runs on any thread; pass IDs captured on the main thread.
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
