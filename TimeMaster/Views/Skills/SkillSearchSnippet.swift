import Foundation
import TimeMasterCore

/// A short "why this matched" line for a search hit whose title did not match.
struct SkillSearchSnippet: Equatable {
    enum Kind: Equatable { case notes, comment, link, group, todo, milestone }

    let text: String
    let kind: Kind

    var systemImage: String {
        switch kind {
        case .notes: "text.alignleft"
        case .comment: "text.bubble"
        case .link: "link"
        case .group: "rectangle.split.3x1"
        case .todo: "checklist"
        case .milestone: "flag.fill"
        }
    }

    static let maxLength = 90

    /// Whether the page's title or anything readable on it holds `query`.
    static func matches(_ manifest: ExercisePageManifest, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return contains(manifest.title, needle) || make(for: manifest, query: needle) != nil
    }

    /// Nil when the title matches (the title already says why) or nothing readable matches. Looks in the notes, the
    /// board groups, the comments on media and links, the links, the to-dos and the milestones, in that order.
    static func make(for manifest: ExercisePageManifest, query: String) -> SkillSearchSnippet? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, !contains(manifest.title, needle) else { return nil }
        if let line = firstLine(of: manifest.markdownBody, containing: needle) {
            return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .notes)
        }
        for section in manifest.orderedSkillBoardSections {
            if contains(section.title, needle) {
                return SkillSearchSnippet(text: "Group “\(section.title)”", kind: .group)
            }
            if let line = firstLine(of: section.markdownBody, containing: needle) {
                return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .notes)
            }
        }
        for filename in manifest.mediaFilenames {
            if let comment = manifest.mediaComments[filename], let line = firstLine(of: comment, containing: needle) {
                return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .comment)
            }
        }
        for url in manifest.linkURLs {
            if let title = manifest.linkMetadata.first(where: { $0.url == url })?.title, contains(title, needle) {
                return SkillSearchSnippet(text: excerpt(title, around: needle), kind: .link)
            }
            if contains(url, needle) {
                return SkillSearchSnippet(text: excerpt(url, around: needle), kind: .link)
            }
            if let comment = manifest.linkComments[url], let line = firstLine(of: comment, containing: needle) {
                return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .comment)
            }
        }
        if let line = firstLine(in: manifest.todos, containing: needle) {
            return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .todo)
        }
        if let line = firstLine(in: manifest.milestones, containing: needle) {
            return SkillSearchSnippet(text: excerpt(line, around: needle), kind: .milestone)
        }
        return nil
    }

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static func contains(_ text: String, _ needle: String) -> Bool {
        text.range(of: needle, options: options) != nil
    }

    private static func firstLine(of text: String, containing needle: String) -> String? {
        for raw in text.split(whereSeparator: { $0.isNewline }) {
            let line = cleaned(String(raw))
            if !line.isEmpty, contains(line, needle) { return line }
        }
        return nil
    }

    /// The first to-do or milestone, at any level, whose title or note holds `needle`.
    private static func firstLine<Entry: ChecklistEntry>(in entries: [Entry], containing needle: String) -> String? {
        for entry in entries {
            if contains(entry.title, needle) { return entry.title }
            if let line = firstLine(of: entry.note, containing: needle) { return line }
            if let line = firstLine(in: entry.children, containing: needle) { return line }
        }
        return nil
    }

    /// Drops Markdown list, heading and quote markers.
    private static func cleaned(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        while let first = result.first, "#>-*•".contains(first) {
            result.removeFirst()
            result = result.trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    /// Keeps the match visible inside `maxLength` characters.
    static func excerpt(_ line: String, around needle: String) -> String {
        guard line.count > maxLength, let match = line.range(of: needle, options: options) else { return line }
        let matchOffset = line.distance(from: line.startIndex, to: match.lowerBound)
        let startOffset = max(0, min(matchOffset - 24, line.count - maxLength))
        let start = line.index(line.startIndex, offsetBy: startOffset)
        let end = line.index(start, offsetBy: min(maxLength, line.count - startOffset))
        var result = String(line[start..<end])
        if startOffset > 0 { result = "…" + result }
        if end < line.endIndex { result += "…" }
        return result
    }
}
