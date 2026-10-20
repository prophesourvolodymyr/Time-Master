import PhotosUI
import SwiftUI

struct LocalPostComposerView: View {
    var postID: UUID? = nil

    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var imageFilename: String?
    @State private var audience: LocalPostAudience = .profile
    @State private var allowsReplies = true
    @State private var originalBody = ""
    @State private var originalImageFilename: String?
    @State private var originalAudience: LocalPostAudience = .profile
    @State private var originalAllowsReplies = true
    @State private var ownedPhotoFilename: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var importTask: Task<Void, Never>?
    @State private var isImporting = false
    @State private var didLoad = false
    @State private var confirmsDiscard = false
    @State private var errorMessage: String?

    private var isUnavailable: Bool {
        if let postID { return !profileStore.snapshot.posts.contains(where: { $0.id == postID }) }
        return false
    }

    private var hasChanges: Bool {
        didLoad && (bodyText != originalBody || imageFilename != originalImageFilename || audience != originalAudience || allowsReplies != originalAllowsReplies || isImporting)
    }

    private var canSave: Bool {
        didLoad && !isUnavailable && !profileStore.isReadOnly && !isImporting &&
        (!bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageFilename != nil) &&
        (postID == nil || hasChanges)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isUnavailable {
                    ProfileEmptyState(symbol: "text.bubble", title: "Post unavailable", detail: "This post was deleted. Your changes have not been published.")
                        .padding(ProfileStyle.inset)
                } else {
                    Form {
                        SwiftUI.Section {
                            HStack(spacing: ProfileStyle.spacing) {
                                ProfileAvatar(profile: profileStore.profile)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                                    Text("Local post · no upload")
                                        .font(TimeMasterFont.caption())
                                        .foregroundStyle(ProfileStyle.secondary)
                                }
                            }
                            TextField("What do you want to share?", text: $bodyText, axis: .vertical)
                                .lineLimit(5...12)
                                .font(TimeMasterFont.body())
                                .accessibilityLabel("Post text")
                        }
                        SwiftUI.Section {
                            if let imageFilename {
                                if let image = PhotoManager.shared.loadPhoto(filename: imageFilename) {
                                    platformImage(image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: 260)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .accessibilityLabel("Attached photo")
                                } else {
                                    Label("Photo unavailable", systemImage: "photo")
                                        .font(TimeMasterFont.secondary())
                                }
                            }
                            if isImporting {
                                HStack(spacing: ProfileStyle.spacing) {
                                    TmaxLoadingIndicator()
                                    Text("Importing photo…").font(TimeMasterFont.secondary())
                                }
                                .accessibilityElement(children: .combine)
                            }
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label(imageFilename == nil ? "Add photo" : "Replace photo", systemImage: "photo.on.rectangle")
                                    .font(TimeMasterFont.rowTitle())
                                    .frame(minHeight: ProfileStyle.touchTarget)
                            }
                            .disabled(isImporting || profileStore.isReadOnly)
                            if imageFilename != nil || isImporting {
                                Button(role: .destructive, action: removePhoto) {
                                    Label(isImporting ? "Cancel photo import" : "Remove photo", systemImage: "trash")
                                        .frame(minHeight: ProfileStyle.touchTarget)
                                }
                            }
                        } header: {
                            Text("Photo")
                        } footer: {
                            Text("One optional photo, stored on this device. Removing a photo from a draft does not change the saved post.")
                        }
                        SwiftUI.Section {
                            Picker("Audience", selection: $audience) {
                                ForEach(LocalPostAudience.allCases) { value in
                                    Text(value.title).tag(value)
                                }
                            }
                            Toggle("Allow replies on this post", isOn: $allowsReplies)
                        } header: {
                            Text("Visibility & discussion")
                        } footer: {
                            Text(profileStore.profile.allowReplies
                                 ? "Profile follows your visitor privacy settings. Only me is never shown in visitor preview. Replies are local notes from you, not messages from other people."
                                 : "Replies are off in profile settings. This post's preference is saved, but new replies remain off until profile replies are enabled. Profile visibility also follows your privacy settings; Only me is always hidden from visitors.")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .disabled(profileStore.isReadOnly)
                }
            }
            .background(Theme.background)
            .navigationTitle(postID == nil ? "New post" : "Edit post")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(postID == nil ? "Post" : "Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
#endif
        .interactiveDismissDisabled(hasChanges)
        .onAppear(perform: loadInitialPost)
        .onChange(of: photoItem, perform: importPhoto)
        .onDisappear(perform: cleanUpDraft)
        .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive, action: discard)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your text and any new photo in this draft will not be saved.")
        }
        .profileErrorAlert($errorMessage)
    }

    private func loadInitialPost() {
        guard !didLoad else { return }
        if let postID, let post = profileStore.snapshot.posts.first(where: { $0.id == postID }) {
            bodyText = post.body
            imageFilename = post.imageFilename
            audience = post.audience
            allowsReplies = post.allowsReplies
        } else if postID == nil {
            allowsReplies = profileStore.profile.allowReplies
        }
        originalBody = bodyText
        originalImageFilename = imageFilename
        originalAudience = audience
        originalAllowsReplies = allowsReplies
        didLoad = true
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        importTask?.cancel()
        isImporting = true
        importTask = Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw LocalPostPhotoError.unreadable
                }
                try Task.checkCancellation()
                guard let image = PhotoPlatformImage(data: data) else { throw LocalPostPhotoError.unreadable }
                guard let filename = PhotoManager.shared.savePhoto(image) else { throw LocalPostPhotoError.cannotSave }
                guard PhotoManager.shared.loadPhoto(filename: filename) != nil else {
                    removeUnreferencedLocalPostPhoto(filename, snapshot: profileStore.snapshot)
                    throw LocalPostPhotoError.unreadable
                }
                removeUnreferencedLocalPostPhoto(ownedPhotoFilename, snapshot: profileStore.snapshot)
                ownedPhotoFilename = filename
                imageFilename = filename
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
            if !Task.isCancelled {
                isImporting = false
                photoItem = nil
                importTask = nil
            }
        }
    }

    private func removePhoto() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
        photoItem = nil
        removeUnreferencedLocalPostPhoto(ownedPhotoFilename, snapshot: profileStore.snapshot)
        ownedPhotoFilename = nil
        imageFilename = nil
    }

    private func cancel() {
        if hasChanges { confirmsDiscard = true }
        else { discard() }
    }

    private func discard() {
        cleanUpDraft()
        dismiss()
    }

    private func cleanUpDraft() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
        removeUnreferencedLocalPostPhoto(ownedPhotoFilename, snapshot: profileStore.snapshot)
        ownedPhotoFilename = nil
    }

    private func save() {
        guard canSave else { return }
        let previousFilename = postID.flatMap { id in
            profileStore.snapshot.posts.first(where: { $0.id == id })?.imageFilename
        }
        do {
            if let postID {
                try profileStore.updatePost(id: postID, body: bodyText, imageFilename: imageFilename, audience: audience, allowsReplies: allowsReplies)
            } else {
                try profileStore.publish(body: bodyText, imageFilename: imageFilename, audience: audience, allowsReplies: allowsReplies)
            }
            ownedPhotoFilename = nil
            removeUnreferencedLocalPostPhoto(previousFilename, snapshot: profileStore.snapshot)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private enum LocalPostPhotoError: LocalizedError {
    case unreadable
    case cannotSave

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This photo could not be read. Try another photo. Your draft has not changed."
        case .cannotSave: return "The photo could not be saved on this device. Your draft has not changed."
        }
    }
}
