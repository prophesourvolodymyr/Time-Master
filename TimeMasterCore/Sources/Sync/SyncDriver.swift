import Foundation

public struct SyncReport: Equatable, Sendable {
    public var itemsHere = 0
    public var itemsThere = 0
    public var deletedHere = 0
    public var deletedThere = 0
    public var historyHere = 0
    public var historyThere = 0
    public var configHere = false
    public var configThere = false
    public var conflicts: [String] = []
    public var warnings: [String] = []
    public var changes: SyncChangeSet = []

    public init() {}

    public var changedHere: Bool { itemsHere + deletedHere + historyHere > 0 || configHere }
    public var changedThere: Bool { itemsThere + deletedThere + historyThere > 0 || configThere }
}

public final class SyncDriver: @unchecked Sendable {
    private let engine: SyncEngine
    private let remote: SyncEndpoint
    private let peer: SyncPeerRecord
    private let progress: @Sendable (String) -> Void

    private static let maxPasses = 4

    public init(engine: SyncEngine, peer: SyncPeerRecord, remote: SyncEndpoint, progress: @escaping @Sendable (String) -> Void = { _ in }) {
        self.engine = engine
        self.peer = peer
        self.remote = remote
        self.progress = progress
    }

    public func reconcile() async throws -> SyncReport {
        var report = SyncReport()
        for _ in 0..<Self.maxPasses {
            guard try await unitsPass(&report) else { break }
        }
        try await historyPass(&report)
        try await configPass(&report)
        var base = engine.store.loadBase(peer: peer.id)
        base.lastSyncedAt = Date()
        try engine.store.saveBase(base, peer: peer.id)
        return report
    }

    private func unitsPass(_ report: inout SyncReport) async throws -> Bool {
        try Task.checkCancellation()
        progress("Looking for changes…")
        let local = try engine.scan()
        let remoteIndex = try await remote.index()
        guard remoteIndex.schema == local.schema else { throw SyncFailure.incompatible }
        try engine.database.syncObserve(index: remoteIndex, store: engine.store)
        var base = engine.store.loadBase(peer: peer.id)
        let plan = SyncPlanner.plan(local: local, remote: remoteIndex, base: base)

        let hashes = Dictionary(local.units.map { ($0.key, $0.hash) }, uniquingKeysWith: { first, _ in first })
        let needBase = plan.same.filter { base.units[$0]?.hash != hashes[$0] }
        if !needBase.isEmpty {
            for bundle in try engine.database.syncBundles(keys: needBase, store: engine.store, deviceName: engine.deviceName) {
                base.units[bundle.key] = SyncBaseUnit(hash: bundle.hash, manifest: bundle.manifest, files: Self.fileMap(bundle.files))
            }
            try engine.store.saveBase(base, peer: peer.id)
        }
        guard !plan.isEmpty else { return false }

        let hereKeys = Set(local.units.map(\.key))
        let thereKeys = Set(remoteIndex.units.map(\.key))
        var localBundles: [String: SyncUnitBundle] = [:]
        for bundle in try engine.database.syncBundles(keys: plan.update.filter(hereKeys.contains), store: engine.store, deviceName: engine.deviceName) {
            localBundles[bundle.key] = bundle
        }
        var remoteBundles: [String: SyncUnitBundle] = [:]
        let wanted = plan.update.filter(thereKeys.contains)
        for start in stride(from: 0, to: wanted.count, by: SyncLimits.unitsPerRequest) {
            try Task.checkCancellation()
            progress("Reading \(peer.name)…")
            for bundle in try await remote.bundles(keys: Array(wanted[start..<min(wanted.count, start + SyncLimits.unitsPerRequest)])) {
                remoteBundles[bundle.key] = bundle
            }
        }
        var merges: [SyncUnitMerge] = []
        var stamps: [String: SyncStamp] = [:]
        for key in plan.update {
            let merge = try SyncUnitMerge.merge(
                local: localBundles[key], remote: remoteBundles[key], base: base.units[key],
                localLabel: engine.deviceName, remoteLabel: peer.name
            )
            merges.append(merge)
            stamps[key] = try finalStamp(for: merge, local: localBundles[key], remote: remoteBundles[key])
            if merge.textConflicts > 0 { report.conflicts.append(merge.title) }
        }

        let staging = try engine.database.syncStagingFolder()
        defer { engine.database.syncRemoveStaging(staging) }
        var stagedFiles: [String: [String: URL]] = [:]
        for merge in merges where merge.changesHere {
            let unitFolder = staging.appendingPathComponent(SyncHash.hex(Data(merge.key.utf8)), isDirectory: true)
            for file in merge.files.fetch {
                let target = SyncPaths.append(file.path, to: unitFolder)
                try await download(file, unitKey: merge.key, to: target)
                stagedFiles[merge.key, default: [:]][file.path] = target
            }
        }

        if merges.contains(where: \.changesHere) || !plan.deleteHere.isEmpty {
            progress("Making a safety copy…")
            try engine.ensureSafetyCopy(for: peer.id)
        }

        let items = merges.filter(\.changesHere).map { merge in
            SyncApplyItem(
                key: merge.key, manifestText: merge.manifestText, stamp: stamps[merge.key] ?? SyncStamp(millis: 0, device: ""),
                expectedLocalHash: localBundles[merge.key]?.hash, files: merge.files.final,
                stagedFiles: stagedFiles[merge.key] ?? [:], removeFiles: merge.files.removeHere, finalHash: merge.hash
            )
        }
        let deletionsHere = plan.deleteHere.map { SyncApplyDeletion(key: $0.key, stamp: $0.stamp, expectedLocalHash: $0.expectedHash) }
        var here = SyncApplyReport()
        if !items.isEmpty || !deletionsHere.isEmpty {
            progress("Updating this device…")
            here = try engine.database.syncApply(items: items, deletions: deletionsHere, store: engine.store, deviceName: engine.deviceName)
        }
        let storedHere = Set(here.applied)

        var pushes: [SyncPushUnit] = []
        for merge in merges where merge.changesThere {
            if merge.changesHere && !storedHere.contains(merge.key) { continue }
            let bundle = SyncUnitBundle(
                key: merge.key, manifest: merge.manifestText, files: merge.files.final, hash: merge.hash,
                stamp: stamps[merge.key] ?? SyncStamp(millis: 0, device: "")
            )
            pushes.append(SyncPushUnit(bundle: bundle, expectedHash: remoteBundles[merge.key]?.hash, removeFiles: merge.files.removeThere))
        }
        let deletionsThere = plan.deleteThere.map { SyncPushDeletion(key: $0.key, stamp: $0.stamp, expectedHash: $0.expectedHash) }
        var there = SyncPushResult()
        if !pushes.isEmpty || !deletionsThere.isEmpty {
            progress("Updating \(peer.name)…")
            there = try await push(SyncPushRequest(units: pushes, deletions: deletionsThere))
        }
        let storedThere = Set(there.applied)

        var base3 = engine.store.loadBase(peer: peer.id)
        for merge in merges {
            let hereOK = !merge.changesHere || storedHere.contains(merge.key)
            let thereOK = !merge.changesThere || storedThere.contains(merge.key)
            if hereOK && thereOK {
                base3.units[merge.key] = SyncBaseUnit(hash: merge.hash, manifest: merge.manifestText, files: Self.fileMap(merge.files.final))
            }
        }
        for deletion in plan.deleteHere where here.deleted.contains(deletion.key) { base3.units[deletion.key] = nil }
        for deletion in plan.deleteThere where there.deleted.contains(deletion.key) { base3.units[deletion.key] = nil }
        try engine.store.saveBase(base3, peer: peer.id)

        report.changes.formUnion(here.changes)
        report.itemsHere += here.applied.count
        report.deletedHere += here.deleted.count
        report.itemsThere += there.applied.count
        report.deletedThere += there.deleted.count
        report.warnings += here.warnings + there.warnings
        return true
    }

    private func finalStamp(for merge: SyncUnitMerge, local: SyncUnitBundle?, remote: SyncUnitBundle?) throws -> SyncStamp {
        guard let local else {
            if let remote { return remote.stamp }
            return try engine.database.syncNextStamp(store: engine.store)
        }
        guard let remote else { return local.stamp }
        if !merge.changesHere { return local.stamp }
        if !merge.changesThere { return remote.stamp }
        return try engine.database.syncNextStamp(store: engine.store)
    }

    private static func fileMap(_ files: [SyncFileEntry]) -> [String: String] {
        Dictionary(files.map { ($0.path, $0.sha256) }, uniquingKeysWith: { first, _ in first })
    }

    private func download(_ file: SyncFileEntry, unitKey: String, to url: URL) async throws {
        try Task.checkCancellation()
        try engine.database.fs.ensureDirectory(url.deletingLastPathComponent())
        guard FileManager.default.createFile(atPath: url.path, contents: nil), let handle = try? FileHandle(forWritingTo: url) else {
            throw SyncError.io("Could not make room for \(file.path).")
        }
        defer { try? handle.close() }
        var offset: Int64 = 0
        while offset < file.size {
            try Task.checkCancellation()
            let chunk = try await remote.readFile(unitKey: unitKey, path: file.path, offset: offset, length: SyncLimits.chunkBytes)
            guard !chunk.isEmpty else { throw SyncFailure.remote("\(file.path) ended early on the other device.") }
            try handle.write(contentsOf: chunk)
            offset += Int64(chunk.count)
            progress("Receiving \((file.path as NSString).lastPathComponent)…")
        }
        guard (try? SyncHash.hex(ofFile: url)) == file.sha256 else {
            throw SyncFailure.remote("\((file.path as NSString).lastPathComponent) changed while it was copied. It will be tried again.")
        }
    }

    private func push(_ request: SyncPushRequest) async throws -> SyncPushResult {
        let ticket = try await remote.pushStart(request)
        for need in ticket.needed {
            var offset: Int64 = 0
            if need.file.size == 0 {
                try await remote.pushFile(token: ticket.token, unitKey: need.unitKey, path: need.file.path, offset: 0, data: Data())
                continue
            }
            while offset < need.file.size {
                try Task.checkCancellation()
                let chunk = try engine.database.syncReadFile(key: need.unitKey, path: need.file.path, offset: offset, length: SyncLimits.chunkBytes, store: engine.store)
                guard !chunk.isEmpty else { throw SyncFailure.remote("\(need.file.path) changed while it was sent. It will be tried again.") }
                try await remote.pushFile(token: ticket.token, unitKey: need.unitKey, path: need.file.path, offset: offset, data: chunk)
                offset += Int64(chunk.count)
                progress("Sending \((need.file.path as NSString).lastPathComponent)…")
            }
        }
        return try await remote.pushCommit(token: ticket.token)
    }

    private func historyPass(_ report: inout SyncReport) async throws {
        try Task.checkCancellation()
        let local = try engine.scan()
        let remoteIndex = try await remote.index()
        let hereShards = Dictionary(local.shards.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let thereShards = Dictionary(remoteIndex.shards.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let tombstonesDiffer = local.historyTombstones != remoteIndex.historyTombstones
        var remoteTombstones = remoteIndex.historyTombstones
        for month in Set(hereShards.keys).union(thereShards.keys).sorted() {
            let same = hereShards[month] == thereShards[month]
            if same && !tombstonesDiffer { continue }
            progress("Syncing your history…")
            let theirLines = thereShards[month] != nil ? try await remote.shardLines(month: month) : []
            let merge = try engine.database.syncMergeHistory(month: month, remoteLines: theirLines, remoteTombstones: remoteTombstones, store: engine.store)
            report.historyHere += merge.added + merge.replaced + merge.deleted
            if merge.changedHere { report.changes.insert(.history) }
            remoteTombstones = merge.tombstones
            if !merge.send.isEmpty || merge.tombstones != remoteIndex.historyTombstones {
                let theirs = try await remote.mergeHistory(month: month, lines: merge.send, tombstones: merge.tombstones)
                report.historyThere += theirs.added + theirs.replaced + theirs.deleted
            }
        }
    }

    private func configPass(_ report: inout SyncReport) async throws {
        try Task.checkCancellation()
        let local = try engine.database.syncConfigPayload(store: engine.store, deviceName: engine.deviceName)
        let there = try await remote.configPayload()
        guard local?.hash != there?.hash else { return }
        var base = engine.store.loadBase(peer: peer.id)
        let preferRemote = (there?.stamp ?? SyncStamp(millis: 0, device: "")) > (local?.stamp ?? SyncStamp(millis: 0, device: ""))
        let mergedText: String
        switch (local, there) {
        case let (l?, r?): mergedText = SyncConfigMerge.merge(base: base.config, local: l.json, remote: r.json, preferRemote: preferRemote)
        case let (l?, nil): mergedText = l.json
        case let (nil, r?): mergedText = r.json
        case (nil, nil): return
        }
        let mergedHash = SyncHash.hex(Data(mergedText.utf8))
        let stamp: SyncStamp
        if let there, there.hash == mergedHash {
            stamp = there.stamp
        } else if let local, local.hash == mergedHash {
            stamp = local.stamp
        } else {
            stamp = try engine.database.syncNextStamp(store: engine.store)
        }
        let payload = SyncConfigPayload(json: mergedText, hash: mergedHash, stamp: stamp)
        var storedHere = true
        var storedThere = true
        if local?.hash != mergedHash {
            storedHere = try engine.database.syncApplyConfig(payload, expectedHash: local?.hash, store: engine.store, deviceName: engine.deviceName)
            if storedHere {
                report.configHere = true
                report.changes.insert(.config)
            }
        }
        if there?.hash != mergedHash, storedHere {
            storedThere = try await remote.applyConfig(payload, expectedHash: there?.hash)
            if storedThere { report.configThere = true }
        }
        if storedHere && storedThere {
            base.config = mergedText
            base.configHash = mergedHash
            try engine.store.saveBase(base, peer: peer.id)
        }
    }
}
