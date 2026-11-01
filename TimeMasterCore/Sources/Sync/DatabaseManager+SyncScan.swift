import Foundation

extension SyncStateStore {
    func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

extension DatabaseManager {
    public func syncScan(store: SyncStateStore, deviceName: String) throws -> SyncIndex {
        try store.locked { try scanLocked(store: store, deviceName: deviceName).index }
    }

    struct SyncScanResult {
        var index: SyncIndex
        var snapshot: SyncSnapshot
    }

    func scanLocked(store: SyncStateStore, deviceName: String) throws -> SyncScanResult {
        let device = try store.deviceID()
        var state = store.loadState()
        let snapshot = syncLoadSnapshot(store: store)

        var versions: [SyncUnitVersion] = []
        versions.reserveCapacity(snapshot.units.count)
        for record in snapshot.units.values {
            let key = record.key
            let hash = record.hash
            let stamp: SyncStamp
            if let known = state.units[key], known.hash == hash {
                stamp = known.stamp
            } else if state.units[key] == nil, state.tombstones[key] == nil {
                stamp = SyncStamp.at(record.firstSeen, device: device)
                state.units[key] = SyncKnownUnit(hash: hash, stamp: stamp)
            } else {
                stamp = state.clock.next(device: device)
                state.units[key] = SyncKnownUnit(hash: hash, stamp: stamp)
            }
            state.clock.observe(stamp)
            state.tombstones[key] = nil
            versions.append(SyncUnitVersion(key: key, hash: hash, stamp: stamp, parentID: record.parentID, title: record.title))
        }
        for key in Array(state.units.keys) where snapshot.units[key] == nil {
            guard let kind = SyncUnitKey.kind(key), snapshot.reliableKinds.contains(kind) else { continue }
            state.tombstones[key] = state.clock.next(device: device)
            state.units[key] = nil
        }

        let config = configRecord(state: &state, device: device)
        let index = SyncIndex(
            device: device, name: deviceName, kinds: snapshot.enabledKinds,
            units: versions.sorted { $0.key < $1.key }, tombstones: state.tombstones,
            shards: historyShards(), historyTombstones: state.historyTombstones, config: config
        )
        try store.saveState(state)
        store.saveHashCacheIfNeeded()
        return SyncScanResult(index: index, snapshot: snapshot)
    }

    func syncConfigText() -> String? {
        guard let data = try? Data(contentsOf: fs.configDirectory.appendingPathComponent("manifest.json")),
              var object = SyncJSON.parse(data) as? [String: Any] else { return nil }
        object["outdoorRecording"] = nil
        guard let canonical = SyncJSON.data(object) else { return nil }
        return String(decoding: canonical, as: UTF8.self)
    }

    private func configRecord(state: inout SyncState, device: String) -> SyncRecordVersion? {
        guard let text = syncConfigText() else { return nil }
        let hash = SyncHash.hex(Data(text.utf8))
        if let known = state.config, known.hash == hash { return SyncRecordVersion(hash: hash, stamp: known.stamp) }
        let stamp: SyncStamp
        if state.config == nil {
            stamp = SyncStamp.at(fs.modificationDate(of: fs.configDirectory.appendingPathComponent("manifest.json")) ?? Date(), device: device)
        } else {
            stamp = state.clock.next(device: device)
        }
        state.clock.observe(stamp)
        state.config = SyncConfigRecord(hash: hash, stamp: stamp)
        return SyncRecordVersion(hash: hash, stamp: stamp)
    }

    public func syncBundles(keys: [String], store: SyncStateStore, deviceName: String) throws -> [SyncUnitBundle] {
        try store.locked {
            let scan = try scanLocked(store: store, deviceName: deviceName)
            let versions = Dictionary(scan.index.units.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
            var bundles: [SyncUnitBundle] = []
            for key in keys {
                guard let record = scan.snapshot.units[key], let version = versions[key] else {
                    throw SyncError.notFound("No \(SyncUnitKey.kind(key)?.title ?? "item") with id \(key).")
                }
                bundles.append(SyncUnitBundle(key: key, manifest: record.manifestText, files: record.files, hash: version.hash, stamp: version.stamp))
            }
            return bundles
        }
    }

    func syncExistingPageFolder(_ id: String) -> URL? {
        guard SyncPaths.isSafeName(id), !SkillGroupID.isGroup(id), let folder = try? resolvePageFolder(id: id),
              fs.fileExists(at: folder.appendingPathComponent("manifest.json")) else { return nil }
        return folder
    }

    func syncUnitFolder(_ key: String, store: SyncStateStore) -> URL? {
        guard let (kind, id) = SyncUnitKey.split(key), SyncPaths.isSafeName(id) else { return nil }
        switch kind {
        case .page:
            return syncExistingPageFolder(id)
        case .workout, .activity:
            guard let root = syncFolder(for: kind, store: store) else { return nil }
            let folder = root.appendingPathComponent(id, isDirectory: true)
            return fs.directoryExists(at: folder) ? folder : nil
        case .route, .media, .photo, .music:
            return nil
        }
    }

    func syncFileURL(key: String, path: String, store: SyncStateStore) throws -> URL {
        guard let (kind, id) = SyncUnitKey.split(key), SyncPaths.isSafeName(id), SyncPaths.isSafeRelative(path) else {
            throw SyncError.invalid("\(path) is not a file path inside a library item.")
        }
        switch kind {
        case .page, .workout, .activity:
            guard path != "manifest.json", path != "guide.md" else { throw SyncError.invalid("\(path) is not a file path inside a library item.") }
            if let folder = syncUnitFolder(key, store: store) { return SyncPaths.append(path, to: folder) }
            throw SyncError.notFound("No \(kind.title) with id \(id).")
        case .media, .photo, .music:
            guard path == id, let root = syncFolder(for: kind, store: store) else { throw SyncError.invalid("\(path) is not a file of this folder.") }
            return root.appendingPathComponent(path)
        case .route:
            throw SyncError.invalid("A route has no files.")
        }
    }

    public func syncReadFile(key: String, path: String, offset: Int64, length: Int, store: SyncStateStore) throws -> Data {
        let url = try syncFileURL(key: key, path: path, store: store)
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw SyncError.notFound("No file \(path).") }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(max(0, offset)))
            return try handle.read(upToCount: max(0, length)) ?? Data()
        } catch {
            throw SyncError.io("Could not read \(path): \(error.localizedDescription)")
        }
    }

    public func syncLocalFiles(key: String, store: SyncStateStore) throws -> [SyncFileEntry] {
        store.locked {
            store.loadHashCacheIfNeeded()
            guard let (kind, id) = SyncUnitKey.split(key) else { return [] }
            var seen = Set<String>()
            var dataless = false
            var files: [SyncFileEntry] = []
            switch kind {
            case .page, .workout, .activity:
                guard let folder = syncUnitFolder(key, store: store) else { return [] }
                files = SyncInventory.entries(inFolder: folder, skipping: kind == .page ? ["manifest.json", "guide.md"] : ["manifest.json"], cache: store.hashCache, seen: &seen, dataless: &dataless)
            case .media, .photo, .music:
                guard let root = syncFolder(for: kind, store: store),
                      let found = SyncInventory.entry(forFile: root.appendingPathComponent(id), name: id, cache: store.hashCache, seen: &seen, dataless: &dataless) else { return [] }
                files = [found.entry]
            case .route:
                break
            }
            store.saveHashCacheIfNeeded()
            return files
        }
    }

    public func syncObserve(index: SyncIndex, store: SyncStateStore) throws {
        try store.locked {
            var state = store.loadState()
            let before = state.clock
            for unit in index.units { state.clock.observe(unit.stamp) }
            for stamp in index.tombstones.values { state.clock.observe(stamp) }
            for stamp in index.historyTombstones.values { state.clock.observe(stamp) }
            if let config = index.config { state.clock.observe(config.stamp) }
            if state.clock != before { try store.saveState(state) }
        }
    }

    public func syncNextStamp(store: SyncStateStore) throws -> SyncStamp {
        try store.locked {
            let device = try store.deviceID()
            var state = store.loadState()
            let stamp = state.clock.next(device: device)
            try store.saveState(state)
            return stamp
        }
    }

    public func syncChangeSignature(store: SyncStateStore) -> String {
        var parts: [String] = []
        let manager = FileManager.default
        func visit(_ url: URL, label: String, depth: Int) {
            guard let entries = try? manager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: []) else { return }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = entry.lastPathComponent
                if name.hasPrefix(".") { continue }
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                if values?.isDirectory == true {
                    parts.append("\(label)/\(name)/ \(modified)")
                    if depth < 12 { visit(entry, label: "\(label)/\(name)", depth: depth + 1) }
                } else {
                    parts.append("\(label)/\(name) \(values?.fileSize ?? 0) \(modified)")
                }
            }
        }
        for kind in syncEnabledKinds(store) {
            if let folder = syncFolder(for: kind, store: store) { visit(folder, label: kind.rawValue, depth: 0) }
        }
        visit(fs.historyDirectory, label: "history", depth: 0)
        let config = fs.configDirectory.appendingPathComponent("manifest.json")
        let attributes = try? manager.attributesOfItem(atPath: config.path)
        parts.append("config \((attributes?[.size] as? Int) ?? 0) \((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)")
        return SyncHash.hex(Data(parts.joined(separator: "\n").utf8))
    }
}
