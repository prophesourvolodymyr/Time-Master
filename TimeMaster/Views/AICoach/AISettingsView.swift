import SwiftUI
import UniformTypeIdentifiers

struct AISettingsView: View {
    @EnvironmentObject var store: AIStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput: String = ""
    @State private var showAPIKey = false
    @State private var showingFilePicker = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        apiKeyCard
                        endpointCard
                        soulCard
                        knowledgeCard
                        dangerCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyAndDismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                apiKeyInput = store.apiKey
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.text, .pdf, UTType(filenameExtension: "md") ?? .text],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        let accessed = url.startAccessingSecurityScopedResource()
                        store.saveKnowledgeFile(url: url)
                        if accessed { url.stopAccessingSecurityScopedResource() }
                    }
                }
            }
            .confirmationDialog("Clear all chat history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { store.clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Cards

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("API Key").font(.headline).foregroundColor(Theme.textPrimary)
            HStack {
                Group {
                    if showAPIKey {
                        TextField("sk-…", text: $apiKeyInput)
                    } else {
                        SecureField("sk-…", text: $apiKeyInput)
                    }
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button { showAPIKey.toggle() } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.trailing, 4)
            }
            Text("Stored securely in Keychain. Works with any OpenAI-compatible API.")
                .font(.caption).foregroundColor(Theme.textSecondary)
        }
    }

    private var endpointCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Endpoint").font(.headline).foregroundColor(Theme.textPrimary)
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL").font(.subheadline).foregroundColor(Theme.textSecondary)
                    TextField("https://api.openai.com", text: $store.baseURL)
                        .padding(14).background(Theme.surface).cornerRadius(10)
                        .foregroundColor(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model").font(.subheadline).foregroundColor(Theme.textSecondary)
                    TextField("gpt-4o", text: $store.model)
                        .padding(14).background(Theme.surface).cornerRadius(10)
                        .foregroundColor(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
    }

    private var soulCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Soul / System Prompt").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("Sets AI personality").font(.caption2).foregroundColor(Theme.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if store.soulPrompt.isEmpty {
                    Text("Describe the AI's personality and role…")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $store.soulPrompt)
                    .frame(minHeight: 120).padding(10)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private var knowledgeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Knowledge Files").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            if store.knowledgeFilenames.isEmpty {
                Text("No files added. Upload .txt, .md, or .pdf files to give the AI extra context.")
                    .font(.caption).foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.knowledgeFilenames, id: \.self) { filename in
                        HStack {
                            Image(systemName: "doc.text").foregroundColor(Theme.textSecondary).frame(width: 28)
                            Text(filename).font(.subheadline).foregroundColor(Theme.textPrimary).lineLimit(1)
                            Spacer()
                            Button {
                                store.deleteKnowledgeFile(filename: filename)
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red).font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.surface)
                        if filename != store.knowledgeFilenames.last {
                            Divider().background(Theme.separator).padding(.leading, 42)
                        }
                    }
                }
                .cornerRadius(10)
            }
        }
    }

    private var dangerCard: some View {
        Button(role: .destructive) {
            showClearConfirm = true
        } label: {
            Text("Clear Chat History")
                .font(.headline).foregroundColor(.red)
                .frame(maxWidth: .infinity).padding(16)
                .background(Theme.surface).cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func applyAndDismiss() {
        store.apiKey = apiKeyInput
        store.saveSettings()
        dismiss()
    }
}

#Preview {
    AISettingsView()
        .environmentObject(AIStore.shared)
        .preferredColorScheme(.dark)
}
