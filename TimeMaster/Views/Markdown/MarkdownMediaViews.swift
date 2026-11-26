import SwiftUI
import CryptoKit

final class RemoteImageLoader: @unchecked Sendable {
    static let shared = RemoteImageLoader()
    private let memory = NSCache<NSString, PhotoPlatformImage>()
    private let directory: URL
    private let session: URLSession

    private init() {
        memory.totalCostLimit = 48 * 1024 * 1024
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimeMasterWebImages", isDirectory: true)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL, maxPixelSize: CGFloat) -> PhotoPlatformImage? {
        memory.object(forKey: Self.memoryKey(url, maxPixelSize))
    }

    func image(from url: URL, maxPixelSize: CGFloat) async -> PhotoPlatformImage? {
        let key = Self.memoryKey(url, maxPixelSize)
        if let cached = memory.object(forKey: key) { return cached }
        let file = directory.appendingPathComponent(Self.fileName(for: url))
        var image = (try? Data(contentsOf: file)).flatMap { PhotoManager.downsampledImage(data: $0, maxPixelSize: maxPixelSize) }
        if image == nil, let data = await download(url) {
            image = PhotoManager.downsampledImage(data: data, maxPixelSize: maxPixelSize)
            if image != nil {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
            }
        }
        guard let image else { return nil }
        memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    private func download(_ url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { return nil }
        return data
    }

    private static func memoryKey(_ url: URL, _ maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)#\(PhotoManager.pixelBucket(for: maxPixelSize))" as NSString
    }

    private static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL
    var maxPixelSize: CGFloat = 640
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var image: PhotoPlatformImage?

    var body: some View {
        Group {
            if let image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            image = RemoteImageLoader.shared.cachedImage(for: url, maxPixelSize: maxPixelSize)
            guard image == nil else { return }
            let loaded = await RemoteImageLoader.shared.image(from: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

enum MarkdownImageSource {
    static func resolve(_ source: String, assets: MarkdownAssets?) -> URL? {
        if let assets { return assets.url(for: source) }
        guard let url = URL(string: source), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    static func load(_ source: String, assets: MarkdownAssets?, maxPixelSize: CGFloat) async -> PhotoPlatformImage? {
        guard let url = resolve(source, assets: assets) else { return nil }
        if url.isFileURL {
            return await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: maxPixelSize)
        }
        return await RemoteImageLoader.shared.image(from: url, maxPixelSize: maxPixelSize)
    }
}

struct MarkdownThumbnailImage: View {
    let source: String
    let assets: MarkdownAssets?
    var maxPixelSize: CGFloat = 900
    @State private var image: PhotoPlatformImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    platformImage(image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.surface2
                }
            }
            .clipped()
            .task(id: source) {
                image = nil
                image = await MarkdownImageSource.load(source, assets: assets, maxPixelSize: maxPixelSize)
            }
    }
}

private struct MarkdownImageOpenKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    var markdownImageOpen: ((String) -> Void)? {
        get { self[MarkdownImageOpenKey.self] }
        set { self[MarkdownImageOpenKey.self] = newValue }
    }
}

struct MarkdownImageBlockView: View {
    let path: String
    let alt: String
    let assets: MarkdownAssets?
    @State private var image: PhotoPlatformImage?
    @State private var failed = false
    @Environment(\.markdownImageOpen) private var openImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let image {
                    platformImage(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Theme.surface2
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .overlay {
                            Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 520)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
            if !alt.isEmpty {
                Text(alt)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: path) {
            image = nil
            failed = false
            let loaded = await MarkdownImageSource.load(path, assets: assets, maxPixelSize: 1600)
            image = loaded
            failed = loaded == nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(alt.isEmpty ? "Image" : alt)
        .accessibilityAddTraits(openImage == nil ? [] : .isButton)
        .modifier(MarkdownImageTap(path: path, open: openImage))
    }
}

private struct MarkdownImageTap: ViewModifier {
    let path: String
    let open: ((String) -> Void)?

    func body(content: Content) -> some View {
        if let open {
            content
                .contentShape(Rectangle())
                .onTapGesture { open(path) }
                .tmaxPointer()
        } else {
            content
        }
    }
}

struct MarkdownLinkCardView: View {
    let title: String
    let url: String
    let thumbnail: String?
    let assets: MarkdownAssets?
    @Environment(\.openURL) private var openURL

    private var info: PageLinkInfo { PageLinkInfo(urlString: url, metadata: nil) }

    var body: some View {
        Button {
            if let destination = URL(string: url) { openURL(destination) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let thumbnail, !thumbnail.isEmpty {
                    Color.clear
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay { MarkdownThumbnailImage(source: thumbnail, assets: assets) }
                        .clipped()
                }
                HStack(spacing: 12) {
                    if thumbnail?.isEmpty ?? true {
                        PageLinkTile(platform: info.platform, thumbnailURL: nil)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.isEmpty ? info.title : title)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(info.subtitle)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.toolbarOrange))
                }
                .padding(10)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 16))
        .accessibilityLabel("\(title.isEmpty ? info.title : title), \(info.subtitle)")
        .accessibilityHint("Opens the link")
    }
}
