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

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        createPhotosDirectoryIfNeeded()
        cache.countLimit = 120
        cache.totalCostLimit = 64 * 1024 * 1024
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
            return filename
        } catch {
            print("Error saving photo: \(error)")
            return nil
        }
    }

    #if os(iOS)
    func loadPhoto(filename: String) -> UIImage? {
        Self.downsampledImage(at: photosDirectory.appendingPathComponent(filename), maxPixelSize: Self.fullPhotoPixelSize)
    }
    #elseif os(macOS)
    func loadPhoto(filename: String) -> NSImage? {
        Self.downsampledImage(at: photosDirectory.appendingPathComponent(filename), maxPixelSize: Self.fullPhotoPixelSize)
    }
    #endif

    func deletePhoto(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
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
        let url = videoURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        let time = CMTimeMake(value: 0, timescale: 1)
        guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #elseif os(macOS)
    func thumbnailForVideo(filename: String) -> NSImage? {
        let url = videoURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        let time = CMTimeMake(value: 0, timescale: 1)
        guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    #endif

    // MARK: - Generic Media

    func deleteMedia(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    #if os(iOS)
    func thumbnail(for item: MediaItem) -> UIImage? {
        switch item.type {
        case .photo: return Self.downsampledImage(at: photoURL(for: item.filename), maxPixelSize: Self.thumbnailPixelSize)
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #elseif os(macOS)
    func thumbnail(for item: MediaItem) -> NSImage? {
        switch item.type {
        case .photo: return Self.downsampledImage(at: photoURL(for: item.filename), maxPixelSize: Self.thumbnailPixelSize)
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #endif
}

extension PhotoManager {
    static let thumbnailPixelSize: CGFloat = 480
    static let defaultPixelSize: CGFloat = 1024
    static let fullPhotoPixelSize: CGFloat = 2048
    static let viewerPixelSize: CGFloat = 3072
    fileprivate static let loadGate = ImageLoadGate(limit: 3)

    func asyncLoadImage(from url: URL, maxPixelSize: CGFloat = PhotoManager.defaultPixelSize) async -> PhotoPlatformImage? {
        let key = "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        await Self.loadGate.enter()
        var image: PhotoPlatformImage?
        if !Task.isCancelled {
            image = await Task.detached(priority: .userInitiated, operation: { () -> PhotoPlatformImage? in
                let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased())
                guard isVideo else { return Self.downsampledImage(at: url, maxPixelSize: maxPixelSize) }
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                let side = min(maxPixelSize, 800)
                generator.maximumSize = CGSize(width: side, height: side)
                guard let cgImage = try? generator.copyCGImage(
                    at: CMTime(seconds: 0, preferredTimescale: 600),
                    actualTime: nil
                ) else {
                    return nil
                }
                return Self.platformImage(cgImage)
            }).value
        }
        await Self.loadGate.leave()

        if let image {
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        }
        return image
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

    func clearCache() {
        cache.removeAllObjects()
    }
}

fileprivate actor ImageLoadGate {
    private let limit: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func enter() async {
        if running < limit {
            running += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func leave() {
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
