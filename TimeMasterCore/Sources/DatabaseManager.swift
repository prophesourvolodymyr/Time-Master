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
            fs.outdoorActivitiesDirectory,
            fs.trashDirectory,
        ]
        for dir in dirs {
            try fs.ensureDirectory(dir)
        }
        if !fs.fileExists(at: fs.schemaURL) {
            try schemaManager.writeSchema()
        }

        if !fs.fileExists(at: fs.agentsURL) {
            let agentsContent = bootstrapAgentsContent()
            try fs.writeAtomically(to: fs.agentsURL, data: agentsContent.data(using: .utf8)!)
        }

        try bootstrapSkillFile(name: "create-exercise.md", content: bootstrapCreateExerciseContent())
        try bootstrapSkillFile(name: "build-workout.md", content: bootstrapBuildWorkoutContent())
        try bootstrapSkillFile(name: "search-database.md", content: bootstrapSearchDatabaseContent())

        try bootstrapKnowledgeFile(name: "fitness-philosophy.md", title: "Fitness Philosophy")
        try bootstrapKnowledgeFile(name: "nutrition-rules.md", title: "Nutrition Rules")
        try bootstrapKnowledgeFile(name: "recovery-protocols.md", title: "Recovery Protocols")

        return fs.dataRoot
    }

    private func bootstrapSkillFile(name: String, content: String) throws {
        let url = fs.skillsDirectory.appendingPathComponent(name)
        guard !fs.fileExists(at: url) else { return }
        try fs.writeAtomically(to: url, data: content.data(using: .utf8)!)
    }

    private func bootstrapKnowledgeFile(name: String, title: String) throws {
        let url = fs.knowledgeDirectory.appendingPathComponent(name)
        guard !fs.fileExists(at: url) else { return }
        let content = "# \(title)\n\nAdd your \(title.lowercased()) here.\n"
        try fs.writeAtomically(to: url, data: content.data(using: .utf8)!)
    }

    private func bootstrapAgentsContent() -> String {
        return """
# TimeMaster Data Directory

This is the local file-system database for TimeMaster, a fitness app.

## Structure
- **Exercises Database/** — all exercises (folders with manifest.json + guide.md)
- **Workouts/** — workout plans referencing exercise IDs
- **Media/** — shared media storage (UUID filenames)
- **Knowledge/** — AI system prompt material (loaded on session start)
- **Workspace/** — free-form AI workspace (app ignores this)
- **skills/** — reusable agent skill definitions
- **Config/** — app configuration
- **History/** — workout history (JSONL)
- **Music/** — background music tracks
- **Backups/** — automatic backups
- **.trash/** — soft-deleted items

## How to Interact
DO NOT edit files directly. Use the CLI tool:

```
timemaster-tool <command> [args]
```

### Available Commands
| Command | Description |
|---|---|
| `list-exercises` | List all exercises, optionally filtered by type or query |
| `get-exercise <id>` | Read full manifest and guide for an exercise |
| `create-exercise <json>` | Create a new exercise folder with manifest |
| `update-exercise <id> <json>` | Update an existing exercise manifest |
| `delete-exercise <id>` | Move an exercise to .trash/ |
| `search-exercises <query>` | Search exercises by name |
| `list-workouts` | List all workout plans |
| `build-workout <json>` | Create a workout from exercise IDs |
| `list-folders` | Browse the Exercises Database folder tree |
| `get-stats` | View workout statistics and streaks |
| `list-types` | List all workout types |
| `validate` | Check the entire database for errors |
| `import-media <path>` | Copy a media file to Media/ |

## Schema
See `schema.json` for the full data contract — exercise fields, workout fields, valid types, and constraints.

## Read/Write Rules
- **Safe to read:** Any directory. The CLI tool queries via `DatabaseManager`.
- **Safe to write:** Only via `timemaster-tool` commands. The tool validates before writing.
- **Workspace/:** Free zone. AI can create, read, and delete anything here. The app ignores it.
- **Never edit:** `schema.json`, `AGENTS.md`, or files inside `.trash/`.
- **Media:** Use `import-media` to copy files into `Media/`. Files get UUID names.

## Skills
See `skills/` for reusable skill files. Load a skill to get step-by-step instructions for common tasks.
"""
    }

    private func bootstrapCreateExerciseContent() -> String {
        return """
# create-exercise
Create a new exercise in the TimeMaster database.

## Steps
1. Generate a UUID for the exercise ID
2. Determine the parent folder path (e.g., "Upper Body/Push")
3. Create the exercise manifest with required fields: id, name, duration, restAfter
4. Write the manifest.json via `timemaster-tool create-exercise`
5. Optionally create guide.md with instructions and details
"""
    }

    private func bootstrapBuildWorkoutContent() -> String {
        return """
# build-workout
Assemble a workout plan from exercises in the database.

## Steps
1. Search for exercises using `timemaster-tool search-exercises`
2. Select exercises that match the user's goal and type
3. Determine section order, duration, sets, and rest periods
4. Create the workout manifest with sections referencing exercise IDs
5. Write via `timemaster-tool create-workout`
"""
    }

    private func bootstrapSearchDatabaseContent() -> String {
        return """
# search-database
Query the TimeMaster exercise database.

## Steps
1. Use `timemaster-tool search-exercises` with a query string
2. Filter results by workout type if needed
3. Use `timemaster-tool get-exercise` to read full details
4. Navigate folders with `timemaster-tool list-folders`
"""
    }

    // MARK: - Exercise CRUD (deprecated — use Page CRUD)

    @available(*, deprecated, message: "Use createPage(manifest:parentID:)")
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

    @available(*, deprecated, message: "Use updatePage(id:manifest:newParentID:)")
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

    @available(*, deprecated, message: "Use deletePage(id:)")
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

    @available(*, deprecated, message: "Use getPage(id:)")
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

    @available(*, deprecated, message: "Use searchPages(query:type:)")
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

    @available(*, deprecated, message: "Use walkPageTree(in:)")
    public func searchAllExercises() throws -> [ExerciseManifest] {
        var results: [ExerciseManifest] = []
        try walkExercises(in: fs.exercisesDatabaseDirectory, relativePath: "") { manifest, _ in
            results.append(manifest)
        }
        return results
    }

    @available(*, deprecated, message: "Use walkPageTree(in:)")
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

    // MARK: - Page CRUD

    private func normalizedPageManifest(_ manifest: ExercisePageManifest, parentID: String?) -> ExercisePageManifest {
        var normalized = manifest
        normalized.parentID = parentID

        if normalized.pageKind == .container, parentID == nil {
            normalized.workoutType = normalized.workoutType ?? .other
        } else {
            normalized.workoutType = nil
        }
        if normalized.pageKind == .container {
            normalized.duration = nil
            normalized.restAfter = nil
            normalized.prepareTime = nil
            normalized.sets = nil
            normalized.restBetweenSets = nil
        } else {
            normalized.coverImageFilename = nil
            normalized.childIDs = []
        }
        return normalized
    }


    private func writePageFiles(_ manifest: ExercisePageManifest, in folder: URL) throws {
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)

        let guideURL = folder.appendingPathComponent("guide.md")
        let guideContent = "# \(manifest.title)\n\n\(manifest.markdownBody.isEmpty ? "Add content here." : manifest.markdownBody)"
        try fs.writeAtomically(to: guideURL, data: guideContent.data(using: .utf8)!)
    }

    private func validatePageManifest(_ manifest: ExercisePageManifest, parentID: String?) throws {
        if manifest.pageKind == .leaf, parentID == nil {
            throw FileSystemHelper.Error.invalidPageKind("exercise pages must be inside a container")
        }

        if let parentID {
            guard parentID != manifest.id else {
                throw FileSystemHelper.Error.invalidPageKind("a page cannot be its own parent")
            }
            let parent = try getPage(id: parentID)
            guard parent.pageKind == .container else {
                throw FileSystemHelper.Error.invalidPageKind("pages can only be nested inside containers")
            }

            var ancestorID = parent.parentID
            while let ancestor = ancestorID {
                guard ancestor != manifest.id else {
                    throw FileSystemHelper.Error.invalidPageKind("a page cannot be moved inside its own descendants")
                }
                ancestorID = try getPage(id: ancestor).parentID
            }
        }

        if manifest.pageKind == .container {
            if manifest.duration != nil || manifest.restAfter != nil || manifest.prepareTime != nil || manifest.sets != nil || manifest.restBetweenSets != nil {
                throw FileSystemHelper.Error.invalidPageKind("containers cannot have workout timing")
            }
            if parentID != nil, manifest.workoutType != nil {
                throw FileSystemHelper.Error.invalidPageKind("nested containers inherit the root container workout type")
            }
        } else {
            if manifest.coverImageFilename != nil {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages use their first media item as the cover")
            }
            guard manifest.duration != nil else {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages require a duration")
            }
            if !manifest.childIDs.isEmpty {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages cannot contain child pages")
            }
            if manifest.workoutType != nil {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages inherit the root container workout type")
            }
        }
    }

    private func pageIDs(parentID: String?) throws -> [String] {
        if let parentID {
            return try getPage(id: parentID).childIDs
        }

        let entries = try fs.listDirectory(fs.exercisesDatabaseDirectory, skipNonSchema: false)
        let orderedEntries: [(id: String, order: Int, position: Int)] = entries.enumerated().compactMap { item -> (id: String, order: Int, position: Int)? in
            let position = item.offset
            let entry = item.element
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { return nil }
            let manifestURL = entry.appendingPathComponent("manifest.json")
            guard fs.fileExists(at: manifestURL),
                  let manifest: ExercisePageManifest = try? fs.readManifest(from: manifestURL, decoder: decoder),
                  manifest.parentID == nil else { return nil }
            return (id: manifest.id, order: manifest.order, position: position)
        }
        return orderedEntries
            .sorted {
                if $0.order != $1.order { return $0.order < $1.order }
                return $0.position < $1.position
            }
            .map(\.id)
    }

    private func persistChildOrdering(parentID: String?, childIDs: [String]) throws {
        let orderedIDs = Array(NSOrderedSet(array: childIDs)) as? [String] ?? childIDs
        if let parentID {
            var parent = try getPage(id: parentID)
            parent.childIDs = orderedIDs
            parent.updatedAt = Date()
            try writePageFiles(parent, in: try resolvePageFolder(id: parentID))
        }

        for (index, childID) in orderedIDs.enumerated() {
            var child = try getPage(id: childID)
            child.parentID = parentID
            child.order = index
            child.updatedAt = Date()
            try writePageFiles(child, in: try resolvePageFolder(id: childID))
        }
    }

    public func createPage(manifest: ExercisePageManifest, parentID: String? = nil) throws {
        let resolvedParentID = parentID ?? manifest.parentID
        if resolvedParentID != nil, manifest.workoutType != nil {
            throw FileSystemHelper.Error.invalidPageKind("only the absolute root container may define a workout type")
        }
        var candidate = manifest
        candidate.parentID = resolvedParentID
        try validatePageManifest(candidate, parentID: resolvedParentID)
        var manifest = normalizedPageManifest(candidate, parentID: resolvedParentID)
        try validatePageManifest(manifest, parentID: manifest.parentID)
        if manifest.parentID != nil {
            manifest.order = try pageIDs(parentID: manifest.parentID).count
        } else {
            manifest.order = try pageIDs(parentID: nil).count
        }

        let folder = try pageFolder(for: manifest.id, parentID: manifest.parentID)
        try fs.ensureDirectory(folder)
        try fs.ensureDirectory(folder.appendingPathComponent("media", isDirectory: true))
        try writePageFiles(manifest, in: folder)

        if let parentID = manifest.parentID {
            var parent = try getPage(id: parentID)
            if !parent.childIDs.contains(manifest.id) {
                parent.childIDs.append(manifest.id)
            }
            try persistChildOrdering(parentID: parentID, childIDs: parent.childIDs)
        }
    }

    public func updatePage(id: String, manifest: ExercisePageManifest, newParentID: String? = nil) throws {
        let existing = try getPage(id: id)
        let resolvedParentID = newParentID ?? manifest.parentID
        var candidate = manifest
        candidate.parentID = resolvedParentID
        candidate.id = id
        try validatePageManifest(candidate, parentID: resolvedParentID)
        var updated = normalizedPageManifest(candidate, parentID: resolvedParentID)
        updated.id = id
        try validatePageManifest(updated, parentID: resolvedParentID)

        let currentFolder = try resolvePageFolder(id: id)
        guard fs.directoryExists(at: currentFolder) else {
            throw FileSystemHelper.Error.notFound(currentFolder.path)
        }

        if existing.parentID != resolvedParentID {
            let newFolder = try pageFolder(for: id, parentID: resolvedParentID)
            if currentFolder.path != newFolder.path {
                try fs.ensureDirectory(newFolder.deletingLastPathComponent())
                try FileManager.default.moveItem(at: currentFolder, to: newFolder)
                updated.order = try pageIDs(parentID: resolvedParentID).count
            }
        }

        updated.updatedAt = Date()
        let destinationFolder = try resolvePageFolder(id: id)
        try writePageFiles(updated, in: destinationFolder)

        guard existing.parentID != resolvedParentID else { return }
        var oldIDs = try pageIDs(parentID: existing.parentID)
        oldIDs.removeAll { $0 == id }
        try persistChildOrdering(parentID: existing.parentID, childIDs: oldIDs)

        var newIDs = try pageIDs(parentID: resolvedParentID)
        newIDs.removeAll { $0 == id }
        let insertionIndex = min(max(updated.order, 0), newIDs.count)
        newIDs.insert(id, at: insertionIndex)
        try persistChildOrdering(parentID: resolvedParentID, childIDs: newIDs)
    }



    public func deletePage(id: String) throws {
        let folder = try resolvePageFolder(id: id)
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }
        try fs.moveToTrash(source: folder)
    }

    public func getPage(id: String) throws -> ExercisePageManifest {
        let folder = try resolvePageFolder(id: id)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        return try fs.readManifest(from: manifestURL, decoder: decoder)
    }

    public func searchPages(query: String, type: WorkoutType? = nil) throws -> [(ExercisePageManifest, path: String)] {
        let all = try walkPageTree(in: fs.exercisesDatabaseDirectory)
        var results: [(ExercisePageManifest, path: String)] = []
        for (manifest, path) in all {
            let titleMatch = query.isEmpty || manifest.title.localizedCaseInsensitiveContains(query)
            let contentMatch = query.isEmpty || manifest.markdownBody.localizedCaseInsensitiveContains(query)
            let typeMatch = type == nil || manifest.workoutType?.id == type?.id
            if (titleMatch || contentMatch) && typeMatch {
                results.append((manifest, path))
            }
        }
        return results
    }

    public func walkPageTree(in directory: URL) throws -> [(ExercisePageManifest, path: String)] {
        var results: [(ExercisePageManifest, path: String)] = []
        try walkPageTreeRecursive(directory, relativePath: "", into: &results)
        return results
    }

    private func walkPageTreeRecursive(_ directory: URL, relativePath: String, into results: inout [(ExercisePageManifest, path: String)]) throws {
        let entries = try fs.listDirectory(directory, skipNonSchema: false)
        for entry in entries {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }

            let manifestURL = entry.appendingPathComponent("manifest.json")
            let pageRelPath = relativePath.isEmpty ? entry.lastPathComponent : "\(relativePath)/\(entry.lastPathComponent)"

            if fs.fileExists(at: manifestURL) {
                if let manifest: ExercisePageManifest = try? fs.readManifest(from: manifestURL, decoder: decoder) {
                    var updatedManifest = manifest
                    let childDirs = try childDirectoryIDs(in: entry)
                    updatedManifest.childIDs = childDirs
                    results.append((updatedManifest, pageRelPath))
                }
            }
            try walkPageTreeRecursive(entry, relativePath: pageRelPath, into: &results)
        }
    }

    private func childDirectoryIDs(in directory: URL) throws -> [String] {
        let entries = try fs.listDirectory(directory, skipNonSchema: false)
        return entries.compactMap { entry in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { return nil }
            let manifestURL = entry.appendingPathComponent("manifest.json")
            guard fs.fileExists(at: manifestURL) else { return nil }
            return entry.lastPathComponent
        }
    }

    public func reorderChildren(parentID: String, childIDs: [String]) throws {
        let parentFolder = try resolvePageFolder(id: parentID)
        var manifest = try getPage(id: parentID)
        manifest.childIDs = childIDs
        manifest.updatedAt = Date()
        let manifestURL = parentFolder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
    }

    public func readGuideContent(pageID: String) throws -> String {
        let folder = try resolvePageFolder(id: pageID)
        let guideURL = folder.appendingPathComponent("guide.md")
        guard fs.fileExists(at: guideURL) else { return "" }
        let data = try fs.readRawData(from: guideURL)
        return String(data: data, encoding: .utf8) ?? ""
    }

    @discardableResult
    public func uploadCoverImage(pageID: String, sourceURL: URL) throws -> String {
        let folder = try resolvePageFolder(id: pageID)
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let filename = "cover.\(ext)"
        let dest = folder.appendingPathComponent(filename)
        if fs.fileExists(at: dest) {
            try fs.moveToTrash(source: dest)
        }
        try fs.copyItem(from: sourceURL, to: dest)
        var manifest = try getPage(id: pageID)
        manifest.coverImageFilename = filename
        manifest.updatedAt = Date()
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
        return filename
    }

    @discardableResult
    public func uploadMediaToPage(pageID: String, sourceURL: URL) throws -> String {
        let folder = try resolvePageFolder(id: pageID)
        let mediaDir = folder.appendingPathComponent("media", isDirectory: true)
        try fs.ensureDirectory(mediaDir)
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let uuid = UUID().uuidString
        let filename = "\(uuid).\(ext)"
        let dest = mediaDir.appendingPathComponent(filename)
        try fs.copyItem(from: sourceURL, to: dest)
        var manifest = try getPage(id: pageID)
        if manifest.mediaFilenames.count >= 20 { return filename }
        manifest.mediaFilenames.append(filename)
        manifest.updatedAt = Date()
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
        return filename
    }
    public func pageMediaURL(pageID: String, filename: String) throws -> URL {
        let folder = try resolvePageFolder(id: pageID)
        return folder
            .appendingPathComponent("media", isDirectory: true)
            .appendingPathComponent(filename)
    }

    public func pageCoverURL(pageID: String, filename: String) throws -> URL {
        let folder = try resolvePageFolder(id: pageID)
        return folder.appendingPathComponent(filename)
    }


    public func removeMediaFromPage(pageID: String, filename: String) throws {
        let folder = try resolvePageFolder(id: pageID)
        let mediaDir = folder.appendingPathComponent("media", isDirectory: true)
        let file = mediaDir.appendingPathComponent(filename)
        if fs.fileExists(at: file) {
            try fs.moveToTrash(source: file)
        }
        var manifest = try getPage(id: pageID)
        manifest.mediaFilenames.removeAll { $0 == filename }
        manifest.updatedAt = Date()
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
    }

    public func movePage(id: String, newParentID: String?, newOrder: Int) throws {
        let currentFolder = try resolvePageFolder(id: id)
        let existing = try getPage(id: id)
        let resolvedParent = newParentID

        if let resolvedParent {
            guard resolvedParent != id else {
                throw FileSystemHelper.Error.invalidPageKind("a page cannot be its own parent")
            }
            guard (try getPage(id: resolvedParent)).pageKind == .container else {
                throw FileSystemHelper.Error.invalidPageKind("pages can only be nested inside containers")
            }
            var ancestorID = try getPage(id: resolvedParent).parentID
            while let ancestor = ancestorID {
                guard ancestor != id else {
                    throw FileSystemHelper.Error.invalidPageKind("a page cannot be moved inside its own descendants")
                }
                ancestorID = try getPage(id: ancestor).parentID
            }
        }

        var moved = existing
        moved.parentID = resolvedParent
        moved.order = newOrder
        moved.updatedAt = Date()
        let normalized = normalizedPageManifest(moved, parentID: resolvedParent)
        try validatePageManifest(normalized, parentID: resolvedParent)

        let newFolder = try pageFolder(for: id, parentID: resolvedParent)
        if currentFolder.path != newFolder.path {
            try fs.ensureDirectory(newFolder.deletingLastPathComponent())
            try FileManager.default.moveItem(at: currentFolder, to: newFolder)
        }
        try writePageFiles(normalized, in: newFolder)

        if let oldParentID = existing.parentID {
            var oldParent = try getPage(id: oldParentID)
            oldParent.childIDs.removeAll { $0 == id }
            oldParent.updatedAt = Date()
            try writePageFiles(oldParent, in: try resolvePageFolder(id: oldParentID))
        }
        if let resolvedParent {
            var newParent = try getPage(id: resolvedParent)
            newParent.childIDs.removeAll { $0 == id }
            let insertionIndex = min(max(newOrder, 0), newParent.childIDs.count)
            newParent.childIDs.insert(id, at: insertionIndex)
            newParent.updatedAt = Date()
            try writePageFiles(newParent, in: try resolvePageFolder(id: resolvedParent))
        }
    }

    public func getPagePath(id: String) throws -> String {

        let allPages = try walkPageTree(in: fs.exercisesDatabaseDirectory)
        let pageLookup = Dictionary(uniqueKeysWithValues: allPages.map { ($0.0.id, ($0.0, $0.1)) })

        var pathComponents: [String] = []
        var current = pageLookup[id]
        while let (manifest, _) = current {
            pathComponents.insert(manifest.title, at: 0)
            if let parentID = manifest.parentID {
                current = pageLookup[parentID]
            } else {
                current = nil
            }
        }
        return pathComponents.joined(separator: "/")
    }

    public func listRootPages() throws -> [(name: String, path: String, manifest: ExercisePageManifest)] {
        let base = fs.exercisesDatabaseDirectory
        let entries = try fs.listDirectory(base, skipNonSchema: false)
        return entries.compactMap { entry in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { return nil }
            let manifestURL = entry.appendingPathComponent("manifest.json")
            guard fs.fileExists(at: manifestURL) else { return nil }
            guard let manifest: ExercisePageManifest = try? fs.readManifest(from: manifestURL, decoder: decoder) else { return nil }
            return (manifest.title, entry.lastPathComponent, manifest)
        }
    }

    private func pageFolder(for id: String, parentID: String?) throws -> URL {
        let base = fs.exercisesDatabaseDirectory
        if let parentID = parentID {
            let parentFolder = try resolvePageFolder(id: parentID)
            return parentFolder.appendingPathComponent(id, isDirectory: true)
        } else {
            return base.appendingPathComponent(id, isDirectory: true)
        }
    }

    private func resolvePageFolder(id: String) throws -> URL {
        let base = fs.exercisesDatabaseDirectory
        let directURL = base.appendingPathComponent(id, isDirectory: true)
        if fs.directoryExists(at: directURL) {
            return directURL
        }
        if let found = findPageFolder(id: id, in: base) {
            return found
        }
        return directURL
    }

    private func findPageFolder(id: String, in directory: URL) -> URL? {
        guard let entries = try? fs.listDirectory(directory, skipNonSchema: false) else { return nil }
        for entry in entries {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }
            if entry.lastPathComponent == id {
                return entry
            }
            if let found = findPageFolder(id: id, in: entry) {
                return found
            }
        }
        return nil
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
    // MARK: - Outdoor Activities

    private func outdoorActivityDirectory(_ id: String) -> URL {
        fs.outdoorActivitiesDirectory.appendingPathComponent(id, isDirectory: true)
    }

    public func createOutdoorActivity(id: String, manifest: OutdoorActivityManifest) throws {
        let folder = outdoorActivityDirectory(id)
        try fs.ensureDirectory(folder)
        try fs.writeAtomically(to: folder.appendingPathComponent("manifest.json"), value: manifest, encoder: encoder)
    }

    public func updateOutdoorActivity(id: String, manifest: OutdoorActivityManifest) throws {
        let folder = outdoorActivityDirectory(id)
        guard fs.directoryExists(at: folder) else { throw FileSystemHelper.Error.notFound(folder.path) }
        let manifestURL = folder.appendingPathComponent("manifest.json")
        if fs.fileExists(at: manifestURL) { try fs.moveToTrash(source: manifestURL) }
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)
    }

    public func getOutdoorActivity(id: String) throws -> OutdoorActivityManifest {
        try fs.readManifest(from: outdoorActivityDirectory(id).appendingPathComponent("manifest.json"), decoder: decoder)
    }

    public func listOutdoorActivities() throws -> [OutdoorActivityManifest] {
        let entries = try fs.listDirectory(fs.outdoorActivitiesDirectory)
        return entries.compactMap { entry in
            try? fs.readManifest(from: entry.appendingPathComponent("manifest.json"), decoder: decoder)
        }.sorted { $0.startedAt > $1.startedAt }
    }

    public func readOutdoorTrackPoints(id: String) throws -> [OutdoorTrackPoint] {
        let url = outdoorActivityDirectory(id).appendingPathComponent("track.jsonl")
        guard fs.fileExists(at: url) else { return [] }
        let data = try fs.readRawData(from: url)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            try? decoder.decode(OutdoorTrackPoint.self, from: Data(line.utf8))
        }
    }

    public func appendOutdoorTrackPoint(id: String, point: OutdoorTrackPoint) throws {
        let folder = outdoorActivityDirectory(id)
        guard fs.directoryExists(at: folder) else { throw FileSystemHelper.Error.notFound(folder.path) }
        let lineEncoder = JSONEncoder()
        lineEncoder.dateEncodingStrategy = .iso8601
        let line = try lineEncoder.encode(point)
        try fs.appendLineAtomically(to: folder.appendingPathComponent("track.jsonl"), data: line + Data([0x0A]))
    }

    public func deleteOutdoorActivity(id: String) throws {
        let folder = outdoorActivityDirectory(id)
        guard fs.directoryExists(at: folder) else { throw FileSystemHelper.Error.notFound(folder.path) }
        try fs.moveToTrash(source: folder)
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

    public func replaceHistory(_ entries: [HistoryEntry]) throws {
        let url = fs.historyDirectory.appendingPathComponent("entries.jsonl")
        let lines = try entries.map { entry -> String in
            guard let line = String(data: try encoder.encode(entry), encoding: .utf8) else {
                throw FileSystemHelper.Error.writeFailed(url.path)
            }
            return line.replacingOccurrences(of: "\n", with: "")
        }
        let content = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        try fs.writeAtomically(to: url, data: Data(content.utf8))
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

    // MARK: - Validation

    public func validateAll() -> [(path: String, valid: Bool, errors: [String], warnings: [String])] {
        return schemaManager.validateAll()
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
