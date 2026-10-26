import SwiftUI
import UniformTypeIdentifiers
import TimeMasterCore

// MARK: - AICoachView

struct AICoachView: View {
    @StateObject private var store      = AIStore.shared
    @State private var inputText        = ""
    @State private var replyingTo: ChatMessage?                         = nil
    @State private var pendingAttachName: String?                       = nil
    @State private var pendingAttachContent: String?                    = nil
    @State private var showingSettings  = false
    @State private var showingSessions  = false
    @State private var showingFilePicker = false
    @FocusState private var inputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Theme.background.ignoresSafeArea()
                    VStack(spacing: 0) {
                        coachContextHeader
                        ChatMessageList(
                            store: store,
                            onReply: { replyingTo = $0 },
                            onSelectPrompt: {
                                inputText = $0
                                inputFocused = true
                            }
                        )
                        if let approval = store.pendingApproval {
                            ApprovalCardView(approval: approval, store: store)
                                .frame(maxHeight: geometry.size.height * 0.45)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .transition(.opacity)
                        }
                        ChatInputBar(
                            text: $inputText,
                            replyingTo: $replyingTo,
                            pendingAttachName: $pendingAttachName,
                            isFocused: $inputFocused,
                            isLoading: store.isLoading,
                            isApprovalPending: store.pendingApproval != nil,
                            onSend: sendMessage,
                            onAttach: { showingFilePicker = true }
                        )
                    }
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity)
                }
            }
            .timeMasterNavigationTitle(store.currentSession.title.isEmpty ? "AI Coach" : store.currentSession.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar { chatToolbar }
            .oneHandedActions(id: "ai-coach", actions: [
                ReachabilityAction("sessions", title: "Conversations") {
                    sessionsButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
                },
                ReachabilityAction("new-session", title: "New Chat") {
                    newSessionButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
                },
                ReachabilityAction("settings", title: "AI Settings") {
                    settingsButton.buttonStyle(TimeMasterToolbarIconButtonStyle())
                }
            ])
            .sheet(isPresented: $showingSettings) { AISettingsView() }
            .sheet(isPresented: $showingSessions) {
                SessionsListSheet(store: store, isPresented: $showingSessions)
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.text, .pdf, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: store.pendingApproval != nil) { pending in
                if pending { inputFocused = false }
            }
            .onReceive(store.$pendingDraft) { draft in
                guard let draft, !draft.isEmpty else { return }
                inputText = draft
                store.pendingDraft = nil
                inputFocused = true
            }
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82),
                       value: store.pendingApproval != nil)
        }
        .font(TimeMasterFont.body())
    }

    private var coachContextHeader: some View {
        HStack(spacing: 12) {
            Label(store.activeProvider.name, systemImage: "brain.head.profile")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            Text(store.model)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        AppToolbar.iconItem(placement: .primaryAction) {
            sessionsButton.oneHandedActionSource()
        }
        AppToolbar.iconGroup(placement: .primaryAction) {
            newSessionButton.oneHandedActionSource()
            settingsButton.oneHandedActionSource()
        }
    }

    private var sessionsButton: some View {
        Button { showingSessions = true } label: {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundColor(.white)
        }
        .accessibilityLabel("Conversations")
    }

    private var newSessionButton: some View {
        Button { store.newSession() } label: {
            Image(systemName: "square.and.pencil")
                .foregroundColor(.white)
        }
        .accessibilityLabel("New Chat")
    }

    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "gearshape.fill")
                .foregroundColor(Color.white.opacity(0.7))
        }
        .accessibilityLabel("AI Settings")
    }

    private func sendMessage() {
        let text    = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingAttachName != nil else { return }
        let reply   = replyingTo
        let attName = pendingAttachName
        let attBody = attName == nil ? nil : pendingAttachContent
        inputText          = ""
        replyingTo         = nil
        pendingAttachName  = nil
        pendingAttachContent = nil
        Task {
            await store.sendMessage(
                text,
                replyTo:           reply,
                attachmentName:    attName,
                attachmentContent: attBody
            )
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            pendingAttachName    = url.lastPathComponent
            pendingAttachContent = text
        } else if let data = try? Data(contentsOf: url) {
            pendingAttachName    = url.lastPathComponent
            pendingAttachContent = "[Binary file – \(data.count) bytes, cannot display as text]"
        }
    }
}

// MARK: - ChatMessageList

private struct ChatMessageList: View {
    @ObservedObject var store: AIStore
    let onReply: (ChatMessage) -> Void
    let onSelectPrompt: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visible: [ChatMessage] {
        store.currentMessages.filter { $0.role != .system }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if visible.isEmpty {
                        EmptyCoachState(onSelectPrompt: onSelectPrompt)
                            .padding(.vertical, 20)
                    }
                    ForEach(visible) { msg in
                        MessageBubble(
                            message: msg,
                            loadingTitle: store.pendingApproval != nil ? "Waiting for your approval" : store.isExecutingTools ? "Running requested tools…" : "Waiting for response…",
                            isWaitingForApproval: store.pendingApproval != nil,
                            onReply: onReply
                        )
                            .id(msg.id)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: visible.count) { _ in scrollToBottom(proxy) }
            .onChange(of: store.currentSessionID) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { scrollToBottom(proxy) }
            }
            .onAppear { scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = visible.last else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - EmptyCoachState

private struct EmptyCoachState: View {
    let onSelectPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 52, height: 52)
                    .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
                    .accessibilityHidden(true)
                Text("How can I help?")
                    .font(TimeMasterFont.black(22, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                Text("Plan your week, work on technique, or talk through recovery. Attach a file when you need more context.")
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                prompt("Plan my week", symbol: "calendar")
                prompt("Improve my squat form", symbol: "figure.strengthtraining.traditional")
                prompt("Help me recover", symbol: "heart")
            }
        }
        .padding(20)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private func prompt(_ title: String, symbol: String) -> some View {
        Button { onSelectPrompt(title) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 24)
                    .foregroundStyle(Theme.toolbarOrange)
                Text(title)
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityHint("Adds this prompt to your message")
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: ChatMessage
    let loadingTitle: String
    let isWaitingForApproval: Bool
    let onReply: (ChatMessage) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 52) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                bubbleContent
                timestampLabel
            }
            .contextMenu { contextMenuItems }

            if !isUser { Spacer(minLength: 52) }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reply quote
            if let replyContent = message.replyToContent {
                ReplyQuoteView(
                    content:  replyContent,
                    isAuthor: message.replyToRole == .user,
                    isUser:   isUser
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            // Attachment badge
            if let attName = message.attachmentName {
                AttachmentBadgeView(name: attName)
                    .padding(.horizontal, 12)
                    .padding(.top, message.replyToContent == nil ? 10 : 0)
                    .padding(.bottom, message.content.isEmpty ? 10 : 4)
            }

            if message.isLoading {
                Group {
                    if isWaitingForApproval {
                        Text(loadingTitle)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        TmaxLoadingIndicator(loadingTitle, size: 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else if !message.content.isEmpty {
                let topPad: CGFloat = (message.replyToContent != nil || message.attachmentName != nil) ? 0 : 10
                if isUser {
                    Text(message.content)
                        .font(TimeMasterFont.body())
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.top, topPad)
                        .padding(.bottom, 10)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    SelectableMarkdownText(text: message.content)
                        .padding(.horizontal, 14)
                        .padding(.top, topPad)
                        .padding(.bottom, 10)
                }
            }
        }
        .modifier(TimeMasterCardSurface(cornerRadius: 20, flat: true))
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if !message.isLoading {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = message.content
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
                #endif
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                onReply(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
            }
        }
    }

    private var timestampLabel: some View {
        HStack(spacing: 4) {
            Text(isUser ? "You" : "AI Coach")
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
            Text("·")
            Text(message.timestamp, style: .time)
        }
        .font(TimeMasterFont.body(11, relativeTo: .caption2))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 4)
    }
}

// MARK: - SelectableMarkdownText

private struct SelectableMarkdownText: View {
    let text: String

    var body: some View {
        if let attr = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(TimeMasterFont.styledText(attr))
                .foregroundColor(Theme.textPrimary)
                .font(TimeMasterFont.body())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .foregroundColor(Theme.textPrimary)
                .font(TimeMasterFont.body())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - ReplyQuoteView

private struct ReplyQuoteView: View {
    let content: String
    let isAuthor: Bool    // true = original was from user
    let isUser: Bool      // true = current bubble is user's

    private var barColor: Color { isUser ? Theme.toolbarOrange : Theme.textSecondary }
    private var textColor: Color { Theme.textPrimary.opacity(0.75) }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(barColor)
                .frame(width: 2)
                .cornerRadius(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(isAuthor ? "You" : "AI Coach")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundColor(textColor)
                Text(content)
                    .font(TimeMasterFont.caption())
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Theme.background.opacity(0.35))
        .cornerRadius(8)
    }
}

// MARK: - AttachmentBadgeView

private struct AttachmentBadgeView: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11))
            Text(name)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.textPrimary.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.background.opacity(0.35))
        .cornerRadius(8)
    }
}


// MARK: - ChatInputBar

private struct ChatInputBar: View {
    @Binding var text: String
    @Binding var replyingTo: ChatMessage?
    @Binding var pendingAttachName: String?
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let isApprovalPending: Bool
    let onSend: () -> Void
    let onAttach: () -> Void

    private var canSend: Bool {
        !isLoading && !isApprovalPending
            && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingAttachName != nil)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let reply = replyingTo {
                ReplyStripView(message: reply, onDismiss: { replyingTo = nil })
            }
            if let name = pendingAttachName {
                PendingAttachmentStrip(name: name, onRemove: { pendingAttachName = nil })
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: onAttach) {
                    Label("Attach a file", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(TimeMasterInsetControlStyle())
                .disabled(isApprovalPending)

                if isApprovalPending {
                    Text("Review the changes above to continue.")
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    TextField("Ask your coach…", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(TimeMasterFont.body())
                        .lineLimit(1...6)
                        .padding(.vertical, 11)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.toolbarOrange)
                        .focused(isFocused)
                        .onSubmit { if canSend { onSend() } }
                }

                Button(action: onSend) {
                    Group {
                        if isLoading {
                            TmaxLoadingIndicator(size: 20)
                        } else {
                            Image(systemName: isApprovalPending ? "lock.fill" : "arrow.up")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, circular: true))
                .disabled(!canSend)
                .accessibilityLabel(isLoading ? "Waiting for response" : "Send message")
            }
        }
        .padding(12)
        .modifier(TimeMasterCardSurface(flat: true))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Theme.background)
    }
}

// MARK: - ReplyStripView

private struct ReplyStripView: View {
    let message: ChatMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Theme.toolbarOrange)
                .frame(width: 2)
                .cornerRadius(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.role == .user ? "Replying to yourself" : "Replying to AI Coach")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textSecondary)
                Text(message.content)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onDismiss) {
                Label("Cancel reply", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterInsetControlStyle())
        }
        .padding(10)
        .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
    }
}

// MARK: - PendingAttachmentStrip

private struct PendingAttachmentStrip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(Color.white.opacity(0.6))
                .font(.system(size: 13))
            Text(name)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Button(action: onRemove) {
                Label("Remove attachment", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterInsetControlStyle())
        }
        .padding(10)
        .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
    }
}

// MARK: - SessionsListSheet

struct SessionsListSheet: View {
    @ObservedObject var store: AIStore
    @Binding var isPresented: Bool

    private var sorted: [ChatSession] {
        store.sessions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Group {
                    if store.sessions.isEmpty {
                        VStack(spacing: 12) {
                            Label("No conversations yet", systemImage: "bubble.left.and.bubble.right")
                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            Button("New Chat") {
                                store.newSession()
                                isPresented = false
                            }
                            .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: true))
                        }
                        .padding(24)
                        .modifier(TimeMasterCardSurface(flat: true))
                        .padding(16)
                    } else {
                        List {
                            ForEach(sorted) { session in
                                Button {
                                    store.switchSession(session.id)
                                    isPresented = false
                                } label: {
                                    SessionRowView(session: session, isCurrent: session.id == store.currentSessionID)
                                }
                                .buttonStyle(TimeMasterCardButtonStyle())
                                .accessibilityAddTraits(session.id == store.currentSessionID ? .isSelected : [])
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                            .onDelete { offsets in
                                offsets.map { sorted[$0].id }.forEach { store.deleteSession(id: $0) }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .timeMasterNavigationTitle("Conversations")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .primaryAction) { Button("Done") { isPresented = false }
                    .foregroundColor(.white)
                                 }
                AppToolbar.iconItem(placement: .primaryAction) { Button {
                    store.newSession()
                    isPresented = false
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                        .foregroundColor(.white)
                }
                                 }
            }
        }
        .font(TimeMasterFont.body())
    }
}

private struct SessionRowView: View {
    let session: ChatSession
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "checkmark.bubble.fill" : "bubble.left")
                .font(.title3)
                .foregroundStyle(isCurrent ? Theme.background : Theme.textSecondary)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? "New conversation" : session.title)
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .foregroundStyle(isCurrent ? Theme.background : Theme.textPrimary)
                    .lineLimit(2)
                Text(session.lastUserPreview.isEmpty ? "No messages yet" : session.lastUserPreview)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(isCurrent ? Theme.background.opacity(0.7) : Theme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.createdAt, format: .dateTime.month(.abbreviated).day())
                Text("\(session.visibleCount) messages")
            }
            .font(TimeMasterFont.body(11, relativeTo: .caption2))
            .foregroundStyle(isCurrent ? Theme.background.opacity(0.7) : Theme.textSecondary)
        }
        .padding(12)
        .background(
            isCurrent ? Theme.toolbarOrange : Theme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}



// MARK: - ApprovalCardView

private struct ApprovalCardView: View {
    let approval: ApprovalRequest
    @ObservedObject var store: AIStore

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Review changes", systemImage: iconName)
                        .font(TimeMasterFont.black(17, relativeTo: .headline))
                        .foregroundStyle(Theme.toolbarOrange)
                    Text(approval.summary)
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(approval.details.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(key)
                                .font(TimeMasterFont.black(12, relativeTo: .caption))
                                .foregroundStyle(Theme.textSecondary)
                            Text(approval.details[key] ?? "")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                Button { store.rejectCurrentToolCall() } label: {
                    Text("Reject").frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterSelectionButtonStyle())
                Button { store.approveCurrentToolCall() } label: {
                    Text("Approve").frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: true))
            }
        }
        .padding(16)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private var iconName: String {
        switch approval.toolName {
        case "create_exercise": return "figure.strengthtraining.traditional"
        case "create_folder": return "folder.badge.plus"
        case "build_workout": return "list.bullet.clipboard"
        case "add_media_note": return "note.text.badge.plus"
        default: return "hammer"
        }
    }
}

#Preview {
    AICoachView()
        .preferredColorScheme(.dark)
}
