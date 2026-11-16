import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Derived thumbnails (video poster frames and downsampled photos) kept in the system caches folder, so a second launch
/// never decodes the same video or photo again. Safe to delete at any time; nothing here is user data.
final class ThumbnailDiskCache: @unchecked Sendable {
    static let shared = ThumbnailDiskCache()

    private let directory: URL
    private let queue = DispatchQueue(label: "com.timemaster.thumbnail-cache", qos: .utility)
    private let byteLimit: Int64 = 300 * 1024 * 1024
    private var didTrim = false

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("TimeMasterThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The cache key of `url` drawn at up to `pixelSize`: it changes when the file is replaced or edited.
    func key(for url: URL, pixelSize: Int) -> String? {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate else { return nil }
        let source = "\(url.standardizedFileURL.path)|\(modified.timeIntervalSinceReferenceDate)|\(values.fileSize ?? 0)|\(pixelSize)"
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The cached thumbnail for `key`, or nil.
    func image(for key: String) -> CGImage? {
        let file = fileURL(for: key)
        guard let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    /// Writes `image` under `key` in the background.
    func store(_ image: CGImage, for key: String) {
        let file = fileURL(for: key)
        queue.async { [weak self] in
            guard !FileManager.default.fileExists(atPath: file.path) else { return }
            let temporary = file.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
            guard let destination = CGImageDestinationCreateWithURL(
                temporary as CFURL, UTType.jpeg.identifier as CFString, 1, nil
            ) else { return }
            CGImageDestinationAddImage(
                destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
            )
            if CGImageDestinationFinalize(destination) {
                try? FileManager.default.moveItem(at: temporary, to: file)
            } else {
                try? FileManager.default.removeItem(at: temporary)
            }
            self?.trimOnce()
        }
    }

    func clear() {
        queue.async { [directory] in
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key + ".jpg")
    }

    /// Once per launch: drops the oldest files until the folder is back under its size limit.
    private func trimOnce() {
        guard !didTrim else { return }
        didTrim = true
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return }
        var entries: [(url: URL, size: Int64, date: Date)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.size }
        guard total > byteLimit else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries where total > byteLimit * 3 / 4 {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }
}
