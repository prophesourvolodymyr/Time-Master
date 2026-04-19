import SwiftUI

struct AICoachView: View {
    @StateObject private var store = AIStore.shared
    @State private var inputText = ""
    @State private var showingSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    messagesScrollView
                    inputBar
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AISettingsView().environmentObject(store)
            }
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.messages.filter({ !$0.isLoading }).isEmpty && !store.isLoading {
                        emptyState
                    }
                    ForEach(store.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: store.messages.count) { _ in
                if let last = store.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundColor(Color.white.opacity(0.2))
            Text("AI Coach")
                .font(.title2.bold()).foregroundColor(Theme.textPrimary)
            Text("Ask anything about your training, form, nutrition, or workout planning.")
                .font(.subheadline).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.separator)
            HStack(spacing: 12) {
                TextField("Ask your coach…", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .cornerRadius(20)
                    .foregroundColor(Theme.textPrimary)
                    .focused($inputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading
                                         ? Color.white.opacity(0.25)
                                         : .white)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.background)
        }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task { await store.sendMessage(text) }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.isLoading {
                    TypingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.surface)
                        .cornerRadius(16)
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(message.role == .user ? .black : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.role == .user ? Color.white : Theme.surface)
                        .cornerRadius(16)
                        .textSelection(.enabled)
                }
            }

            if message.role != .user { Spacer(minLength: 48) }
        }
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(phase == i ? 0.9 : 0.3))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

#Preview {
    AICoachView()
        .preferredColorScheme(.dark)
}
