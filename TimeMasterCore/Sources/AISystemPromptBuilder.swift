import Foundation

public final class AISystemPromptBuilder {
    public enum Error: Swift.Error, LocalizedError {
        case knowledgeDirectoryNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .knowledgeDirectoryNotFound(let path): "Knowledge directory not found: \(path)"
            }
        }
    }

    private let fs: FileSystemHelper

    public init(fs: FileSystemHelper) {
        self.fs = fs
    }

    public func listKnowledgeFiles() -> [URL] {
        guard fs.directoryExists(at: fs.knowledgeDirectory) else { return [] }

        let enumerator = FileManager.default.enumerator(
            at: fs.knowledgeDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "md" {
                files.append(url)
            }
        }

        return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func buildSystemPrompt() -> String {
        let files = listKnowledgeFiles()
        guard !files.isEmpty else { return "" }

        let fileManager = FileManager.default
        let parts: [String] = files.compactMap { url in
            guard let data = fileManager.contents(atPath: url.path),
                  let content = String(data: data, encoding: .utf8) else {
                return nil
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !parts.isEmpty else { return "" }
        return parts.joined(separator: "\n\n---\n\n")
    }
}
