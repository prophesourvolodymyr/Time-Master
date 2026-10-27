import SwiftUI

struct MarkdownDocumentView: View {
    let markdown: String
    var assets: MarkdownAssets? = nil

    var body: some View {
        let document = MarkdownDocument(markdown: markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                blockView(block, index: index, document: document)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.toolbarOrange)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, index: Int, document: MarkdownDocument) -> some View {
        switch block.kind {
        case .paragraph:
            Text(MediaCommentInlineMarkdown.render(block.text))
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let level):
            Text(MediaCommentInlineMarkdown.render(block.text, headingLevel: level))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level == 1 ? 6 : 2)
                .accessibilityAddTraits(.isHeader)
        case .bullet:
            listRow(marker: "\u{2022}", block: block)
        case .numbered:
            listRow(marker: "\(document.numberedPosition(at: index)).", block: block)
        case .todo(let done):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(done ? Theme.toolbarOrange : Theme.textSecondary)
                    .frame(minWidth: 22)
                    .accessibilityLabel(done ? "Completed task" : "Incomplete task")
                Text(MediaCommentInlineMarkdown.render(block.text))
                    .foregroundStyle(done ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(done)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(block.indent) * 22)
        case .quote:
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.toolbarOrange)
                    .frame(width: 3)
                Text(MediaCommentInlineMarkdown.render(block.text))
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
        case .code(let language):
            VStack(alignment: .leading, spacing: 6) {
                if !language.isEmpty {
                    Text(language)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                ScrollView(.horizontal) {
                    Text(verbatim: block.text)
                        .font(.system(.callout, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Theme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Code block")
        case .divider:
            Divider().overlay(Theme.textSecondary.opacity(0.5))
        case .image(let path):
            MarkdownImageBlockView(path: path, alt: block.text, assets: assets)
        case .linkCard(let url, let thumbnail):
            MarkdownLinkCardView(title: block.text, url: url, thumbnail: thumbnail, assets: assets)
        }
    }

    private func listRow(marker: String, block: MarkdownBlock) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(marker)
                .font(TimeMasterFont.body(17))
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 22, alignment: .trailing)
                .accessibilityHidden(marker == "\u{2022}")
            Text(MediaCommentInlineMarkdown.render(block.text))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, CGFloat(block.indent) * 22)
    }
}
