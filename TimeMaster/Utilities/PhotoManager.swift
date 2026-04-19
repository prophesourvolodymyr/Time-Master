import Foundation
import UIKit
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

    /// Public access for BackupManager to enumerate / copy files.
    var photosDirectoryURL: URL { photosDirectory }

    private func createPhotosDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Photos

    func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Error saving photo: \(error)")
            return nil
        }
    }

    func loadPhoto(filename: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deletePhoto(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    func photoURL(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    // MARK: - Videos

    /// Copy video from a temporary URL into the app's Photos directory.
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

    /// Synchronously generate a thumbnail from the first frame of a saved video.
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

    // MARK: - Generic Media

    /// Delete any media file (photo or video) by filename.
    func deleteMedia(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Load a thumbnail UIImage for any MediaItem (photo → full image, video → first frame).
    func thumbnail(for item: MediaItem) -> UIImage? {
        switch item.type {
        case .photo: return loadPhoto(filename: item.filename)
        case .video: return thumbnailForVideo(filename: item.filename)
        }
    }
}
