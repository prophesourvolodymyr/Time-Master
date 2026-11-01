import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum SyncPaths {
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".." && !name.hasPrefix(".")
            && !name.contains("/") && !name.contains("\\") && !name.contains("\0")
            && !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    static func isSafeRelative(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { isSafeName(String($0)) }
    }

    static func relativePath(of file: URL, under folder: URL) -> String? {
        let base = folder.standardizedFileURL.path
        let path = file.standardizedFileURL.path
        guard path.hasPrefix(base + "/") else { return nil }
        return String(path.dropFirst(base.count + 1))
    }

    static func append(_ relative: String, to folder: URL) -> URL {
        relative.split(separator: "/").reduce(folder) { $0.appendingPathComponent(String($1)) }
    }

    static func isDataless(_ url: URL) -> Bool {
        #if canImport(Darwin)
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return false }
        return info.st_flags & 0x4000_0000 != 0
        #else
        return false
        #endif
    }
}

struct SyncUnitRecord {
    var key: String
    var kind: SyncUnitKind
    var id: String
    var manifestText: String?
    var files: [SyncFileEntry]
    var hash: String
    var parentID: String?
    var title: String
    var firstSeen: Date
    var location: URL
    var pageManifest: ExercisePageManifest?
}

struct SyncSnapshot {
    var units: [String: SyncUnitRecord] = [:]
    var enabledKinds: [SyncUnitKind] = []
    var reliableKinds: Set<SyncUnitKind> = []

    var pages: [String: ExercisePageManifest] {
        var result: [String: ExercisePageManifest] = [:]
        for record in units.values { if let manifest = record.pageManifest { result[record.id] = manifest } }
        return result
    }

    func page(_ id: String) -> SyncUnitRecord? { units[SyncUnitKey.make(.page, id)] }
}

enum SyncUnitHasher {
    static func pageObject(_ manifest: ExercisePageManifest) -> [String: Any]? {
        guard let data = try? SyncCoding.encoder(pretty: false).encode(manifest) else { return nil }
        return SyncJSON.parse(data) as? [String: Any]
    }

    static func pageManifestHash(_ manifest: ExercisePageManifest) -> String {
        guard var object = pageObject(manifest) else { return SyncHash.hex(Data(manifest.id.utf8)) }
        object["updatedAt"] = nil
        if manifest.parentID != nil { object["order"] = nil }
        return SyncHash.hex(SyncJSON.data(object) ?? Data())
    }

    static func jsonManifestHash(_ text: String) -> String {
        SyncHash.hex(Data(text.utf8))
    }

    static func filesHash(_ files: [SyncFileEntry]) -> String {
        SyncHash.hex(Data(files.map { "\($0.path)\t\($0.size)\t\($0.sha256)" }.joined(separator: "\n").utf8))
    }

    static func combine(manifest: String, files: String) -> String {
        SyncHash.combine([manifest, files])
    }

    static func pageText(_ manifest: ExercisePageManifest) throws -> String {
        String(decoding: try SyncCoding.encoder(pretty: false).encode(manifest), as: UTF8.self)
    }

    static func manifestHash(kind: SyncUnitKind, text: String?) -> String {
        guard let text else { return "" }
        guard kind == .page, let manifest = try? SyncCoding.decoder().decode(ExercisePageManifest.self, from: Data(text.utf8)) else {
            return jsonManifestHash(text)
        }
        return pageManifestHash(manifest)
    }

    static func hash(kind: SyncUnitKind, manifest: String?, files: [SyncFileEntry]) -> String {
        combine(manifest: manifestHash(kind: kind, text: manifest), files: filesHash(files))
    }
}

enum SyncInventory {
    static func entries(inFolder folder: URL, skipping skipped: Set<String>, cache: SyncFileHashCache, seen: inout Set<String>, dataless: inout Bool) -> [SyncFileEntry] {
        var found: [SyncFileEntry] = []
        collect(folder, root: folder, topLevel: true, skipping: skipped, cache: cache, into: &found, seen: &seen, dataless: &dataless)
        return found.sorted { $0.path < $1.path }
    }

    private static func collect(
        _ directory: URL, root: URL, topLevel: Bool, skipping skipped: Set<String>, cache: SyncFileHashCache,
        into found: inout [SyncFileEntry], seen: inout Set<String>, dataless: inout Bool
    ) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys, options: []) else { return }
        for entry in entries {
            let name = entry.lastPathComponent
            if name.hasPrefix(".") { continue }
            if topLevel, skipped.contains(name) { continue }
            guard let values = try? entry.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                if FileManager.default.fileExists(atPath: entry.appendingPathComponent("manifest.json").path) { continue }
                collect(entry, root: root, topLevel: false, skipping: skipped, cache: cache, into: &found, seen: &seen, dataless: &dataless)
            } else if values.isRegularFile == true {
                guard let relative = SyncPaths.relativePath(of: entry, under: root), let modified = values.contentModificationDate else { continue }
                if SyncPaths.isDataless(entry) {
                    dataless = true
                    continue
                }
                let size = Int64(values.fileSize ?? 0)
                guard let sha = try? cache.hash(of: entry, size: size, modified: modified) else { continue }
                seen.insert(entry.standardizedFileURL.path)
                found.append(SyncFileEntry(path: relative, size: size, sha256: sha))
            }
        }
    }

    static func entry(forFile url: URL, name: String, cache: SyncFileHashCache, seen: inout Set<String>, dataless: inout Bool) -> (entry: SyncFileEntry, modified: Date)? {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true, let modified = values.contentModificationDate else { return nil }
        if SyncPaths.isDataless(url) {
            dataless = true
            return nil
        }
        let size = Int64(values.fileSize ?? 0)
        guard let sha = try? cache.hash(of: url, size: size, modified: modified) else { return nil }
        seen.insert(url.standardizedFileURL.path)
        return (SyncFileEntry(path: name, size: size, sha256: sha), modified)
    }
}

extension DatabaseManager {
    private static let nonPageFolders: Set<String> = ["media", "Attachments", SkillGroupID.folderName]
    private static let pageOwnFiles: Set<String> = ["manifest.json", "guide.md"]

    func syncEnabledKinds(_ store: SyncStateStore) -> [SyncUnitKind] {
        var kinds: [SyncUnitKind] = [.page, .workout, .activity, .route, .media]
        if store.extra.photos != nil { kinds.append(.photo) }
        if store.extra.music != nil { kinds.append(.music) }
        return kinds
    }

    func syncFolder(for kind: SyncUnitKind, store: SyncStateStore) -> URL? {
        switch kind {
        case .page: return fs.exercisesDatabaseDirectory
        case .workout: return fs.workoutsDirectory
        case .activity: return fs.outdoorActivitiesDirectory
        case .route: return fs.routesDirectory
        case .media: return fs.mediaDirectory
        case .photo: return store.extra.photos
        case .music: return store.extra.music
        }
    }

    func syncLoadSnapshot(store: SyncStateStore) -> SyncSnapshot {
        store.loadHashCacheIfNeeded()
        var snapshot = SyncSnapshot()
        snapshot.enabledKinds = syncEnabledKinds(store)
        var seen = Set<String>()
        for kind in snapshot.enabledKinds {
            var reliable = true
            switch kind {
            case .page: scanPages(store: store, into: &snapshot, seen: &seen, reliable: &reliable)
            case .workout, .activity: scanFolderUnits(kind, store: store, into: &snapshot, seen: &seen, reliable: &reliable)
            case .route: scanRoutes(store: store, into: &snapshot, reliable: &reliable)
            case .media, .photo, .music: scanLooseFiles(kind, store: store, into: &snapshot, seen: &seen, reliable: &reliable)
            }
            if reliable { snapshot.reliableKinds.insert(kind) }
        }
        store.hashCache.prune(keeping: seen)
        return snapshot
    }

    private func sortedEntries(_ directory: URL, reliable: inout Bool) -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            reliable = false
            return []
        }
        return entries.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private func scanPages(store: SyncStateStore, into snapshot: inout SyncSnapshot, seen: inout Set<String>, reliable: inout Bool) {
        let decoder = SyncCoding.decoder()
        func walk(_ directory: URL) {
            for entry in sortedEntries(directory, reliable: &reliable) {
                let name = entry.lastPathComponent
                guard !name.hasPrefix("."), isDirectory(entry), !Self.nonPageFolders.contains(name) else { continue }
                let manifestURL = entry.appendingPathComponent("manifest.json")
                if FileManager.default.fileExists(atPath: manifestURL.path) {
                    switch readPageRecord(entry, manifestURL: manifestURL, decoder: decoder, store: store, seen: &seen) {
                    case .record(let record):
                        if snapshot.units[record.key] == nil { snapshot.units[record.key] = record }
                    case .ignored: break
                    case .unreadable: reliable = false
                    }
                }
                walk(entry)
            }
        }
        walk(fs.exercisesDatabaseDirectory)
    }

    private enum PageRead {
        case record(SyncUnitRecord)
        case ignored
        case unreadable
    }

    private func readPageRecord(_ folder: URL, manifestURL: URL, decoder: JSONDecoder, store: SyncStateStore, seen: inout Set<String>) -> PageRead {
        guard let data = try? Data(contentsOf: manifestURL) else { return .unreadable }
        guard let manifest = try? decoder.decode(ExercisePageManifest.self, from: data) else {
            if let object = SyncJSON.parse(data) as? [String: Any], object["title"] == nil { return .ignored }
            return .unreadable
        }
        guard SyncPaths.isSafeName(manifest.id), !SkillGroupID.isGroup(manifest.id), let text = try? SyncUnitHasher.pageText(manifest) else { return .unreadable }
        var dataless = false
        let files = SyncInventory.entries(inFolder: folder, skipping: Self.pageOwnFiles, cache: store.hashCache, seen: &seen, dataless: &dataless)
        if dataless { return .unreadable }
        let hash = SyncUnitHasher.combine(manifest: SyncUnitHasher.pageManifestHash(manifest), files: SyncUnitHasher.filesHash(files))
        return .record(SyncUnitRecord(
            key: SyncUnitKey.make(.page, manifest.id), kind: .page, id: manifest.id, manifestText: text, files: files, hash: hash,
            parentID: manifest.parentID, title: manifest.title, firstSeen: manifest.updatedAt, location: folder, pageManifest: manifest
        ))
    }

    private func jsonTitle(_ object: [String: Any], fallback: String) -> String {
        (object["title"] as? String) ?? (object["name"] as? String) ?? fallback
    }

    private func scanFolderUnits(_ kind: SyncUnitKind, store: SyncStateStore, into snapshot: inout SyncSnapshot, seen: inout Set<String>, reliable: inout Bool) {
        guard let root = syncFolder(for: kind, store: store) else { return }
        for folder in sortedEntries(root, reliable: &reliable) {
            let id = folder.lastPathComponent
            guard !id.hasPrefix("."), isDirectory(folder) else { continue }
            let manifestURL = folder.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { continue }
            guard SyncPaths.isSafeName(id), let data = try? Data(contentsOf: manifestURL), let object = SyncJSON.parse(data) as? [String: Any],
                  let canonical = SyncJSON.data(object) else {
                reliable = false
                continue
            }
            if kind == .activity, (object["finished"] as? Bool) == false { continue }
            var dataless = false
            let files = SyncInventory.entries(inFolder: folder, skipping: ["manifest.json"], cache: store.hashCache, seen: &seen, dataless: &dataless)
            if dataless {
                reliable = false
                continue
            }
            let text = String(decoding: canonical, as: UTF8.self)
            let key = SyncUnitKey.make(kind, id)
            snapshot.units[key] = SyncUnitRecord(
                key: key, kind: kind, id: id, manifestText: text, files: files,
                hash: SyncUnitHasher.hash(kind: kind, manifest: text, files: files), parentID: nil,
                title: jsonTitle(object, fallback: id), firstSeen: fs.modificationDate(of: manifestURL) ?? Date(), location: folder, pageManifest: nil
            )
        }
    }

    private func scanRoutes(store: SyncStateStore, into snapshot: inout SyncSnapshot, reliable: inout Bool) {
        for file in sortedEntries(fs.routesDirectory, reliable: &reliable) {
            let name = file.lastPathComponent
            guard !name.hasPrefix("."), file.pathExtension == "json" else { continue }
            let id = file.deletingPathExtension().lastPathComponent
            guard SyncPaths.isSafeName(id), let data = try? Data(contentsOf: file), let object = SyncJSON.parse(data) as? [String: Any],
                  let canonical = SyncJSON.data(object) else {
                reliable = false
                continue
            }
            let text = String(decoding: canonical, as: UTF8.self)
            let key = SyncUnitKey.make(.route, id)
            snapshot.units[key] = SyncUnitRecord(
                key: key, kind: .route, id: id, manifestText: text, files: [],
                hash: SyncUnitHasher.hash(kind: .route, manifest: text, files: []), parentID: nil,
                title: jsonTitle(object, fallback: id), firstSeen: fs.modificationDate(of: file) ?? Date(), location: file, pageManifest: nil
            )
        }
    }

    private func scanLooseFiles(_ kind: SyncUnitKind, store: SyncStateStore, into snapshot: inout SyncSnapshot, seen: inout Set<String>, reliable: inout Bool) {
        guard let root = syncFolder(for: kind, store: store) else { return }
        for file in sortedEntries(root, reliable: &reliable) {
            let name = file.lastPathComponent
            guard SyncPaths.isSafeName(name), !isDirectory(file) else { continue }
            var dataless = false
            guard let found = SyncInventory.entry(forFile: file, name: name, cache: store.hashCache, seen: &seen, dataless: &dataless) else {
                if dataless { reliable = false }
                continue
            }
            let key = SyncUnitKey.make(kind, name)
            snapshot.units[key] = SyncUnitRecord(
                key: key, kind: kind, id: name, manifestText: nil, files: [found.entry],
                hash: SyncUnitHasher.hash(kind: kind, manifest: nil, files: [found.entry]), parentID: nil,
                title: name, firstSeen: found.modified, location: file, pageManifest: nil
            )
        }
    }
}

extension FileSystemHelper {
    func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
