import SwiftUI

struct MediaCommentMarkdown: View {
    let text: String

    var body: some View {
        MediaCommentMarkdownBlocks(blocks: MediaCommentMarkdownParser.parse(text))
            .foregroundStyle(Theme.textPrimary)
            .tint(.blue)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediaCommentMarkdownBlocks: View {
    let blocks: [MediaCommentMarkdownParser.Block]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MediaCommentMarkdownParser.Block) -> some View {
        switch block {
        case .paragraph(let text):
            Text(MediaCommentInlineMarkdown.render(text))
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let level, let text):
            Text(MediaCommentInlineMarkdown.render(text, headingLevel: level))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .quote(let children):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.toolbarOrange)
                    .frame(width: 3)
                MediaCommentMarkdownBlocks(blocks: children)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
        case .list(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        if let completed = item.completed {
                            Image(systemName: completed ? "checkmark.square.fill" : "square")
                                .foregroundStyle(completed ? Theme.toolbarOrange : Theme.textSecondary)
                                .frame(minWidth: 22)
                                .accessibilityLabel(completed ? "Completed task" : "Incomplete task")
                        } else {
                            Text(item.marker)
                                .font(TimeMasterFont.body(17))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(minWidth: 22, alignment: .trailing)
                                .accessibilityHidden(item.marker == "•")
                        }
                        MediaCommentMarkdownBlocks(blocks: item.blocks)
                    }
                }
            }
        case .code(let code, let language):
            VStack(alignment: .leading, spacing: 6) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                ScrollView(.horizontal) {
                    Text(verbatim: code)
                        .font(.system(.callout, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Theme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Code block")
        case .rule:
            Divider().overlay(Theme.textSecondary.opacity(0.5))
        }
    }
}

enum MediaCommentInlineMarkdown {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func render(_ text: String, headingLevel: Int? = nil) -> AttributedString {
        var rendered = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
        let plainText = String(rendered.characters)
        let fullRange = NSRange(plainText.startIndex..<plainText.endIndex, in: plainText)
        for match in linkDetector?.matches(in: plainText, range: fullRange) ?? [] {
            guard let url = match.url,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let range = Range(match.range, in: plainText),
                  let lower = AttributedString.Index(range.lowerBound, within: rendered),
                  let upper = AttributedString.Index(range.upperBound, within: rendered) else { continue }
            let attributedRange = lower..<upper
            guard rendered[attributedRange].link == nil,
                  !rendered[attributedRange].runs.contains(where: {
                      $0.inlinePresentationIntent?.contains(.code) == true
                  }) else { continue }
            rendered[attributedRange].link = url
        }
        let size: CGFloat = headingLevel.map { [26, 23, 20, 18, 17, 16][min(5, max(0, $0 - 1))] } ?? 17
        let original = rendered
        rendered = TimeMasterFont.styledText(rendered, size: size)
        for run in original.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                rendered[run.range].font = .system(.callout, design: .monospaced)
            } else if headingLevel != nil, run.inlinePresentationIntent?.contains(.emphasized) != true {
                rendered[run.range].font = TimeMasterFont.black(size, relativeTo: .headline)
            }
        }
        return rendered
    }
}

enum MediaCommentMarkdownParser {
    indirect enum Block {
        case paragraph(String)
        case heading(Int, String)
        case quote([Block])
        case list([ListItem])
        case code(String, String?)
        case rule
    }

    struct ListItem {
        let marker: String
        let completed: Bool?
        let blocks: [Block]
    }

    private struct ListMarker {
        let indent: Int
        let contentIndent: Int
        let ordinal: Int?
        let content: String
    }

    private static let listPattern = try? NSRegularExpression(pattern: "^( {0,3})([-+*]|[0-9]{1,9}[.)])([ \\t]+)(.*)$")

    static func parse(_ source: String) -> [Block] {
        parseLines(source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n"))
    }

    private static func parseLines(_ lines: [String]) -> [Block] {
        var result: [Block] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { index += 1; continue }
            if let fence = fenceOpening(line) {
                var code: [String] = []
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.prefix(while: { $0 == fence.character }).count >= fence.count,
                       candidate.allSatisfy({ $0 == fence.character || $0.isWhitespace }) {
                        index += 1
                        break
                    }
                    code.append(lines[index])
                    index += 1
                }
                result.append(.code(code.joined(separator: "\n"), fence.language))
            } else if let heading = heading(line) {
                result.append(.heading(heading.level, heading.text))
                index += 1
            } else if isRule(line) {
                result.append(.rule)
                index += 1
            } else if quoteContent(line) != nil {
                var quoted: [String] = []
                while index < lines.count {
                    if let content = quoteContent(lines[index]) {
                        quoted.append(content)
                        index += 1
                    } else if lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                              index + 1 < lines.count, quoteContent(lines[index + 1]) != nil {
                        quoted.append("")
                        index += 1
                    } else { break }
                }
                result.append(.quote(parseLines(quoted)))
            } else if let firstMarker = listMarker(line) {
                var items: [ListItem] = []
                var ordinal = firstMarker.ordinal ?? 0
                while index < lines.count, let marker = listMarker(lines[index]),
                      marker.indent == firstMarker.indent,
                      (marker.ordinal == nil) == (firstMarker.ordinal == nil) {
                    var content = marker.content
                    var completed: Bool?
                    if content.hasPrefix("[ ] ") || content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                        completed = !content.hasPrefix("[ ]")
                        content = String(content.dropFirst(4))
                    } else if content == "[ ]" || content.lowercased() == "[x]" {
                        completed = content != "[ ]"
                        content = ""
                    }
                    var itemLines = [content]
                    index += 1
                    while index < lines.count {
                        let next = lines[index]
                        let indentation = next.prefix(while: { $0 == " " }).count
                        if next.trimmingCharacters(in: .whitespaces).isEmpty {
                            if index + 1 < lines.count,
                               lines[index + 1].prefix(while: { $0 == " " }).count > firstMarker.indent {
                                itemLines.append("")
                                index += 1
                                continue
                            }
                            break
                        }
                        if indentation >= marker.contentIndent {
                            itemLines.append(String(next.dropFirst(marker.contentIndent)))
                        } else if next.hasPrefix("\t") {
                            itemLines.append(String(next.dropFirst()))
                        } else if listMarker(next) != nil || startsBlock(next) || itemLines.last == "" {
                            break
                        } else {
                            itemLines.append(next)
                        }
                        index += 1
                    }
                    items.append(ListItem(marker: firstMarker.ordinal == nil ? "•" : "\(ordinal).", completed: completed, blocks: parseLines(itemLines)))
                    ordinal += 1
                    while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                        index += 1
                    }
                }
                result.append(.list(items))
            } else if line.hasPrefix("    ") || line.hasPrefix("\t") {
                var code: [String] = []
                while index < lines.count {
                    let next = lines[index]
                    if next.hasPrefix("    ") { code.append(String(next.dropFirst(4))) }
                    else if next.hasPrefix("\t") { code.append(String(next.dropFirst())) }
                    else if next.isEmpty { code.append("") }
                    else { break }
                    index += 1
                }
                result.append(.code(code.joined(separator: "\n"), nil))
            } else {
                var paragraph = [line]
                index += 1
                if index < lines.count, let level = setextLevel(lines[index]) {
                    result.append(.heading(level, line))
                    index += 1
                    continue
                }
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty, !startsBlock(lines[index]) {
                    paragraph.append(lines[index])
                    index += 1
                }
                result.append(.paragraph(paragraph.joined(separator: "\n")))
            }
        }
        return result
    }

    private static func startsBlock(_ line: String) -> Bool {
        fenceOpening(line) != nil || heading(line) != nil || isRule(line) || quoteContent(line) != nil || listMarker(line) != nil
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        guard line.prefix(while: { $0 == " " }).count <= 3 else { return nil }
        let content = line.drop(while: { $0 == " " })
        let level = content.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else { return nil }
        let remainder = content.dropFirst(level)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else { return nil }
        var text = String(remainder).trimmingCharacters(in: .whitespaces)
        if let hash = text.lastIndex(where: { $0 != "#" }), text[hash].isWhitespace {
            text = String(text[...hash]).trimmingCharacters(in: .whitespaces)
        }
        return (level, text)
    }

    private static func setextLevel(_ line: String) -> Int? {
        let text = line.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty, text.allSatisfy({ $0 == "=" }) { return 1 }
        if !text.isEmpty, text.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    private static func isRule(_ line: String) -> Bool {
        let text = line.filter { !$0.isWhitespace }
        guard text.count >= 3, let first = text.first, ["-", "*", "_"].contains(first) else { return false }
        return text.allSatisfy { $0 == first }
    }

    private static func quoteContent(_ line: String) -> String? {
        guard line.prefix(while: { $0 == " " }).count <= 3 else { return nil }
        let trimmed = line.drop(while: { $0 == " " })
        guard trimmed.first == ">" else { return nil }
        let remainder = trimmed.dropFirst()
        return String(remainder.first == " " ? remainder.dropFirst() : remainder)
    }

    private static func fenceOpening(_ line: String) -> (character: Character, count: Int, language: String?)? {
        guard line.prefix(while: { $0 == " " }).count <= 3 else { return nil }
        let trimmed = line.drop(while: { $0 == " " })
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        let language = trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces)
        return (first, count, language.isEmpty ? nil : language)
    }

    private static func listMarker(_ line: String) -> ListMarker? {
        let text = line as NSString
        guard let match = listPattern?.firstMatch(in: line, range: NSRange(location: 0, length: text.length)) else { return nil }
        let marker = text.substring(with: match.range(at: 2))
        let contentRange = match.range(at: 4)
        return ListMarker(indent: match.range(at: 1).length, contentIndent: contentRange.location, ordinal: Int(marker.dropLast()), content: text.substring(with: contentRange))
    }
}
