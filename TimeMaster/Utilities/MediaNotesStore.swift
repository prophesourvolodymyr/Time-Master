import Foundation

@MainActor
final class MediaNotesStore: ObservableObject {
    static let shared = MediaNotesStore()

    @Published private(set) var notes: [String: String]
    let directory: URL
    private let fileURL: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Media Notes", isDirectory: true)
        fileURL = directory.appendingPathComponent("notes.json")
        notes = Self.read(fileURL)
    }

    var assets: MarkdownAssets {
        FolderMarkdownAssets(folder: directory, subfolder: "Assets")
    }

    func note(for url: URL) -> String? {
        notes[url.lastPathComponent]
    }

    func set(_ text: String, for url: URL) throws {
        var updated = notes
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.removeValue(forKey: url.lastPathComponent)
        } else {
            updated[url.lastPathComponent] = text
        }
        guard updated != notes else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: fileURL, options: .atomic)
        notes = updated
    }

    private static func read(_ url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return decoded
    }
}
