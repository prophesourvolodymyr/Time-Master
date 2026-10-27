import Foundation
import ImageIO
import UniformTypeIdentifiers

protocol MarkdownAssets {
    func url(for path: String) -> URL?
    func importImage(data: Data) throws -> String
}

struct FolderMarkdownAssets: MarkdownAssets {
    let folder: URL
    var subfolder: String? = "Attachments"

    func url(for path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let remote = URL(string: trimmed), let scheme = remote.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return remote
        }
        let base = folder.standardizedFileURL
        let resolved = base.appendingPathComponent(trimmed).standardizedFileURL
        guard resolved.path.hasPrefix(base.path + "/") else { return nil }
        return resolved
    }

    func importImage(data: Data) throws -> String {
        let prepared = MarkdownImageImport.prepare(data)
        let directory = subfolder.map { folder.appendingPathComponent($0, isDirectory: true) } ?? folder
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + "." + prepared.fileExtension
        try prepared.data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return subfolder.map { $0 + "/" + name } ?? name
    }
}

enum MarkdownImageImport {
    static let longestSide = 2400

    static func prepare(_ data: Data) -> (data: Data, fileExtension: String) {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: longestSide
              ] as CFDictionary) else {
            return (data, "jpg")
        }
        let output = NSMutableData()
        let hasAlpha = thumbnail.alphaInfo != .none && thumbnail.alphaInfo != .noneSkipFirst && thumbnail.alphaInfo != .noneSkipLast
        let type = hasAlpha ? UTType.png : UTType.jpeg
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return (data, "jpg")
        }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return (data, "jpg") }
        return (output as Data, hasAlpha ? "png" : "jpg")
    }
}

enum MarkdownLinkDetector {
    static func url(in string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }
}
