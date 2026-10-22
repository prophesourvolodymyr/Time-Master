import SwiftUI

struct LocalPostsView: View {
    let asVisitor: Bool
    var repostsOnly = false

    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var showsComposer = false

    private var posts: [LocalProfilePost] {
        profileStore.snapshot.visiblePosts(asVisitor: asVisitor, repostsOnly: repostsOnly)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if !asVisitor {
                Button { showsComposer = true } label: {
                    HStack(spacing: ProfileStyle.spacing) {
                        ProfileAvatar(profile: profileStore.profile, size: 36)
                        Text("Share something from your day")
                            .font(TimeMasterFont.secondary())
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(ProfileStyle.secondary)
                    .padding(ProfileStyle.inset)
                    .frame(minHeight: ProfileStyle.touchTarget)
                    .modifier(TimeMasterCardSurface(flat: true))
                }
                .buttonStyle(.plain)
                .disabled(profileStore.isReadOnly)
                .accessibilityLabel("Create a local post")
            }
            if posts.isEmpty {
                ProfileEmptyState(
                    symbol: repostsOnly ? "arrow.2.squarepath" : "text.bubble",
                    title: repostsOnly ? "No reposts yet" : "No posts to show",
                    detail: asVisitor
                        ? "Only posts allowed by this profile's privacy settings appear in this preview."
                        : repostsOnly
                            ? "Use Repost on one of your posts to collect it here. Reposts stay on this device."
                            : "Write a thought or add a photo. Your posts stay on this device; nothing is uploaded."
                )
            } else {
                ForEach(posts) { post in
                    LocalPostCard(postID: post.id, asVisitor: asVisitor)
                }
            }
            Text(asVisitor ? "Visitor preview · read-only · no network account" : "Local posts, replies and reactions · only on this device")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .sheet(isPresented: $showsComposer) {
            LocalPostComposerView()
        }
    }
}

func visibleLocalPost(id: UUID, in snapshot: LocalProfileSnapshot, asVisitor: Bool) -> LocalProfilePost? {
    guard let post = snapshot.posts.first(where: { $0.id == id }) else { return nil }
    guard asVisitor else { return post }
    guard !snapshot.profile.isPrivate, post.audience == .profile,
          snapshot.profile.showPostsToVisitors || (snapshot.profile.showRepostsToVisitors && snapshot.repostedIDs.contains(id)) else { return nil }
    return post
}

func removeUnreferencedLocalPostPhoto(_ filename: String?, snapshot: LocalProfileSnapshot) {
    guard let filename, !snapshot.mediaFilenames.contains(filename) else { return }
    PhotoManager.shared.deletePhoto(filename: filename)
}

private enum LocalPostSheet: Identifiable {
    case edit(UUID)
    case thread(UUID)
    case reactions(UUID)
    case image(UUID)

    var id: String {
        switch self {
        case .edit(let id): return "edit-\(id)"
        case .thread(let id): return "thread-\(id)"
        case .reactions(let id): return "reactions-\(id)"
        case .image(let id): return "image-\(id)"
        }
    }
}

struct LocalPostCard: View {
    let postID: UUID
    var asVisitor = false
    var showsThreadButton = true

    @EnvironmentObject private var profileStore: LocalProfileStore
    @State private var sheet: LocalPostSheet?
    @State private var confirmsDeletion = false
    @State private var errorMessage: String?

    private var post: LocalProfilePost? {
        visibleLocalPost(id: postID, in: profileStore.snapshot, asVisitor: asVisitor)
    }

    var body: some View {
        Group {
            if let post {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                        ProfileAvatar(profile: profileStore.profile)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                            Text("@\(profileStore.profile.handle)")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(ProfileStyle.secondary)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 6) {
                                    Text(post.createdAt, style: .date)
                                    if post.editedAt != nil { Text("· Edited") }
                                    if post.audience == .onlyMe { Label("Only me", systemImage: "lock") }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.createdAt, style: .date)
                                    if post.editedAt != nil { Text("Edited") }
                                    if post.audience == .onlyMe { Label("Only me", systemImage: "lock") }
                                }
                            }
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                        }
                        Spacer(minLength: 0)
                        if !asVisitor {
                            Menu {
                                Button { sheet = .edit(postID) } label: {
                                    Label("Edit post", systemImage: "pencil")
                                }
                                Button(role: .destructive) { confirmsDeletion = true } label: {
                                    Label("Delete post", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                                    .contentShape(Rectangle())
                            }
                            .disabled(profileStore.isReadOnly)
                            .accessibilityLabel("Post options")
                        }
                    }
                    if !post.body.isEmpty {
                        Text(post.body)
                            .font(TimeMasterFont.body())
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    if let filename = post.imageFilename {
                        if let image = PhotoManager.shared.loadPhoto(filename: filename) {
                            Button { sheet = .image(postID) } label: {
                                platformImage(image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 320)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open post photo")
                        } else {
                            Label("Photo unavailable on this device", systemImage: "photo")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                    }
                    if !post.reactions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(post.reactions.sorted(), id: \.self) { reaction in
                                    if asVisitor {
                                        Text("\(reaction) 1")
                                            .font(TimeMasterFont.secondary())
                                            .padding(.horizontal, 12)
                                            .frame(minHeight: ProfileStyle.touchTarget)
                                            .background(Theme.surface2, in: Capsule())
                                            .accessibilityLabel("\(reaction), one local reaction from the profile owner")
                                    } else {
                                        Button { toggleReaction(reaction) } label: {
                                            Text("\(reaction) 1")
                                                .font(TimeMasterFont.secondary())
                                        }
                                        .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                                        .disabled(profileStore.isReadOnly)
                                        .accessibilityLabel("Remove your local \(reaction) reaction")
                                    }
                                }
                            }
                        }
                        Text("Local reactions from this profile only")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { actions(post) }
                        VStack(alignment: .leading, spacing: 8) { actions(post) }
                    }
                    if !post.allowsReplies || !profileStore.profile.allowReplies {
                        Label("New replies are off", systemImage: "bubble.left.and.bubble.right")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(TimeMasterCardSurface(flat: true))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("local-post-\(postID.uuidString)")
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .edit(let id): LocalPostComposerView(postID: id)
            case .thread(let id): LocalPostThreadView(postID: id, asVisitor: asVisitor)
            case .reactions(let id): LocalPostReactionPicker(postID: id)
            case .image(let id): LocalPostImageViewer(postID: id, asVisitor: asVisitor)
            }
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete post", role: .destructive, action: deletePost)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The post and its local replies will be permanently removed from this device.")
        }
        .profileErrorAlert($errorMessage)
    }

    @ViewBuilder
    private func actions(_ post: LocalProfilePost) -> some View {
        if !asVisitor {
            Button { sheet = .reactions(postID) } label: {
                EverPillTabLabel(title: "React", symbol: "face.smiling", isSelected: false)
            }
            .buttonStyle(.plain)
            .disabled(profileStore.isReadOnly)
        }
        if showsThreadButton {
            Button { sheet = .thread(postID) } label: {
                EverPillTabLabel(title: "\(post.replies.count) \(post.replies.count == 1 ? "reply" : "replies")", symbol: "bubble.left", isSelected: false)
            }
            .buttonStyle(.plain)
        }
        if !asVisitor {
            Button(action: toggleRepost) {
                EverPillTabLabel(
                    title: profileStore.snapshot.repostedIDs.contains(postID) ? "Reposted" : "Repost",
                    symbol: "arrow.2.squarepath",
                    isSelected: profileStore.snapshot.repostedIDs.contains(postID)
                )
            }
            .buttonStyle(.plain)
            .disabled(profileStore.isReadOnly)
            .accessibilityHint("Adds or removes this post in your local Reposted feed")
        }
    }

    private func toggleReaction(_ reaction: String) {
        do { try profileStore.toggleReaction(postID: postID, reaction: reaction) }
        catch { errorMessage = error.localizedDescription }
    }

    private func toggleRepost() {
        do { try profileStore.toggleRepost(postID: postID) }
        catch { errorMessage = error.localizedDescription }
    }

    private func deletePost() {
        let filename = post?.imageFilename
        do {
            try profileStore.deletePost(id: postID)
            removeUnreferencedLocalPostPhoto(filename, snapshot: profileStore.snapshot)
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct LocalPostReactionPicker: View {
    let postID: UUID

    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    private let reactions = ["❤️", "👏", "🔥", "💪", "🎉", "😊"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let post = profileStore.snapshot.posts.first(where: { $0.id == postID }) {
                        Text("Choose a reaction").font(TimeMasterFont.heading())
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                            ForEach(reactions, id: \.self) { reaction in
                                Button { toggle(reaction) } label: {
                                    Text(reaction)
                                        .font(TimeMasterFont.body(30, relativeTo: .title))
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                        .background(post.reactions.contains(reaction) ? Color.white.opacity(0.2) : Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .disabled(profileStore.isReadOnly)
                                .accessibilityLabel("\(post.reactions.contains(reaction) ? "Remove" : "Add") your \(reaction) reaction")
                                .accessibilityAddTraits(post.reactions.contains(reaction) ? .isSelected : [])
                            }
                        }
                        Text("These are your local reactions, not reactions from other people. Each selected emoji counts once. Tap a selected emoji to remove it.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                    } else {
                        ProfileEmptyState(symbol: "text.bubble", title: "Post unavailable", detail: "This post may have been deleted.")
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .timeMasterNavigationTitle("React")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .profileErrorAlert($errorMessage)
    }

    private func toggle(_ reaction: String) {
        do {
            try profileStore.toggleReaction(postID: postID, reaction: reaction)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct LocalPostImageViewer: View {
    let postID: UUID
    let asVisitor: Bool

    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var initialZoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if let post = visibleLocalPost(id: postID, in: profileStore.snapshot, asVisitor: asVisitor),
                   let filename = post.imageFilename,
                   let image = PhotoManager.shared.loadPhoto(filename: filename) {
                    ScrollView([.horizontal, .vertical]) {
                        platformImage(image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * zoom, height: geometry.size.height * zoom)
                            .accessibilityLabel("Post photo")
                            .gesture(MagnificationGesture()
                                .onChanged { zoom = min(4, max(1, initialZoom * $0)) }
                                .onEnded { _ in initialZoom = zoom })
                            .onTapGesture(count: 2) {
                                zoom = zoom == 1 ? 2 : 1
                                initialZoom = zoom
                            }
                    }
                } else {
                    ProfileEmptyState(symbol: "photo", title: "Photo unavailable", detail: "This photo is no longer available in this preview.")
                        .padding(ProfileStyle.inset)
                }
            }
            .background(Theme.background)
            .timeMasterNavigationTitle("Photo")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        zoom = max(1, zoom - 0.5)
                        initialZoom = zoom
                    } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    .disabled(zoom <= 1)
                    Button {
                        zoom = min(4, zoom + 0.5)
                        initialZoom = zoom
                    } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                    .disabled(zoom >= 4)
                }
            }
        }
    }
}
