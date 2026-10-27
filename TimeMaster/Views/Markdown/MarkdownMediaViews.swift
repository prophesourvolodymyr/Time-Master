import SwiftUI

final class MarkdownRemoteImageLoader {
    static let shared = MarkdownRemoteImageLoader()
    private let cache = NSCache<NSURL, PhotoPlatformImage>()

    private init() {
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(from url: URL, maxPixelSize: CGFloat) async -> PhotoPlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let image = PhotoManager.downsampledImage(data: data, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height * 4))
        return image
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
        return await MarkdownRemoteImageLoader.shared.image(from: url, maxPixelSize: maxPixelSize)
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

struct MarkdownImageBlockView: View {
    let path: String
    let alt: String
    let assets: MarkdownAssets?
    @State private var image: PhotoPlatformImage?
    @State private var failed = false

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
        .buttonStyle(.plain)
        .accessibilityLabel("\(title.isEmpty ? info.title : title), \(info.subtitle)")
        .accessibilityHint("Opens the link")
    }
}
