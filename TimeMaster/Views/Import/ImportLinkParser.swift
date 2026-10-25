import Foundation

enum ImportLinkParser {
    static func links(in text: String) -> [URL] {
        guard let expression = try? NSRegularExpression(pattern: #"https?://(?:(?!https?://)[^\s<>\"“”])+"#, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<String>()
        return expression.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            var candidate = String(text[range])
            while let last = candidate.last {
                if ".,;:!?'’".contains(last) {
                    candidate.removeLast()
                } else if let opening = [")": "(", "]": "[", "}": "{"][String(last)],
                          candidate.filter({ String($0) == String(last) }).count > candidate.filter({ String($0) == opening }).count {
                    candidate.removeLast()
                } else {
                    break
                }
            }
            guard var components = URLComponents(string: candidate),
                  let scheme = components.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = components.host, !host.isEmpty else { return nil }
            components.scheme = scheme
            components.host = host.lowercased()
            if (scheme == "http" && components.port == 80) || (scheme == "https" && components.port == 443) {
                components.port = nil
            }
            guard let url = components.url else { return nil }
            return seen.insert(identity(for: url)).inserted ? url : nil
        }
    }

    static func identity(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if components.path.isEmpty { components.path = "/" }
        return components.string ?? url.absoluteString
    }

    static func symbolName(for url: URL) -> String {
        if url.isFileURL { return "film" }
        let host = (url.host ?? "").lowercased()
        if host.contains("youtube") || host.contains("youtu.be") { return "play.rectangle.fill" }
        if host.contains("instagram") { return "camera.fill" }
        if host.contains("tiktok") { return "music.note" }
        if host.contains("vimeo") { return "play.circle.fill" }
        return "link"
    }
}

enum ImportLinkStatus: Equatable {
    case queued
    case validating
    case downloading
    case ready
    case failed(String)
    case cancelled

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .validating: return "Checking video…"
        case .downloading: return "Downloading…"
        case .ready: return "Ready"
        case .failed: return "Couldn’t import"
        case .cancelled: return "Cancelled"
        }
    }

    var isActive: Bool {
        self == .validating || self == .downloading
    }

    var canRetry: Bool {
        switch self {
        case .failed, .cancelled: return true
        default: return false
        }
    }

    var error: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
