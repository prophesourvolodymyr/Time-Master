import Foundation
import TimeMasterCore

class DatabaseStore: ObservableObject {
    static let shared = DatabaseStore()

    @Published var rootPages: [ExercisePage] = []
    @Published var allPagesFlat: [ExercisePage] = []

    private let foldersKey       = "exercise_database_v2"
    private let rootNotesKey     = "exercise_database_root_notes_v1"
    private let rootExercisesKey = "exercise_database_root_exercises_v1"

    @Published var rootFolders: [ExerciseFolder] = []
    @Published var rootNotes: [DatabaseNote] = []
    @Published var rootExercises: [Exercise] = []

    private var isV1Migrated: Bool { MigrationManager.isMigrationComplete }
    private var isV2PageMigrated: Bool { MigrationManager.isV2PageMigrationComplete }

    private init() {
        if isV2PageMigrated {
            loadPagesFromFileSystem()
        } else if isV1Migrated {
            loadFromFileSystem()
        } else {
            load()
        }
    }

    func reload() {
        if isV2PageMigrated {
            loadPagesFromFileSystem()
        } else if isV1Migrated {
            loadFromFileSystem()
        } else {
            load()
        }
    }

    // MARK: - V2 Page Loading

    private func loadPagesFromFileSystem() {
        let db = DatabaseManager.shared
        let base = db.exercisesDatabaseURL

        let flatManifests: [(ExercisePageManifest, String)]
        do {
            flatManifests = try db.walkPageTree(in: base)
        } catch {
            return
        }

        allPagesFlat = flatManifests.map { (manifest, path) in
            let pageURL = base.appendingPathComponent(path, isDirectory: true)
            return ExercisePage(from: manifest, baseURL: pageURL, path: path)
        }

        rootPages = PageTreeBuilder.build(from: allPagesFlat)
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
        try DatabaseManager.shared.createPage(manifest: manifest, parentID: parentID)
        loadPagesFromFileSystem()
    }

    func createPageWithMedia(manifest: ExercisePageManifest, parentID: String?, coverData: Data?, mediaData: [(filename: String, data: Data)]) throws {
        try DatabaseManager.shared.createPage(manifest: manifest, parentID: parentID)

        if let coverData = coverData, let coverFilename = manifest.coverImageFilename {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(coverFilename)
            try coverData.write(to: tempURL)
            try DatabaseManager.shared.uploadCoverImage(pageID: manifest.id, sourceURL: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        }

        for (filename, data) in mediaData {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(filename)
            try data.write(to: tempURL)
            try DatabaseManager.shared.uploadMediaToPage(pageID: manifest.id, sourceURL: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        }

        loadPagesFromFileSystem()
    }

    func updatePage(id: String, manifest: ExercisePageManifest, newParentID: String?) throws {
        try DatabaseManager.shared.updatePage(id: id, manifest: manifest, newParentID: newParentID)
        loadPagesFromFileSystem()
    }

    func deletePage(id: String) throws {
        try DatabaseManager.shared.deletePage(id: id)
        loadPagesFromFileSystem()
    }

    func reorderChildren(parentID: String, childIDs: [String]) throws {
        try DatabaseManager.shared.reorderChildren(parentID: parentID, childIDs: childIDs)
        loadPagesFromFileSystem()
    }

    func persistRootPageOrder() {
        for (index, page) in rootPages.enumerated() {
            var updatedManifest = page.manifest
            updatedManifest.order = index
            do {
                try DatabaseManager.shared.updatePage(id: updatedManifest.id, manifest: updatedManifest, newParentID: nil)
            } catch {}
        }
        loadPagesFromFileSystem()
    }

    func movePage(id: String, newParentID: String?, newOrder: Int) throws {
        try DatabaseManager.shared.movePage(id: id, newParentID: newParentID, newOrder: newOrder)
        loadPagesFromFileSystem()
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

        loadPagesFromFileSystem()
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

    // MARK: - V1 Legacy (backward compatible)

    private func loadFromFileSystem() {
        let db = DatabaseManager.shared
        let base = db.exercisesDatabaseURL
        let fs = FileSystemHelper(dataRoot: db.dataRoot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let (folders, exercises) = walkExerciseDirectory(base, fs: fs, decoder: decoder)
        rootFolders = folders
        rootExercises = exercises
        rootNotes = []
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
