#if os(iOS)
import Foundation
import ImageIO
import UIKit

enum WorkoutLiveActivityArtwork {
    static let appGroupIdentifier = "group.com.timemaster.shared"
    static let directoryName = "LiveActivityArtwork"
    static let maxPixelSize = 240
    static let maxFileNameLength = 80

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 12
        return cache
    }()

    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func store(jpeg: Data, key: String) -> String? {
        guard let directory else { return nil }
        return store(jpeg: jpeg, key: key, in: directory)
    }

    static func image(named name: String) -> UIImage? {
        guard let directory else { return nil }
        return image(named: name, in: directory)
    }

    static func prune<Names: Sequence>(keeping names: Names) where Names.Element == String {
        guard let directory else { return }
        prune(keeping: names, in: directory)
    }

    static func fileName(forKey key: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(key.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        guard !cleaned.isEmpty, cleaned.contains(where: { $0 != "_" }) else { return nil }
        return String(cleaned.prefix(maxFileNameLength - 4)) + ".jpg"
    }

    static func store(jpeg: Data, key: String, in directory: URL) -> String? {
        guard !jpeg.isEmpty, let name = fileName(forKey: key) else { return nil }
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name)
            if let existing = try? Data(contentsOf: url), existing == jpeg {
                return name
            }
            try jpeg.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String, in directory: URL) -> UIImage? {
        guard name == (name as NSString).lastPathComponent, name.hasSuffix(".jpg") else { return nil }
        let url = directory.appendingPathComponent(name)
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        let cacheKey = "\(name)#\(modified)" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    static func prune<Names: Sequence>(keeping names: Names, in directory: URL) where Names.Element == String {
        let keep = Set(names)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls where !keep.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
#endif
