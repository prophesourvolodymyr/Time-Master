import Foundation

public struct SyncPlan: Equatable, Sendable {
    public var update: [String] = []
    public var same: [String] = []
    public var deleteHere: [Deletion] = []
    public var deleteThere: [Deletion] = []

    public struct Deletion: Equatable, Sendable {
        public var key: String
        public var stamp: SyncStamp
        public var expectedHash: String
    }

    public init() {}

    public var isEmpty: Bool { update.isEmpty && deleteHere.isEmpty && deleteThere.isEmpty }
}

public enum SyncPlanner {
    public static func plan(local: SyncIndex, remote: SyncIndex, base: SyncBase) -> SyncPlan {
        var plan = SyncPlan()
        let shared = Set(local.kinds).intersection(remote.kinds)
        func isShared(_ key: String) -> Bool {
            guard let kind = SyncUnitKey.kind(key) else { return false }
            return shared.contains(kind)
        }
        let here = Dictionary(local.units.filter { isShared($0.key) }.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let there = Dictionary(remote.units.filter { isShared($0.key) }.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        for key in Set(here.keys).union(there.keys).sorted() {
            switch (here[key], there[key]) {
            case let (l?, r?):
                if l.hash == r.hash {
                    plan.same.append(key)
                } else {
                    plan.update.append(key)
                }
            case let (l?, nil):
                if let deleted = remote.tombstones[key], l.stamp <= deleted {
                    plan.deleteHere.append(.init(key: key, stamp: deleted, expectedHash: l.hash))
                } else {
                    plan.update.append(key)
                }
            case let (nil, r?):
                if let deleted = local.tombstones[key], r.stamp <= deleted {
                    plan.deleteThere.append(.init(key: key, stamp: deleted, expectedHash: r.hash))
                } else {
                    plan.update.append(key)
                }
            case (nil, nil):
                break
            }
        }
        return plan
    }
}

struct SyncFileMerge {
    var final: [SyncFileEntry] = []
    var fetch: [SyncFileEntry] = []
    var send: [SyncFileEntry] = []
    var removeHere: [String] = []
    var removeThere: [String] = []

    static func merge(base: [String: String], local: [SyncFileEntry], remote: [SyncFileEntry], preferRemote: Bool) -> SyncFileMerge {
        let l = Dictionary(local.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let r = Dictionary(remote.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var result = SyncFileMerge()
        for path in Set(l.keys).union(r.keys).sorted() {
            let mine = l[path], theirs = r[path]
            let ancestor = base[path]
            if mine?.sha256 == theirs?.sha256 {
                if let mine { result.final.append(mine) }
                continue
            }
            enum Side { case here, there }
            let winner: Side
            if mine?.sha256 == ancestor {
                winner = .there
            } else if theirs?.sha256 == ancestor {
                winner = .here
            } else if mine == nil {
                winner = .there
            } else if theirs == nil {
                winner = .here
            } else {
                winner = preferRemote ? .there : .here
            }
            switch winner {
            case .there:
                if let theirs {
                    result.final.append(theirs)
                    result.fetch.append(theirs)
                } else {
                    result.removeHere.append(path)
                }
            case .here:
                if let mine {
                    result.final.append(mine)
                    result.send.append(mine)
                } else {
                    result.removeThere.append(path)
                }
            }
        }
        result.final.sort { $0.path < $1.path }
        return result
    }
}

struct SyncUnitMerge {
    var key: String
    var kind: SyncUnitKind
    var title: String
    var manifestText: String?
    var files: SyncFileMerge
    var hash: String
    var changesHere: Bool
    var changesThere: Bool
    var textConflicts: Int

    static func merge(
        local: SyncUnitBundle?, remote: SyncUnitBundle?, base: SyncBaseUnit?,
        localLabel: String, remoteLabel: String
    ) throws -> SyncUnitMerge {
        guard let reference = local ?? remote, let kind = SyncUnitKey.kind(reference.key) else { throw SyncError.invalid("There is nothing to merge.") }
        let preferRemote: Bool
        if let local, let remote { preferRemote = remote.stamp > local.stamp } else { preferRemote = remote != nil }

        var text: String?
        var conflicts = 0
        var title = SyncUnitKey.split(reference.key)?.id ?? reference.key
        if kind.carriesManifest {
            switch (local?.manifest, remote?.manifest) {
            case let (l?, r?):
                if kind == .page {
                    let decoder = SyncCoding.decoder()
                    func page(_ text: String) throws -> ExercisePageManifest {
                        do { return try decoder.decode(ExercisePageManifest.self, from: Data(text.utf8)) } catch {
                            throw SyncError.invalid("A page from the other device is damaged: \(error.localizedDescription)")
                        }
                    }
                    let baseManifest = base?.manifest.flatMap { try? decoder.decode(ExercisePageManifest.self, from: Data($0.utf8)) }
                    let merged = try SyncManifestMerge.merge(
                        base: baseManifest, local: try page(l), remote: try page(r),
                        preferRemote: preferRemote, localLabel: localLabel, remoteLabel: remoteLabel
                    )
                    text = try SyncUnitHasher.pageText(merged.manifest)
                    conflicts = merged.textConflicts
                    title = merged.manifest.title
                } else {
                    let merged = SyncOpaqueMerge.merge(
                        base: base?.manifest, local: l, remote: r, preferRemote: preferRemote, localLabel: localLabel, remoteLabel: remoteLabel
                    )
                    text = merged.text
                    conflicts = merged.conflicts
                }
            case let (l?, nil): text = l
            case let (nil, r?): text = r
            case (nil, nil): throw SyncError.invalid("A \(kind.title) arrived without its data.")
            }
            if kind != .page, let object = text.flatMap({ SyncJSON.parse($0) }) as? [String: Any] {
                title = (object["title"] as? String) ?? (object["name"] as? String) ?? title
            }
        }
        let agreedFiles = (local != nil && remote != nil) ? (base?.files ?? [:]) : [:]
        let files = SyncFileMerge.merge(base: agreedFiles, local: local?.files ?? [], remote: remote?.files ?? [], preferRemote: preferRemote)
        let hash = SyncUnitHasher.hash(kind: kind, manifest: text, files: files.final)
        return SyncUnitMerge(
            key: reference.key, kind: kind, title: title, manifestText: text, files: files, hash: hash,
            changesHere: local?.hash != hash, changesThere: remote?.hash != hash, textConflicts: conflicts
        )
    }
}
