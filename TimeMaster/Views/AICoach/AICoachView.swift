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

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    ChatMessageList(
                        store: store,
                        onReply: { replyingTo = $0 }
                    )
                    ChatInputBar(
                        text:              $inputText,
                        replyingTo:        $replyingTo,
                        pendingAttachName: $pendingAttachName,
                        isFocused:         $inputFocused,
                        isLoading:         store.isLoading,
                        isApprovalPending: store.pendingApproval != nil,
                        onSend:            sendMessage,
                        onAttach:          { showingFilePicker = true }
                    )
                }
                if let approval = store.pendingApproval {
                    ApprovalCardView(approval: approval, store: store)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle(store.currentSession.title.isEmpty ? "AI Coach" : store.currentSession.title)
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            #if os(iOS)
            .toolbarBackground(Theme.background, for: .navigationBar)
            #endif
            #if os(iOS)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar { chatToolbar }
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
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: store.pendingApproval != nil)
        }
    }

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingSessions = true } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.white)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { store.newSession() } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.white)
            }
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
    }

    private func sendMessage() {
        let text    = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingAttachName != nil else { return }
        let reply   = replyingTo
        let attName = pendingAttachName
        let attBody = pendingAttachContent
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

    private var visible: [ChatMessage] {
        store.currentMessages.filter { $0.role != .system }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if visible.isEmpty {
                        EmptyCoachState()
                            .padding(.top, 60)
                    }
                    ForEach(visible) { msg in
                        MessageBubble(message: msg, onReply: onReply)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .push(from: msg.role == .user ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.92))
                            ))
                    }
                    if store.isExecutingTools {
                        ToolCallIndicator(count: store.toolCallCount)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: visible.count) { _ in scrollToBottom(proxy) }
            .onChange(of: store.currentSessionID) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { scrollToBottom(proxy) }
            }
            .onAppear { scrollToBottom(proxy) }
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.background)
                        .frame(height: 0)
                    LinearGradient(
                        colors: [Theme.background, Theme.background.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = visible.last else { return }
        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}

// MARK: - EmptyCoachState

private struct EmptyCoachState: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 30))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            VStack(spacing: 6) {
                Text("AI Coach")
                    .font(.title3.bold())
                    .foregroundColor(Color.white.opacity(0.9))
                Text("Ask about training, form, nutrition, or recovery.\nAttach files for extra context.")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            HStack(spacing: 20) {
                SuggestionPill(text: "Plan my week")
                SuggestionPill(text: "Fix my squat form")
                SuggestionPill(text: "Rest day tips")
            }
        }
        .padding(.horizontal, 32)
    }
}

private struct SuggestionPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Color.white.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07))
            .cornerRadius(20)
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: ChatMessage
    let onReply: (ChatMessage) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 52) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                bubbleContent
                timestampLabel
                    .contextMenu { contextMenuItems }
            }

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
                AttachmentBadgeView(name: attName, isUser: isUser)
                    .padding(.horizontal, 12)
                    .padding(.top, message.replyToContent == nil ? 10 : 0)
                    .padding(.bottom, message.content.isEmpty ? 10 : 4)
            }

            if message.isLoading {
                TypingBubble()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else if !message.content.isEmpty {
                let topPad: CGFloat = (message.replyToContent != nil || message.attachmentName != nil) ? 0 : 10
                if isUser {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.black)
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
        .background(isUser ? Color.white : Color(hex: "1C1C1C"))
        .clipShape(BubbleShape(isUser: isUser))
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
        Text(relativeTime(message.timestamp))
            .font(.system(size: 10))
            .foregroundColor(Color.white.opacity(0.28))
            .padding(.horizontal, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
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
            Text(attr)
                .foregroundColor(Theme.textPrimary)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .foregroundColor(Theme.textPrimary)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - BubbleShape

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let smallR: CGFloat = 4
        var path = Path()
        if isUser {
            // top-left, top-right (small), bottom-right (small), bottom-left
            path.addRoundedRect(in: rect, cornerRadii: RectangleCornerRadii(
                topLeading: r, bottomLeading: r, bottomTrailing: smallR, topTrailing: r
            ))
        } else {
            path.addRoundedRect(in: rect, cornerRadii: RectangleCornerRadii(
                topLeading: r, bottomLeading: smallR, bottomTrailing: r, topTrailing: r
            ))
        }
        return path
    }
}

// MARK: - ReplyQuoteView

private struct ReplyQuoteView: View {
    let content: String
    let isAuthor: Bool    // true = original was from user
    let isUser: Bool      // true = current bubble is user's

    private var barColor: Color { isUser ? Color.black.opacity(0.25) : Color.white.opacity(0.3) }
    private var textColor: Color { isUser ? Color.black.opacity(0.65) : Color.white.opacity(0.55) }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(barColor)
                .frame(width: 2)
                .cornerRadius(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(isAuthor ? "You" : "AI Coach")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textColor)
                Text(content)
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background((isUser ? Color.black : Color.white).opacity(0.07))
        .cornerRadius(8)
    }
}

// MARK: - AttachmentBadgeView

private struct AttachmentBadgeView: View {
    let name: String
    let isUser: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11))
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(isUser ? Color.black.opacity(0.6) : Color.white.opacity(0.55))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isUser ? Color.black : Color.white).opacity(0.10))
        .cornerRadius(8)
    }
}

// MARK: - TypingBubble

private struct TypingBubble: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(phase == i ? 0.85 : 0.25))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.15 : 0.9)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: phase)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
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
        !text.trimmingCharacters(in: .whitespaces).isEmpty || pendingAttachName != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))

            // Reply strip
            if let reply = replyingTo {
                ReplyStripView(message: reply, onDismiss: { replyingTo = nil })
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Attachment badge
            if let name = pendingAttachName {
                PendingAttachmentStrip(name: name, onRemove: { pendingAttachName = nil })
                    .padding(.horizontal, 12)
                    .padding(.top, replyingTo == nil ? 8 : 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input row
            HStack(alignment: .bottom, spacing: 10) {
                // Attach
                Button(action: onAttach) {
                    Image(systemName: pendingAttachName != nil ? "paperclip.circle.fill" : "paperclip")
                        .font(.system(size: 20))
                        .foregroundColor(pendingAttachName != nil ? .white : Color.white.opacity(0.45))
                }
                .frame(width: 36, height: 36)
                .disabled(isApprovalPending)

                // Text field
                if isApprovalPending {
                    Text("Review the requested changes above...")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "1C1C1C"))
                        .cornerRadius(20)
                } else {
                    TextField("Message…", text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "1C1C1C"))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        .tint(.white)
                        .focused(isFocused)
                        .onSubmit { if canSend { onSend() } }
                }

                // Send
                Button(action: onSend) {
                    ZStack {
                        Circle()
                            .fill(canSend && !isLoading && !isApprovalPending ? Color.white : Color.white.opacity(0.12))
                            .frame(width: 36, height: 36)
                        if isLoading {
                            ProgressView()
                                .tint(Color.white.opacity(0.6))
                                .scaleEffect(0.75)
                        } else if isApprovalPending {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.3))
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(canSend ? .black : Color.white.opacity(0.3))
                        }
                    }
                }
                .disabled(!canSend || isLoading || isApprovalPending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: replyingTo?.id)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingAttachName)
        }
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
                .fill(Color.white.opacity(0.5))
                .frame(width: 2)
                .cornerRadius(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.role == .user ? "Replying to yourself" : "Replying to AI Coach")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.white.opacity(0.35))
                    .font(.system(size: 18))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.white.opacity(0.35))
                    .font(.system(size: 18))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
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
                        Text("No conversations yet.")
                            .foregroundColor(Color.white.opacity(0.4))
                    } else {
                        List {
                            ForEach(sorted) { session in
                                SessionRowView(
                                    session: session,
                                    isCurrent: session.id == store.currentSessionID
                                )
                                .listRowBackground(
                                    session.id == store.currentSessionID
                                    ? Color.white.opacity(0.08)
                                    : Color(hex: "141414")
                                )
                                .listRowSeparatorTint(Color.white.opacity(0.06))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation { store.switchSession(session.id) }
                                    isPresented = false
                                }
                            }
                            .onDelete { offsets in
                                offsets.map { sorted[$0].id }.forEach { store.deleteSession(id: $0) }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Conversations")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.newSession()
                        isPresented = false
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

private struct SessionRowView: View {
    let session: ChatSession
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.white : Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 15))
                    .foregroundColor(isCurrent ? .black : Color.white.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .white : Color.white.opacity(0.85))
                    .lineLimit(1)
                Text(session.lastUserPreview)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.38))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(shortDate(session.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.28))
                Text("\(session.visibleCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }

    private func shortDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 86400 {
            let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
        }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
}


// MARK: - ToolCallIndicator

private struct ToolCallIndicator: View {
    let count: Int
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 52)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(pulse ? 0.7 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulse ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                Text(toolActionText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "1C1C1C"))
            .clipShape(BubbleShape(isUser: false))
            .onAppear { pulse = true }
        }
        .padding(.vertical, 2)
    }

    private var toolActionText: String {
        if count >= 5 { return "Working on it..." }
        switch count {
        case 1: return "Checking your data..."
        case 2: return "Looking deeper..."
        case 3: return "Almost done..."
        default: return "Working on it..."
        }
    }
}

// MARK: - ApprovalCardView

private struct ApprovalCardView: View {
    let approval: ApprovalRequest
    @ObservedObject var store: AIStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "FFD60A"))
                    Text("AI wants to make changes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Text(approval.summary)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                if !approval.details.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(approval.details.keys.sorted(), id: \.self) { key in
                            HStack(spacing: 4) {
                                Text(key + ":")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.4))
                                Text(approval.details[key] ?? "")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Button(action: { store.rejectCurrentToolCall() }) {
                        Text("Reject")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                    Button(action: { store.approveCurrentToolCall() }) {
                        Text("Approve")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "FFD60A"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "1C1C1C"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "FFD60A").opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
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
