import Foundation
import TimeMasterCore
#if os(macOS)
import CoreServices
#elseif canImport(UIKit)
import UIKit
#endif

class DatabaseStore: ObservableObject {
    static let shared = DatabaseStore()

    @Published var rootPages: [ExercisePage] = [] {
        didSet { derived.reset() }
    }
    @Published var allPagesFlat: [ExercisePage] = [] {
        didSet { derived.reset() }
    }
    /// Not published: derived from the two lists above and cleared whenever either changes.
    let derived = LibraryDerivedCache()

    private let foldersKey       = "exercise_database_v2"
    private let rootNotesKey     = "exercise_database_root_notes_v1"
    private let rootExercisesKey = "exercise_database_root_exercises_v1"
    private let legacyDatabaseKeys = [
        "exercise_database_v2",
        "exercise_database_root_notes_v1",
        "exercise_database_root_exercises_v1"
    ]
    private var reloadWorkItem: DispatchWorkItem?
    private var reloadGeneration = 0
    private var appliedSignature: Int?

    @Published var rootFolders: [ExerciseFolder] = []
    @Published var rootNotes: [DatabaseNote] = []
    @Published var rootExercises: [Exercise] = []
    @Published private(set) var libraryRevision = 0
    #if os(macOS)
    private var libraryWatcher: LibraryWatcher?
    #endif

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
        startWatchingLibrary()
    }

    func reload() {
        reloadWorkItem?.cancel()
        reloadGeneration &+= 1
        let generation = reloadGeneration

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let loaded = self.loadedLibrary() else { return }
            DispatchQueue.main.async {
                guard self.reloadGeneration == generation else { return }
                self.applyLoaded(loaded)
            }
        }

        reloadWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    @MainActor
    func reloadAndWait() async {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        reloadGeneration &+= 1
        let generation = reloadGeneration
        let loaded = await Task.detached(priority: .userInitiated) { [self] in
            loadedLibrary() ?? .pages(Self.snapshot(flat: [], roots: []))
        }.value
        guard reloadGeneration == generation else { return }
        applyLoaded(loaded)
    }

    private enum LoadedLibrary {
        case pages(PageSnapshot)
        case legacy(folders: [ExerciseFolder], exercises: [Exercise])
        case defaults([ExerciseFolder])
    }

    private func loadedLibrary() -> LoadedLibrary? {
        if isV2PageMigrated {
            return pageSnapshotIfReadable().map(LoadedLibrary.pages)
        }
        if isV1Migrated {
            let snapshot = legacySnapshotFromFileSystem()
            return .legacy(folders: snapshot.folders, exercises: snapshot.exercises)
        }
        return .defaults(defaultFolders())
    }

    private func applyLoaded(_ loaded: LoadedLibrary) {
        switch loaded {
        case .pages(let snapshot):
            if apply(snapshot) { libraryRevision &+= 1 }
        case .legacy(let folders, let exercises):
            rootFolders = folders
            rootExercises = exercises
        case .defaults(let folders):
            rootFolders = folders
        }
    }

    func reloadImmediately() {
        reloadWorkItem?.cancel()
        reloadGeneration &+= 1

        if isV2PageMigrated {
            if apply(pageSnapshotFromFileSystem()) { libraryRevision &+= 1 }
        } else if isV1Migrated {
            let snapshot = legacySnapshotFromFileSystem()
            rootFolders = snapshot.folders
            rootExercises = snapshot.exercises
        } else {
            rootFolders = defaultFolders()
        }
    }

    private func invalidatePendingReloads() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        reloadGeneration &+= 1
    }

    private func startWatchingLibrary() {
        #if os(macOS)
        watchLibraryDirectory()
        NotificationCenter.default.addObserver(forName: .exerciseLibraryDidSync, object: nil, queue: .main) { [weak self] notification in
            guard notification.userInfo?["accountChanged"] as? Bool == true else { return }
            self?.watchLibraryDirectory()
        }
        #elseif canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        #endif
    }

    #if os(macOS)
    private func watchLibraryDirectory() {
        let path = DatabaseManager.shared.exercisesDatabaseURL.path
        guard libraryWatcher?.path != path else { return }
        libraryWatcher?.stop()
        libraryWatcher = LibraryWatcher(path: path) { [weak self] in
            DispatchQueue.main.async {
                self?.watchLibraryDirectory()
                self?.reload()
            }
        }
    }
    #endif


    // MARK: - V2 Page Loading

    private func loadPagesFromFileSystem() {
        apply(pageSnapshotFromFileSystem())
    }

    private struct PageSnapshot {
        let flat: [ExercisePage]
        let roots: [ExercisePage]
        let index: PageIndex
        let library: SkillLibrary
        let signature: Int
    }

    @discardableResult
    private func apply(_ snapshot: PageSnapshot) -> Bool {
        guard snapshot.signature != appliedSignature else { return false }
        appliedSignature = snapshot.signature
        allPagesFlat = snapshot.flat
        rootPages = snapshot.roots
        derived.index = snapshot.index
        derived.skillLibrary = snapshot.library
        derived.pageTree = snapshot.roots
        return true
    }

    private func pageSnapshotFromFileSystem() -> PageSnapshot {
        pageSnapshotIfReadable() ?? Self.snapshot(flat: [], roots: [])
    }

    private static func snapshot(flat: [ExercisePage], roots: [ExercisePage]) -> PageSnapshot {
        let index = PageIndex(pages: flat)
        return PageSnapshot(flat: flat, roots: roots, index: index, library: SkillLibrary(index: index), signature: signature(of: flat))
    }

    private static func signature(of pages: [ExercisePage]) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var hasher = Hasher()
        for page in pages {
            hasher.combine(page.path)
            hasher.combine(page.mediaURLs)
            hasher.combine(page.coverImageURL)
            hasher.combine(page.inheritedWorkoutType?.id)
            if let data = try? encoder.encode(page.manifest) { hasher.combine(data) }
        }
        return hasher.finalize()
    }

    private func pageSnapshotIfReadable() -> PageSnapshot? {
        let db = DatabaseManager.shared
        let base = db.exercisesDatabaseURL
        let legacyMediaDirectory = db.dataRoot.appendingPathComponent("Media", isDirectory: true)
        guard let flatManifests = try? db.walkPageTree(in: base) else { return nil }

        let rawPages = flatManifests.map { (manifest, path) in
            let pageURL = base.appendingPathComponent(path, isDirectory: true)
            return ExercisePage(from: manifest, baseURL: pageURL, legacyMediaDirectory: legacyMediaDirectory, path: path)
        }
        let lookup = Dictionary(rawPages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let flat = rawPages.map { page in
            ExercisePage(
                manifest: page.manifest,
                coverImageURL: page.coverImageURL,
                mediaURLs: page.mediaURLs,
                path: page.path,
                inheritedWorkoutType: inheritedWorkoutType(for: page, lookup: lookup)
            )
        }
        return Self.snapshot(flat: flat, roots: PageTreeBuilder.build(from: flat))
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
        if let known = derived.pageTree { return known }
        let tree = PageTreeBuilder.build(from: allPagesFlat)
        derived.pageTree = tree
        return tree
    }

    /// Lookups over the current `allPagesFlat`; rebuilt on the first read after a change.
    var index: PageIndex {
        if let known = derived.index { return known }
        let built = PageIndex(pages: allPagesFlat)
        derived.index = built
        return built
    }

    /// The skill screens' read of the current `allPagesFlat`; shared by every caller until the library changes.
    var skillLibrary: SkillLibrary {
        if let known = derived.skillLibrary { return known }
        let built = SkillLibrary(index: index)
        derived.skillLibrary = built
        return built
    }

    var pagesByTitle: [ExercisePage] {
        if let known = derived.pagesByTitle { return known }
        let sorted = allPagesFlat.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        derived.pagesByTitle = sorted
        return sorted
    }

    var pagesByPath: [ExercisePage] {
        if let known = derived.pagesByPath { return known }
        let sorted = allPagesFlat.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        derived.pagesByPath = sorted
        return sorted
    }

    func page(id: UUID) -> ExercisePage? {
        index.byID[id]
    }

    func folderURL(for page: ExercisePage) -> URL {
        DatabaseManager.shared.exercisesDatabaseURL.appendingPathComponent(page.path, isDirectory: true)
    }

    func children(of parentID: UUID) -> [ExercisePage] {
        index.childrenByParent[parentID] ?? []
    }

    func breadcrumbs(for pageID: UUID) -> [ExercisePage] {
        index.breadcrumbs(for: pageID)
    }

    // MARK: - Page CRUD (V2)

    func createPage(manifest: ExercisePageManifest, parentID: String?) throws {
        var persistedManifest = manifest
        persistedManifest.parentID = parentID ?? manifest.parentID
        invalidatePendingReloads()
        try DatabaseManager.shared.createPage(manifest: persistedManifest, parentID: parentID)
        publishCreatedPage((try? DatabaseManager.shared.getPage(id: persistedManifest.id)) ?? persistedManifest)
    }

    func updatePage(id: String, manifest: ExercisePageManifest, newParentID: String?) throws {
        try DatabaseManager.shared.updatePage(id: id, manifest: manifest, newParentID: newParentID)
        reload()
    }

    func updateMediaComment(pageID: String, filename: String, comment: String) throws {
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
            try DatabaseManager.shared.updateMediaComment(pageID: pageID, filename: filename, comment: comment)
        }
        publishSavedPage(SkillGroupID.split(pageID)?.containerID ?? pageID)
        reload()
    }

    func deletePage(id: String) throws {
        try DatabaseManager.shared.deletePage(id: id)
        reload()
    }

    @MainActor
    func createPageWithMedia(
        manifest: ExercisePageManifest,
        parentID: String?,
        media: [(filename: String, url: URL)]
    ) async throws {
        var persistedManifest = manifest
        persistedManifest.parentID = parentID ?? manifest.parentID
        persistedManifest.coverImageFilename = nil
        if !media.isEmpty {
            persistedManifest.mediaFilenames = []
            persistedManifest.mediaComments = [:]
        }
        let comments = manifest.mediaComments
        let libraryToken = ExerciseLibraryAccess.shared.capture()
        try await Task.detached(priority: .userInitiated) { [persistedManifest] in
            try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                try DatabaseManager.shared.createPage(manifest: persistedManifest, parentID: parentID)
                try DatabaseStore.attachMedia(media, comments: comments, toNewPage: persistedManifest.id)
            }
        }.value
        await reloadAndWait()
    }

    static func attachMedia(
        _ media: [(filename: String, url: URL)],
        comments: [String: String],
        toNewPage pageID: String
    ) throws {
        let database = DatabaseManager.shared
        do {
            for (filename, url) in media {
                let savedFilename = try database.uploadMediaToPage(pageID: pageID, sourceURL: url)
                if let comment = comments[filename] {
                    try database.updateMediaComment(pageID: pageID, filename: savedFilename, comment: comment)
                }
            }
        } catch {
            let saveError = error
            do {
                try database.deletePage(id: pageID)
            } catch {
                throw FileSystemHelper.Error.writeFailed("\(saveError.localizedDescription) Cleanup failed: \(error.localizedDescription)")
            }
            throw saveError
        }
    }


    private func publishUploadedMedia(
        pageID: String,
        coverFilename: String? = nil,
        mediaFilenames: [String] = [],
        libraryToken: ExerciseLibraryAccess.Token
    ) {
        let update = { [weak self] in
            guard ExerciseLibraryAccess.shared.isCurrent(libraryToken) else { return }
            guard let self, let index = self.allPagesFlat.firstIndex(where: { $0.manifest.id == pageID }) else { return }
            var manifest = self.allPagesFlat[index].manifest
            if let coverFilename {
                manifest.coverImageFilename = coverFilename
            }
            for filename in mediaFilenames where !manifest.mediaFilenames.contains(filename) {
                manifest.mediaFilenames.append(filename)
            }

            let currentPage = self.allPagesFlat[index]
            let uploaded = coverFilename ?? mediaFilenames.first
            let pageURL = uploaded.flatMap { try? DatabaseManager.shared.pageMediaURL(pageID: pageID, filename: $0) }
                .map { $0.deletingLastPathComponent().deletingLastPathComponent() }
                ?? self.folderURL(for: currentPage)
            let refreshed = ExercisePage(from: manifest, baseURL: pageURL, legacyMediaDirectory: DatabaseManager.shared.dataRoot.appendingPathComponent("Media", isDirectory: true), path: currentPage.path)
            self.allPagesFlat[index] = ExercisePage(
                manifest: refreshed.manifest,
                coverImageURL: refreshed.coverImageURL,
                mediaURLs: refreshed.mediaURLs,
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
            mediaFilenames: mediaFilenames,
            libraryToken: ExerciseLibraryAccess.shared.capture()
        )
    }

    func persistSkillBoard(
        containerID: String,
        sections: [SkillBoardSection],
        placements: [SkillBoardPlacement]
    ) throws {
        try DatabaseManager.shared.updateSkillBoard(
            containerID: containerID,
            sections: sections,
            placements: placements
        )
        reload()
    }

    func updateLinkedPages(pageID: String, linkedPageIDs: [String]) throws {
        guard let page = allPagesFlat.first(where: { $0.manifest.id == pageID }) else {
            throw FileSystemHelper.Error.notFound(pageID)
        }
        var manifest = page.manifest
        manifest.linkedPageIDs = Array(NSOrderedSet(array: linkedPageIDs)) as? [String] ?? linkedPageIDs
        try DatabaseManager.shared.updatePage(
            id: pageID,
            manifest: manifest,
            newParentID: manifest.parentID
        )
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
        newManifest.coverImageFilename = nil
        newManifest.mediaFilenames = []
        try DatabaseManager.shared.createPage(manifest: newManifest, parentID: page.manifest.parentID)
        if page.isNote { copyNoteAttachments(from: page, to: newManifest.id) }

        for sourceURL in page.mediaURLs where FileManager.default.fileExists(atPath: sourceURL.path) {
            try? DatabaseManager.shared.uploadMediaToPage(
                pageID: newManifest.id,
                sourceURL: sourceURL
            )
        }

        reload()
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

    /// Puts the saved manifest of `pageID` in place right away, with its media addresses.
    func publishSavedPage(_ pageID: String) {
        guard let manifest = try? DatabaseManager.shared.getPage(id: pageID),
              let index = allPagesFlat.firstIndex(where: { $0.manifest.id == pageID }) else { return }
        let current = allPagesFlat[index]
        var merged = manifest
        merged.childIDs = current.manifest.childIDs
        let refreshed = ExercisePage(
            from: merged,
            baseURL: folderURL(for: current),
            legacyMediaDirectory: DatabaseManager.shared.dataRoot.appendingPathComponent("Media", isDirectory: true),
            path: current.path
        )
        allPagesFlat[index] = ExercisePage(
            manifest: refreshed.manifest,
            coverImageURL: refreshed.coverImageURL,
            mediaURLs: refreshed.mediaURLs,
            path: current.path,
            inheritedWorkoutType: current.inheritedWorkoutType
        )
        rootPages = PageTreeBuilder.build(from: allPagesFlat)
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

#if os(macOS)
private final class LibraryWatcher {
    let path: String
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init?(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<LibraryWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            if changed.contains(where: { !$0.contains("/.trash/") && !$0.hasSuffix(".DS_Store") }) {
                watcher.onChange()
            }
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.4,
            flags
        ) else { return nil }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return nil
        }
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
#endif

struct PageCreationDraft: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var pageKind: ExercisePageManifest.PageKind
    var pageType: PageType?
    var skillStatus: SkillStatus?
    var skillBoardSectionID: String?
    var parentID: String?
    var workoutType: TimeMasterCore.WorkoutType?
    var markdownBody: String
    var duration: Int
    var prepareTime: Int
    var restAfter: Int
    var sets: Int
    var restBetweenSets: Int
    var dropSetTemplates: [PageDropSetTemplate]
    var linkURLs: [String]
    var linkMetadata: [LinkMetadata]
    var mediaFilenames: [String]
    var mediaComments: [String: String]? = nil
    let createdAt: Date
    var updatedAt: Date
}

final class PageCreationDraftStore: ObservableObject {
    static let shared = PageCreationDraftStore()
    static let lifetime: TimeInterval = 30 * 24 * 60 * 60

    @Published private(set) var drafts: [PageCreationDraft] = []

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var draftsDirectory: URL {
        DatabaseManager.shared.dataRoot
            .appendingPathComponent("Workspace", isDirectory: true)
            .appendingPathComponent("Page Drafts", isDirectory: true)
    }

    private init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        reload()
    }

    func reload() {
        purgeExpiredDrafts()
        guard let entries = try? fileManager.contentsOfDirectory(
            at: draftsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            drafts = []
            return
        }

        drafts = entries.compactMap { entry in
            let fileURL = entry.appendingPathComponent("draft.json")
            guard let data = try? Data(contentsOf: fileURL),
                  let draft = try? decoder.decode(PageCreationDraft.self, from: data) else {
                return nil
            }
            return draft
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ draft: PageCreationDraft, mediaSources: [String: URL]) throws {
        let draftDirectory = draftsDirectory.appendingPathComponent(draft.id.uuidString, isDirectory: true)
        let mediaDirectory = draftDirectory.appendingPathComponent("media", isDirectory: true)
        try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)

        let allowedFilenames = Set(draft.mediaFilenames.map { URL(fileURLWithPath: $0).lastPathComponent })
        if let existingFiles = try? fileManager.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: nil) {
            for file in existingFiles where !allowedFilenames.contains(file.lastPathComponent) {
                try? fileManager.removeItem(at: file)
            }
        }

        for filename in allowedFilenames {
            guard let source = mediaSources[filename] ?? mediaSources.first(where: { URL(fileURLWithPath: $0.key).lastPathComponent == filename })?.value else {
                continue
            }
            let destination = mediaDirectory.appendingPathComponent(filename)
            if source.standardizedFileURL.path != destination.standardizedFileURL.path,
               !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: source, to: destination)
            }
        }

        let fileURL = draftDirectory.appendingPathComponent("draft.json")
        try encoder.encode(draft).write(to: fileURL, options: .atomic)
        reload()
    }

    func mediaURL(for draft: PageCreationDraft, filename: String) -> URL {
        draftsDirectory
            .appendingPathComponent(draft.id.uuidString, isDirectory: true)
            .appendingPathComponent("media", isDirectory: true)
            .appendingPathComponent(URL(fileURLWithPath: filename).lastPathComponent)
    }

    func delete(id: UUID) {
        let directory = draftsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: directory)
        drafts.removeAll { $0.id == id }
    }

    private func purgeExpiredDrafts() {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: draftsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let expiration = Date().addingTimeInterval(-Self.lifetime)
        for entry in entries {
            let fileURL = entry.appendingPathComponent("draft.json")
            guard let data = try? Data(contentsOf: fileURL),
                  let draft = try? decoder.decode(PageCreationDraft.self, from: data) else {
                continue
            }
            if draft.updatedAt < expiration {
                try? fileManager.removeItem(at: entry)
            }
        }
    }
}
