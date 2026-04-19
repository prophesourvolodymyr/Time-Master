import SwiftUI
import UniformTypeIdentifiers

// MARK: - AISettingsView

struct AISettingsView: View {
    @StateObject private var store = AIStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput        = ""
    @State private var showAPIKey         = false
    @State private var showingFilePicker  = false
    @State private var showClearConfirm   = false
    @State private var showModelPicker    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        apiKeySection
                        endpointSection
                        modelSection
                        soulSection
                        knowledgeSection
                        dangerSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { applyAndDismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { apiKeyInput = store.apiKey }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.text, .pdf, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        let ok = url.startAccessingSecurityScopedResource()
                        store.saveKnowledgeFile(url: url)
                        if ok { url.stopAccessingSecurityScopedResource() }
                    }
                }
            }
            .confirmationDialog("Clear chat history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All Sessions", role: .destructive) {
                    store.sessions = [ChatSession()]
                    store.currentSessionID = store.sessions[0].id
                    store.saveSettings()
                }
                Button("Clear Current Chat", role: .destructive) { store.clearCurrentSession() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerSheet(models: store.availableModels, selected: $store.model)
            }
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        SettingsCard(title: "API Key", icon: "key.fill") {
            HStack(spacing: 10) {
                Group {
                    if showAPIKey {
                        TextField("sk-…", text: $apiKeyInput)
                    } else {
                        SecureField("sk-…", text: $apiKeyInput)
                    }
                }
                .padding(13)
                .background(Color(hex: "1C1C1C"))
                .cornerRadius(10)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button { showAPIKey.toggle() } label: {
                    Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 36, height: 36)
                }
            }

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(apiKeyInput.isEmpty ? Color.red.opacity(0.7) : Color.green.opacity(0.8))
                    .frame(width: 6, height: 6)
                Text(apiKeyInput.isEmpty
                     ? "No key set — the AI won't respond without one."
                     : "Key entered. Tap Done to save securely.")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.45))
            }
        }
    }

    // MARK: - Endpoint

    private var endpointSection: some View {
        SettingsCard(title: "API Endpoint", icon: "network") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.45))
                TextField("https://api.openai.com", text: $store.baseURL)
                    .padding(13)
                    .background(Color(hex: "1C1C1C"))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            Text("Works with any OpenAI-compatible endpoint (OpenAI, Anthropic-proxy, Ollama, LM Studio, etc.)")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        SettingsCard(title: "Model", icon: "cpu") {
            HStack(spacing: 10) {
                TextField("gpt-4o", text: $store.model)
                    .padding(13)
                    .background(Color(hex: "1C1C1C"))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                // Detect button
                Button {
                    Task {
                        await store.fetchModels()
                        if !store.availableModels.isEmpty {
                            showModelPicker = true
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 44, height: 44)
                        if store.isFetchingModels {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                        }
                    }
                }
                .disabled(store.isFetchingModels || apiKeyInput.isEmpty)
            }

            if !store.availableModels.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green.opacity(0.8))
                        .font(.caption)
                    Text("\(store.availableModels.count) models detected. Tap the antenna icon to pick.")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.45))
                }
            } else {
                Text("Tap the antenna icon to auto-detect available models from your endpoint.")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
    }

    // MARK: - Soul

    private var soulSection: some View {
        SettingsCard(title: "System Prompt", icon: "text.bubble.fill") {
            ZStack(alignment: .topLeading) {
                if store.soulPrompt.isEmpty {
                    Text("Describe the AI's personality and role…")
                        .foregroundColor(Color.white.opacity(0.25))
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $store.soulPrompt)
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
            }
            .background(Color(hex: "1C1C1C"))
            .cornerRadius(10)
        }
    }

    // MARK: - Knowledge

    private var knowledgeSection: some View {
        SettingsCard(title: "Knowledge Files", icon: "doc.text.fill") {
            if store.knowledgeFilenames.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundColor(Color.white.opacity(0.25))
                    Text("Upload .txt, .md, or .pdf to give the AI extra context about you or your goals.")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(10)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.knowledgeFilenames, id: \.self) { filename in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundColor(Color.white.opacity(0.5))
                                .frame(width: 24)
                            Text(filename)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            Button { store.deleteKnowledgeFile(filename: filename) } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if filename != store.knowledgeFilenames.last {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(Color(hex: "1C1C1C"))
                .cornerRadius(10)
            }

            Button { showingFilePicker = true } label: {
                Label("Add File", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        SettingsCard(title: "Data", icon: "trash.fill") {
            Button {
                showClearConfirm = true
            } label: {
                Text("Clear Chat History")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(13)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Apply

    private func applyAndDismiss() {
        store.apiKey = apiKeyInput  // saves to Keychain + UserDefaults fallback
        store.saveSettings()
        dismiss()
    }
}

// MARK: - SettingsCard

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            content()
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(14)
    }
}

// MARK: - ModelPickerSheet

struct ModelPickerSheet: View {
    let models: [String]
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        search.isEmpty ? models : models.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                Group {
                    if models.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 44))
                                .foregroundColor(Color.white.opacity(0.15))
                            Text("No models detected")
                                .font(.headline)
                                .foregroundColor(Color.white.opacity(0.5))
                            Text("Make sure your API key and base URL are correct, then tap the antenna icon again.")
                                .font(.subheadline)
                                .foregroundColor(Color.white.opacity(0.35))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filtered, id: \.self) { modelID in
                            Button {
                                selected = modelID
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(modelID)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(modelCategory(modelID))
                                            .font(.caption)
                                            .foregroundColor(Color.white.opacity(0.38))
                                    }
                                    Spacer()
                                    if selected == modelID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(
                                selected == modelID
                                ? Color.white.opacity(0.10)
                                : Color(hex: "141414")
                            )
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                        .scrollContentBackground(.hidden)
                        .searchable(text: $search, prompt: "Filter models")
                    }
                }
            }
            .navigationTitle("Choose Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func modelCategory(_ id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("gpt-4")    { return "OpenAI GPT-4" }
        if lower.contains("gpt-3")    { return "OpenAI GPT-3.5" }
        if lower.contains("claude")   { return "Anthropic Claude" }
        if lower.contains("gemini")   { return "Google Gemini" }
        if lower.contains("llama")    { return "Meta LLaMA" }
        if lower.contains("mistral")  { return "Mistral AI" }
        if lower.contains("o1") || lower.contains("o3") { return "OpenAI Reasoning" }
        return "Language Model"
    }
}


#Preview {
    AISettingsView()
        .preferredColorScheme(.dark)
}
