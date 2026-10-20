import SwiftUI

struct LocalProfileReportView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Spam"
    @State private var details = ""
    @State private var saved = false
    @State private var errorMessage: String?
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            EverSettingsPage(title: "Report profile") {
                if saved {
                    ProfileEmptyState(symbol: "doc.text", title: "Report draft saved locally", detail: "Nothing was sent. TimeMaster has no social moderation service connected. You can share the report text yourself.")
                    ShareLink(item: reportText) {
                        Label("Share report text", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(EverPrimaryButtonStyle())
                } else {
                    EverSettingsSection(title: "Local draft", detail: "This does not submit a report, notify anyone, or restrict an account.") {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("@\(profileStore.profile.handle)").font(TimeMasterFont.rowTitle())
                            Picker("Reason", selection: $reason) {
                                ForEach(["Spam", "Abuse", "Impersonation", "Something else"], id: \.self) { Text($0).tag($0) }
                            }
                            TextField("Optional details", text: $details, axis: .vertical)
                                .lineLimit(4...12).textFieldStyle(.plain).accessibilityLabel("Report details")
                        }
                        .padding(ProfileStyle.inset)
                    }
                    Button("Save draft on this device") {
                        do {
                            try profileStore.saveReportDraft(reason: reason, details: details)
                            saved = true
                        } catch { errorMessage = error.localizedDescription }
                    }
                    .buttonStyle(EverPrimaryButtonStyle()).disabled(profileStore.isReadOnly)
                }
            }
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button(saved ? "Done" : "Cancel") {
                        if !saved && !details.isEmpty { confirmsDiscard = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!saved && !details.isEmpty)
            .confirmationDialog("Discard report draft?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .profileErrorAlert($errorMessage)
        }
        .tint(.white)
    }

    private var reportText: String {
        "TimeMaster profile report draft\n@\(profileStore.profile.handle)\nReason: \(reason)\n\(details)\nSaved locally; not submitted to a moderation service."
    }
}
