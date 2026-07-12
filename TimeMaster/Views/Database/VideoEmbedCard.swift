import SwiftUI
import TimeMasterCore

struct VideoEmbedCard: View {
    let metadata: LinkMetadata
    let onTap: () -> Void

    @State private var loadedThumbnail: Image?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnailArea
                infoBar
            }
            .background(Theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnailArea: some View {
        ZStack(alignment: .center) {
            if let thumbnail = loadedThumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } else if let thumbURL = metadata.thumbnailURL, let url = URL(string: thumbURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure, .empty:
                        platformPlaceholder
                    @unknown default:
                        platformPlaceholder
                    }
                }
            } else if metadata.platform == .youtube {
                youtubeThumbnail
            } else {
                platformPlaceholder
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .center,
                endPoint: .bottom
            )

            playButtonOverlay
        }
    }

    @ViewBuilder
    private var playButtonOverlay: some View {
        if metadata.platform == .youtube {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 4)
        } else if metadata.platform == .instagram || metadata.platform == .tiktok {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 3)
        }
    }

    @ViewBuilder
    private var youtubeThumbnail: some View {
        if let videoID = extractYouTubeVideoID(from: metadata.url),
           let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg") {
            AsyncImage(url: thumbURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                case .failure, .empty:
                    platformPlaceholder
                @unknown default:
                    platformPlaceholder
                }
            }
        } else {
            platformPlaceholder
        }
    }

    private var platformPlaceholder: some View {
        Rectangle()
            .fill(platformColor.opacity(0.15))
            .frame(height: 180)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: platformIconName)
                        .font(.system(size: 36))
                        .foregroundColor(platformColor.opacity(0.6))
                    Text(platformName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(platformColor.opacity(0.6))
                }
            )
    }

    private var infoBar: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(platformColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: platformIconName)
                        .font(.system(size: 14))
                        .foregroundColor(platformColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                if let title = metadata.title {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                } else {
                    Text(platformName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                }
                if let desc = metadata.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "arrow.up.forward")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var platformName: String {
        switch metadata.platform {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .facebook: return "Facebook"
        case .web: return shortURL
        }
    }

    private var shortURL: String {
        guard let url = URL(string: metadata.url) else { return metadata.url }
        return url.host ?? metadata.url
    }

    private func extractYouTubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if let host = url.host, host.contains("youtu.be"),
           !url.pathComponents.isEmpty {
            return String(url.pathComponents.last ?? "").filter { $0 != "/" }
        }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        return nil
    }

    private var platformIconName: String {
        switch metadata.platform {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .facebook: return "f.square.fill"
        case .web: return "globe"
        }
    }

    private var platformColor: Color {
        switch metadata.platform {
        case .youtube: return .red
        case .instagram: return .purple
        case .tiktok: return .white
        case .facebook: return .blue
        case .web: return Theme.textSecondary
        }
    }
}

struct VideoEmbedListView: View {
    let urls: [String]
    let metadata: [LinkMetadata]
    let onTapURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                if index < metadata.count {
                    let meta = metadata[index]
                    if meta.platform == .youtube || meta.platform == .instagram || meta.platform == .tiktok {
                        VideoEmbedCard(metadata: meta) {
                            onTapURL(urlString)
                        }
                    } else {
                        simpleLinkRow(urlString: urlString, metadata: meta)
                    }
                } else {
                    simpleLinkRow(urlString: urlString, metadata: nil)
                }
            }
        }
    }

    private func simpleLinkRow(urlString: String, metadata: LinkMetadata?) -> some View {
        Button {
            onTapURL(urlString)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.textSecondary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: metadata?.platform == .web ? "globe" : "safari")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    if let title = metadata?.title {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text(URL(string: urlString)?.host ?? urlString)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    if let desc = metadata?.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary.opacity(0.4))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
