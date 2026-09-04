import SwiftUI
import TimeMasterCore

struct PageLinkPreviewView: View {
    let metadata: LinkMetadata

    var body: some View {
        HStack(spacing: 12) {
            platformIcon
            VStack(alignment: .leading, spacing: 3) {
                if let title = metadata.title {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                } else {
                    Text(shortURL)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                if let desc = metadata.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.forward")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.4))
        }
        .padding(.vertical, 6)
    }

    private var shortURL: String {
        guard let url = URL(string: metadata.url) else { return metadata.url }
        return url.host ?? metadata.url
    }

    @ViewBuilder
    private var platformIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(platformColor.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: platformIconName)
                    .font(.system(size: 16))
                    .foregroundColor(platformColor)
            )
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

struct PageLinkList: View {
    let urls: [String]
    let metadata: [LinkMetadata]
    let onTapURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Links")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                if index < metadata.count {
                    Button {
                        onTapURL(urlString)
                    } label: {
                        PageLinkPreviewView(metadata: metadata[index])
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onTapURL(urlString)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.textSecondary.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "globe")
                                        .font(.system(size: 16))
                                        .foregroundColor(Theme.textSecondary)
                                )
                            Text(URL(string: urlString)?.host ?? urlString)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
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
        }
    }
}

enum LinkMetadataFetcher {
    static func fetchMetadata(for urls: [String], existing: [LinkMetadata]) async -> [LinkMetadata] {
        var results: [LinkMetadata] = []
        let existingLookup = Dictionary(uniqueKeysWithValues: existing.map { ($0.url, $0) })

        for url in urls {
            if let cached = existingLookup[url],
               cached.title != nil || cached.description != nil || cached.thumbnailURL != nil {
                results.append(cached)
                continue
            }

            let platform = detectPlatform(url: url)
            let meta = await fetchOGMetadata(url: url, platform: platform)
            results.append(meta)
        }

        return results
    }

    static func detectPlatform(url: String) -> LinkPlatform {
        let lower = url.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("instagram.com") { return .instagram }
        if lower.contains("tiktok.com") { return .tiktok }
        if lower.contains("facebook.com") || lower.contains("fb.com") { return .facebook }
        return .web
    }

    private static func fetchOGMetadata(url: String, platform: LinkPlatform) async -> LinkMetadata {
        guard let requestURL = URL(string: url) else {
            return LinkMetadata(url: url, platform: platform)
        }

        do {
            var req = URLRequest(url: requestURL)
            req.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: req)

            guard let html = String(data: data, encoding: .utf8) else {
                return LinkMetadata(url: url, platform: platform)
            }

            let title = extractMetaProperty(html, property: "og:title")
                ?? extractTagContent(html, tag: "title")
            let description = extractMetaProperty(html, property: "og:description")
            let thumbnail = extractMetaProperty(html, property: "og:image")

            return LinkMetadata(
                url: url,
                title: title,
                description: description,
                thumbnailURL: thumbnail,
                platform: platform
            )
        } catch {
            return LinkMetadata(url: url, platform: platform)
        }
    }

    private static func extractMetaProperty(_ html: String, property: String) -> String? {
        let patterns = [
            "<meta[^>]*property=[\"']" + property + "[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']" + property + "[\"']",
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = html[range]
                if let contentRange = match.range(of: "content=[\"']([^\"']+)[\"']", options: .regularExpression) {
                    var content = String(match[contentRange])
                    content = content.replacingOccurrences(of: "content=\"", with: "")
                        .replacingOccurrences(of: "content='", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "'", with: "")
                    return content
                }
            }
        }
        return nil
    }

    private static func extractTagContent(_ html: String, tag: String) -> String? {
        let pattern = "<" + tag + "[^>]*>([^<]+)</" + tag + ">"
        guard let range = html.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(html[range])
        guard let innerRange = match.range(of: ">([^<]+)<", options: .regularExpression) else { return nil }
        var content = String(match[innerRange])
        content = String(content.dropFirst().dropLast())
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
