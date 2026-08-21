import Foundation
import ZIPFoundation
import TimeMasterCore

struct BackupOfflineRegionMetadata: Codable, Equatable {
    static let storageKey = "OutdoorOfflineRegions"

    struct Bounds: Codable, Equatable {
        var swLat: Double
        var swLon: Double
        var neLat: Double
        var neLon: Double
    }

    var bounds: Bounds
    var minZoom: Int
    var maxZoom: Int
    var styleURL: String
    var downloadedAt: Date
    var provider: OutdoorMapProvider? = nil
    var capabilities: [OutdoorMapMode]? = nil
    var cacheRights: OutdoorMapCacheRights? = nil
    var attribution: OutdoorMapAttribution? = nil
}

struct BackupManifest: Codable {
    var version: Int = 2
    var exportedAt: Date = Date()
    var workouts: [Workout]
    var workoutHistory: [WorkoutHistoryEntry]
    var folders: [ExerciseFolder]
    var rootNotes: [DatabaseNote]
    var rootExercises: [Exercise]
    var outdoorActivities: [OutdoorActivity]? = nil
    var plannedRoutes: [PlannedRoute]? = nil
    var config: ConfigManifest? = nil
    var offlineRegions: [BackupOfflineRegionMetadata]? = nil

    init(
        workouts: [Workout],
        workoutHistory: [WorkoutHistoryEntry],
        folders: [ExerciseFolder],
        rootNotes: [DatabaseNote],
        rootExercises: [Exercise],
        outdoorActivities: [OutdoorActivity]? = nil,
        plannedRoutes: [PlannedRoute]? = nil,
        config: ConfigManifest? = nil,
        offlineRegions: [BackupOfflineRegionMetadata]? = nil
    ) {
        self.workouts = workouts
        self.workoutHistory = workoutHistory
        self.folders = folders
        self.rootNotes = rootNotes
        self.rootExercises = rootExercises
        self.outdoorActivities = outdoorActivities
        self.plannedRoutes = plannedRoutes
        self.config = config
        self.offlineRegions = offlineRegions
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, workouts, workoutHistory, folders, rootNotes, rootExercises
        case outdoorActivities, plannedRoutes, config, offlineRegions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        workouts = try container.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        workoutHistory = try container.decodeIfPresent([WorkoutHistoryEntry].self, forKey: .workoutHistory) ?? []
        folders = try container.decodeIfPresent([ExerciseFolder].self, forKey: .folders) ?? []
        rootNotes = try container.decodeIfPresent([DatabaseNote].self, forKey: .rootNotes) ?? []
        rootExercises = try container.decodeIfPresent([Exercise].self, forKey: .rootExercises) ?? []
        outdoorActivities = try container.decodeIfPresent([OutdoorActivity].self, forKey: .outdoorActivities)
        plannedRoutes = try container.decodeIfPresent([PlannedRoute].self, forKey: .plannedRoutes)
        config = try container.decodeIfPresent(ConfigManifest.self, forKey: .config)
        offlineRegions = try container.decodeIfPresent([BackupOfflineRegionMetadata].self, forKey: .offlineRegions)
    }
}

// MARK: - Import Summary

struct ImportSummary {
    var exercisesImported: Int = 0
    var foldersCreated: Int = 0
    var workoutsImported: Int = 0
    var historyImported: Int = 0
    var outdoorActivitiesImported: Int = 0
    var routesImported: Int = 0
    var preferencesImported: Int = 0
    var offlineRegionsImported: Int = 0
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
        let outdoorActivities: [OutdoorActivity]
        let outdoorRoutes: [String: [OutdoorTrackPoint]]
        let plannedRoutes: [PlannedRoute]
        let config: ConfigManifest
        let offlineRegions: [BackupOfflineRegionMetadata]
        let rootExercises: [Exercise]
    }

    /// Call this on the main thread to capture current store state.
    func snapshot(workoutStore: WorkoutStore, databaseStore: DatabaseStore, outdoorStore: OutdoorActivityStore) -> ExportSnapshot {
        let outdoorActivities = outdoorStore.activities
        var outdoorRoutes: [String: [OutdoorTrackPoint]] = [:]
        for activity in outdoorActivities {
            outdoorRoutes[activity.id.uuidString] = outdoorStore.trackPoints(for: activity)
        }
        return ExportSnapshot(
            workouts: workoutStore.workouts,
            workoutHistory: workoutStore.historyEntries,
            folders: databaseStore.rootFolders,
            rootNotes: databaseStore.rootNotes,
            outdoorActivities: outdoorActivities,
            outdoorRoutes: outdoorRoutes,
            plannedRoutes: outdoorStore.plannedRoutes,
            config: (try? db.loadConfig()) ?? ConfigManifest(),
            offlineRegions: loadOfflineRegionMetadata(),
            rootExercises: databaseStore.rootExercises
        )
    }

    /// Builds a `.zip` archive containing all data + media.
    func export(snapshot: ExportSnapshot) throws -> URL {

        // 1. Build manifest
        let manifest = BackupManifest(
            workouts: snapshot.workouts,
            workoutHistory: snapshot.workoutHistory,
            folders: snapshot.folders,
            rootNotes: snapshot.rootNotes,
            rootExercises: snapshot.rootExercises,
            outdoorActivities: snapshot.outdoorActivities,
            plannedRoutes: snapshot.plannedRoutes,
            config: snapshot.config,
            offlineRegions: snapshot.offlineRegions
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

        let routeEncoder = JSONEncoder()
        routeEncoder.dateEncodingStrategy = .iso8601
        for activity in snapshot.outdoorActivities {
            let routeLines = try (snapshot.outdoorRoutes[activity.id.uuidString] ?? []).map { point -> String in
                String(data: try routeEncoder.encode(point.coreValue), encoding: .utf8) ?? ""
            }
            let routeData = Data((routeLines.joined(separator: "\n") + (routeLines.isEmpty ? "" : "\n")).utf8)
            try archive.addEntry(
                with: "activities/\(activity.id.uuidString)/track.jsonl",
                type: .file,
                uncompressedSize: UInt32(routeData.count),
                provider: { position, size in
                    routeData.subdata(in: Int(position) ..< Int(position) + Int(size))
                }
            )
        }

        return destURL
    }

    // MARK: - Import (file-based)

    /// Unzips the backup file and writes data to the file-system database
    /// via DatabaseManager. Stores are reloaded after import to pick up changes.
    func importBackup(
        from url: URL,
        workoutStore: WorkoutStore,
        databaseStore: DatabaseStore,
        outdoorStore: OutdoorActivityStore
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
        struct PendingOutdoorImport {
            let activity: OutdoorActivity
            let points: [OutdoorTrackPoint]
        }
        let routeDecoder = JSONDecoder()
        routeDecoder.dateDecodingStrategy = .iso8601
        var pendingOutdoorImports: [PendingOutdoorImport] = []
        for activity in manifest.outdoorActivities ?? [] {
            let id = activity.id.uuidString
            let folder = db.dataRoot.appendingPathComponent("Activities/\(id)", isDirectory: true)
            if fm.fileExists(atPath: folder.path) {
                continue
            }
            guard activity.finished == (activity.recordingState == .finished),
                  activity.establishedAt == nil || activity.finished else {
                throw BackupError.invalidBackup
            }
            let routeURL = tmpDir.appendingPathComponent("activities/\(id)/track.jsonl")
            guard fm.fileExists(atPath: routeURL.path) else {
                throw BackupError.invalidBackup
            }
            var points: [OutdoorTrackPoint] = []
            let text = try String(contentsOf: routeURL)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                let point = try routeDecoder.decode(TimeMasterCore.OutdoorTrackPoint.self, from: Data(line.utf8))
                let decodedPoint = OutdoorTrackPoint(core: point)
                guard OutdoorMetricsCalculator.isValidLocationPoint(decodedPoint) else {
                    throw BackupError.invalidBackup
                }
                points.append(decodedPoint)
            }
            pendingOutdoorImports.append(PendingOutdoorImport(activity: activity, points: points))
        }

        let routeEncoder = JSONEncoder()
        routeEncoder.dateEncodingStrategy = .iso8601
        var pendingRoutes: [PlannedRoute] = []
        var pendingRouteIDs = Set<UUID>()
        for route in manifest.plannedRoutes ?? [] {
            let routeURL = db.routesDirectory.appendingPathComponent("\(route.id.uuidString).json")
            guard !fm.fileExists(atPath: routeURL.path), pendingRouteIDs.insert(route.id).inserted else {
                continue
            }
            guard route.points.count > 1,
                  route.points.allSatisfy({ OutdoorMetricsCalculator.isValidLocationPoint($0) }) else {
                throw BackupError.invalidBackup
            }
            _ = try routeEncoder.encode(route)
            pendingRoutes.append(route)
        }
        let originalConfig: ConfigManifest?
        let mergedConfig: ConfigManifest?
        if let importedConfig = manifest.config {
            let currentConfig = try db.loadConfig()
            originalConfig = currentConfig
            var nextConfig = currentConfig
            nextConfig.outdoorRecording = importedConfig.outdoorRecording
            mergedConfig = nextConfig
        } else {
            originalConfig = nil
            mergedConfig = nil
        }
        let originalOfflineRegionsData = UserDefaults.standard.data(forKey: BackupOfflineRegionMetadata.storageKey)
        let preparedOfflineRegions: (data: Data, importedCount: Int)?
        if let regions = manifest.offlineRegions, !regions.isEmpty {
            let existing = originalOfflineRegionsData.flatMap {
                try? JSONDecoder().decode([BackupOfflineRegionMetadata].self, from: $0)
            } ?? []
            var merged = existing
            var importedCount = 0
            for region in regions where !merged.contains(region) {
                merged.append(region)
                importedCount += 1
            }
            preparedOfflineRegions = (try JSONEncoder().encode(merged), importedCount)
        } else {
            preparedOfflineRegions = nil
        }

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

            var manifest = workout.coreManifest
            manifest.id = wID
            manifest.sections = manifest.sections.map { section in
                var section = section
                section.mediaFilenames = section.mediaFilenames.map { mediaMap[$0] ?? $0 }
                return section
            }
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

        var outdoorActivitiesImported = 0
        var routesImported = 0
        var preferencesImported = 0
        var offlineRegionsImported = 0
        var createdOutdoorIDs: [String] = []
        var createdRouteURLs: [URL] = []
        do {
            for activity in manifest.outdoorActivities ?? [] {
                let id = activity.id.uuidString
                let folder = db.dataRoot.appendingPathComponent("Activities/\(id)", isDirectory: true)
                if fm.fileExists(atPath: folder.path) {
                    duplicatesSkipped += 1
                    continue
                }
                guard let pending = pendingOutdoorImports.first(where: { $0.activity.id == activity.id }) else {
                    throw BackupError.invalidBackup
                }
                try db.createOutdoorActivity(id: id, manifest: activity.coreValue)
                createdOutdoorIDs.append(id)
                for point in pending.points {
                    try db.appendOutdoorTrackPoint(id: id, point: point.coreValue)
                }
                outdoorActivitiesImported += 1
            }

            for route in pendingRoutes {
                let routeURL = db.routesDirectory.appendingPathComponent("\(route.id.uuidString).json")
                let routeData = try routeEncoder.encode(route)
                try routeData.write(to: routeURL, options: .atomic)
                createdRouteURLs.append(routeURL)
                routesImported += 1
            }
            for route in (manifest.plannedRoutes ?? []) where !pendingRoutes.contains(where: { $0.id == route.id }) {
                duplicatesSkipped += 1
            }

            if let importedConfig = manifest.config, let mergedConfig {
                try db.saveConfig(mergedConfig)
                if importedConfig.outdoorRecording != nil {
                    preferencesImported = 1
                }
            }

            if let preparedOfflineRegions {
                UserDefaults.standard.set(
                    preparedOfflineRegions.data,
                    forKey: BackupOfflineRegionMetadata.storageKey
                )
                offlineRegionsImported = preparedOfflineRegions.importedCount
            }
        } catch {
            for routeURL in createdRouteURLs {
                try? fm.removeItem(at: routeURL)
            }
            for id in createdOutdoorIDs {
                try? db.deleteOutdoorActivity(id: id)
            }
            if let originalConfig {
                try? db.saveConfig(originalConfig)
            }
            if let originalOfflineRegionsData {
                UserDefaults.standard.set(
                    originalOfflineRegionsData,
                    forKey: BackupOfflineRegionMetadata.storageKey
                )
            } else {
                UserDefaults.standard.removeObject(forKey: BackupOfflineRegionMetadata.storageKey)
            }
            throw error
        }

        // 10. Reload stores on main thread (@Published properties)
        DispatchQueue.main.sync {
            workoutStore.reload()
            databaseStore.reload()
            outdoorStore.reload()
            if preferencesImported > 0 {
                NotificationCenter.default.post(name: .outdoorRecordingPreferencesDidChange, object: nil)
            }
        }

        return ImportSummary(
            exercisesImported: exercisesImported,
            foldersCreated: foldersCreated,
            workoutsImported: workoutsImported,
            historyImported: historyImported,
            outdoorActivitiesImported: outdoorActivitiesImported,
            routesImported: routesImported,
            preferencesImported: preferencesImported,
            offlineRegionsImported: offlineRegionsImported,
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
    private func loadOfflineRegionMetadata() -> [BackupOfflineRegionMetadata] {
        guard
            let data = UserDefaults.standard.data(forKey: BackupOfflineRegionMetadata.storageKey),
            let metadata = try? JSONDecoder().decode([BackupOfflineRegionMetadata].self, from: data)
        else {
            return []
        }
        return metadata.filter {
            $0.bounds.swLat.isFinite
                && $0.bounds.swLon.isFinite
                && $0.bounds.neLat.isFinite
                && $0.bounds.neLon.isFinite
                && $0.minZoom >= 0
                && $0.maxZoom >= $0.minZoom
                && !$0.styleURL.isEmpty
        }
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
