import SwiftUI

struct MediaCommentEditor: View {
    let mediaURL: URL
    let originalComment: String
    let onSave: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var showDiscardConfirmation = false
    @State private var showSaveError = false
    @State private var saveError = ""
    @ScaledMetric(relativeTo: .body) private var thumbnailHeight: CGFloat = 150

    init(mediaURL: URL, comment: String, onSave: @escaping (String) throws -> Void) {
        self.mediaURL = mediaURL
        originalComment = comment
        self.onSave = onSave
        _draft = State(initialValue: comment)
    }

    private var hasChanges: Bool { draft != originalComment }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncCoverImage(
                        url: mediaURL,
                        fallbackIcon: "photo.on.rectangle",
                        height: thumbnailHeight,
                        contentMode: .fit,
                        overlayGradient: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    MediaCommentComposer(text: $draft)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Media comment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!hasChanges)
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
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 740, minHeight: 480, idealHeight: 680)
        #endif
    }

    private func cancel() {
        if hasChanges { showDiscardConfirmation = true } else { dismiss() }
    }

    private func save() {
        do {
            try onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : draft)
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
        }
    }
}
