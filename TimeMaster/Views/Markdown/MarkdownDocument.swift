import Foundation

struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case paragraph
        case heading(Int)
        case bullet
        case numbered
        case todo(Bool)
        case quote
        case code(String)
        case divider
        case image(String)
        case linkCard(url: String, thumbnail: String?)
    }

    let id: UUID
    var kind: Kind
    var text: String
    var indent: Int

    init(id: UUID = UUID(), kind: Kind = .paragraph, text: String = "", indent: Int = 0) {
        self.id = id
        self.kind = kind
        self.text = text
        self.indent = indent
    }

    var isTextual: Bool {
        switch kind {
        case .divider, .image, .linkCard: return false
        default: return true
        }
    }

    var isListItem: Bool {
        switch kind {
        case .bullet, .numbered, .todo: return true
        default: return false
        }
    }

    var isCode: Bool {
        if case .code = kind { return true }
        return false
    }

    var isParagraph: Bool { kind == .paragraph }
}

struct MarkdownCaret: Equatable {
    var blockID: UUID
    var location: Int
}

struct MarkdownDocument: Equatable {
    var blocks: [MarkdownBlock]

    init(blocks: [MarkdownBlock] = []) {
        self.blocks = blocks
    }

    init(markdown: String) {
        blocks = MarkdownCodec.parse(markdown)
    }

    var markdown: String {
        MarkdownCodec.serialize(blocks)
    }

    func index(of id: UUID) -> Int? {
        blocks.firstIndex { $0.id == id }
    }

    func previousTextualIndex(before index: Int) -> Int? {
        guard index > 0 else { return nil }
        return (0..<index).reversed().first { blocks[$0].isTextual }
    }

    func nextTextualIndex(after index: Int) -> Int? {
        guard index + 1 < blocks.count else { return nil }
        return ((index + 1)..<blocks.count).first { blocks[$0].isTextual }
    }

    mutating func ensureTrailingParagraph() {
        if let last = blocks.last, last.isParagraph, last.text.isEmpty { return }
        blocks.append(MarkdownBlock())
    }

    @discardableResult
    mutating func splitBlock(id: UUID, caret: Int) -> MarkdownCaret? {
        guard let index = index(of: id), blocks[index].isTextual, !blocks[index].isCode else { return nil }
        let block = blocks[index]
        if (block.isListItem || block.kind == .quote) && block.text.isEmpty {
            if block.indent > 0 {
                blocks[index].indent -= 1
            } else {
                blocks[index].kind = .paragraph
            }
            return MarkdownCaret(blockID: id, location: 0)
        }
        if block.isParagraph, block.text == "---" {
            blocks[index].kind = .divider
            blocks[index].text = ""
            let next = MarkdownBlock()
            blocks.insert(next, at: index + 1)
            return MarkdownCaret(blockID: next.id, location: 0)
        }
        let source = block.text as NSString
        let location = min(max(0, caret), source.length)
        blocks[index].text = source.substring(to: location)
        let rest = source.substring(from: location)
        let kind: MarkdownBlock.Kind
        switch block.kind {
        case .heading: kind = .paragraph
        case .todo: kind = .todo(false)
        default: kind = block.kind
        }
        let next = MarkdownBlock(kind: kind, text: rest, indent: block.isListItem ? block.indent : 0)
        blocks.insert(next, at: index + 1)
        return MarkdownCaret(blockID: next.id, location: 0)
    }

    @discardableResult
    mutating func deleteBackwardAtStart(id: UUID) -> MarkdownCaret? {
        guard let index = index(of: id), blocks[index].isTextual else { return nil }
        let block = blocks[index]
        if !block.isParagraph {
            if block.isListItem, block.indent > 0 {
                blocks[index].indent -= 1
            } else {
                blocks[index].kind = .paragraph
                blocks[index].indent = 0
            }
            return MarkdownCaret(blockID: id, location: 0)
        }
        guard index > 0 else { return nil }
        let previous = blocks[index - 1]
        if previous.isTextual, !previous.isCode {
            let length = (previous.text as NSString).length
            blocks[index - 1].text = previous.text + block.text
            blocks.remove(at: index)
            return MarkdownCaret(blockID: previous.id, location: length)
        }
        if block.text.isEmpty {
            blocks.remove(at: index)
            if let target = previousTextualIndex(before: index) {
                return MarkdownCaret(blockID: blocks[target].id, location: (blocks[target].text as NSString).length)
            }
            ensureTrailingParagraph()
            return blocks.last.map { MarkdownCaret(blockID: $0.id, location: 0) }
        }
        return nil
    }

    @discardableResult
    mutating func applyShortcut(id: UUID, caret: Int) -> MarkdownCaret? {
        guard let index = index(of: id), blocks[index].isTextual else { return nil }
        let block = blocks[index]
        guard block.isParagraph || block.kind == .bullet else { return nil }
        let text = block.text

        if block.isParagraph, text == "---", caret == 3 {
            blocks[index].kind = .divider
            blocks[index].text = ""
            let next = MarkdownBlock()
            blocks.insert(next, at: index + 1)
            return MarkdownCaret(blockID: next.id, location: 0)
        }
        if block.isParagraph, text == "```", caret == 3 {
            blocks[index].kind = .code("")
            blocks[index].text = ""
            return MarkdownCaret(blockID: id, location: 0)
        }

        let patterns: [(prefix: String, kind: MarkdownBlock.Kind, paragraphOnly: Bool)] = [
            ("### ", .heading(3), true),
            ("## ", .heading(2), true),
            ("# ", .heading(1), true),
            ("[x] ", .todo(true), false),
            ("[X] ", .todo(true), false),
            ("[ ] ", .todo(false), false),
            ("[] ", .todo(false), false),
            ("- ", .bullet, true),
            ("* ", .bullet, true),
            ("+ ", .bullet, true),
            ("> ", .quote, true)
        ]
        for pattern in patterns where text.hasPrefix(pattern.prefix) && caret == (pattern.prefix as NSString).length {
            if pattern.paragraphOnly && !block.isParagraph { continue }
            blocks[index].kind = pattern.kind
            blocks[index].text = String(text.dropFirst(pattern.prefix.count))
            return MarkdownCaret(blockID: id, location: 0)
        }
        if block.isParagraph, let numbered = MarkdownCodec.numberedPrefix(text), caret == numbered {
            blocks[index].kind = .numbered
            blocks[index].text = (text as NSString).substring(from: numbered)
            return MarkdownCaret(blockID: id, location: 0)
        }
        return nil
    }

    mutating func convert(id: UUID, to kind: MarkdownBlock.Kind) {
        guard let index = index(of: id) else { return }
        blocks[index].kind = kind
        switch kind {
        case .bullet, .numbered, .todo:
            break
        default:
            blocks[index].indent = 0
        }
        if kind == .divider {
            blocks[index].text = ""
            if index + 1 >= blocks.count { blocks.append(MarkdownBlock()) }
        }
    }

    mutating func changeIndent(id: UUID, by delta: Int) {
        guard let index = index(of: id), blocks[index].isListItem else { return }
        let limit: Int
        if index > 0, blocks[index - 1].isListItem {
            limit = min(MarkdownCodec.maximumIndent, blocks[index - 1].indent + 1)
        } else {
            limit = 0
        }
        let proposed = blocks[index].indent + delta
        if delta > 0 {
            blocks[index].indent = min(proposed, max(blocks[index].indent, limit))
        } else {
            blocks[index].indent = max(0, proposed)
        }
    }

    mutating func insert(_ block: MarkdownBlock, after id: UUID?) {
        if let id, let index = index(of: id) {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
    }

    mutating func replace(id: UUID, with block: MarkdownBlock) {
        guard let index = index(of: id) else { return }
        blocks[index] = block
    }

    @discardableResult
    mutating func remove(id: UUID) -> MarkdownCaret? {
        guard let index = index(of: id) else { return nil }
        blocks.remove(at: index)
        if blocks.isEmpty { blocks.append(MarkdownBlock()) }
        let target = min(index, blocks.count - 1)
        if let textual = (0...target).reversed().first(where: { blocks[$0].isTextual }) ?? blocks.indices.first(where: { blocks[$0].isTextual }) {
            return MarkdownCaret(blockID: blocks[textual].id, location: (blocks[textual].text as NSString).length)
        }
        return nil
    }

    mutating func move(id: UUID, offset: Int) {
        guard let index = index(of: id) else { return }
        let target = min(max(0, index + offset), blocks.count - 1)
        guard target != index else { return }
        let block = blocks.remove(at: index)
        blocks.insert(block, at: target)
    }

    mutating func toggleTodo(id: UUID) {
        guard let index = index(of: id), case .todo(let done) = blocks[index].kind else { return }
        blocks[index].kind = .todo(!done)
    }

    @discardableResult
    mutating func duplicate(id: UUID) -> UUID? {
        guard let index = index(of: id) else { return nil }
        var copy = blocks[index]
        copy = MarkdownBlock(kind: copy.kind, text: copy.text, indent: copy.indent)
        blocks.insert(copy, at: index + 1)
        return copy.id
    }

    func numberedPosition(at index: Int) -> Int {
        guard blocks.indices.contains(index), blocks[index].kind == .numbered else { return 1 }
        var position = 1
        var cursor = index - 1
        while cursor >= 0 {
            let candidate = blocks[cursor]
            guard candidate.isListItem, candidate.indent >= blocks[index].indent else { break }
            if candidate.indent == blocks[index].indent {
                guard candidate.kind == .numbered else { break }
                position += 1
            }
            cursor -= 1
        }
        return position
    }
}

enum MarkdownCodec {
    static let maximumIndent = 3

    private static let heading = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.*)$")
    private static let divider = try! NSRegularExpression(pattern: "^(?:-{3,}|\\*{3,}|_{3,})$")
    private static let todo = try! NSRegularExpression(pattern: "^(\\s*)[-*+]\\s+\\[([ xX])\\]\\s?(.*)$")
    private static let bullet = try! NSRegularExpression(pattern: "^(\\s*)[-*+]\\s+(.*)$")
    private static let numbered = try! NSRegularExpression(pattern: "^(\\s*)\\d{1,9}[.)]\\s+(.*)$")
    private static let quote = try! NSRegularExpression(pattern: "^\\s{0,3}>\\s?(.*)$")
    private static let image = try! NSRegularExpression(pattern: "^!\\[((?:\\\\.|[^\\]\\\\])*)\\]\\(\\s*(<[^>]+>|[^)\\s]+)(?:\\s+\"[^\"]*\")?\\s*\\)$")
    private static let cardWithThumbnail = try! NSRegularExpression(
        pattern: "^\\[!\\[((?:\\\\.|[^\\]\\\\])*)\\]\\(\\s*(<[^>]+>|[^)\\s]+)\\s*\\)\\]\\(\\s*(<[^>]+>|[^)\\s]+)\\s*\\)$"
    )
    private static let cardWithoutThumbnail = try! NSRegularExpression(
        pattern: "^\\[((?:\\\\.|[^\\]\\\\])+)\\]\\(\\s*(<[^>]+>|[^)\\s]+)\\s+\"card\"\\s*\\)$"
    )

    private static func continuesList(_ previous: MarkdownBlock, _ block: MarkdownBlock) -> Bool {
        guard previous.isListItem, block.isListItem else { return false }
        return previous.indent != block.indent || (previous.kind == .numbered) == (block.kind == .numbered)
    }
    private static let numberedPrefixPattern = try! NSRegularExpression(pattern: "^\\d{1,9}\\. ")

    static func numberedPrefix(_ text: String) -> Int? {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return numberedPrefixPattern.firstMatch(in: text, range: range).map { $0.range.length }
    }

    static func parse(_ source: String) -> [MarkdownBlock] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quoteLines: [String] = []
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .paragraph, text: paragraph.joined(separator: "\n")))
            paragraph = []
        }
        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .quote, text: quoteLines.joined(separator: "\n")))
            quoteLines = []
        }
        func flush() {
            flushParagraph()
            flushQuote()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let fence = fenceOpening(trimmed) {
                flush()
                var body: [String] = []
                index += 1
                while index < lines.count, !isFenceClosing(lines[index].trimmingCharacters(in: .whitespaces), fence: fence) {
                    body.append(lines[index])
                    index += 1
                }
                blocks.append(MarkdownBlock(kind: .code(fence.language), text: body.joined(separator: "\n")))
                index += 1
                continue
            }

            if trimmed.isEmpty {
                flush()
            } else if matches(divider, trimmed) {
                flush()
                blocks.append(MarkdownBlock(kind: .divider))
            } else if let groups = captures(heading, trimmed) {
                flush()
                blocks.append(MarkdownBlock(kind: .heading(min(3, groups[0].count)), text: groups[1]))
            } else if let groups = captures(image, trimmed) {
                flush()
                blocks.append(MarkdownBlock(kind: .image(unwrap(groups[1])), text: unescape(groups[0])))
            } else if let groups = captures(cardWithThumbnail, trimmed) {
                flush()
                blocks.append(MarkdownBlock(
                    kind: .linkCard(url: unwrap(groups[2]), thumbnail: unwrap(groups[1])),
                    text: unescape(groups[0])
                ))
            } else if let groups = captures(cardWithoutThumbnail, trimmed) {
                flush()
                blocks.append(MarkdownBlock(kind: .linkCard(url: unwrap(groups[1]), thumbnail: nil), text: unescape(groups[0])))
            } else if let groups = captures(todo, line) {
                flush()
                blocks.append(MarkdownBlock(kind: .todo(groups[1] != " "), text: groups[2], indent: indent(groups[0])))
            } else if let groups = captures(bullet, line) {
                flush()
                blocks.append(MarkdownBlock(kind: .bullet, text: groups[1], indent: indent(groups[0])))
            } else if let groups = captures(numbered, line) {
                flush()
                blocks.append(MarkdownBlock(kind: .numbered, text: groups[1], indent: indent(groups[0])))
            } else if let groups = captures(quote, line) {
                flushParagraph()
                quoteLines.append(groups[0])
            } else {
                flushQuote()
                paragraph.append(line)
            }
            index += 1
        }
        flush()
        return blocks
    }

    static func serialize(_ blocks: [MarkdownBlock]) -> String {
        var output = ""
        var counters = Array(repeating: 0, count: maximumIndent + 1)
        var previous: MarkdownBlock?

        for block in blocks {
            if block.isParagraph, block.text.isEmpty { continue }
            var line = ""
            switch block.kind {
            case .paragraph:
                line = block.text
            case .heading(let level):
                line = String(repeating: "#", count: min(3, max(1, level))) + " " + block.text
            case .bullet:
                line = String(repeating: "  ", count: block.indent) + "- " + block.text
            case .numbered:
                counters[block.indent] += 1
                if block.indent < maximumIndent {
                    for deeper in (block.indent + 1)...maximumIndent { counters[deeper] = 0 }
                }
                line = String(repeating: "  ", count: block.indent) + "\(counters[block.indent]). " + block.text
            case .todo(let done):
                line = String(repeating: "  ", count: block.indent) + (done ? "- [x] " : "- [ ] ") + block.text
            case .quote:
                line = block.text.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
            case .code(let language):
                let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: block.text) + 1))
                line = fence + language + "\n" + block.text + "\n" + fence
            case .divider:
                line = "---"
            case .image(let path):
                line = "![\(escape(block.text))](<\(path)>)"
            case .linkCard(let url, let thumbnail):
                if let thumbnail, !thumbnail.isEmpty {
                    line = "[![\(escape(block.text))](<\(thumbnail)>)](<\(url)>)"
                } else {
                    line = "[\(escape(block.text.isEmpty ? url : block.text))](<\(url)> \"card\")"
                }
            }
            switch block.kind {
            case .numbered:
                break
            case .bullet, .todo:
                for level in 0...maximumIndent where level >= block.indent { counters[level] = 0 }
            default:
                counters = Array(repeating: 0, count: maximumIndent + 1)
            }

            if let previous {
                output += continuesList(previous, block) ? "\n" : "\n\n"
            }
            output += line
            previous = block
        }
        return output
    }

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    private static func captures(_ expression: NSRegularExpression, _ text: String) -> [String]? {
        let source = text as NSString
        guard let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: source.length)) else { return nil }
        return (1..<match.numberOfRanges).map { group in
            let range = match.range(at: group)
            return range.location == NSNotFound ? "" : source.substring(with: range)
        }
    }

    private static func indent(_ leading: String) -> Int {
        let spaces = leading.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
        return min(maximumIndent, spaces / 2)
    }

    private static func unwrap(_ value: String) -> String {
        guard value.hasPrefix("<"), value.hasSuffix(">"), value.count >= 2 else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\[", with: "[")
            .replacingOccurrences(of: "\\]", with: "]")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func fenceOpening(_ trimmed: String) -> (character: Character, count: Int, language: String)? {
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix { $0 == first }.count
        guard count >= 3 else { return nil }
        let info = String(trimmed.dropFirst(count)).trimmingCharacters(in: .whitespaces)
        if first == "`", info.contains("`") { return nil }
        return (first, count, info)
    }

    private static func isFenceClosing(_ trimmed: String, fence: (character: Character, count: Int, language: String)) -> Bool {
        guard let first = trimmed.first, first == fence.character else { return false }
        let count = trimmed.prefix { $0 == first }.count
        return count >= fence.count && trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty
    }
}
