import SwiftUI

struct MarkdownEditorSheet: View {
    let title: String
    @Binding var text: String
    var assets: MarkdownAssets? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MarkdownEditorView(text: $text, assets: assets, autofocus: text.isEmpty)
                .background(Theme.background.ignoresSafeArea())
                .timeMasterNavigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    AppToolbar.item(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .buttonStyle(TimeMasterToolbarTextButtonStyle())
                            .tint(Theme.toolbarOrange)
                    }
                }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 760, minHeight: 520, idealHeight: 700)
        #endif
    }
}

struct MarkdownEditorField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var assets: MarkdownAssets? = nil
    var minHeight: CGFloat = 120
    @State private var presenting = false

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button {
            presenting = true
        } label: {
            Group {
                if isEmpty {
                    Text(placeholder)
                        .font(TimeMasterFont.body(17))
                        .foregroundStyle(Theme.textSecondary.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MarkdownDocumentView(markdown: text, assets: assets)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(14)
            .padding(.trailing, 22)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .padding(12)
                    .accessibilityHidden(true)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isEmpty ? "Empty" : text)
        .accessibilityHint("Opens the full-screen editor")
        .sheet(isPresented: $presenting) {
            MarkdownEditorSheet(title: title, text: $text, assets: assets)
        }
    }
}
