import Foundation

enum NotePreview {
    private static let leadingMarker = try! NSRegularExpression(pattern: #"^\s*(?:#{1,6}\s+|>\s?|[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|\d+[.)]\s+)"#)
    private static let inlineLink = try! NSRegularExpression(pattern: #"\[([^\]]*)\]\([^)]*\)"#)
    private static let inlineMarks = CharacterSet(charactersIn: "*_`~")
    private static let scanLimit = 900

    static func text(from markdown: String, maxLines: Int = 2, maxLength: Int = 180) -> String {
        var lines: [String] = []
        var inFence = false
        for raw in markdown.prefix(scanLimit).split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence || line.isEmpty || line.hasPrefix("![") || line.hasPrefix("[![") || line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) { continue }
            let plain = strip(line)
            guard !plain.isEmpty else { continue }
            lines.append(plain)
            if lines.count == maxLines { break }
        }
        let joined = lines.joined(separator: " ")
        return joined.count > maxLength ? String(joined.prefix(maxLength)) + "…" : joined
    }

    private static func strip(_ line: String) -> String {
        var text = line
        var range = NSRange(text.startIndex..., in: text)
        text = leadingMarker.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        range = NSRange(text.startIndex..., in: text)
        text = inlineLink.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
        return text.unicodeScalars.filter { !inlineMarks.contains($0) }.reduce(into: "") { $0.unicodeScalars.append($1) }
            .trimmingCharacters(in: .whitespaces)
    }
}
