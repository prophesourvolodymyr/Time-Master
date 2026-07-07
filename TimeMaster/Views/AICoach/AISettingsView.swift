import SwiftUI
import UniformTypeIdentifiers

// MARK: - AISettingsView

struct AISettingsView: View {
    @StateObject private var store = AIStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft        = ""
    @State private var showAPIKey         = false
    @State private var detectedProvider: AIProvider? = nil
    @State private var showProviderPicker = false
    @State private var showingFilePicker  = false
    @State private var showClearConfirm   = false
    @State private var showModelPicker    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        providerSection
                        modelSection
                        soulSection
                        knowledgeSection
                        dangerSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("AI Settings")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { applyAndDismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { reloadAPIKeyDraft() }
            .onChange(of: store.activeProviderID) { _ in reloadAPIKeyDraft() }
            .onChange(of: apiKeyDraft) { newVal in
                detectedProvider = AIProvider.detect(apiKey: newVal)
            }
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
            .sheet(isPresented: $showProviderPicker) {
                ProviderPickerSheet(activeID: $store.activeProviderID)
            }
        }
    }

    // MARK: - Provider + API Key (combined)

    private var providerSection: some View {
        SettingsCard(title: "Provider & API Key", icon: "server.rack") {
            // Active provider row
            providerRow

            Divider().background(Color.white.opacity(0.07))

            // API key field
            apiKeyField

            // Detection hint
            if let detected = detectedProvider, detected.id != store.activeProviderID {
                detectionBanner(detected)
            }

            // Base URL field only for Custom provider
            if store.activeProviderID == "custom" {
                customURLField
            }

            // Key status dot
            keyStatusRow
        }
    }

    private var providerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: store.activeProvider.iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeProvider.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if !store.activeProvider.apiKeyHint.isEmpty {
                    Text("Key format: \(store.activeProvider.apiKeyHint)")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.38))
                }
            }

            Spacer()

            Button("Switch") { showProviderPicker = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
        }
    }

    private var apiKeyField: some View {
        HStack(spacing: 10) {
            Group {
                if showAPIKey {
                    TextField(store.activeProvider.apiKeyHint, text: $apiKeyDraft)
                } else {
                    SecureField(store.activeProvider.apiKeyHint, text: $apiKeyDraft)
                }
            }
            .padding(13)
            .background(Color(hex: "1C1C1C"))
            .cornerRadius(10)
            .foregroundColor(.white)
            .autocorrectionDisabled()
            #if os(iOS)
                                        .textInputAutocapitalization(.never)
                                        #endif

            Button { showAPIKey.toggle() } label: {
                Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 36, height: 36)
            }
        }
    }

    private func detectionBanner(_ detected: AIProvider) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Color.white.opacity(0.65))
                .font(.caption)
            Text("This looks like a \(detected.name) key.")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.65))
            Spacer()
            Button("Switch") {
                applyCurrentKeyDraft()
                store.activeProviderID = detected.id
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }

    private var customURLField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Base URL")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.45))
            TextField("http://localhost:11434/v1", text: $store.customBaseURL)
                .padding(13)
                .background(Color(hex: "1C1C1C"))
                .cornerRadius(10)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                #if os(iOS)
                                        .textInputAutocapitalization(.never)
                                        #endif
                #if os(iOS)
                .keyboardType(.URL)
                #endif
            Text("Works with Ollama, LM Studio, or any OpenAI-compatible endpoint.")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.35))
        }
    }

    private var keyStatusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(apiKeyDraft.isEmpty ? Color.red.opacity(0.7) : Color.green.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(apiKeyDraft.isEmpty
                 ? "No key set — the AI won't respond without one."
                 : "Key entered. Tap Done to save securely.")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.45))
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        SettingsCard(title: "Model", icon: "cpu") {
            HStack(spacing: 10) {
                TextField("e.g. gpt-4o", text: $store.model)
                    .padding(13)
                    .background(Color(hex: "1C1C1C"))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    #if os(iOS)
                                        .textInputAutocapitalization(.never)
                                        #endif

                Button {
                    Task {
                        await store.fetchModels()
                        if !store.availableModels.isEmpty { showModelPicker = true }
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
                .disabled(store.isFetchingModels || apiKeyDraft.isEmpty)
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
                knownModelsSuggestions
            }
        }
    }

    @ViewBuilder
    private var knownModelsSuggestions: some View {
        let models = store.activeProvider.knownModels
        if !models.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Known models for \(store.activeProvider.name):")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.38))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(models, id: \.self) { m in
                            Button(m) { store.model = m }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        } else {
            Text("Tap the antenna icon to auto-detect available models.")
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.35))
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
            Button { showClearConfirm = true } label: {
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

    // MARK: - Helpers

    private func reloadAPIKeyDraft() {
        apiKeyDraft = store.apiKey(for: store.activeProviderID)
    }

    private func applyCurrentKeyDraft() {
        store.setApiKey(apiKeyDraft, for: store.activeProviderID)
    }

    private func applyAndDismiss() {
        store.setApiKey(apiKeyDraft, for: store.activeProviderID)
        store.saveSettings()
        dismiss()
    }
}

// MARK: - ProviderPickerSheet

struct ProviderPickerSheet: View {
    @Binding var activeID: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = AIStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    ForEach(AIProvider.grouped, id: \.group) { section in
                        SwiftUI.Section {
                            ForEach(section.providers) { provider in
                                Button {
                                    activeID = provider.id
                                    dismiss()
                                } label: {
                                    ProviderRow(provider: provider, isActive: activeID == provider.id, store: store)
                                }
                                .listRowBackground(
                                    activeID == provider.id
                                    ? Color.white.opacity(0.08)
                                    : Color(hex: "141414")
                                )
                                .listRowSeparatorTint(Color.white.opacity(0.06))
                            }
                        } header: {
                            Text(section.group)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.38))
                                .textCase(.uppercase)
                                .kerning(0.5)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose Provider")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - ProviderRow

private struct ProviderRow: View {
    let provider: AIProvider
    let isActive: Bool
    let store: AIStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: provider.iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(provider.apiKeyHint.isEmpty ? "No key required" : "Key: \(provider.apiKeyHint)")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.38))
            }

            Spacer()

            // Green dot if key is configured
            Circle()
                .fill(store.hasKey(for: provider.id) ? Color.green.opacity(0.75) : Color.white.opacity(0.15))
                .frame(width: 7, height: 7)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 4)
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
                            Text("Make sure your API key is correct, then tap the antenna icon again.")
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
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
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
        if lower.contains("gpt-4")   { return "OpenAI GPT-4" }
        if lower.contains("gpt-3")   { return "OpenAI GPT-3.5" }
        if lower.contains("claude")  { return "Anthropic Claude" }
        if lower.contains("gemini")  { return "Google Gemini" }
        if lower.contains("llama")   { return "Meta LLaMA" }
        if lower.contains("mistral") { return "Mistral AI" }
        if lower.contains("o1") || lower.contains("o3") { return "OpenAI Reasoning" }
        return "Language Model"
    }
}

#Preview {
    AISettingsView()
        .preferredColorScheme(.dark)
}
