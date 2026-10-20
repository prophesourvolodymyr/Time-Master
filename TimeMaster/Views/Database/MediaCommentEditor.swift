import SwiftUI

struct MediaCommentEditor: View {
    let mediaURL: URL
    let originalComment: String
    let onSave: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var linkText = ""
    @State private var linkAddress = ""
    @State private var showLinkEditor = false
    @State private var showDiscardConfirmation = false
    @State private var showSaveError = false
    @State private var saveError = ""
    @FocusState private var composerFocused: Bool
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    init(mediaURL: URL, comment: String, onSave: @escaping (String) throws -> Void) {
        self.mediaURL = mediaURL
        originalComment = comment
        self.onSave = onSave
        _draft = State(initialValue: comment)
    }

    private var hasChanges: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
            != originalComment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var insertedURL: URL? {
        guard let url = URL(string: linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncCoverImage(
                        url: mediaURL,
                        fallbackIcon: "photo.on.rectangle",
                        height: controlSize * 4,
                        contentMode: .fit,
                        overlayGradient: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: controlSize * 0.4, style: .continuous))
                    if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        MediaCommentBubble(text: draft)
                    }
                    Text("Supports **bold**, *italic*, ~~strikethrough~~, `code`, and links. Line breaks are preserved.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .navigationTitle("Media comment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Discard unsaved comment changes?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert("Could not save comment", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError)
            }
            .onAppear { composerFocused = true }
        }
        .preferredColorScheme(.dark)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                linkText = ""
                linkAddress = ""
                showLinkEditor = true
            } label: {
                Image(systemName: "link")
                    .frame(width: controlSize, height: controlSize)
            }
            .accessibilityLabel("Insert comment link")
            .alert("Insert link", isPresented: $showLinkEditor) {
                TextField("Link text (optional)", text: $linkText)
                TextField("https://example.com", text: $linkAddress)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                Button("Insert", action: insertLink).disabled(insertedURL == nil)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use a web link beginning with http:// or https://.")
            }
            Text(draft.isEmpty || draft.hasSuffix("\n") ? draft + " " : draft)
                .font(.body)
                .lineLimit(1...6)
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: controlSize, alignment: .leading)
                .hidden()
                .overlay {
                    TextEditor(text: $draft)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($composerFocused)
                        .accessibilityLabel("Media comment")
                }
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Add a comment…")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            Button(action: save) {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, circular: true, minimumSize: controlSize))
            .accessibilityLabel(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Remove media comment" : "Save media comment")
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!hasChanges)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .padding(6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: controlSize * 0.6, style: .continuous))
        .padding(12)
        .background(Theme.background)
    }

    private func cancel() {
        if hasChanges { showDiscardConfirmation = true } else { dismiss() }
    }

    private func insertLink() {
        guard let url = insertedURL else { return }
        let label = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedLabel = (label.isEmpty ? url.absoluteString : label)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let separator = draft.isEmpty || draft.last?.isWhitespace == true ? "" : " "
        draft += "\(separator)[\(escapedLabel)](<\(url.absoluteString)>)"
        composerFocused = true
    }

    private func save() {
        do {
            try onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}
