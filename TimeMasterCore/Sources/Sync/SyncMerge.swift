import Foundation

enum SyncJSON {
    static func parse(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func parse(_ text: String) -> Any? {
        parse(Data(text.utf8))
    }

    static func data(_ value: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (l?, r?): return (l as AnyObject).isEqual(r)
        default: return false
        }
    }
}

enum SyncTextMerge {
    struct Hunk: Equatable {
        var start: Int
        var end: Int
        var lines: [String]
    }

    private static let maxCells = 4_000_000

    static func merge(base: String, local: String, remote: String, localLabel: String, remoteLabel: String) -> (text: String, conflicts: Int) {
        if local == remote { return (local, 0) }
        if local == base { return (remote, 0) }
        if remote == base { return (local, 0) }
        let b = lines(base), l = lines(local), r = lines(remote)
        let hl = hunks(from: b, to: l)
        let hr = hunks(from: b, to: r)
        var out: [String] = []
        var position = 0
        var i = 0, j = 0
        var conflicts = 0

        func overlaps(_ x: Hunk, _ y: Hunk) -> Bool {
            if x.start == x.end, y.start == y.end { return x.start == y.start }
            return x.start < y.end && y.start < x.end
        }

        while i < hl.count || j < hr.count {
            let a: Hunk? = i < hl.count ? hl[i] : nil
            let c: Hunk? = j < hr.count ? hr[j] : nil
            if let a, c == nil || (a.end <= c!.start && !overlaps(a, c!)) {
                out += b[position..<a.start]
                out += a.lines
                position = a.end
                i += 1
                continue
            }
            if let c, a == nil || (c.end <= a!.start && !overlaps(a!, c)) {
                out += b[position..<c.start]
                out += c.lines
                position = c.end
                j += 1
                continue
            }
            guard let a, let c else { break }
            let start = min(a.start, c.start)
            var end = max(a.end, c.end)
            var i2 = i + 1, j2 = j + 1
            var grew = true
            while grew {
                grew = false
                if i2 < hl.count, hl[i2].start < end || (hl[i2].start == end && hl[i2].end == end && start == end) {
                    end = max(end, hl[i2].end)
                    i2 += 1
                    grew = true
                }
                if j2 < hr.count, hr[j2].start < end || (hr[j2].start == end && hr[j2].end == end && start == end) {
                    end = max(end, hr[j2].end)
                    j2 += 1
                    grew = true
                }
            }
            func apply(_ hunks: ArraySlice<Hunk>) -> [String] {
                var result: [String] = []
                var cursor = start
                for hunk in hunks {
                    result += b[cursor..<hunk.start]
                    result += hunk.lines
                    cursor = hunk.end
                }
                result += b[cursor..<end]
                return result
            }
            let mine = apply(hl[i..<i2])
            let theirs = apply(hr[j..<j2])
            let original = Array(b[start..<end])
            out += b[position..<start]
            if mine == theirs {
                out += mine
            } else if mine == original {
                out += theirs
            } else if theirs == original {
                out += mine
            } else {
                conflicts += 1
                out.append("<<<<<<< \(localLabel)")
                out += mine
                out.append("=======")
                out += theirs
                out.append(">>>>>>> \(remoteLabel)")
            }
            position = end
            i = i2
            j = j2
        }
        out += b[position...]
        return (out.joined(separator: "\n"), conflicts)
    }

    static func lines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    static func hunks(from a: [String], to b: [String]) -> [Hunk] {
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let aMid = Array(a[prefix..<(a.count - suffix)])
        let bMid = Array(b[prefix..<(b.count - suffix)])
        if aMid.isEmpty, bMid.isEmpty { return [] }
        if aMid.isEmpty { return [Hunk(start: prefix, end: prefix, lines: bMid)] }
        if bMid.isEmpty { return [Hunk(start: prefix, end: prefix + aMid.count, lines: [])] }
        let n = aMid.count, m = bMid.count
        guard n * m <= maxCells else { return [Hunk(start: prefix, end: prefix + n, lines: bMid)] }

        var table = [[Int32]](repeating: [Int32](repeating: 0, count: m + 1), count: n + 1)
        for x in stride(from: n - 1, through: 0, by: -1) {
            for y in stride(from: m - 1, through: 0, by: -1) {
                table[x][y] = aMid[x] == bMid[y] ? table[x + 1][y + 1] + 1 : max(table[x + 1][y], table[x][y + 1])
            }
        }
        var result: [Hunk] = []
        var x = 0, y = 0
        var openA: Int?
        var openB = 0
        while x < n || y < m {
            if x < n, y < m, aMid[x] == bMid[y] {
                if let from = openA {
                    result.append(Hunk(start: prefix + from, end: prefix + x, lines: Array(bMid[openB..<y])))
                    openA = nil
                }
                x += 1
                y += 1
            } else {
                if openA == nil {
                    openA = x
                    openB = y
                }
                if y < m, x == n || table[x][y + 1] >= table[x + 1][y] {
                    y += 1
                } else {
                    x += 1
                }
            }
        }
        if let from = openA {
            result.append(Hunk(start: prefix + from, end: prefix + x, lines: Array(bMid[openB..<y])))
        }
        return result
    }
}

struct SyncJSONMerge {
    var preferRemote: Bool
    var localLabel = "This device"
    var remoteLabel = "Other device"
    private(set) var textConflicts = 0

    private static let identityKeys = ["id", "week", "url"]
    private static let textKeys: Set<String> = ["markdownBody", "markdown", "notes", "text", "publicDescription"]

    init(preferRemote: Bool, localLabel: String = "This device", remoteLabel: String = "Other device") {
        self.preferRemote = preferRemote
        self.localLabel = localLabel
        self.remoteLabel = remoteLabel
    }

    mutating func merge(base: Any?, local: Any?, remote: Any?, key: String? = nil) -> Any? {
        if SyncJSON.equal(local, remote) { return local }
        if SyncJSON.equal(local, base) { return remote }
        if SyncJSON.equal(remote, base) { return local }
        guard let local else { return remote }
        guard let remote else { return local }
        if let l = local as? [String: Any], let r = remote as? [String: Any] {
            return mergeObjects(base as? [String: Any], l, r)
        }
        if let l = local as? [Any], let r = remote as? [Any] {
            return mergeLists(base as? [Any], l, r)
        }
        if let l = local as? String, let r = remote as? String, Self.isText(key, l, r) {
            if !(base is String) {
                if l.contains(r) { return l }
                if r.contains(l) { return r }
            }
            let result = SyncTextMerge.merge(base: (base as? String) ?? "", local: l, remote: r, localLabel: localLabel, remoteLabel: remoteLabel)
            textConflicts += result.conflicts
            return result.text
        }
        return preferRemote ? remote : local
    }

    private static func isText(_ key: String?, _ l: String, _ r: String) -> Bool {
        if let key, textKeys.contains(key) { return true }
        return l.contains("\n") || r.contains("\n")
    }


    private mutating func mergeObjects(_ base: [String: Any]?, _ local: [String: Any], _ remote: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        var keys = Set(local.keys).union(remote.keys)
        if let base { keys.formUnion(base.keys) }
        for key in keys {
            if let value = merge(base: base?[key], local: local[key], remote: remote[key], key: key) {
                out[key] = value
            }
        }
        return out
    }


    private mutating func mergeLists(_ base: [Any]?, _ local: [Any], _ remote: [Any]) -> [Any] {
        let everything = local + remote + (base ?? [])
        if !everything.isEmpty, let key = Self.identityKeys.first(where: { key in
            everything.allSatisfy { ($0 as? [String: Any])?[key] is String }
        }) {
            return mergeByIdentity(key, base, local, remote)
        }
        if everything.allSatisfy({ $0 is String || $0 is NSNumber }) {
            return mergeAsSet(base ?? [], local, remote)
        }
        return preferRemote ? remote : local
    }

    private mutating func mergeByIdentity(_ key: String, _ base: [Any]?, _ local: [Any], _ remote: [Any]) -> [Any] {
        func ids(_ list: [Any]) -> [String] { list.compactMap { ($0 as? [String: Any])?[key] as? String } }
        func map(_ list: [Any]?) -> [String: Any] {
            var result: [String: Any] = [:]
            for item in list ?? [] {
                if let id = (item as? [String: Any])?[key] as? String { result[id] = item }
            }
            return result
        }
        let l = map(local), r = map(remote), b = map(base)
        let primary = preferRemote ? ids(remote) : ids(local)
        let secondary = preferRemote ? ids(local) : ids(remote)
        var order = primary
        var present = Set(primary)
        for (position, id) in secondary.enumerated() where !present.contains(id) {
            let before = secondary[..<position].last(where: { present.contains($0) })
            let insertAt = before.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? (position == 0 ? 0 : order.count)
            order.insert(id, at: insertAt)
            present.insert(id)
        }
        var out: [Any] = []
        for id in order {
            if let merged = merge(base: b[id], local: l[id], remote: r[id]) { out.append(merged) }
        }
        return out
    }

    private func mergeAsSet(_ base: [Any], _ local: [Any], _ remote: [Any]) -> [Any] {
        func contains(_ list: [Any], _ value: Any) -> Bool { list.contains { SyncJSON.equal($0, value) } }
        let primary = preferRemote ? remote : local
        let other = preferRemote ? local : remote
        var result = primary.filter { value in !(contains(base, value) && !contains(other, value)) }
        for (position, value) in other.enumerated() where !contains(base, value) && !contains(result, value) {
            let before = other[..<position].last(where: { contains(result, $0) })
            let insertAt = before.flatMap { anchor in result.firstIndex { SyncJSON.equal($0, anchor) } }.map { $0 + 1 } ?? (position == 0 ? 0 : result.count)
            result.insert(value, at: insertAt)
        }
        return result
    }
}


enum SyncManifestMerge {
    struct Result {
        var manifest: ExercisePageManifest
        var textConflicts: Int
    }

    private static let placeKeys = ["parentID", "skillBoardSectionID", "skillBoardOrder"]

    static func merge(
        base: ExercisePageManifest?, local: ExercisePageManifest, remote: ExercisePageManifest,
        preferRemote: Bool, localLabel: String, remoteLabel: String
    ) throws -> Result {
        func object(_ manifest: ExercisePageManifest) throws -> [String: Any] {
            guard let value = SyncUnitHasher.pageObject(manifest) else {
                throw SyncError.invalid("\(manifest.title) could not be compared.")
            }
            return value
        }
        let localObject = try object(local), remoteObject = try object(remote)
        let baseObject = try base.map(object)
        var merger = SyncJSONMerge(preferRemote: preferRemote, localLabel: localLabel, remoteLabel: remoteLabel)
        let merged = merger.merge(base: baseObject, local: localObject, remote: remoteObject)
        guard var dictionary = merged as? [String: Any] else {
            throw SyncError.invalid("\(local.title) could not be merged.")
        }
        func changed(_ side: [String: Any]) -> Bool {
            guard let baseObject else { return true }
            return placeKeys.contains { !SyncJSON.equal(side[$0], baseObject[$0]) }
        }
        let localMoved = changed(localObject), remoteMoved = changed(remoteObject)
        let placeSide: [String: Any]
        if localMoved != remoteMoved {
            placeSide = localMoved ? localObject : remoteObject
        } else {
            placeSide = preferRemote ? remoteObject : localObject
        }
        for key in placeKeys { dictionary[key] = placeSide[key] }
        guard let data = SyncJSON.data(dictionary) else {
            throw SyncError.invalid("\(local.title) could not be merged.")
        }
        var manifest: ExercisePageManifest
        do {
            manifest = try SyncCoding.decoder().decode(ExercisePageManifest.self, from: data)
        } catch {
            throw SyncError.invalid("The merged \(local.title) is not a valid page: \(error.localizedDescription)")
        }
        manifest.id = local.id
        manifest.createdAt = min(local.createdAt, remote.createdAt)
        manifest.updatedAt = max(local.updatedAt, remote.updatedAt)
        sanitize(&manifest)
        return Result(manifest: manifest, textConflicts: merger.textConflicts)
    }

    static func sanitize(_ manifest: inout ExercisePageManifest) {
        var normalized = DatabaseManager.normalizedPageManifest(manifest, parentID: manifest.parentID, parentIsSkill: nil)
        normalized.childIDs = normalized.childIDs.uniqued().filter { $0 != normalized.id }
        normalized.linkedPageIDs = normalized.linkedPageIDs.uniqued()
        manifest = normalized
    }
}

enum SyncOpaqueMerge {
    static func merge(base: String?, local: String, remote: String, preferRemote: Bool, localLabel: String, remoteLabel: String) -> (text: String, conflicts: Int) {
        var merger = SyncJSONMerge(preferRemote: preferRemote, localLabel: localLabel, remoteLabel: remoteLabel)
        let merged = merger.merge(base: base.flatMap { SyncJSON.parse($0) }, local: SyncJSON.parse(local), remote: SyncJSON.parse(remote))
        guard let merged, let data = SyncJSON.data(merged) else { return (preferRemote ? remote : local, 0) }
        return (String(decoding: data, as: UTF8.self), merger.textConflicts)
    }
}
