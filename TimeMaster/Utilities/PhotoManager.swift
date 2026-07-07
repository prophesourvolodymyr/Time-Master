import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import AVFoundation

class PhotoManager {
    static let shared = PhotoManager()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        createPhotosDirectoryIfNeeded()
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
        let fileURL = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    #elseif os(macOS)
    func loadPhoto(filename: String) -> NSImage? {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return NSImage(data: data)
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
        case .photo: return loadPhoto(filename: item.filename)
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #elseif os(macOS)
    func thumbnail(for item: MediaItem) -> NSImage? {
        switch item.type {
        case .photo: return loadPhoto(filename: item.filename)
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
    #endif
}
