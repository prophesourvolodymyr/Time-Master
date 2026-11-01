import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct SyncApplyItem: Sendable {
    public var key: String
    public var manifestText: String?
    public var stamp: SyncStamp
    public var expectedLocalHash: String?
    public var files: [SyncFileEntry]
    public var stagedFiles: [String: URL]
    public var removeFiles: [String]
    public var finalHash: String

    public init(
        key: String, manifestText: String?, stamp: SyncStamp, expectedLocalHash: String?, files: [SyncFileEntry],
        stagedFiles: [String: URL] = [:], removeFiles: [String] = [], finalHash: String
    ) {
        self.key = key
        self.manifestText = manifestText
        self.stamp = stamp
        self.expectedLocalHash = expectedLocalHash
        self.files = files
        self.stagedFiles = stagedFiles
        self.removeFiles = removeFiles
        self.finalHash = finalHash
    }
}

public struct SyncApplyDeletion: Sendable {
    public var key: String
    public var stamp: SyncStamp
    public var expectedLocalHash: String?

    public init(key: String, stamp: SyncStamp, expectedLocalHash: String?) {
        self.key = key
        self.stamp = stamp
        self.expectedLocalHash = expectedLocalHash
    }
}

public struct SyncApplyReport: Equatable, Sendable {
    public var applied: [String] = []
    public var stale: [String] = []
    public var deleted: [String] = []
    public var rescued: [String] = []
    public var warnings: [String] = []

    public init() {}

    public var changedAnything: Bool { !applied.isEmpty || !deleted.isEmpty || !rescued.isEmpty }
    public var changes: SyncChangeSet { SyncChangeSet(keys: applied + deleted + rescued) }
}

extension DatabaseManager {
    public func syncStagingFolder() throws -> URL {
        let folder = fs.dataRoot.appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent("sync-\(UUID().uuidString)", isDirectory: true)
        try fs.ensureDirectory(folder)
        return folder
    }

    public func syncRemoveStaging(_ folder: URL) {
        try? fs.removeItem(at: folder)
    }

    func syncPurgeStaleStaging() {
        let root = fs.dataRoot.appendingPathComponent(".staging", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.lastPathComponent.hasPrefix("sync-") {
            if let modified = fs.modificationDate(of: entry), Date().timeIntervalSince(modified) > 6 * 3600 { try? fs.removeItem(at: entry) }
        }
    }

    public func syncCreateSafetyCopy(label: String = "before-sync") throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stem = "\(formatter.string(from: Date()))-\(label)"
        var folder = fs.backupsDirectory.appendingPathComponent(stem, isDirectory: true)
        var suffix = 1
        while fs.fileExists(at: folder) {
            folder = fs.backupsDirectory.appendingPathComponent("\(stem)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        try fs.ensureDirectory(folder)
        let parts: [(URL, String)] = [
            (fs.exercisesDatabaseDirectory, "Exercises Database"), (fs.workoutsDirectory, "Workouts"),
            (fs.outdoorActivitiesDirectory, "Activities"), (fs.routesDirectory, "Routes"), (fs.historyDirectory, "History"),
        ]
        for (source, name) in parts where fs.directoryExists(at: source) {
            try Self.cloneOrCopy(source, to: folder.appendingPathComponent(name, isDirectory: true))
        }
        let config = fs.configDirectory.appendingPathComponent("manifest.json")
        if fs.fileExists(at: config) {
            try fs.ensureDirectory(folder.appendingPathComponent("Config", isDirectory: true))
            try Self.cloneOrCopy(config, to: folder.appendingPathComponent("Config", isDirectory: true).appendingPathComponent("manifest.json"))
        }
        return folder
    }

    private static func cloneOrCopy(_ source: URL, to destination: URL) throws {
        #if canImport(Darwin)
        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE)
        if copyfile(source.path, destination.path, nil, flags) == 0 { return }
        try? FileManager.default.removeItem(at: destination)
        #endif
        try FileManager.default.copyItem(at: source, to: destination)
    }

    public func syncApply(items: [SyncApplyItem], deletions: [SyncApplyDeletion], store: SyncStateStore, deviceName: String) throws -> SyncApplyReport {
        try store.locked {
            var report = SyncApplyReport()
            let scan = try scanLocked(store: store, deviceName: deviceName)
            let device = try store.deviceID()
            var state = store.loadState()
            let localHash = Dictionary(scan.index.units.map { ($0.key, $0.hash) }, uniquingKeysWith: { first, _ in first })
            let deletionKeys = Set(deletions.map(\.key))
            var touchedParents = Set<String>()
            var rootsTouched = false

            let itemsByKey = Dictionary(items.map { ($0.key, $0) }, uniquingKeysWith: { _, last in last })
            func pageDepth(of key: String) -> Int {
                guard let (kind, id) = SyncUnitKey.split(key), kind == .page else { return 0 }
                var depth = 0
                func parent(of id: String) -> String? {
                    if let text = itemsByKey[SyncUnitKey.make(.page, id)]?.manifestText,
                       let manifest = try? SyncCoding.decoder().decode(ExercisePageManifest.self, from: Data(text.utf8)) { return manifest.parentID }
                    return scan.snapshot.page(id)?.pageManifest?.parentID
                }
                var current = parent(of: id)
                var seen: Set<String> = [id]
                while let next = current, seen.insert(next).inserted {
                    depth += 1
                    current = parent(of: next)
                }
                return depth
            }

            var applied: [SyncApplyItem] = []
            for item in items.sorted(by: { pageDepth(of: $0.key) < pageDepth(of: $1.key) }) {
                guard let (kind, id) = SyncUnitKey.split(item.key), SyncPaths.isSafeName(id), store.hasEnabled(kind, in: self) else {
                    report.stale.append(item.key)
                    continue
                }
                guard localHash[item.key] == item.expectedLocalHash, !deletionKeys.contains(item.key) else {
                    report.stale.append(item.key)
                    continue
                }
                do {
                    let places = try storeUnit(item, kind: kind, id: id, store: store, report: &report)
                    touchedParents.formUnion(places.parents)
                    rootsTouched = rootsTouched || places.touchesRoots
                    applied.append(item)
                    report.applied.append(item.key)
                } catch {
                    report.warnings.append("\(SyncUnitKey.split(item.key)?.id ?? item.key): \(error.localizedDescription)")
                    report.stale.append(item.key)
                }
            }

            func localDepth(_ key: String) -> Int {
                guard let (kind, id) = SyncUnitKey.split(key), kind == .page else { return 0 }
                var depth = 0
                var current = scan.snapshot.page(id)?.pageManifest?.parentID
                var seen: Set<String> = [id]
                while let next = current, seen.insert(next).inserted {
                    depth += 1
                    current = scan.snapshot.page(next)?.pageManifest?.parentID
                }
                return depth
            }
            for deletion in deletions.sorted(by: { localDepth($0.key) > localDepth($1.key) }) {
                guard let (kind, id) = SyncUnitKey.split(deletion.key), SyncPaths.isSafeName(id), store.hasEnabled(kind, in: self) else { continue }
                guard localHash[deletion.key] == deletion.expectedLocalHash else {
                    report.stale.append(deletion.key)
                    continue
                }
                do {
                    let places = try deleteUnit(deletion.key, kind: kind, id: id, deletionKeys: deletionKeys, store: store, report: &report)
                    touchedParents.formUnion(places.parents)
                    rootsTouched = rootsTouched || places.touchesRoots
                } catch {
                    report.warnings.append("\(id): \(error.localizedDescription)")
                    report.stale.append(deletion.key)
                }
            }
            if !report.rescued.isEmpty { rootsTouched = true }

            try reconcileStructure(parents: touchedParents, roots: rootsTouched)

            let finalScan = syncLoadSnapshot(store: store)
            for item in applied {
                guard let record = finalScan.units[item.key] else { continue }
                let stamp = record.hash == item.finalHash ? item.stamp : state.clock.next(device: device)
                state.units[item.key] = SyncKnownUnit(hash: record.hash, stamp: stamp)
                state.tombstones[item.key] = nil
                state.clock.observe(item.stamp)
            }
            for deletion in deletions where report.deleted.contains(deletion.key) {
                state.units[deletion.key] = nil
                if let existing = state.tombstones[deletion.key], existing > deletion.stamp {
                } else {
                    state.tombstones[deletion.key] = deletion.stamp
                }
                state.clock.observe(deletion.stamp)
            }
            try store.saveState(state)
            store.saveHashCacheIfNeeded()
            return report
        }
    }

    private struct Places {
        var parents: Set<String> = []
        var touchesRoots = false
    }

    private func writeOpaqueManifest(_ text: String, to url: URL) throws {
        guard let object = SyncJSON.parse(text) else { throw SyncError.invalid("A manifest from the other device is damaged.") }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            throw SyncError.invalid("A manifest from the other device is damaged.")
        }
        try fs.writeAtomically(to: url, data: data)
    }

    private func storeUnit(_ item: SyncApplyItem, kind: SyncUnitKind, id: String, store: SyncStateStore, report: inout SyncApplyReport) throws -> Places {
        var places = Places()
        switch kind {
        case .page:
            guard let text = item.manifestText, let decoded = try? SyncCoding.decoder().decode(ExercisePageManifest.self, from: Data(text.utf8)) else {
                throw SyncError.invalid("A page from the other device is damaged.")
            }
            guard decoded.id == id else { throw SyncError.invalid("A page from the other device carries the wrong id.") }
            places = try storePage(decoded, report: &report)
        case .workout, .activity:
            guard let text = item.manifestText, let root = syncFolder(for: kind, store: store) else { throw SyncError.invalid("A \(kind.title) from the other device is damaged.") }
            let folder = root.appendingPathComponent(id, isDirectory: true)
            try fs.ensureDirectory(folder)
            try writeOpaqueManifest(text, to: folder.appendingPathComponent("manifest.json"))
        case .route:
            guard let text = item.manifestText else { throw SyncError.invalid("A route from the other device is damaged.") }
            try fs.ensureDirectory(fs.routesDirectory)
            try writeOpaqueManifest(text, to: fs.routesDirectory.appendingPathComponent("\(id).json"))
        case .media, .photo, .music:
            break
        }
        for path in item.removeFiles {
            let url = try syncFileURL(key: item.key, path: path, store: store)
            if fs.fileExists(at: url) { try? fs.moveToTrash(source: url) }
        }
        for (path, staged) in item.stagedFiles {
            let destination: URL
            if kind.isFolderUnit {
                guard let folder = syncUnitFolder(item.key, store: store) else { throw SyncError.notFound("No \(kind.title) with id \(id).") }
                guard SyncPaths.isSafeRelative(path), path != "manifest.json", path != "guide.md" else { throw SyncError.invalid("\(path) is not a file path inside a library item.") }
                destination = SyncPaths.append(path, to: folder)
            } else {
                destination = try syncFileURL(key: item.key, path: path, store: store)
            }
            try fs.ensureDirectory(destination.deletingLastPathComponent())
            if fs.fileExists(at: destination) { try? fs.moveToTrash(source: destination) }
            try FileManager.default.moveItem(at: staged, to: destination)
        }
        return places
    }

    private func deleteUnit(_ key: String, kind: SyncUnitKind, id: String, deletionKeys: Set<String>, store: SyncStateStore, report: inout SyncApplyReport) throws -> Places {
        var places = Places()
        switch kind {
        case .page:
            guard let folder = syncExistingPageFolder(id) else {
                report.deleted.append(key)
                return places
            }
            let page: ExercisePageManifest = try fs.readManifest(from: folder.appendingPathComponent("manifest.json"), decoder: SyncCoding.decoder())
            let destinationParent = page.parentID.flatMap { syncExistingPageFolder($0) } ?? fs.exercisesDatabaseDirectory
            for childFolder in pageChildFolders(in: folder) {
                guard var child: ExercisePageManifest = try? fs.readManifest(from: childFolder.appendingPathComponent("manifest.json"), decoder: SyncCoding.decoder()),
                      !deletionKeys.contains(SyncUnitKey.make(.page, child.id)) else { continue }
                let target = destinationParent.appendingPathComponent(child.id, isDirectory: true)
                try fs.ensureDirectory(destinationParent)
                try FileManager.default.moveItem(at: childFolder, to: target)
                child.parentID = page.parentID
                child.skillBoardSectionID = nil
                child = Self.normalizedPageManifest(child, parentID: page.parentID, parentIsSkill: nil)
                try writePageFiles(child, in: target)
                report.rescued.append(SyncUnitKey.make(.page, child.id))
            }
            try fs.moveToTrash(source: folder)
            if let parentID = page.parentID { places.parents.insert(parentID) } else { places.touchesRoots = true }
        case .workout, .activity:
            if let folder = syncUnitFolder(key, store: store) { try fs.moveToTrash(source: folder) }
        case .route:
            let url = fs.routesDirectory.appendingPathComponent("\(id).json")
            if fs.fileExists(at: url) { try fs.moveToTrash(source: url) }
        case .media, .photo, .music:
            if let root = syncFolder(for: kind, store: store) {
                let url = root.appendingPathComponent(id)
                if fs.fileExists(at: url) { try fs.moveToTrash(source: url) }
            }
        }
        report.deleted.append(key)
        return places
    }

    private func pageChildFolders(in folder: URL) -> [URL] {
        var found: [URL] = []
        func walk(_ directory: URL) {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                if fs.fileExists(at: entry.appendingPathComponent("manifest.json")) { found.append(entry) } else { walk(entry) }
            }
        }
        walk(folder)
        return found
    }

    private func storePage(_ decoded: ExercisePageManifest, report: inout SyncApplyReport) throws -> Places {
        var manifest = decoded
        let id = manifest.id
        var places = Places()

        let existingFolder = syncExistingPageFolder(id)
        let oldParentID: String? = existingFolder.flatMap { try? fs.readManifest(from: $0.appendingPathComponent("manifest.json"), decoder: SyncCoding.decoder()) as ExercisePageManifest }?.parentID

        var parentFolder = fs.exercisesDatabaseDirectory
        if let parentID = manifest.parentID {
            if let folder = syncExistingPageFolder(parentID) {
                parentFolder = folder
            } else {
                report.warnings.append("\(manifest.title): the page it belongs to is not here, so it was placed at the top level.")
                manifest.parentID = nil
                manifest.skillBoardSectionID = nil
            }
        }
        if let existingFolder, parentFolder.standardizedFileURL.path.hasPrefix(existingFolder.standardizedFileURL.path + "/") {
            report.warnings.append("\(manifest.title): moving it would put it inside itself, so it stays where it is.")
            manifest.parentID = oldParentID
            parentFolder = existingFolder.deletingLastPathComponent()
        }

        let parentIsSkill: Bool
        if let parentID = manifest.parentID, let parent: ExercisePageManifest = (try? getPage(id: parentID)) {
            parentIsSkill = parent.pageType == .skill || parent.pageType == .tutorial
        } else {
            parentIsSkill = false
        }
        manifest = Self.normalizedPageManifest(manifest, parentID: manifest.parentID, parentIsSkill: parentIsSkill)

        var folder: URL
        if let existingFolder {
            folder = existingFolder
            if existingFolder.deletingLastPathComponent().standardizedFileURL != parentFolder.standardizedFileURL {
                let destination = parentFolder.appendingPathComponent(id, isDirectory: true)
                try fs.ensureDirectory(parentFolder)
                try FileManager.default.moveItem(at: existingFolder, to: destination)
                folder = destination
            }
        } else {
            folder = parentFolder.appendingPathComponent(id, isDirectory: true)
            try fs.ensureDirectory(folder)
        }
        try writePageFiles(manifest, in: folder)

        if let parentID = manifest.parentID { places.parents.insert(parentID) } else { places.touchesRoots = true }
        if let oldParentID, oldParentID != manifest.parentID { places.parents.insert(oldParentID) }
        if existingFolder != nil, oldParentID == nil, manifest.parentID != nil { places.touchesRoots = true }
        places.parents.insert(id)
        return places
    }

    private func syncPageRecords() -> [String: (manifest: ExercisePageManifest, folder: URL)] {
        var records: [String: (manifest: ExercisePageManifest, folder: URL)] = [:]
        let decoder = SyncCoding.decoder()
        func walk(_ directory: URL) {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = entry.lastPathComponent
                guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      name != "media", name != "Attachments", name != SkillGroupID.folderName else { continue }
                if let data = try? Data(contentsOf: entry.appendingPathComponent("manifest.json")),
                   let manifest = try? decoder.decode(ExercisePageManifest.self, from: data), records[manifest.id] == nil {
                    records[manifest.id] = (manifest, entry)
                }
                walk(entry)
            }
        }
        walk(fs.exercisesDatabaseDirectory)
        return records
    }

    private func reconcileStructure(parents: Set<String>, roots: Bool) throws {
        guard !parents.isEmpty || roots else { return }
        let records = syncPageRecords()
        var manifests = records.mapValues(\.manifest)
        var dirty = Set<String>()
        var childrenOf: [String: [String]] = [:]
        for record in records.values {
            if let parentID = record.manifest.parentID { childrenOf[parentID, default: []].append(record.manifest.id) }
        }
        func before(_ lhs: ExercisePageManifest, _ rhs: ExercisePageManifest) -> Bool {
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
        for parentID in parents.sorted() {
            guard var parent = manifests[parentID] else { continue }
            let children = childrenOf[parentID] ?? []
            var desired: [String] = []
            var seen = Set<String>()
            for id in parent.childIDs where children.contains(id) && seen.insert(id).inserted { desired.append(id) }
            let newcomers = children.filter { !seen.contains($0) }.compactMap { manifests[$0] }.sorted(by: before)
            desired += newcomers.map(\.id)

            let validSections = Set(parent.skillBoardSections.map(\.id))
            for (position, id) in desired.enumerated() {
                guard var child = manifests[id] else { continue }
                let original = child
                child.order = position
                if let section = child.skillBoardSectionID, !validSections.contains(section) { child.skillBoardSectionID = nil }
                if child.order != original.order || child.skillBoardSectionID != original.skillBoardSectionID {
                    manifests[id] = child
                    dirty.insert(id)
                }
            }
            if parent.childIDs != desired {
                parent.childIDs = desired
                manifests[parentID] = parent
                dirty.insert(parentID)
            }
        }
        if roots {
            let rootManifests = manifests.values.filter { $0.parentID == nil }.sorted(by: before)
            var previous = Int.min
            for manifest in rootManifests {
                let order = manifest.order > previous ? manifest.order : previous + 1
                previous = order
                guard order != manifest.order else { continue }
                var updated = manifest
                updated.order = order
                manifests[manifest.id] = updated
                dirty.insert(manifest.id)
            }
        }
        for id in dirty.sorted() {
            guard let manifest = manifests[id], let record = records[id] else { continue }
            try writePageFiles(manifest, in: record.folder)
        }
    }
}

extension SyncStateStore {
    func hasEnabled(_ kind: SyncUnitKind, in database: DatabaseManager) -> Bool {
        database.syncEnabledKinds(self).contains(kind)
    }
}
