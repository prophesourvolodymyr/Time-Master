import SwiftUI
import TimeMasterCore

/// Changes the icon of one entry: none, a symbol or an emoji, or one of the page's pictures.
struct ChecklistIconChooserSheet<Entry: ChecklistEntry>: View {
    let pageID: String
    let entryID: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore
    @State private var iconName = ""
    @State private var iconType: SkillBoardIconType = .emoji
    @State private var iconImage: String?
    @State private var loaded = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChecklistIconEditor(
                        iconName: $iconName, iconType: $iconType, iconImage: $iconImage,
                        pictures: (store.page(manifestID: pageID)?.mediaURLs ?? []).filter { ChecklistMedia.isPicture($0.lastPathComponent) }
                    )
                    if let errorMessage {
                        ChecklistErrorBanner(message: errorMessage) { self.errorMessage = nil }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
        .keyNavHost()
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 460)
        #endif
        .onAppear {
            guard !loaded, let entry = store.checklist(Entry.self, of: pageID).entry(entryID) else { return }
            loaded = true
            iconName = entry.iconName ?? ""
            iconType = entry.iconType ?? .emoji
            iconImage = entry.iconImage
        }
    }

    private func save() {
        do {
            try store.updateChecklistEntry(Entry.self, entryID, in: pageID) { entry in
                let name = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.iconImage = iconImage
                entry.iconName = name.isEmpty || iconImage != nil ? nil : name
                entry.iconType = entry.iconName == nil ? nil : iconType
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
