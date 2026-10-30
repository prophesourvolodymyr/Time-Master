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

    let fs: FileSystemHelper
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

    public var routesDirectory: URL { fs.routesDirectory }

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
            fs.routesDirectory,
            fs.trashDirectory,
        ]
        for dir in dirs {
            try fs.ensureDirectory(dir)
        }
        try writeSchemaIfChanged()

        try bootstrapManagedFile(at: fs.agentsURL, content: bootstrapAgentsContent())
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("create-exercise.md"), content: bootstrapCreateExerciseContent())
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("build-workout.md"), content: bootstrapBuildWorkoutContent())
        try bootstrapManagedFile(at: fs.skillsDirectory.appendingPathComponent("search-database.md"), content: bootstrapSearchDatabaseContent())

        try bootstrapKnowledgeFile(name: "fitness-philosophy.md", title: "Fitness Philosophy")
        try bootstrapKnowledgeFile(name: "nutrition-rules.md", title: "Nutrition Rules")
        try bootstrapKnowledgeFile(name: "recovery-protocols.md", title: "Recovery Protocols")

        return fs.dataRoot
    }

    private func writeSchemaIfChanged() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(try schemaManager.generateSchema())
        if fs.fileExists(at: fs.schemaURL), (try? fs.readRawData(from: fs.schemaURL)) == data { return }
        try fs.writeAtomically(to: fs.schemaURL, data: data)
    }

    private func bootstrapManagedFile(at url: URL, content: String) throws {
        if fs.fileExists(at: url) {
            let existing = (try? fs.readRawData(from: url)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard existing.contains("timemaster-tool") else { return }
        }
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
# Tmax Data Directory

This is the local library behind Tmax, a fitness app.

## Structure
- **Exercises Database/** — pages: folders and exercises (manifest.json + guide.md, media in each page's media/)
- **Workouts/** — workout plans referencing exercise page ids
- **Media/** — legacy shared media storage
- **Knowledge/** — AI system prompt material (loaded on session start)
- **Workspace/** — free-form AI workspace (app ignores this)
- **skills/** — reusable agent skill definitions
- **Config/** — app configuration
- **History/** — workout history (JSONL)
- **Music/** — background music tracks
- **Backups/** — automatic backups
- **.trash/** — soft-deleted items

## How to Interact
Do not edit these files. Use the `tmax` command. It talks to the running Tmax app (and starts it if needed), so every change is validated and appears in the app immediately.

```
tmax context                  library overview and conventions (start here)
tmax tools                    every tool and its arguments
tmax <tool> --key value ...   run a tool; add --dry-run to validate without saving
tmax <tool> --json '{...}'    pass arguments as JSON (or - for stdin)
tmax batch plan.json          several operations, rolled back together if one fails
tmax undo                     reverse the last agent creations
tmax mcp                      serve the same tools over MCP (stdio)
```

Pages are referenced by title path, for example `"Lower Body/Glutes"` (an id also works). Media is attached by absolute local path and the app copies it: `tmax attach_media --page "Boxing/Jab" --path ~/clip.mp4`.

Replies are compact JSON: empty fields are left out and long lists stop at a limit with a `more` count, so narrow with `parent` or `query` instead of asking for everything. Creating, editing and moving run immediately. Deleting asks the user in the app, and deleted pages go to the trash.

## Schema
See `schema.json` for the data contract: page and workout fields and the tool list.

## Read/Write Rules
- **Read:** any directory is safe to read.
- **Write:** only through `tmax`. Never edit manifests by hand.
- **Workspace/:** free zone for agents; the app ignores it.
- **Never edit:** `schema.json`, `AGENTS.md`, or files inside `.trash/`.

## Skills
See `skills/` for step-by-step instructions for common tasks.
"""
    }

    private func bootstrapCreateExerciseContent() -> String {
        return """
# create-exercise
Create an exercise page in Tmax.

## Steps
1. `tmax context` to see the folders and workout types.
2. `tmax search_pages --query "<name>"` to avoid duplicates and find the parent folder.
3. `tmax create_exercise_page --title "<name>" --parent "<Folder/Path>" --duration 30 --markdown-body "<instructions>"`
4. Attach media in the same call with repeated `--media /abs/clip.mp4` flags (or `--json '{"title":"...","media":[{"path":"/abs/clip.mp4","comment":"..."}]}'` for captions), or later with `tmax attach_media`.
5. Add `--dry-run` first when unsure.
"""
    }

    private func bootstrapBuildWorkoutContent() -> String {
        return """
# build-workout
Assemble a workout from exercise pages.

## Steps
1. `tmax search_pages --query "<goal>" --kind exercise` to find exercise paths.
2. Choose order, duration, sets and rest.
3. `tmax build_workout --json '{"name":"...","type":"Strength","sections":[{"exercise":"<id or path>","duration":40,"sets":3}]}'`
4. `tmax get_workout --workout "<name>"` to confirm the total time.
"""
    }

    private func bootstrapSearchDatabaseContent() -> String {
        return """
# search-database
Find pages in the Tmax library.

## Steps
1. `tmax search_pages --query "<words>"` ranks matches by title, path and notes.
2. `tmax list_pages --parent "<Folder>" --depth 2` browses the tree.
3. `tmax get_page --page "<id or path>"` reads notes, timing, media and children.
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

    func normalizedPageManifest(_ manifest: ExercisePageManifest, parentID: String?) -> ExercisePageManifest {
        var normalized = manifest
        normalized.parentID = parentID

        let contentType = normalized.pageType
            ?? (normalized.pageKind == .leaf ? .exercise : nil)

        if contentType == .skill || contentType == .tutorial {
            normalized.pageKind = .container
            normalized.pageType = contentType
            normalized.duration = nil
            normalized.restAfter = nil
            normalized.prepareTime = nil
            normalized.sets = nil
            normalized.restBetweenSets = nil
            normalized.dropSetTemplates = []
            normalized.skillStatus = normalized.skillStatus ?? .notStarted
            normalized.skillBoardOrder = max(0, normalized.skillBoardOrder ?? 0)
            normalized.skillBoardSections = Self.renumberedSections(normalized.skillBoardSections)
            let parent = parentID.flatMap { try? getPage(id: $0) }
            let parentIsSkill = parent?.pageType == .skill || parent?.pageType == .tutorial
            normalized.typePresets = parentIsSkill ? [] : Self.renumberedTypePresets(normalized.typePresets)
            let media = Set(normalized.mediaFilenames)
            let links = Set(normalized.linkURLs)
            let icon = normalized.iconName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            normalized.iconName = icon.isEmpty ? nil : icon
            if normalized.iconName == nil { normalized.iconType = nil }
            if let picture = normalized.iconImage, !media.contains(picture), !Self.isWebImageReference(picture) {
                normalized.iconImage = nil
            }
            normalized.dependencyPageIDs = normalized.dependencyPageIDs.uniqued().filter { $0 != normalized.id }
            normalized.dependencyMediaFilenames = normalized.dependencyMediaFilenames.uniqued().filter(media.contains)
            normalized.dependencyLinkURLs = normalized.dependencyLinkURLs.uniqued().filter(links.contains)
        } else if contentType == .exercise {
            normalized.pageKind = .leaf
            normalized.pageType = .exercise
            normalized.coverImageFilename = nil
            normalized.childIDs = []
            normalized.skillStatus = nil
            normalized.skillBoardSectionID = nil
            normalized.skillBoardOrder = nil
            normalized.skillBoardSections = []
            normalized.linkedPageIDs = []
            normalized.iconName = nil
            normalized.iconType = nil
            normalized.iconImage = nil
            normalized.dependencyPageIDs = []
            normalized.dependencyMediaFilenames = []
            normalized.dependencyLinkURLs = []
            normalized.typePresets = []
            normalized.typeID = nil
        } else {
            normalized.pageKind = .container
            normalized.pageType = nil
            normalized.duration = nil
            normalized.restAfter = nil
            normalized.prepareTime = nil
            normalized.sets = nil
            normalized.restBetweenSets = nil
            normalized.dropSetTemplates = []
            normalized.skillStatus = nil
            normalized.skillBoardSectionID = nil
            normalized.skillBoardOrder = nil
            normalized.linkedPageIDs = []
            normalized.iconName = nil
            normalized.iconType = nil
            normalized.iconImage = nil
            normalized.dependencyPageIDs = []
            normalized.dependencyMediaFilenames = []
            normalized.dependencyLinkURLs = []
            normalized.typeID = nil
            normalized.skillBoardSections = Self.renumberedSections(normalized.skillBoardSections)
            normalized.typePresets = Self.renumberedTypePresets(normalized.typePresets)
            if parentID == nil {
                normalized.workoutType = normalized.workoutType ?? .other
            }
        }
        if !normalized.mediaComments.isEmpty {
            var filenames = Set(normalized.mediaFilenames)
            if let cover = normalized.coverImageFilename { filenames.insert(cover) }
            normalized.mediaComments = normalized.mediaComments.filter { filenames.contains($0.key) }
        }
        if let cover = normalized.coverMediaFilename, !normalized.mediaFilenames.contains(cover) {
            normalized.coverMediaFilename = nil
        }
        if !normalized.linkComments.isEmpty {
            let links = Set(normalized.linkURLs)
            normalized.linkComments = normalized.linkComments.filter {
                links.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        return normalized
    }

    /// Groups renumbered 0…n in their order (ties keep their stored order), each with its material tidied.
    static func renumberedSections(_ sections: [SkillBoardSection]) -> [SkillBoardSection] {
        sections.enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .enumerated()
            .map { position, item in
                var section = item.element.normalizedMaterial()
                section.order = position
                return section
            }
    }

    /// True for an http(s) image address a picture icon may point at instead of one of the page's media.
    static func isWebImageReference(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host != nil
    }

    /// Writes a page's `manifest.json` and its `guide.md` mirror. A group's content folder (see `SkillGroupID`) has
    /// neither: its material is written back into the group on its board page.
    func writePageFiles(_ manifest: ExercisePageManifest, in folder: URL) throws {
        if SkillGroupID.owner(ofContentFolder: folder) != nil {
            try writePageManifest(manifest, at: folder)
            return
        }
        let manifestURL = folder.appendingPathComponent("manifest.json")
        try fs.writeAtomically(to: manifestURL, value: manifest, encoder: encoder)

        let guideURL = folder.appendingPathComponent("guide.md")
        let guideContent = "# \(manifest.title)\n\n\(manifest.markdownBody.isEmpty ? "Add content here." : manifest.markdownBody)"
        try fs.writeAtomically(to: guideURL, data: guideContent.data(using: .utf8)!)
    }

    /// Reads the manifest of the page at `folder`; a group's content folder reads as the group's page.
    func readPageManifest(at folder: URL) throws -> ExercisePageManifest {
        if let owner = SkillGroupID.owner(ofContentFolder: folder) {
            let container: ExercisePageManifest = try fs.readManifest(
                from: owner.containerFolder.appendingPathComponent("manifest.json"),
                decoder: decoder
            )
            guard let section = container.skillBoardSection(owner.sectionID) else {
                throw FileSystemHelper.Error.notFound(SkillGroupID.make(containerID: container.id, sectionID: owner.sectionID))
            }
            return section.asPage(container: container, childIDs: [])
        }
        return try fs.readManifest(from: folder.appendingPathComponent("manifest.json"), decoder: decoder)
    }

    /// Writes only `manifest.json` of the page at `folder`; a group's page goes back into its group on the board page.
    func writePageManifest(_ manifest: ExercisePageManifest, at folder: URL) throws {
        if let owner = SkillGroupID.owner(ofContentFolder: folder) {
            var container: ExercisePageManifest = try fs.readManifest(
                from: owner.containerFolder.appendingPathComponent("manifest.json"),
                decoder: decoder
            )
            guard let index = container.skillBoardSections.firstIndex(where: { $0.id == owner.sectionID }) else {
                throw FileSystemHelper.Error.notFound(SkillGroupID.make(containerID: container.id, sectionID: owner.sectionID))
            }
            container.skillBoardSections[index].adopt(manifest)
            container.skillBoardSections[index] = container.skillBoardSections[index].normalizedMaterial()
            container.updatedAt = Date()
            try writePageFiles(container, in: owner.containerFolder)
            return
        }
        try fs.writeAtomically(to: folder.appendingPathComponent("manifest.json"), value: manifest, encoder: encoder)
    }

    private func validatePageManifest(_ manifest: ExercisePageManifest, parentID: String?) throws {
        if let parentID {
            guard parentID != manifest.id else {
                throw FileSystemHelper.Error.invalidPageKind("a page cannot be its own parent")
            }

            let parent = try getPage(id: parentID)
            guard parent.pageKind == .container else {
                throw FileSystemHelper.Error.invalidPageKind("pages can only be nested inside pages that allow children")
            }

            var ancestorID = parent.parentID
            while let ancestor = ancestorID {
                guard ancestor != manifest.id else {
                    throw FileSystemHelper.Error.invalidPageKind("a page cannot be moved inside its own descendants")
                }
                ancestorID = try getPage(id: ancestor).parentID
            }
        }

        guard !manifest.linkedPageIDs.contains(manifest.id) else {
            throw FileSystemHelper.Error.invalidPageKind("a page cannot attach itself")
        }

        let contentType = manifest.pageType
            ?? (manifest.pageKind == .leaf ? .exercise : nil)
        switch contentType {
        case .exercise:
            guard manifest.pageKind == .leaf else {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages cannot contain child pages")
            }
            if manifest.coverImageFilename != nil {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages use their first media item as the cover")
            }
            guard manifest.duration != nil else {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages require a duration")
            }
            if !manifest.childIDs.isEmpty {
                throw FileSystemHelper.Error.invalidPageKind("exercise pages cannot contain child pages")
            }
        case .skill, .tutorial:
            if manifest.duration != nil || manifest.restAfter != nil || manifest.prepareTime != nil || manifest.sets != nil || manifest.restBetweenSets != nil {
                throw FileSystemHelper.Error.invalidPageKind("skill and tutorial pages do not have workout timing")
            }
        case nil:
            guard manifest.pageKind == .container else {
                throw FileSystemHelper.Error.invalidPageKind("untyped pages must be containers")
            }
            if manifest.duration != nil || manifest.restAfter != nil || manifest.prepareTime != nil || manifest.sets != nil || manifest.restBetweenSets != nil {
                throw FileSystemHelper.Error.invalidPageKind("containers cannot have workout timing")
            }
        }
    }

    private func migrateLegacyCoverIfNeeded(
        existing: ExercisePageManifest,
        updated: ExercisePageManifest,
        in folder: URL
    ) throws {
        guard let legacyFilename = existing.coverImageFilename else { return }

        let legacyURL = folder.appendingPathComponent(legacyFilename)
        let mediaDirectory = folder.appendingPathComponent("media", isDirectory: true)
        let mediaURL = mediaDirectory.appendingPathComponent(legacyFilename)

        if updated.mediaFilenames.contains(legacyFilename) {
            try fs.ensureDirectory(mediaDirectory)
            if fs.fileExists(at: legacyURL) && !fs.fileExists(at: mediaURL) {
                try FileManager.default.moveItem(at: legacyURL, to: mediaURL)
            } else if fs.fileExists(at: legacyURL), fs.fileExists(at: mediaURL) {
                try fs.moveToTrash(source: legacyURL)
            }
        } else if fs.fileExists(at: legacyURL) {
            try fs.moveToTrash(source: legacyURL)
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

    /// Creates a page. `parentID` may be a group id (see `SkillGroupID`): the page is created on the group's board
    /// page, inside that group, at the end of it.
    public func createPage(manifest: ExercisePageManifest, parentID: String? = nil) throws {
        if let owner = (parentID ?? manifest.parentID).flatMap(SkillGroupID.split) {
            try createPage(manifest, inGroup: owner.sectionID, of: owner.containerID)
            return
        }
        let resolvedParentID = parentID ?? manifest.parentID
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

    /// Updates a page. `id` may be a group id: the group keeps the title, icon, notes, media, links, comments,
    /// prerequisites and cover (its strip picture) of `manifest`; its colour and place change with `updateSkillGroup`.
    public func updatePage(id: String, manifest: ExercisePageManifest, newParentID: String? = nil) throws {
        if SkillGroupID.split(id) != nil {
            var page = manifest
            page.id = id
            page.dependencyPageIDs.removeAll { $0 == id }
            try writePageManifest(page, at: try resolvePageFolder(id: id))
            return
        }
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
        try migrateLegacyCoverIfNeeded(existing: existing, updated: updated, in: currentFolder)

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
        guard SkillGroupID.split(id) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("a group is removed from its board with deleteSkillGroup")
        }
        let folder = try resolvePageFolder(id: id)
        guard fs.directoryExists(at: folder) else {
            throw FileSystemHelper.Error.notFound(folder.path)
        }

        let page = try getPage(id: id)
        let parentContext: (
            original: ExercisePageManifest,
            updated: ExercisePageManifest,
            folder: URL
        )?
        if let parentID = page.parentID {
            let originalParent = try getPage(id: parentID)
            let parentFolder = try resolvePageFolder(id: parentID)
            var updatedParent = originalParent
            updatedParent.childIDs.removeAll { $0 == id }
            updatedParent.updatedAt = Date()
            parentContext = (
                original: originalParent,
                updated: updatedParent,
                folder: parentFolder
            )
        } else {
            parentContext = nil
        }

        guard let parentContext else {
            try fs.moveToTrash(source: folder)
            return
        }

        let trashedFolder = try fs.moveToTrashReturningURL(source: folder)
        do {
            try fs.writeAtomically(
                to: parentContext.folder.appendingPathComponent("manifest.json"),
                value: parentContext.updated,
                encoder: encoder
            )
        } catch {
            var rollbackErrors: [String] = []

            do {
                try fs.writeAtomically(
                    to: parentContext.folder.appendingPathComponent("manifest.json"),
                    value: parentContext.original,
                    encoder: encoder
                )
            } catch {
                rollbackErrors.append(error.localizedDescription)
            }

            do {
                guard !fs.directoryExists(at: folder) else {
                    throw FileSystemHelper.Error.writeFailed(folder.path)
                }
                try FileManager.default.moveItem(at: trashedFolder, to: folder)
            } catch {
                rollbackErrors.append(error.localizedDescription)
            }

            guard rollbackErrors.isEmpty else {
                throw FileSystemHelper.Error.writeFailed(
                    "Page deletion failed: \(error.localizedDescription) Rollback failed: \(rollbackErrors.joined(separator: " "))"
                )
            }
            throw error
        }
    }

    /// The manifest of a page. A group id reads as the group's page (pageType skill, parent = the board page; its
    /// `childIDs` are empty here: the pages inside a group are the board page's skill children placed in it).
    public func getPage(id: String) throws -> ExercisePageManifest {
        try readPageManifest(at: try resolvePageFolder(id: id))
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
            guard isDir.boolValue,
                  entry.lastPathComponent != "media",
                  entry.lastPathComponent != "Attachments",
                  entry.lastPathComponent != SkillGroupID.folderName else { continue }

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
            guard isDir.boolValue,
                  entry.lastPathComponent != "media",
                  entry.lastPathComponent != "Attachments",
                  entry.lastPathComponent != SkillGroupID.folderName else { return nil }
            let manifestURL = entry.appendingPathComponent("manifest.json")
            guard fs.fileExists(at: manifestURL) else { return nil }
            return entry.lastPathComponent
        }
    }

    public func reorderChildren(parentID: String, childIDs: [String]) throws {
        guard SkillGroupID.split(parentID) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("the pages of a group are ordered on its board")
        }
        let parentFolder = try resolvePageFolder(id: parentID)
        var manifest = try getPage(id: parentID)
        manifest.childIDs = childIDs
        manifest.updatedAt = Date()
        try writePageManifest(manifest, at: parentFolder)
    }

    /// Saves a board page's groups and where its skill pages sit. Groups keep all their material; a page whose place
    /// did not change is not rewritten; the media folders of groups that are gone move to the trash.
    public func updateSkillBoard(
        containerID: String,
        sections: [SkillBoardSection],
        placements: [SkillBoardPlacement]
    ) throws {
        guard SkillGroupID.split(containerID) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("a group cannot hold groups")
        }
        var container = try getPage(id: containerID)
        guard container.pageKind == .container else {
            throw FileSystemHelper.Error.invalidPageKind("skill boards belong to pages that allow children")
        }

        let kept = sections.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard kept.allSatisfy({ SkillGroupID.isUsableSectionID($0.id) }), Set(kept.map(\.id)).count == kept.count else {
            throw FileSystemHelper.Error.writeFailed("skill board groups need distinct, usable ids")
        }
        let normalizedSections = kept.enumerated().map { index, section in
            var section = section.normalizedMaterial()
            section.order = index
            return section
        }
        let sectionIDs = Set(normalizedSections.map(\.id))
        let childIDs = Set(container.childIDs)

        for placement in placements {
            guard childIDs.contains(placement.pageID) else {
                throw FileSystemHelper.Error.invalidPageKind("skill board items must be direct child pages")
            }
            guard placement.sectionID == nil || sectionIDs.contains(placement.sectionID!) else {
                throw FileSystemHelper.Error.writeFailed("skill board placement references an unknown section")
            }
            var page = try getPage(id: placement.pageID)
            guard page.pageType == .skill || page.pageType == .tutorial else {
                throw FileSystemHelper.Error.invalidPageKind("only skills and tutorials can be placed on a skill board")
            }
            let order = max(0, placement.order)
            guard page.skillStatus != placement.status
                    || page.skillBoardSectionID != placement.sectionID
                    || page.skillBoardOrder != order else { continue }
            page.skillStatus = placement.status
            page.skillBoardSectionID = placement.sectionID
            page.skillBoardOrder = order
            page.updatedAt = Date()
            try writePageFiles(page, in: try resolvePageFolder(id: placement.pageID))
        }

        let containerFolder = try resolvePageFolder(id: containerID)
        let removedSectionIDs = Set(container.skillBoardSections.map(\.id)).subtracting(sectionIDs)
        container.skillBoardSections = normalizedSections
        container.updatedAt = Date()
        try writePageFiles(container, in: containerFolder)
        for sectionID in removedSectionIDs where SkillGroupID.isUsableSectionID(sectionID) {
            let content = SkillGroupID.contentFolder(containerFolder: containerFolder, sectionID: sectionID)
            if fs.directoryExists(at: content) { try fs.moveToTrash(source: content) }
        }
    }

    /// The page's notes as Markdown: its `guide.md` mirror; a group has no mirror and answers with its notes.
    public func readGuideContent(pageID: String) throws -> String {
        if SkillGroupID.split(pageID) != nil {
            return try getPage(id: pageID).markdownBody
        }
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
        try writePageManifest(manifest, at: folder)
        return filename
    }

    @discardableResult
    public func uploadMediaToPage(pageID: String, sourceURL: URL) throws -> String {
        let folder = try resolvePageFolder(id: pageID)
        let mediaDir = folder.appendingPathComponent("media", isDirectory: true)
        try fs.ensureDirectory(mediaDir)
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let manifest = try getPage(id: pageID)
        guard manifest.mediaFilenames.count < 20 else {
            throw FileSystemHelper.Error.writeFailed("A page can contain up to 20 media items.")
        }
        let destination = mediaDir.appendingPathComponent(filename)
        try fs.copyItem(from: sourceURL, to: destination)
        var updatedManifest = manifest
        updatedManifest.mediaFilenames.append(filename)
        updatedManifest.updatedAt = Date()
        try writePageManifest(updatedManifest, at: folder)
        return filename
    }

    public func updateMediaComment(pageID: String, filename: String, comment: String) throws {
        var manifest = try getPage(id: pageID)
        guard manifest.mediaFilenames.contains(filename) || manifest.coverImageFilename == filename else {
            throw FileSystemHelper.Error.notFound(filename)
        }
        manifest.mediaComments[filename] = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
        manifest.updatedAt = Date()
        try writePageManifest(manifest, at: try resolvePageFolder(id: pageID))
    }

    public func reorderPageMedia(pageID: String, filenames: [String]) throws {
        let folder = try resolvePageFolder(id: pageID)
        var manifest = try getPage(id: pageID)
        let allowed = Set(manifest.mediaFilenames)
        let reordered = filenames.filter { allowed.contains($0) }
        guard Set(reordered) == allowed, reordered.count == allowed.count else {
            throw FileSystemHelper.Error.writeFailed("Media order must contain every existing media item exactly once.")
        }
        manifest.mediaFilenames = reordered
        manifest.updatedAt = Date()
        try writePageManifest(manifest, at: folder)
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
        manifest.mediaComments.removeValue(forKey: filename)
        manifest.dependencyMediaFilenames.removeAll { $0 == filename }
        if manifest.coverMediaFilename == filename { manifest.coverMediaFilename = nil }
        if manifest.iconImage == filename { manifest.iconImage = nil }
        manifest.updatedAt = Date()
        try writePageManifest(manifest, at: folder)
    }

    public func movePage(id: String, newParentID: String?, newOrder: Int) throws {
        guard SkillGroupID.split(id) == nil, newParentID.flatMap(SkillGroupID.split) == nil else {
            throw FileSystemHelper.Error.invalidPageKind("groups stay on their board; place pages in a group with updateSkillBoard")
        }
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

    func pageFolder(for id: String, parentID: String?) throws -> URL {
        let base = fs.exercisesDatabaseDirectory
        if let parentID = parentID {
            let parentFolder = try resolvePageFolder(id: parentID)
            return parentFolder.appendingPathComponent(id, isDirectory: true)
        } else {
            return base.appendingPathComponent(id, isDirectory: true)
        }
    }

    /// Folder of a page. A group id resolves to the group's content folder under its board page
    /// (`<board page>/Sections/<section id>`, created when the group gets its first media file).
    func resolvePageFolder(id: String) throws -> URL {
        if let owner = SkillGroupID.split(id) {
            guard SkillGroupID.isUsableSectionID(owner.sectionID) else {
                throw FileSystemHelper.Error.notFound(id)
            }
            let containerFolder = try resolvePageFolder(id: owner.containerID)
            let container = try readPageManifest(at: containerFolder)
            guard container.skillBoardSection(owner.sectionID) != nil else {
                throw FileSystemHelper.Error.notFound(id)
            }
            return SkillGroupID.contentFolder(containerFolder: containerFolder, sectionID: owner.sectionID)
        }
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
        let decoder = OutdoorTrackPoint.makeJSONDecoder()
        return text.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            try? decoder.decode(OutdoorTrackPoint.self, from: Data(line.utf8))
        }
    }

    public func appendOutdoorTrackPoint(id: String, point: OutdoorTrackPoint) throws {
        let folder = outdoorActivityDirectory(id)
        guard fs.directoryExists(at: folder) else { throw FileSystemHelper.Error.notFound(folder.path) }
        let lineEncoder = OutdoorTrackPoint.makeJSONEncoder()
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
