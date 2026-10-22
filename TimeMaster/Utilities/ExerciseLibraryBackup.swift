import Foundation
import ZIPFoundation
import TimeMasterCore

enum ExerciseLibraryBackup {
    struct ImportResult {
        var pages = 0
        var media = 0
        var duplicates = 0
    }

    static func validate(_ archive: Archive) throws {
        for entry in archive {
            let path = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            guard entry.type != .symlink, validPath(path) else { throw BackupError.invalidBackup }
        }
    }

    static func add(to archive: Archive, database: DatabaseManager) throws {
        let root = database.exercisesDatabaseURL
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        let files = try regularFiles(in: root)
        var referencedMedia = Set<String>()
        for (relative, url) in files {
            try archive.addEntry(with: "database/Exercises Database/" + relative, fileURL: url)
            if url.lastPathComponent == "manifest.json" {
                let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
                let folder = url.deletingLastPathComponent()
                for name in object?["mediaFilenames"] as? [String] ?? [] where !FileManager.default.fileExists(atPath: folder.appendingPathComponent("media/" + name).path) {
                    referencedMedia.insert(name)
                }
                if let cover = object?["coverImageFilename"] as? String,
                   !FileManager.default.fileExists(atPath: folder.appendingPathComponent(cover).path) {
                    referencedMedia.insert(cover)
                }
            }
        }
        let mediaRoot = database.dataRoot.appendingPathComponent("Media", isDirectory: true)
        for name in referencedMedia.sorted() where validComponent(name) {
            let url = mediaRoot.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw BackupError.invalidBackup }
                try archive.addEntry(with: "database/Media/" + name, fileURL: url)
            }
        }
    }

    static func restore(from directory: URL, database: DatabaseManager) throws -> ImportResult {
        let fileManager = FileManager.default
        let source = directory.appendingPathComponent("database/Exercises Database", isDirectory: true)
        guard fileManager.fileExists(atPath: source.path) else { return ImportResult() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = try regularFiles(in: source)
        var pages: [(manifest: ExercisePageManifest, folder: URL, depth: Int)] = []
        var incomingIDs = Set<String>()
        for (path, url) in files where url.lastPathComponent == "manifest.json" {
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard object?["title"] != nil else { continue }
            let manifest = try decoder.decode(ExercisePageManifest.self, from: data)
            guard validComponent(manifest.id), incomingIDs.insert(manifest.id).inserted,
                  manifest.parentID.map(validComponent) ?? true,
                  manifest.mediaFilenames.allSatisfy(validComponent),
                  manifest.coverImageFilename.map(validComponent) ?? true else { throw BackupError.invalidBackup }
            pages.append((manifest, url.deletingLastPathComponent(), path.split(separator: "/").count))
        }
        var paths = Dictionary(uniqueKeysWithValues: try database.walkPageTree(in: database.exercisesDatabaseURL).map { ($0.0.id, $0.path) })
        let knownIDs = Set(paths.keys).union(incomingIDs)
        guard pages.allSatisfy({ $0.manifest.parentID.map(knownIDs.contains) ?? true }) else { throw BackupError.invalidBackup }
        pages.sort {
            if $0.depth != $1.depth { return $0.depth < $1.depth }
            if $0.manifest.order != $1.manifest.order { return $0.manifest.order < $1.manifest.order }
            return $0.manifest.id < $1.manifest.id
        }
        var available = Set(paths.keys)
        for page in pages where !available.contains(page.manifest.id) {
            guard page.manifest.parentID.map(available.contains) ?? true else { throw BackupError.invalidBackup }
            available.insert(page.manifest.id)
        }
        var referencedMedia = Set<String>()
        for page in pages where paths[page.manifest.id] == nil {
            for name in page.manifest.mediaFilenames where !fileManager.fileExists(atPath: page.folder.appendingPathComponent("media/" + name).path) {
                referencedMedia.insert(name)
            }
            if let cover = page.manifest.coverImageFilename,
               !fileManager.fileExists(atPath: page.folder.appendingPathComponent(cover).path) {
                referencedMedia.insert(cover)
            }
        }
        var result = ImportResult()
        var mediaMap: [String: String] = [:]
        let sourceMedia = directory.appendingPathComponent("database/Media", isDirectory: true)
        if fileManager.fileExists(atPath: sourceMedia.path) {
            let destinationMedia = database.dataRoot.appendingPathComponent("Media", isDirectory: true)
            try fileManager.createDirectory(at: destinationMedia, withIntermediateDirectories: true)
            for (name, url) in try regularFiles(in: sourceMedia) {
                guard validComponent(name) else { throw BackupError.invalidBackup }
                guard referencedMedia.contains(name) else { continue }
                var destination = destinationMedia.appendingPathComponent(name)
                if fileManager.fileExists(atPath: destination.path), !fileManager.contentsEqual(atPath: destination.path, andPath: url.path) {
                    let suffix = url.pathExtension.isEmpty ? "" : "." + url.pathExtension
                    destination = destinationMedia.appendingPathComponent(UUID().uuidString + suffix)
                }
                if !fileManager.fileExists(atPath: destination.path) {
                    try fileManager.copyItem(at: url, to: destination)
                    result.media += 1
                }
                mediaMap[name] = destination.lastPathComponent
            }
        }
        for page in pages {
            var manifest = page.manifest
            if paths[manifest.id] != nil {
                result.duplicates += 1
                continue
            }
            let parentPath: String
            if let parentID = manifest.parentID {
                guard let path = paths[parentID] else { throw BackupError.invalidBackup }
                parentPath = path + "/"
            } else { parentPath = "" }
            var renamed: [String: String] = [:]
            manifest.mediaFilenames = manifest.mediaFilenames.map { name in
                let local = page.folder.appendingPathComponent("media/" + name)
                let restored = fileManager.fileExists(atPath: local.path) ? name : mediaMap[name] ?? name
                if restored != name { renamed[name] = restored }
                return restored
            }
            if let cover = manifest.coverImageFilename, !fileManager.fileExists(atPath: page.folder.appendingPathComponent(cover).path) {
                let restored = mediaMap[cover] ?? cover
                manifest.coverImageFilename = restored
                if restored != cover { renamed[cover] = restored }
            }
            for (old, new) in renamed {
                if let comment = manifest.mediaComments.removeValue(forKey: old) { manifest.mediaComments[new] = comment }
            }
            manifest.childIDs = []
            let path = parentPath + manifest.id
            let destination = database.exercisesDatabaseURL.appendingPathComponent(path, isDirectory: true)
            guard !fileManager.fileExists(atPath: destination.path) else { throw BackupError.invalidBackup }
            let assets = try ownFiles(in: page.folder)
            try database.createPage(manifest: manifest, parentID: manifest.parentID)
            for (relative, url) in assets where relative != "manifest.json" {
                let target = destination.appendingPathComponent(relative)
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let temporary = target.deletingLastPathComponent().appendingPathComponent(".import-" + UUID().uuidString)
                try fileManager.copyItem(at: url, to: temporary)
                if fileManager.fileExists(atPath: target.path) {
                    _ = try fileManager.replaceItemAt(target, withItemAt: temporary)
                } else { try fileManager.moveItem(at: temporary, to: target) }
                if relative.hasPrefix("media/") || relative == page.manifest.coverImageFilename { result.media += 1 }
            }
            paths[manifest.id] = path
            result.pages += 1
        }
        return result
    }

    private static func ownFiles(in directory: URL) throws -> [(String, URL)] {
        try regularFiles(in: directory, skipNestedPages: true)
    }

    private static func regularFiles(in directory: URL, skipNestedPages: Bool = false) throws -> [(String, URL)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        var traversalError: Error?
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: { _, error in
            traversalError = error
            return false
        }) else { throw BackupError.invalidBackup }
        let prefix = directory.standardizedFileURL.path + "/"
        var result: [(String, URL)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true, url.standardizedFileURL.path.hasPrefix(prefix) else { throw BackupError.invalidBackup }
            if skipNestedPages, values.isDirectory == true,
               FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
                enumerator.skipDescendants()
                continue
            }
            if values.isRegularFile == true {
                let relative = String(url.standardizedFileURL.path.dropFirst(prefix.count))
                guard validPath(relative) else { throw BackupError.invalidBackup }
                result.append((relative, url))
            }
        }
        if let traversalError { throw traversalError }
        return result.sorted { $0.0 < $1.0 }
    }

    private static func validPath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.contains("\0") && path.components(separatedBy: "/").allSatisfy(validComponent)
    }

    private static func validComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") && !value.contains("\0")
    }
}
