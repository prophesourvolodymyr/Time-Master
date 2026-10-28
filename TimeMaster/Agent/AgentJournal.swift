import Foundation
import TimeMasterCore

final class AgentJournal: @unchecked Sendable {
    static let shared = AgentJournal()

    struct Entry: Codable {
        var id: String
        var time: Date
        var origin: String
        var tool: String
        var effects: [AgentEffect]
        var undone: String?
    }

    private let lock = NSLock()

    private var url: URL {
        DatabaseManager.shared.dataRoot.appendingPathComponent(".agent/journal.jsonl")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @discardableResult
    func record(origin: AgentOrigin, tool: String, effects: [AgentEffect]) -> String? {
        guard !effects.isEmpty else { return nil }
        let entry = Entry(id: UUID().uuidString.prefix(8).lowercased().description, time: Date(), origin: origin.rawValue, tool: tool, effects: effects)
        lock.lock()
        defer { lock.unlock() }
        append(entry)
        return entry.id
    }

    func undoable(id: String?) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        let entries = load()
        let undone = Set(entries.compactMap(\.undone))
        let candidates = entries.filter { $0.undone == nil && $0.origin == AgentOrigin.external.rawValue && !undone.contains($0.id) }
        if let id { return candidates.first { $0.id == id } }
        return candidates.last
    }

    func markUndone(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        append(Entry(id: UUID().uuidString.prefix(8).lowercased().description, time: Date(), origin: AgentOrigin.external.rawValue, tool: "undo", effects: [], undone: id))
    }

    private func load() -> [Entry] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { try? decoder.decode(Entry.self, from: Data($0.utf8)) }
    }

    private func append(_ entry: Entry) {
        guard let data = try? encoder.encode(entry) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data + Data("\n".utf8))
    }
}
