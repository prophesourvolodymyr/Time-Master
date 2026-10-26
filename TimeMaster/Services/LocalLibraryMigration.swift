#if os(macOS)
import Foundation
import Darwin
import TimeMasterCore

enum LocalLibraryMigration {
    struct Report: Sendable {
        var copied = 0
        var unavailable = 0
    }

    static let messageKey = "tm.localLibrary.migrationMessage"
    private static let completedKey = "tm.localLibrary.migrationCompleted"
    static let pendingKey = "tm.localLibrary.pendingRecovery"
    private static let datalessFlag: UInt32 = 0x4000_0000

    static var previousRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/TimeMaster", isDirectory: true)
    }

    static func prepareIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return }
        do {
            _ = try importCachedFiles()
            UserDefaults.standard.set(true, forKey: completedKey)
        } catch {
            UserDefaults.standard.set(true, forKey: pendingKey)
            UserDefaults.standard.set("Previous library could not be copied: \(error.localizedDescription) The original files are unchanged.", forKey: messageKey)
        }
    }

    static func importCachedFiles() throws -> Report {
        let report = try copyCachedFiles(from: previousRoot, to: DatabaseManager.shared.dataRoot)
        record(report)
        return report
    }

    static func copyCachedFiles(from source: URL, to destination: URL) throws -> Report {
        var report = Report()
        try copy(source, to: destination, report: &report)
        return report
    }

    private static func copy(_ source: URL, to destination: URL, report: inout Report) throws {
        var info = stat()
        guard lstat(source.path, &info) == 0 else {
            if errno == ENOENT { return }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: source.path])
        }
        let kind = info.st_mode & S_IFMT
        guard info.st_flags & datalessFlag == 0, kind == S_IFDIR || kind == S_IFREG else {
            report.unavailable += 1
            return
        }
        let manager = FileManager.default
        var target = stat()
        let exists = lstat(destination.path, &target) == 0
        if kind == S_IFDIR {
            if exists, target.st_mode & S_IFMT != S_IFDIR {
                report.unavailable += 1
                return
            }
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            for name in try manager.contentsOfDirectory(atPath: source.path) where name != ".DS_Store" {
                try copy(source.appendingPathComponent(name), to: destination.appendingPathComponent(name), report: &report)
            }
        } else if !exists {
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let temporary = destination.deletingLastPathComponent().appendingPathComponent(".local-copy-\(UUID().uuidString)")
            defer { try? manager.removeItem(at: temporary) }
            if clonefile(source.path, temporary.path, UInt32(CLONE_NOFOLLOW)) != 0 {
                var current = stat()
                guard lstat(source.path, &current) == 0, current.st_flags & datalessFlag == 0 else {
                    report.unavailable += 1
                    return
                }
                try manager.copyItem(at: source, to: temporary)
            }
            var copied = stat()
            guard lstat(temporary.path, &copied) == 0, copied.st_flags & datalessFlag == 0 else {
                report.unavailable += 1
                return
            }
            try manager.moveItem(at: temporary, to: destination)
            report.copied += 1
        }
    }

    private static func record(_ report: Report) {
        let message = report.unavailable > 0
            ? "Some previous library items are only in iCloud or are links. The original library is unchanged. Download the items in Finder, then import cached files here. Existing local files are never overwritten."
            : "Your library is stored locally. The previous Documents library is unchanged."
        UserDefaults.standard.set(message, forKey: messageKey)
        UserDefaults.standard.set(report.unavailable > 0, forKey: pendingKey)
    }
}
#endif
