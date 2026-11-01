import XCTest
@testable import TimeMasterCore

class SyncPairTestCase: XCTestCase {
    struct Replica {
        let db: DatabaseManager
        let engine: SyncEngine
        let photos: URL
        let music: URL
        var fs: FileSystemHelper { db.fs }
        var root: URL { db.dataRoot }

        func folder(_ id: String) throws -> URL {
            guard let url = db.syncExistingPageFolder(id) else { throw SyncError.notFound("No page \(id)") }
            return url
        }

        func exists(_ id: String) -> Bool { db.syncExistingPageFolder(id) != nil }

        func page(_ id: String) throws -> ExercisePageManifest { try db.getPage(id: id) }

        func edit(_ id: String, _ change: (inout ExercisePageManifest) -> Void) throws {
            var manifest = try db.getPage(id: id)
            change(&manifest)
            try db.updatePage(id: id, manifest: manifest)
        }

        func pages() -> [String: ExercisePageManifest] {
            db.syncLoadSnapshot(store: engine.store).pages
        }

        func pageIDs() -> Set<String> { Set(pages().keys) }

        func trashIsEmpty() -> Bool {
            ((try? FileManager.default.contentsOfDirectory(atPath: fs.trashDirectory.path)) ?? []).isEmpty
        }

        func backups() -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: fs.backupsDirectory.path)) ?? []).filter { $0.contains("before-sync") }
        }
    }

    var base: URL!
    var mac: Replica!
    var phone: Replica!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("tm-sync-\(UUID().uuidString)", isDirectory: true)
        mac = try makeReplica("mac", deviceName: "Mac")
        phone = try makeReplica("phone", deviceName: "iPhone")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    func makeReplica(_ folder: String, deviceName: String) throws -> Replica {
        let root = base.appendingPathComponent(folder, isDirectory: true)
        let db = DatabaseManager(fs: FileSystemHelper(dataRoot: root))
        try db.bootstrapIfNeeded()
        let photos = base.appendingPathComponent("\(folder)-photos", isDirectory: true)
        let music = base.appendingPathComponent("\(folder)-music", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
        return Replica(db: db, engine: SyncEngine(database: db, deviceName: deviceName, extra: SyncExtraFolders(photos: photos, music: music)), photos: photos, music: music)
    }

    @discardableResult
    func sync(from driver: Replica? = nil, with other: Replica? = nil) async throws -> SyncReport {
        let d = driver ?? mac!
        let o = other ?? phone!
        let peer = SyncPeerRecord(id: try o.engine.deviceID(), name: o.engine.deviceName, platform: "iphone", key: Data(repeating: 1, count: 32))
        return try await SyncDriver(engine: d.engine, peer: peer, remote: SyncService(engine: o.engine, peerID: try d.engine.deviceID())).reconcile()
    }

    func assertInSync(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
        let x = try mac.engine.scan()
        let y = try phone.engine.scan()
        XCTAssertEqual(x.units.map { "\($0.key) \($0.hash)" }, y.units.map { "\($0.key) \($0.hash)" }, message, file: file, line: line)
        XCTAssertEqual(x.config?.hash, y.config?.hash, "settings differ. " + message, file: file, line: line)
        XCTAssertEqual(x.shards, y.shards, "history differs. " + message, file: file, line: line)
    }

    func writeFile(_ text: String, named name: String = "note.txt") throws -> URL {
        let url = base.appendingPathComponent("src-\(UUID().uuidString)-\(name)")
        try Data(text.utf8).write(to: url)
        return url
    }

    @discardableResult
    func makePage(_ replica: Replica, _ title: String, parent: String? = nil, body: String = "", type: PageType? = .skill) throws -> ExercisePageManifest {
        let manifest = ExercisePageManifest(title: title, pageType: type, markdownBody: body)
        try replica.db.createPage(manifest: manifest, parentID: parent)
        return try replica.page(manifest.id)
    }

    @discardableResult
    func makePiano(on replica: Replica) throws -> (piano: ExercisePageManifest, scales: ExercisePageManifest, chords: ExercisePageManifest) {
        let piano = try makePage(replica, "Piano")
        let scales = try makePage(replica, "Scales", parent: piano.id, body: "Major and minor.")
        let chords = try makePage(replica, "Chords", parent: piano.id)
        return (try replica.page(piano.id), scales, chords)
    }

    func makeWorkout(_ replica: Replica, name: String = "Full body", sections: [String] = ["Push-ups", "Squats"]) throws -> WorkoutManifest {
        let id = UUID().uuidString
        let manifest = WorkoutManifest(id: id, name: name, sections: sections.map { WorkoutSectionManifest(exerciseID: "", name: $0, duration: 30) })
        try replica.db.createWorkout(id: id, manifest: manifest)
        return manifest
    }

    func historyEntry(_ name: String, at time: TimeInterval, id: String = UUID().uuidString) -> HistoryEntry {
        HistoryEntry(id: id, workoutId: UUID().uuidString, workoutName: name, completedAt: Date(timeIntervalSince1970: time), durationCompleted: 600)
    }

    func libraryProblems(_ replica: Replica) -> [String] {
        let snapshot = replica.db.syncLoadSnapshot(store: replica.engine.store)
        var problems: [String] = []
        if !snapshot.reliableKinds.contains(.page) { problems.append("a page manifest cannot be read") }
        let pages = snapshot.pages
        for (id, page) in pages {
            let name = "\(id.prefix(4)) \(page.title)"
            if page.id != id { problems.append("\(name): id mismatch") }
            if let parentID = page.parentID {
                guard let parent = pages[parentID] else {
                    problems.append("\(name): parent \(parentID.prefix(4)) is missing")
                    continue
                }
                if !parent.childIDs.contains(id) { problems.append("\(name): its parent does not list it") }
                if let section = page.skillBoardSectionID, !parent.skillBoardSections.contains(where: { $0.id == section }) {
                    problems.append("\(name): section \(section) is not on its parent")
                }
                if let record = snapshot.page(id), let parentRecord = snapshot.page(parentID),
                   record.location.deletingLastPathComponent().standardizedFileURL != parentRecord.location.standardizedFileURL {
                    problems.append("\(name): its folder is not inside its parent's folder")
                }
                if parent.pageKind == .leaf { problems.append("\(name): inside a leaf page") }
            } else {
                if let record = snapshot.page(id), record.location.deletingLastPathComponent().standardizedFileURL != replica.fs.exercisesDatabaseDirectory.standardizedFileURL {
                    problems.append("\(name): a root page that is not at the top")
                }
            }
            var seen = Set<String>()
            for child in page.childIDs {
                if !seen.insert(child).inserted { problems.append("\(name): lists \(child.prefix(4)) twice") }
                guard let childPage = pages[child] else {
                    problems.append("\(name): lists a missing child \(child.prefix(4))")
                    continue
                }
                if childPage.parentID != id { problems.append("\(name): lists a child that names another parent") }
            }
            if Set(page.childIDs) != Set(pages.values.filter { $0.parentID == id }.map(\.id)) { problems.append("\(name): children list and parent links disagree") }
        }
        return problems
    }
}
