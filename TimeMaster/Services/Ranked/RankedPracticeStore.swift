import Foundation
import Combine
import TimeMasterCore

@MainActor
final class RankedPracticeStore: ObservableObject {
    static let shared = RankedPracticeStore()
    @Published private(set) var results: [RankedPracticeResult] = []
    @Published private(set) var error: String?
    private let directoryURL: URL

    init(directoryURL: URL = DatabaseManager.shared.dataRoot.appendingPathComponent("ranked/practice", isDirectory: true)) {
        self.directoryURL = directoryURL
        reload()
    }

    func results(for accountID: String?) -> [RankedPracticeResult] {
        results.filter { $0.accountID == accountID }
    }

    func reload() {
        do {
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                results = []
                error = nil
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let loaded = try files.filter { $0.pathExtension == "json" }.map { url in
                let value = try decoder.decode(RankedPracticeResult.self, from: Data(contentsOf: url))
                guard value.isValid, url.deletingPathExtension().lastPathComponent == value.id.uuidString else {
                    throw RankedPracticeStorageError.unreadable
                }
                return value
            }
            results = loaded.sorted { $0.startedAt > $1.startedAt }
            error = nil
        } catch {
            self.error = "Practice history could not be read. Existing results were preserved. \(error.localizedDescription)"
        }
    }

    func save(_ result: RankedPracticeResult) throws {
        guard result.isValid else { throw RankedPracticeStorageError.invalidResult }
        let url = directoryURL.appendingPathComponent(result.id.uuidString).appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: url.path) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            let existing = try decoder.decode(RankedPracticeResult.self, from: Data(contentsOf: url))
            guard existing == result else { throw RankedPracticeStorageError.conflictingResult }
            if !results.contains(where: { $0.id == result.id }) { insert(result) }
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encoder.encode(result).write(to: url, options: .atomic)
        insert(result)
    }

    private func insert(_ result: RankedPracticeResult) {
        let index = results.firstIndex { $0.startedAt < result.startedAt } ?? results.endIndex
        results.insert(result, at: index)
    }
}

enum RankedPracticeStorageError: LocalizedError {
    case unreadable, invalidResult, conflictingResult

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Practice history contains an unreadable result."
        case .invalidResult: return "This Practice result could not be saved because its score or duration is invalid."
        case .conflictingResult: return "A different result already exists for this Practice round. It was not overwritten."
        }
    }
}
