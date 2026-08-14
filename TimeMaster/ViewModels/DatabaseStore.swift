import Foundation
import TimeMasterCore

class DatabaseStore: ObservableObject {
    static let shared = DatabaseStore()

    @Published var rootPages: [ExercisePage] = []
    @Published var allPagesFlat: [ExercisePage] = []

    private let foldersKey       = "exercise_database_v2"
    private let rootNotesKey     = "exercise_database_root_notes_v1"
    private let rootExercisesKey = "exercise_database_root_exercises_v1"
    private let legacyDatabaseKeys = [
        "exercise_database_v2",
        "exercise_database_root_notes_v1",
        "exercise_database_root_exercises_v1"
    ]
    private var reloadWorkItem: DispatchWorkItem?

    @Published var rootFolders: [ExerciseFolder] = []
    @Published var rootNotes: [DatabaseNote] = []
    @Published var rootExercises: [Exercise] = []

    private var isV1Migrated: Bool { MigrationManager.isMigrationComplete }
    private var isV2PageMigrated: Bool { MigrationManager.isV2PageMigrationComplete }

    private init() {
        legacyDatabaseKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        if isV2PageMigrated {
            loadPagesFromFileSystem()
        } else if isV1Migrated {
            loadFromFileSystem()
        } else {
            load()
        }
    }

    func reload() {
        reloadWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let snapshot: (() -> Void)? = {
                if self.isV2PageMigrated {
                    let snapshot = self.pageSnapshotFromFileSystem()
                    return {
                        self.allPagesFlat = snapshot.flat
                        self.rootPages = snapshot.roots
                    }
                }

                if self.isV1Migrated {
                    let snapshot = self.legacySnapshotFromFileSystem()
                    return {
                        self.rootFolders = snapshot.folders
                        self.rootExercises = snapshot.exercises
                    }
                }

                let folders = self.defaultFolders()
                return {
                    self.rootFolders = folders
                }
            }()

            guard let snapshot else { return }
            DispatchQueue.main.async(execute: snapshot)
        }

        reloadWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    func reloadImmediately() {
        reloadWorkItem?.cancel()

        if isV2PageMigrated {
            let snapshot = pageSnapshotFromFileSystem()
            allPagesFlat = snapshot.flat
            rootPages = snapshot.roots
        } else if isV1Migrated {
            let snapshot = legacySnapshotFromFileSystem()
            rootFolders = snapshot.folders
            rootExercises = snapshot.exercises
        } else {
            rootFolders = defaultFolders()
        }
    }

    // MARK: - V2 Page Loading

    private func loadPagesFromFileSystem() {
        let snapshot = pageSnapshotFromFileSystem()
        allPagesFlat = snapshot.flat
        rootPages = snapshot.roots
    }

    private func pageSnapshotFromFileSystem() -> (flat: [ExercisePage], roots: [ExercisePage]) {
        let db = DatabaseManager.shared
        let base = db.exercisesDatabaseURL
        let flatManifests: [(ExercisePageManifest, String)]

        do {
            flatManifests = try db.walkPageTree(in: base)
        } catch {
            return ([], [])
        }

        let rawPages = flatManifests.map { (manifest, path) in
            let pageURL = base.appendingPathComponent(path, isDirectory: true)
            return ExercisePage(from: manifest, baseURL: pageURL, path: path)
        }
        let lookup = Dictionary(uniqueKeysWithValues: rawPages.map { ($0.id, $0) })
        let flat = rawPages.map { page in
            ExercisePage(
                manifest: page.manifest,
                coverImageURL: page.coverImageURL,
                mediaURLs: page.mediaURLs,
                path: page.path,
                inheritedWorkoutType: inheritedWorkoutType(for: page, lookup: lookup)
            )
        }
        return (flat, PageTreeBuilder.build(from: flat))
    }

    private func inheritedWorkoutType(
        for page: ExercisePage,
        lookup: [UUID: ExercisePage]
    ) -> TimeMasterCore.WorkoutType? {
        var currentID = page.manifest.parentID.flatMap(UUID.init(uuidString:))
        while let id = currentID, let parent = lookup[id] {
            if let type = parent.manifest.workoutType {
                return type
            }
            currentID = parent.manifest.parentID.flatMap(UUID.init(uuidString:))
        }
        return nil
    }

    var pageTree: [ExercisePage] {
        PageTreeBuilder.build(from: allPagesFlat)
    }

    func page(id: UUID) -> ExercisePage? {
        allPagesFlat.first { $0.id == id }
    }

    func children(of parentID: UUID) -> [ExercisePage] {
        guard let parent = page(id: parentID) else { return [] }
        return parent.manifest.childIDs.compactMap { childID in
            guard let childUUID = UUID(uuidString: childID) else { return nil }
            return page(id: childUUID)
        }
    }

    func breadcrumbs(for pageID: UUID) -> [ExercisePage] {
        PageTreeBuilder.breadcrumbs(for: pageID, in: allPagesFlat)
    }

    // MARK: - Page CRUD (V2)

    func createPage(manifest: ExercisePageManifest, parentID: String?) throws {
        var persistedManifest = manifest
        persistedManifest.parentID = parentID ?? manifest.parentID
        try DatabaseManager.shared.createPage(manifest: persistedManifest, parentID: parentID)
        publishCreatedPage(persistedManifest)
    }

    func updatePage(id: String, manifest: ExercisePageManifest, newParentID: String?) throws {
        try DatabaseManager.shared.updatePage(id: id, manifest: manifest, newParentID: newParentID)
        reload()
    }

    func deletePage(id: String) throws {
        try DatabaseManager.shared.deletePage(id: id)
        reload()
    }

    func createPageWithMedia(
        manifest: ExercisePageManifest,
        parentID: String?,
        coverData: Data?,
        mediaData: [(filename: String, data: Data)]
    ) throws {
        var persistedManifest = manifest
        persistedManifest.parentID = parentID ?? manifest.parentID
        if !mediaData.isEmpty {
            persistedManifest.mediaFilenames = []
        }
        try DatabaseManager.shared.createPage(manifest: persistedManifest, parentID: parentID)
        publishCreatedPage(persistedManifest)

        let pageID = persistedManifest.id
        let coverUpload = coverData.flatMap { data -> (String, Data)? in
            guard let filename = persistedManifest.coverImageFilename else { return nil }
            return (filename, data)
        }
        guard coverUpload != nil || !mediaData.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            if let (filename, data) = coverUpload {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + filename)
                do {
                    try data.write(to: tempURL)
                    let uploadedFilename = try DatabaseManager.shared.uploadCoverImage(
                        pageID: pageID,
                        sourceURL: tempURL
                    )
                    self.publishUploadedMedia(pageID: pageID, coverFilename: uploadedFilename)
                } catch {}
                try? FileManager.default.removeItem(at: tempURL)
            }

            for (filename, data) in mediaData {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + filename)
                do {
                    try data.write(to: tempURL)
                    let uploadedFilename = try DatabaseManager.shared.uploadMediaToPage(
                        pageID: pageID,
                        sourceURL: tempURL
                    )
                    self.publishUploadedMedia(pageID: pageID, mediaFilenames: [uploadedFilename])
                } catch {}
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    func publishUploadedMedia(
        pageID: String,
        coverFilename: String? = nil,
        mediaFilenames: [String] = []
    ) {
        let update = { [weak self] in
            guard let self, let index = self.allPagesFlat.firstIndex(where: { $0.manifest.id == pageID }) else { return }
            var manifest = self.allPagesFlat[index].manifest
            if let coverFilename {
                manifest.coverImageFilename = coverFilename
            }
            for filename in mediaFilenames where !manifest.mediaFilenames.contains(filename) {
                manifest.mediaFilenames.append(filename)
            }

            let currentPage = self.allPagesFlat[index]
            let coverURL: URL?
            if manifest.pageKind == .container, let filename = manifest.coverImageFilename {
                coverURL = try? DatabaseManager.shared.pageCoverURL(pageID: pageID, filename: filename)
            } else if manifest.pageKind == .leaf, let filename = manifest.mediaFilenames.first {
                coverURL = try? DatabaseManager.shared.pageMediaURL(pageID: pageID, filename: filename)
            } else {
                coverURL = nil
            }
            let mediaURLs = manifest.mediaFilenames.compactMap {
                try? DatabaseManager.shared.pageMediaURL(pageID: pageID, filename: $0)
            }
            self.allPagesFlat[index] = ExercisePage(
                manifest: manifest,
                coverImageURL: coverURL,
                mediaURLs: mediaURLs,
                path: currentPage.path,
                inheritedWorkoutType: currentPage.inheritedWorkoutType
            )
            self.rootPages = PageTreeBuilder.build(from: self.allPagesFlat)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
    
    func updatePageMedia(
        pageID: String,
        coverFilename: String? = nil,
        mediaFilenames: [String] = []
    ) {
        publishUploadedMedia(
            pageID: pageID,
            coverFilename: coverFilename,
            mediaFilenames: mediaFilenames
        )
    }

    func reorderChildren(parentID: String, childIDs: [String]) throws {
        try DatabaseManager.shared.reorderChildren(parentID: parentID, childIDs: childIDs)
        reload()
    }

    func persistRootPageOrder() {
        for (index, page) in rootPages.enumerated() {
            var updatedManifest = page.manifest
            updatedManifest.order = index
            do {
                try DatabaseManager.shared.updatePage(id: updatedManifest.id, manifest: updatedManifest, newParentID: nil)
            } catch {}
        }
        reload()
    }

    func movePage(id: String, newParentID: String?, newOrder: Int) throws {
        try DatabaseManager.shared.movePage(id: id, newParentID: newParentID, newOrder: newOrder)
        reload()
    }

    func duplicatePage(_ page: ExercisePage) throws {
        var newManifest = page.manifest
        newManifest.id = UUID().uuidString
        newManifest.title = "\(page.title) Copy"
        newManifest.createdAt = Date()
        newManifest.updatedAt = Date()
        newManifest.childIDs = []
        newManifest.parentID = page.manifest.parentID
        newManifest.order = page.manifest.order + 1
        try DatabaseManager.shared.createPage(manifest: newManifest, parentID: page.manifest.parentID)

        if let coverFilename = page.manifest.coverImageFilename {
            let sourceDir = DatabaseManager.shared.exercisesDatabaseURL
            if let existingFolder = resolvePageFolderURL(id: page.manifest.id) {
                let sourceURL = existingFolder.appendingPathComponent(coverFilename)
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try? DatabaseManager.shared.uploadCoverImage(pageID: newManifest.id, sourceURL: sourceURL)
                }
            }
        }

        for filename in page.manifest.mediaFilenames {
            if let existingFolder = resolvePageFolderURL(id: page.manifest.id) {
                let sourceURL = existingFolder.appendingPathComponent("media", isDirectory: true).appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try? DatabaseManager.shared.uploadMediaToPage(pageID: newManifest.id, sourceURL: sourceURL)
                }
            }
        }

        reload()
    }

    private func resolvePageFolderURL(id: String) -> URL? {
        let base = DatabaseManager.shared.exercisesDatabaseURL
        func find(in dir: URL) -> URL? {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
            for entry in entries {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
                guard isDir.boolValue else { continue }
                if entry.lastPathComponent == id { return entry }
                if let found = find(in: entry) { return found }
            }
            return nil
        }
        return find(in: base)
    }
    
    private func publishCreatedPage(_ manifest: ExercisePageManifest) {
        let publish = { [weak self] in
            guard let self else { return }

            var pages = self.allPagesFlat
            let parentUUID = manifest.parentID.flatMap(UUID.init(uuidString:))
            let inheritedType = parentUUID.flatMap { self.page(id: $0)?.effectiveWorkoutType }

            if let parentUUID,
               let parentIndex = pages.firstIndex(where: { $0.id == parentUUID }) {
                var parentManifest = pages[parentIndex].manifest
                if !parentManifest.childIDs.contains(manifest.id) {
                    parentManifest.childIDs.append(manifest.id)
                }
                pages[parentIndex] = ExercisePage(
                    manifest: parentManifest,
                    coverImageURL: pages[parentIndex].coverImageURL,
                    mediaURLs: pages[parentIndex].mediaURLs,
                    path: pages[parentIndex].path,
                    inheritedWorkoutType: pages[parentIndex].inheritedWorkoutType
                )
            }

            let page = ExercisePage(
                manifest: manifest,
                inheritedWorkoutType: inheritedType
            )
            if let pageIndex = pages.firstIndex(where: { $0.id == page.id }) {
                pages[pageIndex] = page
            } else {
                pages.append(page)
            }
            self.allPagesFlat = pages
            self.rootPages = PageTreeBuilder.build(from: pages)
        }

        if Thread.isMainThread {
            publish()
        } else {
            DispatchQueue.main.async(execute: publish)
        }
    }

    // MARK: - V1 Legacy (backward compatible)

    private func loadFromFileSystem() {
        let snapshot = legacySnapshotFromFileSystem()
        rootFolders = snapshot.folders
        rootExercises = snapshot.exercises
        rootNotes = []
    }

    private func legacySnapshotFromFileSystem() -> (folders: [ExerciseFolder], exercises: [Exercise]) {
        let db = DatabaseManager.shared
        let base = db.exercisesDatabaseURL
        let fs = FileSystemHelper(dataRoot: db.dataRoot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return walkExerciseDirectory(base, fs: fs, decoder: decoder)
    }

    private func walkExerciseDirectory(
        _ dir: URL,
        fs: FileSystemHelper,
        decoder: JSONDecoder,
        parentPath: String = ""
    ) -> (folders: [ExerciseFolder], exercises: [Exercise]) {
        var folders: [ExerciseFolder] = []
        var exercises: [Exercise] = []

        let entries = (try? fs.listDirectory(dir, skipNonSchema: false)) ?? []
        for entry in entries {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }

            let manifestURL = entry.appendingPathComponent("manifest.json")
            if fs.fileExists(at: manifestURL) {
                if let manifest: ExerciseManifest = try? fs.readManifest(from: manifestURL, decoder: decoder) {
                    exercises.append(convertExercise(manifest))
                }
            } else {
                let name = entry.lastPathComponent
                let childPath = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
                let (subfolders, subExercises) = walkExerciseDirectory(entry, fs: fs, decoder: decoder, parentPath: childPath)

                var folder = ExerciseFolder(name: name)
                folder.subfolders = subfolders
                folder.exercises = subExercises
                folders.append(folder)
            }
        }

        return (folders, exercises)
    }

    private func convertExercise(_ manifest: ExerciseManifest) -> Exercise {
        let mediaItems: [MediaItem]
        if !manifest.mediaFilenames.isEmpty {
            mediaItems = manifest.mediaFilenames.map { MediaItem(filename: $0, type: .photo) }
        } else {
            mediaItems = []
        }
        return Exercise(
            id: UUID(uuidString: manifest.id) ?? UUID(),
            name: manifest.name,
            description: manifest.details,
            duration: manifest.duration,
            restAfter: manifest.restAfter,
            mediaItems: mediaItems
        )
    }

    // MARK: - V0 Legacy (UserDefaults, pre-migration)

    func load() {
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([ExerciseFolder].self, from: data) {
            rootFolders = decoded
        } else {
            rootFolders = defaultFolders()
            saveFolders()
        }

        if let data = UserDefaults.standard.data(forKey: rootNotesKey),
           let decoded = try? JSONDecoder().decode([DatabaseNote].self, from: data) {
            rootNotes = decoded
        }

        if let data = UserDefaults.standard.data(forKey: rootExercisesKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            rootExercises = decoded
        }
    }

    func save() {
        saveFolders()
        saveRootNotes()
        saveRootExercises()
    }

    private func saveFolders() {
        if let encoded = try? JSONEncoder().encode(rootFolders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
    }

    private func saveRootNotes() {
        if let encoded = try? JSONEncoder().encode(rootNotes) {
            UserDefaults.standard.set(encoded, forKey: rootNotesKey)
        }
    }

    private func saveRootExercises() {
        if let encoded = try? JSONEncoder().encode(rootExercises) {
            UserDefaults.standard.set(encoded, forKey: rootExercisesKey)
        }
    }

    // MARK: - Folder lookup

    func folder(id: UUID) -> ExerciseFolder? {
        findFolder(id: id, in: rootFolders)
    }

    private func findFolder(id: UUID, in folders: [ExerciseFolder]) -> ExerciseFolder? {
        for f in folders {
            if f.id == id { return f }
            if let found = findFolder(id: id, in: f.subfolders) { return found }
        }
        return nil
    }

    // MARK: - Root folder CRUD

    func addRootFolder(name: String, colorHex: String = "FFFFFF", workoutType: WorkoutType? = nil) {
        var folder = ExerciseFolder(name: name, colorHex: colorHex)
        folder.workoutType = workoutType
        rootFolders.append(folder)
        saveFolders()
    }

    func deleteRootFolder(id: UUID) {
        rootFolders.removeAll { $0.id == id }
        saveFolders()
    }

    func renameFolder(id: UUID, newName: String) {
        updateFolder(id: id) { $0.name = newName }
    }

    // MARK: - Subfolder CRUD

    func addSubfolder(name: String, toFolderID parentID: UUID, colorHex: String = "FFFFFF", workoutType: WorkoutType? = nil) {
        var folder = ExerciseFolder(name: name, colorHex: colorHex)
        folder.workoutType = workoutType
        updateFolder(id: parentID) { $0.subfolders.append(folder) }
    }

    func deleteSubfolder(id: UUID, fromParentID parentID: UUID) {
        updateFolder(id: parentID) { $0.subfolders.removeAll { $0.id == id } }
    }

    // MARK: - Exercise CRUD (in folder)

    func addExercise(_ exercise: Exercise, toFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.exercises.append(exercise) }
    }

    func updateExercise(_ exercise: Exercise, inFolderID folderID: UUID) {
        updateFolder(id: folderID) { folder in
            if let idx = folder.exercises.firstIndex(where: { $0.id == exercise.id }) {
                folder.exercises[idx] = exercise
            }
        }
    }

    func deleteExercise(id: UUID, fromFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.exercises.removeAll { $0.id == id } }
    }

    // MARK: - Root Exercise CRUD

    func addRootExercise(_ exercise: Exercise) {
        rootExercises.append(exercise)
        saveRootExercises()
    }

    func updateRootExercise(_ exercise: Exercise) {
        if let idx = rootExercises.firstIndex(where: { $0.id == exercise.id }) {
            rootExercises[idx] = exercise
        }
        saveRootExercises()
    }

    func deleteRootExercise(id: UUID) {
        rootExercises.removeAll { $0.id == id }
        saveRootExercises()
    }

    // MARK: - Note CRUD (in folder)

    func addNote(_ note: DatabaseNote, toFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.notes.append(note) }
    }

    func updateNote(_ note: DatabaseNote, inFolderID folderID: UUID) {
        updateFolder(id: folderID) { folder in
            if let idx = folder.notes.firstIndex(where: { $0.id == note.id }) {
                folder.notes[idx] = note
            }
        }
    }

    func deleteNote(id: UUID, fromFolderID folderID: UUID) {
        updateFolder(id: folderID) { $0.notes.removeAll { $0.id == id } }
    }

    // MARK: - Root Note CRUD

    func addRootNote(_ note: DatabaseNote) {
        rootNotes.append(note)
        saveRootNotes()
    }

    func updateRootNote(_ note: DatabaseNote) {
        if let idx = rootNotes.firstIndex(where: { $0.id == note.id }) {
            rootNotes[idx] = note
        }
        saveRootNotes()
    }

    func deleteRootNote(id: UUID) {
        rootNotes.removeAll { $0.id == id }
        saveRootNotes()
    }

    // MARK: - F5: Reorder root collections

    func moveRootFolder(from: IndexSet, to: Int) {
        rootFolders.move(fromOffsets: from, toOffset: to)
        saveFolders()
    }

    func moveRootExercise(from: IndexSet, to: Int) {
        rootExercises.move(fromOffsets: from, toOffset: to)
        saveRootExercises()
    }

    func moveRootNote(from: IndexSet, to: Int) {
        rootNotes.move(fromOffsets: from, toOffset: to)
        saveRootNotes()
    }

    // MARK: - F5: Reorder within folder

    func moveFolderExercise(from: IndexSet, to: Int, inFolderID: UUID) {
        updateFolder(id: inFolderID) { $0.exercises.move(fromOffsets: from, toOffset: to) }
    }

    func moveFolderNote(from: IndexSet, to: Int, inFolderID: UUID) {
        updateFolder(id: inFolderID) { $0.notes.move(fromOffsets: from, toOffset: to) }
    }

    func moveSubfolder(from: IndexSet, to: Int, inParentID: UUID) {
        updateFolder(id: inParentID) { $0.subfolders.move(fromOffsets: from, toOffset: to) }
    }

    // MARK: - F5: Move to different folder

    func moveExercise(id: UUID, fromFolderID: UUID?, toFolderID: UUID?) {
        guard fromFolderID != toFolderID else { return }
        var exercise: Exercise?

        if let from = fromFolderID {
            updateFolder(id: from) { folder in
                if let idx = folder.exercises.firstIndex(where: { $0.id == id }) {
                    exercise = folder.exercises[idx]
                    folder.exercises.remove(at: idx)
                }
            }
        } else {
            if let idx = rootExercises.firstIndex(where: { $0.id == id }) {
                exercise = rootExercises[idx]
                rootExercises.remove(at: idx)
                saveRootExercises()
            }
        }

        guard let ex = exercise else { return }

        if let to = toFolderID {
            updateFolder(id: to) { $0.exercises.append(ex) }
        } else {
            rootExercises.append(ex)
            saveRootExercises()
        }
    }

    func moveNote(id: UUID, fromFolderID: UUID?, toFolderID: UUID?) {
        guard fromFolderID != toFolderID else { return }
        var note: DatabaseNote?

        if let from = fromFolderID {
            updateFolder(id: from) { folder in
                if let idx = folder.notes.firstIndex(where: { $0.id == id }) {
                    note = folder.notes[idx]
                    folder.notes.remove(at: idx)
                }
            }
        } else {
            if let idx = rootNotes.firstIndex(where: { $0.id == id }) {
                note = rootNotes[idx]
                rootNotes.remove(at: idx)
                saveRootNotes()
            }
        }

        guard let n = note else { return }

        if let to = toFolderID {
            updateFolder(id: to) { $0.notes.append(n) }
        } else {
            rootNotes.append(n)
            saveRootNotes()
        }
    }

    // MARK: - Private tree mutation

    private func updateFolder(id: UUID, transform: (inout ExerciseFolder) -> Void) {
        if mutateInArray(&rootFolders, id: id, transform: transform) {
            saveFolders()
        }
    }

    @discardableResult
    private func mutateInArray(
        _ folders: inout [ExerciseFolder],
        id: UUID,
        transform: (inout ExerciseFolder) -> Void
    ) -> Bool {
        for i in folders.indices {
            if folders[i].id == id {
                transform(&folders[i])
                return true
            }
            if mutateInArray(&folders[i].subfolders, id: id, transform: transform) {
                return true
            }
        }
        return false
    }

    // MARK: - Default content

    private func defaultFolders() -> [ExerciseFolder] {
        [
            ExerciseFolder(name: "Upper Body",
                subfolders: [
                    ExerciseFolder(name: "Push", exercises: [
                        Exercise(name: "Push-ups",
                                 description: "Classic push-up. Keep core tight, body in a straight line.",
                                 duration: 30, restAfter: 10),
                        Exercise(name: "Pike Push-ups",
                                 description: "Hips high in a pike. Lower head between hands to target shoulders.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Diamond Push-ups",
                                 description: "Hands form a diamond under your chest. Isolates triceps.",
                                 duration: 30, restAfter: 15),
                    ]),
                    ExerciseFolder(name: "Pull", exercises: [
                        Exercise(name: "Inverted Rows",
                                 description: "Under a table or bar. Pull chest up to the surface.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Scapular Pulls",
                                 description: "Dead hang from bar. Retract shoulder blades without bending elbows.",
                                 duration: 20, restAfter: 10),
                    ]),
                ],
                exercises: [
                    Exercise(name: "Arm Circles",
                             description: "Forward and backward circles. Loosen the shoulder joint.",
                             duration: 30, restAfter: 5),
                    Exercise(name: "Shoulder Shrugs",
                             description: "Shrug shoulders to ears, hold 1s, release.",
                             duration: 20, restAfter: 5),
                ]
            ),
            ExerciseFolder(name: "Lower Body",
                subfolders: [
                    ExerciseFolder(name: "Quads", exercises: [
                        Exercise(name: "Squats",
                                 description: "Feet shoulder-width. Knees track over toes. Keep chest up.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Jump Squats",
                                 description: "Explosive squat with full extension at top. Land softly.",
                                 duration: 30, restAfter: 20),
                        Exercise(name: "Wall Sit",
                                 description: "Back flat against wall. Hold 90° position.",
                                 duration: 45, restAfter: 15),
                    ]),
                    ExerciseFolder(name: "Glutes", exercises: [
                        Exercise(name: "Glute Bridges",
                                 description: "Lie on back. Drive hips up and squeeze glutes at the top.",
                                 duration: 30, restAfter: 10),
                        Exercise(name: "Lunges",
                                 description: "Step forward. Back knee hovers just above the floor.",
                                 duration: 30, restAfter: 15),
                        Exercise(name: "Donkey Kicks",
                                 description: "On all fours. Kick heel straight up, squeeze glute at top.",
                                 duration: 30, restAfter: 10),
                    ]),
                ]
            ),
            ExerciseFolder(name: "Core", exercises: [
                Exercise(name: "Plank",
                         description: "Forearm plank. Keep hips level — don't let them sag or pike.",
                         duration: 45, restAfter: 15),
                Exercise(name: "Crunches",
                         description: "Controlled crunch. Hands light behind head — don't pull your neck.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Leg Raises",
                         description: "Flat on back. Raise straight legs to 90°, lower slowly.",
                         duration: 30, restAfter: 15),
                Exercise(name: "Russian Twists",
                         description: "Rotate side to side. Lift feet off the floor for extra challenge.",
                         duration: 30, restAfter: 15),
                Exercise(name: "Bicycle Crunches",
                         description: "Alternate elbow to opposite knee. Control the rotation.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Mountain Climbers",
                         description: "High plank. Drive knees alternately to chest at a quick pace.",
                         duration: 30, restAfter: 10),
            ]),
            ExerciseFolder(name: "Cardio", exercises: [
                Exercise(name: "Jumping Jacks",
                         description: "Full extension at top, feet together on landing.",
                         duration: 45, restAfter: 10),
                Exercise(name: "High Knees",
                         description: "Drive knees up to hip height. Pump arms for speed.",
                         duration: 30, restAfter: 10),
                Exercise(name: "Burpees",
                         description: "Squat → kick back → push-up → jump up. Full body blast.",
                         duration: 30, restAfter: 20),
                Exercise(name: "Skaters",
                         description: "Side-to-side lateral bounds. Reach hand to opposite foot.",
                         duration: 30, restAfter: 15),
            ]),
        ]
    }
}
