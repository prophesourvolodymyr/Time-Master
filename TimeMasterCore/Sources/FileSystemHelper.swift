import Foundation

public final class FileSystemHelper {
    public enum Error: Swift.Error, LocalizedError {
        case directoryCreationFailed(String)
        case writeFailed(String)
        case readFailed(String)
        case decodeFailed(String)
        case trashFailed(String)
        case notFound(String)

        public var errorDescription: String? {
            switch self {
            case .directoryCreationFailed(let path): "Failed to create directory: \(path)"
            case .writeFailed(let path): "Failed to write file: \(path)"
            case .readFailed(let path): "Failed to read file: \(path)"
            case .decodeFailed(let reason): "Failed to decode data: \(reason)"
            case .trashFailed(let path): "Failed to move to trash: \(path)"
            case .notFound(let path): "Not found: \(path)"
            }
        }
    }

    private let fileManager = FileManager.default
    public let dataRoot: URL

    private static let knownDirectories: Set<String> = [
        "Exercises Database", "Workouts", "Media", "Workspace",
        "Knowledge", "skills", "Config", "History", "Music",
        "Backups", ".trash"
    ]

    private static let schemaFileNames: Set<String> = [
        "manifest.json", "guide.md", "schema.json", "AGENTS.md"
    ]

    public init(dataRoot: URL) {
        self.dataRoot = dataRoot
    }

    public convenience init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.init(dataRoot: docs.appendingPathComponent("TimeMaster", isDirectory: true))
    }

    public var trashDirectory: URL {
        dataRoot.appendingPathComponent(".trash", isDirectory: true)
    }

    public var exercisesDatabaseDirectory: URL {
        dataRoot.appendingPathComponent("Exercises Database", isDirectory: true)
    }

    public var workoutsDirectory: URL {
        dataRoot.appendingPathComponent("Workouts", isDirectory: true)
    }

    public var mediaDirectory: URL {
        dataRoot.appendingPathComponent("Media", isDirectory: true)
    }

    public var workspaceDirectory: URL {
        dataRoot.appendingPathComponent("Workspace", isDirectory: true)
    }

    public var knowledgeDirectory: URL {
        dataRoot.appendingPathComponent("Knowledge", isDirectory: true)
    }

    public var skillsDirectory: URL {
        dataRoot.appendingPathComponent("skills", isDirectory: true)
    }

    public var configDirectory: URL {
        dataRoot.appendingPathComponent("Config", isDirectory: true)
    }

    public var historyDirectory: URL {
        dataRoot.appendingPathComponent("History", isDirectory: true)
    }

    public var musicDirectory: URL {
        dataRoot.appendingPathComponent("Music", isDirectory: true)
    }

    public var backupsDirectory: URL {
        dataRoot.appendingPathComponent("Backups", isDirectory: true)
    }

    public var schemaURL: URL {
        dataRoot.appendingPathComponent("schema.json")
    }

    public var agentsURL: URL {
        dataRoot.appendingPathComponent("AGENTS.md")
    }

    public func writeAtomically(to url: URL, data: Data) throws {
        let directory = url.deletingLastPathComponent()
        try ensureDirectory(directory)

        let tempURL = directory.appendingPathComponent(".\(url.lastPathComponent).tmp")
        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.moveItem(at: tempURL, to: url)
    }

    public func writeAtomically<T: Encodable>(to url: URL, value: T, encoder: JSONEncoder = JSONEncoder()) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try writeAtomically(to: url, data: data)
    }

    public func readManifest<T: Decodable>(from url: URL, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard fileManager.fileExists(atPath: url.path) else {
            throw Error.notFound(url.path)
        }
        guard let data = fileManager.contents(atPath: url.path) else {
            throw Error.readFailed(url.path)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw Error.decodeFailed("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    public func listDirectory(_ url: URL, skipNonSchema: Bool = true) throws -> [URL] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        if !skipNonSchema { return contents }
        return contents.filter { entry in
            let name = entry.lastPathComponent
            if name.hasPrefix(".") { return false }
            if Self.knownDirectories.contains(name) { return true }
            if Self.schemaFileNames.contains(name) { return true }
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: entry.path, isDirectory: &isDir)
            if isDir.boolValue {
                let manifest = entry.appendingPathComponent("manifest.json")
                return fileManager.fileExists(atPath: manifest.path)
            }
            return false
        }
    }

    public func ensureDirectory(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func moveToTrash(source: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        try ensureDirectory(trashDirectory)
        let timestamp = Int(Date().timeIntervalSince1970)
        let name = source.lastPathComponent
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: source.path, isDirectory: &isDir)

        if isDir.boolValue {
            let dest = trashDirectory.appendingPathComponent("\(timestamp)-\(name)", isDirectory: true)
            try fileManager.moveItem(at: source, to: dest)
        } else {
            let folder = trashDirectory.appendingPathComponent("\(timestamp)-\(name)", isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let dest = folder.appendingPathComponent(name)
            try fileManager.moveItem(at: source, to: dest)
        }
    }

    public func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public func removeItem(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func readRawData(from url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw Error.notFound(url.path)
        }
        guard let data = fileManager.contents(atPath: url.path) else {
            throw Error.readFailed(url.path)
        }
        return data
    }

    public func writeRawData(to url: URL, data: Data) throws {
        let directory = url.deletingLastPathComponent()
        try ensureDirectory(directory)
        try data.write(to: url, options: .atomic)
    }

    public func copyItem(from source: URL, to dest: URL) throws {
        let dir = dest.deletingLastPathComponent()
        try ensureDirectory(dir)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: source, to: dest)
    }
}
