import Foundation

public struct WriteApproval {
    public enum OperationType: String {
        case createExercise
        case updateExercise
        case deleteExercise
        case createWorkout
        case updateWorkout
        case deleteWorkout
        case createFolder
        case deleteFolder
    }

    public let operation: OperationType
    public let targetName: String
    public let targetID: String
    public let preview: String
    public let changes: [String: String]
}

public final class DatabaseManager {
    public static let shared = DatabaseManager()

    private let fs: FileSystemHelper
    private let schemaManager: SchemaManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var pendingApprovals: [UUID: WriteApproval] = [:]
    private let approvalLock = NSLock()

    private init() {
        self.fs = FileSystemHelper()
        self.schemaManager = SchemaManager(fs: fs)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public init(fs: FileSystemHelper) {
        self.fs = fs
        self.schemaManager = SchemaManager(fs: fs)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public var dataRoot: URL { fs.dataRoot }

    public var exercisesDatabaseURL: URL { fs.exercisesDatabaseDirectory }

    // MARK: - Bootstrap

    @discardableResult
    public func bootstrapIfNeeded() throws -> URL {
        let dirs: [URL] = [
            fs.dataRoot,
            fs.exercisesDatabaseDirectory,
            fs.workoutsDirectory,
            fs.mediaDirectory,
            fs.workspaceDirectory,
            fs.knowledgeDirectory,
            fs.skillsDirectory,
            fs.configDirectory,
            fs.historyDirectory,
            fs.musicDirectory,
            fs.backupsDirectory,
            fs.trashDirectory,
        ]
        for dir in dirs {
            try fs.ensureDirectory(dir)
        }
        if !fs.fileExists(at: fs.schemaURL) {
            try schemaManager.writeSchema()
        }
        return fs.dataRoot
    }

    // MARK: - Exercise CRUD

    public func createExercise(id: String, manifest: ExerciseManifest, parentPath: String? = nil) throws {
        let base = fs.exercisesDatabaseDirectory
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        try fs.ensureDirectory(folder)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
        let guideURL = folder.appendingPathComponent("guide.md")
        let guideContent = "# \(manifest.name)\n\n\(manifest.details.isEmpty ? "Add instructions here." : manifest.details)\n\n---\n\n**Duration:** \(manifest.duration)s | **Rest:** \(manifest.restAfter)s"
        try fs.writeAtomically(to: guideURL, data: guideContent.data(using: .utf8)!)
    }

    public func updateExercise(id: String, manifest: ExerciseManifest, parentPath: String? = nil) throws {
        let base = fs.exercisesDatabaseDirectory
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        let manifestURL = folder.appendingPathComponent("manifest.json")
        if fs.fileExists(at: manifestURL) {
            try fs.moveToTrash(source: manifestURL)
        }
        var updated = manifest
        updated.updatedAt = Date()
        try fs.writeAtomically(to: manifestURL, value: updated, encoder: encoder)
    }

    public func deleteExercise(id: String, parentPath: String? = nil) throws {
        let base = fs.exercisesDatabaseDirectory
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        try fs.moveToTrash(source: folder)
    }

    public func getExercise(id: String, parentPath: String? = nil) throws -> ExerciseManifest {
        let base = fs.exercisesDatabaseDirectory
        let folder: URL
        if let parent = parentPath {
            folder = base.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        } else {
            folder = base.appendingPathComponent(id, isDirectory: true)
        }
        let manifestURL = folder.appendingPathComponent("manifest.json")
        return try fs.readManifest(from: manifestURL, decoder: decoder)
    }

    public func searchExercises(query: String, type: WorkoutType? = nil) throws -> [(manifest: ExerciseManifest, path: String)] {
        var results: [(ExerciseManifest, String)] = []
        try walkExercises(in: fs.exercisesDatabaseDirectory, relativePath: "") { manifest, relPath in
            let nameMatch = query.isEmpty || manifest.name.localizedCaseInsensitiveContains(query)
            let typeMatch = type == nil || manifest.workoutType?.id == type?.id
            if nameMatch && typeMatch {
                results.append((manifest, relPath))
            }
        }
        return results
    }

    public func searchAllExercises() throws -> [ExerciseManifest] {
        var results: [ExerciseManifest] = []
        try walkExercises(in: fs.exercisesDatabaseDirectory, relativePath: "") { manifest, _ in
            results.append(manifest)
        }
        return results
    }

    private func walkExercises(in directory: URL, relativePath: String, visitor: (ExerciseManifest, String) throws -> Void) throws {
        let entries = try fs.listDirectory(directory, skipNonSchema: false)
        for entry in entries {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            if isDir.boolValue {
                let manifestURL = entry.appendingPathComponent("manifest.json")
                if fs.fileExists(at: manifestURL) {
                    if let manifest: ExerciseManifest = try? fs.readManifest(from: manifestURL, decoder: decoder) {
                        let relPath = relativePath.isEmpty ? entry.lastPathComponent : "\(relativePath)/\(entry.lastPathComponent)"
                        try visitor(manifest, relPath)
                    }
                }
                try walkExercises(in: entry, relativePath: relativePath.isEmpty ? entry.lastPathComponent : "\(relativePath)/\(entry.lastPathComponent)", visitor: visitor)
            }
        }
    }

    // MARK: - Folder Operations

    public func listFolders(parentPath: String? = nil) throws -> [(name: String, path: String, hasManifest: Bool)] {
        let base = parentPath.map { fs.exercisesDatabaseDirectory.appendingPathComponent($0, isDirectory: true) } ?? fs.exercisesDatabaseDirectory
        let entries = try fs.listDirectory(base, skipNonSchema: false)
        return entries.compactMap { entry in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { return nil }
            let manifestURL = entry.appendingPathComponent("manifest.json")
            let hasManifest = fs.fileExists(at: manifestURL)
            return (entry.lastPathComponent, entry.lastPathComponent, hasManifest)
        }
    }

    public func createFolder(name: String, parentPath: String? = nil) throws -> String {
        let base = parentPath.map { fs.exercisesDatabaseDirectory.appendingPathComponent($0, isDirectory: true) } ?? fs.exercisesDatabaseDirectory
        let folder = base.appendingPathComponent(name, isDirectory: true)
        if !fs.directoryExists(at: folder) {
            try fs.ensureDirectory(folder)
        }
        return name
    }

    public func deleteFolder(path: String, parentPath: String? = nil) throws {
        let base = parentPath.map { fs.exercisesDatabaseDirectory.appendingPathComponent($0, isDirectory: true) } ?? fs.exercisesDatabaseDirectory
        let folder = base.appendingPathComponent(path, isDirectory: true)
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        try fs.moveToTrash(source: folder)
    }

    // MARK: - Workout CRUD

    public func createWorkout(id: String, manifest: WorkoutManifest) throws {
        let folder = fs.workoutsDirectory.appendingPathComponent(id, isDirectory: true)
        try fs.ensureDirectory(folder)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
    }

    public func updateWorkout(id: String, manifest: WorkoutManifest) throws {
        let folder = fs.workoutsDirectory.appendingPathComponent(id, isDirectory: true)
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        let manifestURL = folder.appendingPathComponent("manifest.json")
        if fs.fileExists(at: manifestURL) {
            try fs.moveToTrash(source: manifestURL)
        }
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
    }

    public func deleteWorkout(id: String) throws {
        let folder = fs.workoutsDirectory.appendingPathComponent(id, isDirectory: true)
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        try fs.moveToTrash(source: folder)
    }

    public func getWorkout(id: String) throws -> WorkoutManifest {
        let folder = fs.workoutsDirectory.appendingPathComponent(id, isDirectory: true)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        return try fs.readManifest(from: manifestURL, decoder: decoder)
    }

    public func listWorkouts() throws -> [WorkoutManifest] {
        let entries = try fs.listDirectory(fs.workoutsDirectory)
        return entries.compactMap { entry in
            let manifestURL = entry.appendingPathComponent("manifest.json")
            return try? fs.readManifest(from: manifestURL, decoder: decoder)
        }
    }

    // MARK: - History

    public func appendHistoryEntry(_ entry: HistoryEntry) throws {
        let url = fs.historyDirectory.appendingPathComponent("entries.jsonl")
        let line = try encoder.encode(entry)
        guard let lineStr = String(data: line, encoding: .utf8) else {
            throw FileSystemHelper.Error.writeFailed(url.path)
        }
        let entryLine = lineStr.replacingOccurrences(of: "\n", with: "") + "\n"
        if fs.fileExists(at: url) {
            let existing = try fs.readRawData(from: url)
            guard let existingStr = String(data: existing, encoding: .utf8) else {
                throw FileSystemHelper.Error.readFailed(url.path)
            }
            let combined = existingStr + entryLine
            try fs.writeAtomically(to: url, data: combined.data(using: .utf8)!)
        } else {
            try fs.writeAtomically(to: url, data: entryLine.data(using: .utf8)!)
        }
    }

    public func readHistory() throws -> [HistoryEntry] {
        let url = fs.historyDirectory.appendingPathComponent("entries.jsonl")
        guard fs.fileExists(at: url) else { return [] }
        let data = try fs.readRawData(from: url)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(HistoryEntry.self, from: lineData)
        }
    }

    // MARK: - Config

    public func saveConfig(_ config: ConfigManifest) throws {
        let url = fs.configDirectory.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: url, value: config, encoder: encoder)
    }

    public func loadConfig() throws -> ConfigManifest {
        let url = fs.configDirectory.appendingPathComponent("manifest.json")
        guard fs.fileExists(at: url) else {
            return ConfigManifest()
        }
        return try fs.readManifest(from: url, decoder: decoder)
    }

    // MARK: - Stats

    public func getStats(type: WorkoutType? = nil, days: Int? = nil) throws -> (count: Int, streak: Int, bestStreak: Int, totalDuration: Int) {
        let entries = try readHistory()
        let filtered: [HistoryEntry]
        if let type = type {
            filtered = entries.filter { $0.workoutType.id == type.id }
        } else {
            filtered = entries
        }

        let dateFiltered: [HistoryEntry]
        if let days = days {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
            dateFiltered = filtered.filter { $0.completedAt >= cutoff }
        } else {
            dateFiltered = filtered
        }

        let count = dateFiltered.count
        let totalDuration = dateFiltered.reduce(0) { $0 + $1.durationCompleted }

        let cal = Calendar.current
        let daySet = Set(dateFiltered.map { cal.startOfDay(for: $0.completedAt) })
        let daysList = daySet.sorted()

        var best = 0
        var cur = 0
        var prev: Date? = nil
        for day in daysList {
            if let p = prev, let next = cal.date(byAdding: .day, value: 1, to: p), cal.isDate(next, inSameDayAs: day) {
                cur += 1
            } else {
                cur = 1
            }
            best = max(best, cur)
            prev = day
        }

        var currentStreak = 0
        var check = cal.startOfDay(for: Date())
        while daySet.contains(check) {
            currentStreak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }

        return (count, currentStreak, best, totalDuration)
    }

    // MARK: - Media

    public func importMedia(from source: URL) throws -> String {
        let uuid = UUID().uuidString
        let ext = source.pathExtension
        let filename = ext.isEmpty ? uuid : "\(uuid).\(ext)"
        let dest = fs.mediaDirectory.appendingPathComponent(filename)
        try fs.copyItem(from: source, to: dest)
        return filename
    }

    // MARK: - Approval Gate

    @discardableResult
    public func approveWrite(operation: WriteApproval.OperationType, targetName: String, targetID: String, preview: String, changes: [String: String] = [:]) -> UUID {
        let approval = WriteApproval(
            operation: operation,
            targetName: targetName,
            targetID: targetID,
            preview: preview,
            changes: changes
        )
        let approvalID = UUID()
        approvalLock.lock()
        pendingApprovals[approvalID] = approval
        approvalLock.unlock()
        return approvalID
    }

    public func confirmApproval(id: UUID) -> WriteApproval? {
        approvalLock.lock()
        defer { approvalLock.unlock() }
        let approval = pendingApprovals[id]
        pendingApprovals.removeValue(forKey: id)
        return approval
    }

    public func rejectApproval(id: UUID) {
        approvalLock.lock()
        pendingApprovals.removeValue(forKey: id)
        approvalLock.unlock()
    }

    public func pendingApprovalCount() -> Int {
        approvalLock.lock()
        defer { approvalLock.unlock() }
        return pendingApprovals.count
    }

    // MARK: - Backup/Restore

    public func createAutoBackup() throws -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupURL = fs.backupsDirectory.appendingPathComponent("auto-\(timestamp).zip")
        let data = try encoder.encode("backup-placeholder")
        try fs.writeAtomically(to: backupURL, data: data)
        return backupURL
    }
}
