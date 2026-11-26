import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import AVFoundation
import ImageIO

#if os(iOS)
typealias PhotoPlatformImage = UIImage
#elseif os(macOS)
typealias PhotoPlatformImage = NSImage
#endif

class PhotoManager {
    static let shared = PhotoManager()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let cache = NSCache<NSString, PhotoPlatformImage>()
    private let fileCache = NSCache<NSString, PhotoPlatformImage>()
    private let profileImageCache = NSCache<NSString, PhotoPlatformImage>()

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        createPhotosDirectoryIfNeeded()
        cache.countLimit = 120
        cache.totalCostLimit = 64 * 1024 * 1024
        fileCache.countLimit = 40
        fileCache.totalCostLimit = 48 * 1024 * 1024
        profileImageCache.countLimit = 24
        profileImageCache.totalCostLimit = 24 * 1024 * 1024
    }

    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("Photos")
    }

    var photosDirectoryURL: URL { photosDirectory }

    private func createPhotosDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Photos

    #if os(iOS)
    func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        return writePhotoData(data, ext: "jpg")
    }
    #elseif os(macOS)
    func savePhoto(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else { return nil }
        return writePhotoData(jpegData, ext: "jpg")
    }
    #endif

    private func writePhotoData(_ data: Data, ext: String) -> String? {
        let filename = UUID().uuidString + "." + ext
        let fileURL = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            forgetProfileImages(filename: filename)
            return filename
        } catch {
            print("Error saving photo: \(error)")
            return nil
        }
    }

    #if os(iOS)
    func loadPhoto(filename: String) -> UIImage? {
        rememberedImage(at: photosDirectory.appendingPathComponent(filename), kind: "photo") {
            Self.downsampledImage(at: $0, maxPixelSize: Self.fullPhotoPixelSize)
        }
    }
    #elseif os(macOS)
    func loadPhoto(filename: String) -> NSImage? {
        rememberedImage(at: photosDirectory.appendingPathComponent(filename), kind: "photo") {
            Self.downsampledImage(at: $0, maxPixelSize: Self.fullPhotoPixelSize)
        }
    }
    #endif

    func deletePhoto(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
        forgetProfileImages(filename: filename)
    }

    func photoURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    // MARK: - Videos

    func saveVideo(from tempURL: URL) -> String? {
        let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
        let filename = UUID().uuidString + "." + ext
        let destURL = photosDirectory.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: tempURL, to: destURL)
            return filename
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }

    func videoURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    #if os(iOS)
    func thumbnailForVideo(filename: String) -> UIImage? {
        rememberedImage(at: videoURL(for: filename), kind: "poster") { url in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 400, height: 400)
            let time = CMTimeMake(value: 0, timescale: 1)
            guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
    #elseif os(macOS)
    func thumbnailForVideo(filename: String) -> NSImage? {
        rememberedImage(at: videoURL(for: filename), kind: "poster") { url in
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 400, height: 400)
            let time = CMTimeMake(value: 0, timescale: 1)
            guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
    #endif

    // MARK: - Generic Media

    func deleteMedia(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
        forgetProfileImages(filename: filename)
    }

    #if os(iOS)
    func thumbnail(for item: MediaItem) -> UIImage? {
        switch item.type {
        case .photo:
            return rememberedImage(at: photoURL(for: item.filename), kind: "thumb") {
                Self.downsampledImage(at: $0, maxPixelSize: Self.thumbnailPixelSize)
            }
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #elseif os(macOS)
    func thumbnail(for item: MediaItem) -> NSImage? {
        switch item.type {
        case .photo:
            return rememberedImage(at: photoURL(for: item.filename), kind: "thumb") {
                Self.downsampledImage(at: $0, maxPixelSize: Self.thumbnailPixelSize)
            }
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #endif

    private func rememberedImage(at url: URL, kind: String, load: (URL) -> PhotoPlatformImage?) -> PhotoPlatformImage? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate else { return load(url) }
        let key = "\(url.absoluteString)#\(kind)#\(modified.timeIntervalSinceReferenceDate)#\(values.fileSize ?? 0)" as NSString
        if let cached = fileCache.object(forKey: key) { return cached }
        guard let image = load(url) else { return nil }
        fileCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }
}

extension PhotoManager {
    static let thumbnailPixelSize: CGFloat = 480
    static let defaultPixelSize: CGFloat = 1024
    static let fullPhotoPixelSize: CGFloat = 2048
    static let viewerPixelSize: CGFloat = 3072
    fileprivate static let loadGate = ImageLoadGate(limit: 3)
    private static let pixelBuckets = [160, 240, 320, 480, 640, 960, 1280, 2048, 3072]

    /// `size` rounded up to a shared step, so near-identical sizes reuse one decoded image.
    static func pixelBucket(for size: CGFloat) -> Int {
        let wanted = Int(size.rounded(.up))
        return pixelBuckets.first { $0 >= wanted } ?? wanted
    }

    func cachedImage(from url: URL, maxPixelSize: CGFloat) -> PhotoPlatformImage? {
        let bucket = Self.pixelBucket(for: maxPixelSize)
        return cache.object(forKey: "\(url.absoluteString)#\(bucket)" as NSString)
    }

    func asyncLoadImage(from url: URL, maxPixelSize: CGFloat = PhotoManager.defaultPixelSize) async -> PhotoPlatformImage? {
        let bucket = Self.pixelBucket(for: maxPixelSize)
        let key = "\(url.absoluteString)#\(bucket)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard await Self.loadGate.enter() else { return nil }
        var image: PhotoPlatformImage?
        if !Task.isCancelled {
            image = await Task.detached(priority: .userInitiated, operation: { () -> PhotoPlatformImage? in
                Self.decode(url: url, pixelSize: bucket)
            }).value
        }
        await Self.loadGate.leave()

        if let image {
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        }
        return image
    }

    /// Reads the cover from the disk cache when it is there; otherwise decodes the photo or the video's first frame and
    /// keeps the result for the next launch.
    private static func decode(url: URL, pixelSize: Int) -> PhotoPlatformImage? {
        let cacheKey = pixelSize <= 1280 ? ThumbnailDiskCache.shared.key(for: url, pixelSize: pixelSize) : nil
        if let cacheKey, let cached = ThumbnailDiskCache.shared.image(for: cacheKey) {
            return platformImage(cached)
        }
        let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased())
        let decoded: CGImage?
        if isVideo {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            let side = CGFloat(min(pixelSize, 800))
            generator.maximumSize = CGSize(width: side, height: side)
            decoded = try? generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil)
        } else {
            decoded = downsampledCGImage(at: url, maxPixelSize: CGFloat(pixelSize))
        }
        guard let decoded else { return nil }
        if let cacheKey { ThumbnailDiskCache.shared.store(decoded, for: cacheKey) }
        return platformImage(decoded)
    }

    private static func downsampledCGImage(at url: URL, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> PhotoPlatformImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return platformImage(cgImage)
    }

    static func downsampledImage(data: Data, maxPixelSize: CGFloat) -> PhotoPlatformImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return platformImage(cgImage)
    }

    private static func platformImage(_ cgImage: CGImage) -> PhotoPlatformImage {
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }

    private static func profileImageKey(filename: String, bucket: Int) -> NSString {
        "\(filename)#\(bucket)" as NSString
    }

    func cachedProfileImage(filename: String, maxPixelSize: CGFloat) -> PhotoPlatformImage? {
        profileImageCache.object(forKey: Self.profileImageKey(filename: filename, bucket: Self.pixelBucket(for: maxPixelSize)))
    }

    func loadProfileImage(filename: String, maxPixelSize: CGFloat) async -> PhotoPlatformImage? {
        let bucket = Self.pixelBucket(for: maxPixelSize)
        let key = Self.profileImageKey(filename: filename, bucket: bucket)
        if let cached = profileImageCache.object(forKey: key) { return cached }
        let url = photosDirectory.appendingPathComponent(filename)
        let image = await Task.detached(priority: .userInitiated, operation: { () -> PhotoPlatformImage? in
            Self.downsampledImage(at: url, maxPixelSize: CGFloat(bucket))
        }).value
        guard let image else { return nil }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        profileImageCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    private func forgetProfileImages(filename: String) {
        for bucket in Self.pixelBuckets {
            profileImageCache.removeObject(forKey: Self.profileImageKey(filename: filename, bucket: bucket))
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        fileCache.removeAllObjects()
        profileImageCache.removeAllObjects()
    }
}

/// Lets a few image loads run at once. A request that is cancelled while it waits (its row scrolled away) leaves the
/// queue at once, and the newest request goes first, because that is the row now on screen.
fileprivate actor ImageLoadGate {
    private let limit: Int
    private var running = 0
    private var nextID: UInt64 = 0
    private var waiters: [(id: UInt64, continuation: CheckedContinuation<Bool, Never>)] = []

    init(limit: Int) {
        self.limit = limit
    }

    /// True when the caller holds a slot (and must `leave()`); false when it was cancelled while waiting.
    func enter() async -> Bool {
        if Task.isCancelled { return false }
        if running < limit {
            running += 1
            return true
        }
        let id = nextID
        nextID &+= 1
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiters.append((id, continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(returning: false)
    }

    func leave() {
        if let waiter = waiters.popLast() {
            waiter.continuation.resume(returning: true)
        } else {
            running -= 1
        }
    }
}
