import SwiftUI

struct MediaCommentComposer: View {
    @Binding var text: String
    var minimumEditorHeight: CGFloat = 200
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var focusRequest = UUID()
    @State private var showLinkEditor = false
    @State private var linkText = ""
    @State private var linkAddress = ""
    @State private var linkSelection = NSRange(location: 0, length: 0)
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17

    private var insertedURL: URL? {
        guard let url = URL(string: linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            formattingBar
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    sourceEditor.frame(minWidth: 250)
                    preview.frame(minWidth: 250)
                }
                VStack(alignment: .leading, spacing: 12) {
                    sourceEditor
                    preview
                }
            }
        }
        .alert("Insert link", isPresented: $showLinkEditor) {
            TextField("Link text", text: $linkText)
            TextField("https://example.com", text: $linkAddress)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
            Button("Insert", action: insertLink).disabled(insertedURL == nil)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Markdown", systemImage: "text.alignleft")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            MediaCommentTextView(text: $text, selection: $selection, focusRequest: focusRequest, fontSize: fontSize)
                .frame(height: max(minimumEditorHeight, fontSize * 10))
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Add a comment…")
                            .font(TimeMasterFont.body(17))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Live preview", systemImage: "eye")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface2)
                    .frame(height: 56)
                    .accessibilityLabel("Comment preview is empty")
            } else {
                MediaCommentBubble(text: text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                formatButton("Bold", symbol: "bold") { wrap("**", placeholder: "bold") }
                formatButton("Italic", symbol: "italic") { wrap("*", placeholder: "italic") }
                formatButton("Strikethrough", symbol: "strikethrough") { wrap("~~", placeholder: "text") }
                Menu {
                    ForEach(1...6, id: \.self) { level in
                        Button("Heading \(level)") { prefixLines(String(repeating: "#", count: level) + " ") }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 44, height: 44)
                }
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif
                .accessibilityLabel("Insert heading")
                .help("Heading")
                formatButton("Bulleted list", symbol: "list.bullet") { prefixLines("- ") }
                formatButton("Numbered list", symbol: "list.number") { prefixLines("1. ") }
                formatButton("Task list", symbol: "checklist") { prefixLines("- [ ] ") }
                formatButton("Quote", symbol: "text.quote") { prefixLines("> ") }
                formatButton("Inline code", symbol: "chevron.left.forwardslash.chevron.right") { wrap("`", placeholder: "code") }
                formatButton("Code block", symbol: "curlybraces.square") { wrap("```\n", suffix: "\n```", placeholder: "code") }
                formatButton("Insert link", symbol: "link") {
                    linkSelection = MediaCommentFormatting.clamped(selection, in: text)
                    linkText = (text as NSString).substring(with: linkSelection)
                    linkAddress = ""
                    showLinkEditor = true
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
        }
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
        .help(label)
    }

    private func wrap(_ prefix: String, suffix: String? = nil, placeholder: String) {
        MediaCommentFormatting.wrap(&text, selection: &selection, prefix: prefix, suffix: suffix ?? prefix, placeholder: placeholder)
        focusRequest = UUID()
    }

    private func prefixLines(_ prefix: String) {
        MediaCommentFormatting.prefixLines(&text, selection: &selection, prefix: prefix)
        focusRequest = UUID()
    }

    private func insertLink() {
        guard let url = insertedURL else { return }
        selection = linkSelection
        MediaCommentFormatting.insertLink(&text, selection: &selection, label: linkText, url: url)
        focusRequest = UUID()
    }
}
