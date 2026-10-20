import SwiftUI
import PhotosUI

struct LocalProfileEditorView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LocalUserProfile()
    @State private var original = LocalUserProfile()
    @State private var hasLoaded = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var imageTask: Task<Void, Never>?
    @State private var isImporting = false
    @State private var temporaryFilenames: Set<String> = []
    @State private var errorMessage: String?
    @State private var showsDiscard = false
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 80

    private var hasChanges: Bool { hasLoaded && draft != original }

    var body: some View {
        NavigationStack {
            EverSettingsPage(title: "Edit profile") {
                EverSettingsSection(title: "Identity", detail: "Saved only on this device. Your handle is not reserved online.") {
                    VStack(spacing: ProfileStyle.inset) {
                        ProfileAvatar(profile: draft, size: avatarSize)
                        HStack {
                            photoPicker("Avatar", selection: $avatarItem)
                            if draft.avatarFilename != nil {
                                Button(role: .destructive) { draft.avatarFilename = nil } label: {
                                    Text("Remove avatar")
                                        .frame(minHeight: ProfileStyle.touchTarget)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                        if let filename = draft.bannerFilename, let image = PhotoManager.shared.loadPhoto(filename: filename) {
                            platformImage(image).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).aspectRatio(2.6, contentMode: .fit).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: ProfileStyle.corner))
                        }
                        HStack {
                            photoPicker("Banner", selection: $bannerItem)
                            if draft.bannerFilename != nil {
                                Button(role: .destructive) { draft.bannerFilename = nil } label: {
                                    Text("Remove banner")
                                        .frame(minHeight: ProfileStyle.touchTarget)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                        if isImporting { TmaxLoadingIndicator("Importing photo…") }
                        field("Display name", text: $draft.displayName)
                        field("Handle", text: $draft.handle)
                        field("Location", text: $draft.location)
                    }
                    .padding(ProfileStyle.inset)
                }
                EverSettingsSection(title: "Biography", detail: "Your profile shows the first eight characters. Tap to read the full description.") {
                    TextEditor(text: $draft.biography)
                        .font(TimeMasterFont.body()).scrollContentBackground(.hidden)
                        .frame(minHeight: avatarSize * 1.5)
                        .padding(ProfileStyle.spacing)
                        .accessibilityLabel("Biography")
                }
                EverSettingsSection(title: "Social links", detail: "Up to three links. Include https:// in each address.") {
                    VStack(spacing: ProfileStyle.inset) {
                        ForEach($draft.links) { $link in
                            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                                HStack {
                                    Picker("Platform", selection: $link.title) {
                                        ForEach(["Website", "YouTube", "Instagram", "TikTok", "X"], id: \.self) { Text($0).tag($0) }
                                    }
                                    Spacer()
                                    Button(role: .destructive) { draft.links.removeAll { $0.id == link.id } } label: {
                                        Image(systemName: "minus.circle").frame(minWidth: ProfileStyle.touchTarget, minHeight: ProfileStyle.touchTarget)
                                    }
                                    .accessibilityLabel("Remove \(link.title) link")
                                }
                                urlField(text: $link.url)
                            }
                        }
                        if draft.links.count < 3 {
                            Button { draft.links.append(LocalSocialLink()) } label: {
                                Label("Add link", systemImage: "plus")
                                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                            }
                            .buttonStyle(TimeMasterInsetControlStyle())
                            .accessibilityIdentifier("profile-add-link")
                        }
                    }
                    .padding(ProfileStyle.inset)
                }
            }
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showsDiscard = true } else { cancel() }
                    }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isImporting || !hasLoaded || profileStore.isReadOnly)
                        .accessibilityIdentifier("profile-edit-save")
                }
            }
            .interactiveDismissDisabled(hasChanges || isImporting)
            .confirmationDialog("Discard profile changes?", isPresented: $showsDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive, action: cancel)
                Button("Keep editing", role: .cancel) {}
            }
            .profileErrorAlert($errorMessage)
            .onAppear {
                guard !hasLoaded else { return }
                draft = profileStore.profile
                original = draft
                hasLoaded = true
            }
            .onChange(of: avatarItem) { item in importPhoto(item, isAvatar: true) }
            .onChange(of: bannerItem) { item in importPhoto(item, isAvatar: false) }
            .onDisappear {
                imageTask?.cancel()
                cleanTemporaryPhotos()
            }
        }
        .tint(.white)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            TextField(title, text: text).textFieldStyle(.plain)
                .font(TimeMasterFont.body()).padding(ProfileStyle.spacing)
                .autocorrectionDisabled(title == "Handle")
#if os(iOS)
                .textInputAutocapitalization(title == "Handle" ? .never : .sentences)
#endif
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: ProfileStyle.spacing))
                .accessibilityIdentifier("profile-field-\(title.lowercased())")
        }
    }

    private func urlField(text: Binding<String>) -> some View {
        TextField("https://example.com", text: text)
            .textFieldStyle(.plain).font(TimeMasterFont.body())
            .autocorrectionDisabled()
#if os(iOS)
            .textInputAutocapitalization(.never).keyboardType(.URL)
#endif
            .padding(ProfileStyle.spacing)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: ProfileStyle.spacing))
            .accessibilityLabel("Link address")
    }

    private func photoPicker(_ title: String, selection: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
            Label(title, systemImage: "photo").frame(minHeight: ProfileStyle.touchTarget)
        }
        .font(TimeMasterFont.rowTitle()).disabled(isImporting)
    }

    private func importPhoto(_ item: PhotosPickerItem?, isAvatar: Bool) {
        guard let item else { return }
        imageTask?.cancel()
        isImporting = true
        imageTask = Task { @MainActor in
            defer {
                isImporting = false
                if isAvatar { avatarItem = nil } else { bannerItem = nil }
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                guard let image = PhotoPlatformImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                guard let filename = PhotoManager.shared.savePhoto(image) else { throw CocoaError(.fileWriteUnknown) }
                temporaryFilenames.insert(filename)
                if isAvatar { draft.avatarFilename = filename } else { draft.bannerFilename = filename }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { errorMessage = "The photo could not be imported. \(error.localizedDescription)" }
            }
        }
    }

    private func save() {
        do {
            try profileStore.updateProfile(draft)
            cleanTemporaryPhotos()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancel() {
        imageTask?.cancel()
        cleanTemporaryPhotos()
        dismiss()
    }

    private func cleanTemporaryPhotos() {
        let retained = Set(profileStore.snapshot.mediaFilenames)
        for filename in temporaryFilenames where !retained.contains(filename) {
            PhotoManager.shared.deletePhoto(filename: filename)
        }
        temporaryFilenames.removeAll()
    }
}
