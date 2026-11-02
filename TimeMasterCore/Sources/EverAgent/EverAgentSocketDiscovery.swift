#if os(macOS)
import Foundation

public enum EverAgentSocketDiscovery {
    public static func candidates(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String] {
        let root = home.appendingPathComponent(".ompp", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("c").path)) ?? []
        let paths = [root.appendingPathComponent("server/control.sock").path] + names.map { root.appendingPathComponent("c/\($0)/control.sock").path }
        return paths
            .compactMap { path -> (path: String, modified: Double)? in
                var info = stat()
                guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFSOCK else { return nil }
                return (path, Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1_000_000_000)
            }
            .sorted { $0.modified > $1.modified }
            .map(\.path)
    }
}
#endif
