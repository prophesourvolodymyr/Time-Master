import SwiftUI

struct MediaCommentMarkdown: View {
    let text: String
    var assets: MarkdownAssets? = nil

    var body: some View {
        MarkdownDocumentView(markdown: text, assets: assets)
    }
}

enum MediaCommentInlineMarkdown {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private final class Rendered {
        let text: AttributedString

        init(_ text: AttributedString) {
            self.text = text
        }
    }

    private static let cache: NSCache<NSString, Rendered> = {
        let cache = NSCache<NSString, Rendered>()
        cache.countLimit = 600
        return cache
    }()

    static func render(_ text: String, headingLevel: Int? = nil) -> AttributedString {
        let level = headingLevel.map { "\($0)" } ?? "-"
        let key = "\(level)\u{1F}\(text)" as NSString
        if let hit = cache.object(forKey: key) { return hit.text }
        let result = make(text, headingLevel: headingLevel)
        cache.setObject(Rendered(result), forKey: key)
        return result
    }

    private static func make(_ text: String, headingLevel: Int?) -> AttributedString {
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
