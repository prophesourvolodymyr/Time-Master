import SwiftUI
import TimeMasterCore

struct PageLinkInfo {
    let url: String
    let platform: LinkPlatform
    let title: String
    let subtitle: String
    let thumbnailURL: URL?

    init(urlString: String, metadata: LinkMetadata?) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let platform = metadata?.platform ?? LinkMetadataFetcher.detectPlatform(url: trimmed)
        let parts = LinkURLParts(trimmed)
        url = trimmed
        self.platform = platform
        title = LinkMetadataFetcher.usableTitle(metadata?.title, platform: platform) ?? parts.derivedTitle(for: platform)
        subtitle = parts.shortDescription
        thumbnailURL = platform == .youtube ? parts.youtubeThumbnail : nil
    }
}

private struct LinkURLParts {
    private static let instagramSections: Set<String> = [
        "explore", "accounts", "direct", "about", "legal", "developer", "directory", "web"
    ]

    let raw: String
    let host: String
    let path: [String]
    let query: [String: String]

    init(_ string: String) {
        raw = string
        let components = URLComponents(string: string)
        var host = (components?.host ?? "").lowercased()
        for prefix in ["www.", "m.", "mobile."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        self.host = host
        path = (components?.path ?? "").split(separator: "/").map(String.init)
        query = Dictionary(
            (components?.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var shortDescription: String {
        guard !host.isEmpty else { return raw }
        let base = ([host] + path).joined(separator: "/")
        if path == ["watch"], let identifier = query["v"] { return "\(base)?v=\(identifier)" }
        return base
    }

    var youtubeThumbnail: URL? {
        let identifier: String?
        if host == "youtu.be" {
            identifier = path.first
        } else if path.first == "shorts" || path.first == "embed" || path.first == "live" {
            identifier = path.dropFirst().first
        } else {
            identifier = query["v"]
        }
        return identifier.flatMap { URL(string: "https://img.youtube.com/vi/\($0)/mqdefault.jpg") }
    }

    func derivedTitle(for platform: LinkPlatform) -> String {
        let first = path.first?.lowercased()
        switch platform {
        case .instagram:
            switch first {
            case "p": return "Instagram post"
            case "reel", "reels": return "Instagram reel"
            case "tv": return "Instagram video"
            case "stories": return "Instagram story"
            case let name? where !Self.instagramSections.contains(name): return "@\(path[0])"
            default: return "Instagram"
            }
        case .youtube:
            if host == "youtu.be" { return "YouTube video" }
            switch first {
            case "shorts": return "YouTube Short"
            case "playlist": return "YouTube playlist"
            case "watch", "live", "embed": return "YouTube video"
            case let name? where name.hasPrefix("@"): return path[0]
            case "channel", "c", "user": return path.dropFirst().first ?? "YouTube channel"
            default: return "YouTube"
            }
        case .tiktok:
            if path.contains("video") { return "TikTok video" }
            if let handle = path.first, handle.hasPrefix("@") { return handle }
            return "TikTok"
        case .facebook:
            if path.contains(where: { $0 == "reel" || $0 == "reels" }) { return "Facebook reel" }
            if path.contains(where: { $0 == "videos" || $0 == "watch" }) || host == "fb.watch" { return "Facebook video" }
            if path.contains("posts") { return "Facebook post" }
            return "Facebook"
        case .web:
            return host.isEmpty ? raw : host
        }
    }
}

enum LinkMetadataFetcher {
    private static let cache = LinkMetadataCache()

    static func fetchMetadata(for urls: [String], existing: [LinkMetadata]) async -> [LinkMetadata] {
        let known = Dictionary(existing.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        return await withTaskGroup(of: (Int, LinkMetadata).self) { group in
            for (index, url) in urls.enumerated() {
                let stored = known[url]
                group.addTask { (index, await resolve(url: url, stored: stored)) }
            }
            var results: [Int: LinkMetadata] = [:]
            for await (index, metadata) in group {
                results[index] = metadata
            }
            return urls.enumerated().map { offset, url in
                results[offset] ?? LinkMetadata(url: url, platform: detectPlatform(url: url))
            }
        }
    }

    static func detectPlatform(url: String) -> LinkPlatform {
        let lower = url.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("instagram.com") || lower.contains("instagr.am") { return .instagram }
        if lower.contains("tiktok.com") { return .tiktok }
        if lower.contains("facebook.com") || lower.contains("fb.com") || lower.contains("fb.watch") { return .facebook }
        return .web
    }

    static func usableTitle(_ title: String?, platform: LinkPlatform) -> String? {
        guard platform == .youtube || platform == .web else { return nil }
        let cleaned = decodeEntities(title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let lowered = cleaned.lowercased()
        let platformNames: Set<String> = ["instagram", "youtube", "tiktok", "facebook"]
        let blocked = [
            "log in", "login", "sign up", "sign in", "create an account", "just a moment",
            "access denied", "attention required", "forbidden", "page not found", "404 not found"
        ]
        if platformNames.contains(lowered) || blocked.contains(where: { lowered.contains($0) }) { return nil }
        return cleaned
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        if let expression = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") {
            let matches = expression.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let whole = Range(match.range, in: result),
                      let digits = Range(match.range(at: 2), in: result),
                      let scalarValue = UInt32(result[digits], radix: match.range(at: 1).length > 0 ? 16 : 10),
                      let scalar = Unicode.Scalar(scalarValue) else { continue }
                result.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        let named = [
            "&quot;": "\"", "&apos;": "'", "&nbsp;": " ", "&ndash;": "\u{2013}", "&mdash;": "\u{2014}",
            "&hellip;": "\u{2026}", "&lt;": "<", "&gt;": ">", "&amp;": "&"
        ]
        for (entity, value) in named {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result
    }

    private static func resolve(url: String, stored: LinkMetadata?) async -> LinkMetadata {
        let platform = detectPlatform(url: url)
        switch platform {
        case .instagram, .tiktok, .facebook:
            return LinkMetadata(url: url, platform: platform)
        case .youtube, .web:
            if let stored, usableTitle(stored.title, platform: platform) != nil { return stored }
            if let cached = cache.value(for: url) { return cached }
            let fetched = platform == .youtube ? await fetchYouTube(url: url) : await fetchOpenGraph(url: url)
            cache.store(fetched, for: url)
            return fetched
        }
    }

    private static func fetchYouTube(url: String) async -> LinkMetadata {
        let empty = LinkMetadata(url: url, platform: .youtube)
        var components = URLComponents(string: "https://www.youtube.com/oembed")
        components?.queryItems = [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "url", value: url)]
        guard let endpoint = components?.url else { return empty }
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 6
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return empty
        }
        return LinkMetadata(
            url: url,
            title: object["title"] as? String,
            description: object["author_name"] as? String,
            thumbnailURL: object["thumbnail_url"] as? String,
            platform: .youtube
        )
    }

    private static func fetchOpenGraph(url: String) async -> LinkMetadata {
        let empty = LinkMetadata(url: url, platform: .web)
        guard let requestURL = URL(string: url),
              let scheme = requestURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return empty }
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 6
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        guard let html = await readHead(of: request) else { return empty }
        let title = extractMetaProperty(html, property: "og:title") ?? extractTagContent(html, tag: "title")
        let description = extractMetaProperty(html, property: "og:description")
        return LinkMetadata(
            url: url,
            title: title.map(decodeEntities),
            description: description.map(decodeEntities),
            thumbnailURL: extractMetaProperty(html, property: "og:image"),
            platform: .web
        )
    }

    private static func readHead(of request: URLRequest) async -> String? {
        guard let (bytes, response) = try? await URLSession.shared.bytes(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { return nil }
        var data = Data()
        let closing = Data("</head>".utf8)
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 200_000 { break }
                if data.count % 4096 == 0, data.range(of: closing) != nil { break }
            }
        } catch {
            return data.isEmpty ? nil : String(decoding: data, as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func extractMetaProperty(_ html: String, property: String) -> String? {
        let patterns = [
            "<meta[^>]*property=[\"']" + property + "[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']" + property + "[\"']",
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            return String(html[range])
        }
        return nil
    }

    private static func extractTagContent(_ html: String, tag: String) -> String? {
        let pattern = "<" + tag + "[^>]*>([^<]+)</" + tag + ">"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class LinkMetadataCache {
    private let lock = NSLock()
    private var storage: [String: LinkMetadata] = [:]

    func value(for url: String) -> LinkMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return storage[url]
    }

    func store(_ metadata: LinkMetadata, for url: String) {
        guard metadata.title != nil else { return }
        lock.lock()
        storage[url] = metadata
        lock.unlock()
    }
}
