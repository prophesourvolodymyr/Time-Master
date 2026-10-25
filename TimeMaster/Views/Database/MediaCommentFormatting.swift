import Foundation

enum MediaCommentFormatting {
    static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let count = (text as NSString).length
        let location = min(max(0, range.location), count)
        return NSRange(location: location, length: min(max(0, range.length), count - location))
    }

    static func wrap(
        _ text: inout String,
        selection: inout NSRange,
        prefix: String,
        suffix: String,
        placeholder: String
    ) {
        let source = text as NSString
        let range = clamped(selection, in: text)
        let selected = source.substring(with: range)
        let prefixLength = (prefix as NSString).length
        let suffixLength = (suffix as NSString).length
        if range.length >= prefixLength + suffixLength,
           selected.hasPrefix(prefix), selected.hasSuffix(suffix) {
            let inner = (selected as NSString).substring(with: NSRange(location: prefixLength, length: range.length - prefixLength - suffixLength))
            text = source.replacingCharacters(in: range, with: inner)
            selection = NSRange(location: range.location, length: (inner as NSString).length)
        } else if range.location >= prefixLength,
                  NSMaxRange(range) + suffixLength <= source.length,
                  source.substring(with: NSRange(location: range.location - prefixLength, length: prefixLength)) == prefix,
                  source.substring(with: NSRange(location: NSMaxRange(range), length: suffixLength)) == suffix {
            let outer = NSRange(location: range.location - prefixLength, length: range.length + prefixLength + suffixLength)
            text = source.replacingCharacters(in: outer, with: selected)
            selection = NSRange(location: outer.location, length: range.length)
        } else {
            let content = selected.isEmpty ? placeholder : selected
            text = source.replacingCharacters(in: range, with: prefix + content + suffix)
            selection = NSRange(location: range.location + prefixLength, length: (content as NSString).length)
        }
    }

    static func prefixLines(_ text: inout String, selection: inout NSRange, prefix: String) {
        let source = text as NSString
        let selectedRange = clamped(selection, in: text)
        var range = selectedRange
        if range.length > 0, source.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1)) == "\n" {
            range.length -= 1
        }
        let lineRange = source.lineRange(for: range)
        let selectedLines = source.substring(with: lineRange)
        let hasTrailingNewline = selectedLines.hasSuffix("\n")
        var lines = selectedLines.components(separatedBy: "\n")
        if hasTrailingNewline { lines.removeLast() }
        let removesPrefix = lines.allSatisfy { $0.hasPrefix(prefix) }
        let replacement = lines.enumerated().map { index, line in
            if removesPrefix { return String(line.dropFirst(prefix.count)) }
            if prefix == "1. " { return "\(index + 1). " + line }
            return prefix + line
        }.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        text = source.replacingCharacters(in: lineRange, with: replacement)
        if selectedRange.length == 0 {
            let delta = removesPrefix ? -(prefix as NSString).length : (prefix as NSString).length
            selection = NSRange(location: max(lineRange.location, selectedRange.location + delta), length: 0)
        } else {
            selection = NSRange(location: lineRange.location, length: (replacement as NSString).length)
        }
    }

    static func insertLink(_ text: inout String, selection: inout NSRange, label: String, url: URL) {
        let range = clamped(selection, in: text)
        let content = (label.isEmpty ? url.absoluteString : label)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let replacement = "[\(content)](<\(url.absoluteString)>)"
        text = (text as NSString).replacingCharacters(in: range, with: replacement)
        selection = NSRange(location: range.location + (replacement as NSString).length, length: 0)
    }
}
