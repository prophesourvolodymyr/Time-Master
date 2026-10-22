import SwiftUI

struct MediaCommentBubble: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 18
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    var body: some View {
        Text(Self.render(text))
            .font(TimeMasterFont.body(17))
            .foregroundStyle(Theme.textPrimary)
            .tint(.blue)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .environment(\.openURL, OpenURLAction { url in
                ["http", "https"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
            })
    }

    private static func render(_ text: String) -> AttributedString {
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
        return TimeMasterFont.styledText(rendered, size: 17)
    }
}
