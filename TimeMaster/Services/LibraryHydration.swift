#if os(macOS)
import Foundation

enum LibraryHydration {
    private static let datalessFlag: UInt32 = 0x4000_0000
    private static let maximumFileSize: off_t = 2 * 1024 * 1024
    private static let skippedDirectories: Set<String> = [".trash", "Backups", "Music", "Media"]
    private static let simultaneousDownloads = 24

    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URL] = []

        func add(_ url: URL) {
            lock.lock()
            items.append(url)
            lock.unlock()
        }

        var all: [URL] {
            lock.lock()
            defer { lock.unlock() }
            return items
        }
    }

    static func pendingFiles(in root: URL) -> [URL] {
        let collector = Collector()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.timemaster.library-scan", qos: .userInitiated, attributes: .concurrent)
        scan(root, queue: queue, group: group, collector: collector)
        group.wait()
        return collector.all
    }

    private static func scan(_ directory: URL, queue: DispatchQueue, group: DispatchGroup, collector: Collector) {
        group.enter()
        queue.async {
            defer { group.leave() }
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
            for name in names {
                let url = directory.appendingPathComponent(name)
                var info = stat()
                guard lstat(url.path, &info) == 0 else { continue }
                let kind = info.st_mode & S_IFMT
                if kind == S_IFDIR {
                    if !skippedDirectories.contains(name) {
                        scan(url, queue: queue, group: group, collector: collector)
                    }
                } else if kind == S_IFREG, info.st_flags & datalessFlag != 0, info.st_size <= maximumFileSize {
                    collector.add(url)
                }
            }
        }
    }

    static func download(_ files: [URL]) {
        let queue = DispatchQueue(label: "com.timemaster.library-download", qos: .userInitiated, attributes: .concurrent)
        let gate = DispatchSemaphore(value: simultaneousDownloads)
        let group = DispatchGroup()
        for url in files {
            gate.wait()
            group.enter()
            queue.async {
                defer {
                    gate.signal()
                    group.leave()
                }
                guard let handle = try? FileHandle(forReadingFrom: url) else { return }
                _ = try? handle.read(upToCount: 1)
                try? handle.close()
            }
        }
        group.wait()
    }
}
#endif
