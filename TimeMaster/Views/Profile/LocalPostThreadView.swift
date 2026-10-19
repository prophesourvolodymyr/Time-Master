import SwiftUI

struct LocalPostThreadView: View {
    let postID: UUID
    var asVisitor = false
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var reply = ""
    @State private var errorMessage: String?
    @State private var confirmsDiscard = false
    @State private var deletingReply: UUID?

    private var post: LocalProfilePost? {
        visibleLocalPost(id: postID, in: profileStore.snapshot, asVisitor: asVisitor)
    }
    private var canReply: Bool {
        !asVisitor && !profileStore.isReadOnly && profileStore.profile.allowReplies && post?.allowsReplies == true
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ProfileStyle.inset) {
                        if let post {
                            LocalPostCard(postID: postID, asVisitor: asVisitor, showsThreadButton: false)
                            Text("Replies").font(TimeMasterFont.heading())
                            if post.replies.isEmpty {
                                ProfileEmptyState(symbol: "bubble.left.and.bubble.right", title: "No replies yet", detail: asVisitor ? "There are no local replies to show." : "Add a local reply to keep the conversation with this post. Nothing is sent online.")
                            }
                            ForEach(post.replies.sorted { $0.createdAt < $1.createdAt }) { item in
                                replyRow(item).id(item.id)
                            }
                            if canReply {
                                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                                    TextField("Write a local reply", text: $reply, axis: .vertical)
                                        .lineLimit(2...8).textFieldStyle(.plain)
                                        .accessibilityLabel("Reply text")
                                    Button("Add reply") {
                                        do {
                                            try profileStore.addReply(postID: postID, body: reply)
                                            reply = ""
                                            if let last = self.post?.replies.last { reader.scrollTo(last.id, anchor: .bottom) }
                                        } catch { errorMessage = error.localizedDescription }
                                    }
                                    .buttonStyle(EverPrimaryButtonStyle())
                                    .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    Text("Replies are saved under your own local profile, not posted as another person.")
                                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                }
                                .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                            } else {
                                Text(asVisitor ? "Visitor preview is read-only." : "New replies are off. Existing replies remain visible; your unsent text is kept until you close this discussion.")
                                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                            }
                        } else {
                            ProfileEmptyState(symbol: "text.bubble", title: "Post unavailable", detail: "The post was deleted or is no longer visible in this preview.")
                        }
                    }
                    .font(TimeMasterFont.body()).foregroundStyle(.white)
                    .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
                    .padding(ProfileStyle.inset)
                }
                .background(Theme.background.ignoresSafeArea())
            }
            .navigationTitle("Discussion")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if !reply.isEmpty { confirmsDiscard = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!reply.isEmpty)
            .confirmationDialog("Discard unsent reply?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard reply", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Delete this local reply?", isPresented: Binding(
                get: { deletingReply != nil }, set: { if !$0 { deletingReply = nil } }
            ), titleVisibility: .visible) {
                Button("Delete reply", role: .destructive) {
                    guard let id = deletingReply else { return }
                    do { try profileStore.deleteReply(postID: postID, replyID: id) }
                    catch { errorMessage = error.localizedDescription }
                    deletingReply = nil
                }
                Button("Cancel", role: .cancel) { deletingReply = nil }
            }
            .profileErrorAlert($errorMessage)
        }
        .tint(.white)
    }

    private func replyRow(_ item: LocalPostReply) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            ProfileAvatar(profile: profileStore.profile)
            VStack(alignment: .leading, spacing: 8) {
                Text(profileStore.profile.displayName).font(TimeMasterFont.rowTitle())
                Text(item.createdAt, style: .date).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                Text(item.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !asVisitor {
                Button(role: .destructive) { deletingReply = item.id } label: {
                    Image(systemName: "trash").frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                }
                .buttonStyle(.plain).disabled(profileStore.isReadOnly).accessibilityLabel("Delete your reply")
            }
        }
        .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
    }
}
