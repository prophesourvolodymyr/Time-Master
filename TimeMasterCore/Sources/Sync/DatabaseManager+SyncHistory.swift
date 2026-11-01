import Foundation

public struct SyncHistoryMerge: Codable, Equatable, Sendable {
    public var added = 0
    public var replaced = 0
    public var deleted = 0
    public var send: [String] = []
    public var tombstones: [String: SyncStamp] = [:]

    public init() {}

    public var changedHere: Bool { added + replaced + deleted > 0 }
}

extension DatabaseManager {
    var syncHistoryURL: URL { fs.historyDirectory.appendingPathComponent("entries.jsonl") }

    struct SyncHistoryLine {
        var line: String
        var key: String
        var month: String
        var completedAt: Date
    }

    private static func isoDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    static func syncMonth(of date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 1970, parts.month ?? 1)
    }

    func parseHistoryLine(_ line: String) -> SyncHistoryLine? {
        guard let object = SyncJSON.parse(line) as? [String: Any], let id = object["id"] as? String, !id.isEmpty else { return nil }
        let date = (object["completedAt"] as? String).flatMap(Self.isoDate) ?? Date(timeIntervalSince1970: 0)
        return SyncHistoryLine(line: line, key: id.lowercased(), month: Self.syncMonth(of: date), completedAt: date)
    }

    func historyLines() -> [String] {
        guard let data = try? Data(contentsOf: syncHistoryURL) else { return [] }
        return String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func historyShards() -> [SyncShard] {
        var buckets: [String: [String]] = [:]
        for line in historyLines() {
            guard let parsed = parseHistoryLine(line) else { continue }
            buckets[parsed.month, default: []].append(line)
        }
        return buckets.keys.sorted().map { month in
            let lines = buckets[month] ?? []
            return SyncShard(name: month, count: lines.count, digest: SyncHash.hex(Data(lines.sorted().joined(separator: "\n").utf8)))
        }
    }

    public func syncShardLines(_ month: String, store: SyncStateStore) throws -> [String] {
        guard Self.isMonth(month) else { throw SyncError.invalid("\(month) is not a History month.") }
        return store.locked { historyLines().filter { parseHistoryLine($0)?.month == month } }
    }

    private static func isMonth(_ name: String) -> Bool {
        let parts = name.split(separator: "-", omittingEmptySubsequences: false)
        return parts.count == 2 && parts[0].count == 4 && parts[1].count == 2 && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    func recordHistoryTombstones(_ ids: [String], store: SyncStateStore) {
        guard !ids.isEmpty, store.hasState, let device = try? store.deviceID() else { return }
        var state = store.loadState()
        let stamp = state.clock.next(device: device)
        for id in ids { state.historyTombstones[id.lowercased()] = stamp }
        try? store.saveState(state)
    }

    func forgetHistoryTombstones(_ ids: [String], store: SyncStateStore) {
        guard store.hasState else { return }
        var state = store.loadState()
        var changed = false
        for id in ids where state.historyTombstones.removeValue(forKey: id.lowercased()) != nil { changed = true }
        if changed { try? store.saveState(state) }
    }

    private func preferred(_ a: SyncHistoryLine, over b: SyncHistoryLine) -> Bool {
        a.line >= b.line
    }

    public func syncMergeHistory(month: String, remoteLines: [String], remoteTombstones: [String: SyncStamp], store: SyncStateStore) throws -> SyncHistoryMerge {
        guard Self.isMonth(month) else { throw SyncError.invalid("\(month) is not a History month.") }
        return try store.locked {
            var state = store.loadState()
            for (id, stamp) in remoteTombstones {
                if let known = state.historyTombstones[id], known >= stamp { continue }
                state.historyTombstones[id] = stamp
                state.clock.observe(stamp)
            }
            var remote: [String: SyncHistoryLine] = [:]
            for line in remoteLines {
                if let parsed = parseHistoryLine(line) { remote[parsed.key] = parsed }
            }

            var result = SyncHistoryMerge()
            result.tombstones = state.historyTombstones
            var output: [String] = []
            var seen = Set<String>()
            var localKeys = Set<String>()
            for line in historyLines() {
                guard let mine = parseHistoryLine(line) else {
                    output.append(line)
                    continue
                }
                guard mine.month == month else {
                    output.append(line)
                    continue
                }
                let key = mine.key
                localKeys.insert(key)
                guard seen.insert(key).inserted else { continue }
                if state.historyTombstones[key] != nil {
                    result.deleted += 1
                    continue
                }
                if let theirs = remote[key], theirs.line != line {
                    if preferred(theirs, over: mine) {
                        output.append(theirs.line)
                        result.replaced += 1
                    } else {
                        output.append(line)
                        result.send.append(line)
                    }
                } else {
                    output.append(line)
                    if remote[key] == nil { result.send.append(line) }
                }
            }
            let newcomers = remote.values
                .filter { !localKeys.contains($0.key) && $0.month == month && state.historyTombstones[$0.key] == nil }
                .sorted { ($0.completedAt, $0.key) < ($1.completedAt, $1.key) }
            for theirs in newcomers {
                output.append(theirs.line)
                result.added += 1
            }
            if result.changedHere {
                try fs.writeAtomically(to: syncHistoryURL, data: Data((output.isEmpty ? "" : output.joined(separator: "\n") + "\n").utf8))
            }
            try store.saveState(state)
            return result
        }
    }

    public func syncConfigPayload(store: SyncStateStore, deviceName: String) throws -> SyncConfigPayload? {
        try store.locked {
            let scan = try scanLocked(store: store, deviceName: deviceName)
            guard let version = scan.index.config, let text = syncConfigText() else { return nil }
            return SyncConfigPayload(json: text, hash: version.hash, stamp: version.stamp)
        }
    }

    @discardableResult
    public func syncApplyConfig(_ payload: SyncConfigPayload, expectedHash: String?, store: SyncStateStore, deviceName: String) throws -> Bool {
        try store.locked {
            let scan = try scanLocked(store: store, deviceName: deviceName)
            guard scan.index.config?.hash == expectedHash else { return false }
            guard var object = SyncJSON.parse(payload.json) as? [String: Any] else {
                throw SyncError.invalid("The settings from the other device are damaged.")
            }
            let configURL = fs.configDirectory.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: configURL), let local = SyncJSON.parse(data) as? [String: Any], let preferences = local["outdoorRecording"] {
                object["outdoorRecording"] = preferences
            }
            guard let data = SyncJSON.data(object), let config = try? SyncCoding.decoder().decode(ConfigManifest.self, from: data) else {
                throw SyncError.invalid("The settings from the other device are damaged.")
            }
            try saveConfig(config)
            let device = try store.deviceID()
            var state = store.loadState()
            if let text = syncConfigText() {
                let hash = SyncHash.hex(Data(text.utf8))
                state.config = SyncConfigRecord(hash: hash, stamp: hash == payload.hash ? payload.stamp : state.clock.next(device: device))
            }
            state.clock.observe(payload.stamp)
            try store.saveState(state)
            return true
        }
    }
}

enum SyncConfigMerge {
    static func merge(base: String?, local: String?, remote: String, preferRemote: Bool) -> String {
        guard let local else { return remote }
        var merger = SyncJSONMerge(preferRemote: preferRemote)
        let merged = merger.merge(base: base.flatMap { SyncJSON.parse($0) }, local: SyncJSON.parse(local), remote: SyncJSON.parse(remote))
        guard let merged, let data = SyncJSON.data(merged) else { return preferRemote ? remote : local }
        return String(decoding: data, as: UTF8.self)
    }
}
