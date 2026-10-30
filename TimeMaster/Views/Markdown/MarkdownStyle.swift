import SwiftUI
#if os(iOS)
import UIKit
typealias MarkdownFont = UIFont
typealias MarkdownColor = UIColor
#else
import AppKit
typealias MarkdownFont = NSFont
typealias MarkdownColor = NSColor
#endif

enum MarkdownStyle {
    static let bodySize: CGFloat = 17
    static let lineSpacing: CGFloat = 4

    static func font(_ name: String, _ size: CGFloat) -> MarkdownFont {
        _ = TimeMasterFont.black(1)
        return MarkdownFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    static func body(_ size: CGFloat = bodySize) -> MarkdownFont { font("Manrope-Regular", size) }
    static func strong(_ size: CGFloat = bodySize) -> MarkdownFont { font("Inter-Black", size) }
    static func emphasis(_ size: CGFloat = bodySize) -> MarkdownFont { font("Inter-BlackItalic", size) }
    static func mono(_ size: CGFloat) -> MarkdownFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

    static var textColor: MarkdownColor { MarkdownColor(Theme.textPrimary) }
    static var dimColor: MarkdownColor { MarkdownColor(white: 1, alpha: 0.28) }
    static var secondaryColor: MarkdownColor { MarkdownColor(white: 1, alpha: 0.5) }
    static var accentColor: MarkdownColor { MarkdownColor(Theme.toolbarOrange) }
    static var codeBackground: MarkdownColor { MarkdownColor(white: 1, alpha: 0.08) }
    static let concealedFont: MarkdownFont = .systemFont(ofSize: 0.1)

    static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 23
        default: return 19
        }
    }

    static func base(for kind: MarkdownBlock.Kind) -> (font: MarkdownFont, color: MarkdownColor) {
        switch kind {
        case .heading(let level):
            return (strong(headingSize(level)), textColor)
        case .code:
            return (mono(15), textColor)
        case .quote:
            return (body(), MarkdownColor(white: 1, alpha: 0.78))
        case .todo(true):
            return (body(), secondaryColor)
        default:
            return (body(), textColor)
        }
    }

    static func paragraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }
}

enum MarkdownInlineStyler {
    private static let code = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
    private static let bold = try! NSRegularExpression(pattern: "(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private static let italic = try! NSRegularExpression(pattern: "(?<![*\\w])([*_])(?=[^\\s*_])(.+?)(?<=[^\\s*_])\\1(?![*\\w])")
    private static let strike = try! NSRegularExpression(pattern: "(~~)(?=\\S)(.+?)(?<=\\S)~~")
    private static let link = try! NSRegularExpression(pattern: "\\[([^\\]\\n]*)\\]\\(([^)\\n]*)\\)")
    private static let url = try! NSRegularExpression(pattern: "https?://[^\\s<>\"')\\]]+")

    static func apply(to storage: NSMutableAttributedString, kind: MarkdownBlock.Kind, concealsMarkup: Bool = false) {
        let full = NSRange(location: 0, length: storage.length)
        let base = MarkdownStyle.base(for: kind)
        storage.setAttributes([
            .font: base.font,
            .foregroundColor: base.color,
            .paragraphStyle: MarkdownStyle.paragraphStyle()
        ], range: full)
        guard storage.length > 0 else { return }

        if case .code = kind {
            storage.addAttribute(.backgroundColor, value: MarkdownStyle.codeBackground, range: full)
            return
        }
        if case .todo(true) = kind {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: full)
        }

        let size = base.font.pointSize
        let string = storage.string
        var protected: [NSRange] = []

        func dim(_ range: NSRange) {
            if concealsMarkup {
                storage.addAttributes([
                    .font: MarkdownStyle.concealedFont,
                    .foregroundColor: MarkdownColor.clear
                ], range: range)
            } else {
                storage.addAttribute(.foregroundColor, value: MarkdownStyle.dimColor, range: range)
            }
        }
        func free(_ range: NSRange) -> Bool {
            !protected.contains { NSIntersectionRange($0, range).length > 0 }
        }

        for match in code.matches(in: string, range: full) {
            let range = match.range
            protected.append(range)
            storage.addAttributes([
                .font: MarkdownStyle.mono(size - 1),
                .backgroundColor: MarkdownStyle.codeBackground
            ], range: match.range(at: 1))
            dim(NSRange(location: range.location, length: 1))
            dim(NSRange(location: NSMaxRange(range) - 1, length: 1))
        }
        for match in bold.matches(in: string, range: full) where free(match.range) {
            storage.addAttribute(.font, value: MarkdownStyle.strong(size), range: match.range(at: 2))
            let marker = match.range(at: 1).length
            dim(NSRange(location: match.range.location, length: marker))
            dim(NSRange(location: NSMaxRange(match.range) - marker, length: marker))
        }
        for match in italic.matches(in: string, range: full) where free(match.range) {
            storage.addAttribute(.font, value: MarkdownStyle.emphasis(size), range: match.range(at: 2))
            dim(NSRange(location: match.range.location, length: 1))
            dim(NSRange(location: NSMaxRange(match.range) - 1, length: 1))
        }
        for match in strike.matches(in: string, range: full) where free(match.range) {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
            dim(NSRange(location: match.range.location, length: 2))
            dim(NSRange(location: NSMaxRange(match.range) - 2, length: 2))
        }
        var linked: [NSRange] = []
        for match in link.matches(in: string, range: full) where free(match.range) {
            let label = match.range(at: 1)
            if concealsMarkup, label.length > 0 {
                dim(NSRange(location: match.range.location, length: 1))
                dim(NSRange(location: NSMaxRange(label), length: NSMaxRange(match.range) - NSMaxRange(label)))
            } else {
                dim(match.range)
            }
            if label.length > 0 {
                storage.addAttributes([
                    .foregroundColor: MarkdownStyle.accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: label)
            }
            linked.append(match.range)
        }
        for match in url.matches(in: string, range: full)
        where free(match.range) && !linked.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
            storage.addAttribute(.foregroundColor, value: MarkdownStyle.accentColor, range: match.range)
        }
    }
}

struct MarkdownFocusRequest: Equatable {
    var blockID: UUID
    var location: Int
    var token = UUID()
}

struct MarkdownTextHandlers {
    var onFocus: () -> Void = {}
    var onBlur: () -> Void = {}
    var onChange: (String, NSRange) -> Void = { _, _ in }
    var onSelection: (NSRange) -> Void = { _ in }
    var onReturn: (Int) -> Bool = { _ in false }
    var onBackspaceAtStart: () -> Bool = { false }
    var onTab: (Bool) -> Bool = { _ in false }
    var onPasteString: (String, NSRange) -> Bool = { _, _ in false }
    var onPasteImage: (Data) -> Bool = { _ in false }
    var onMoveUp: () -> Bool = { false }
    var onMoveDown: () -> Bool = { false }
    var liveText: () -> String? = { nil }
}
