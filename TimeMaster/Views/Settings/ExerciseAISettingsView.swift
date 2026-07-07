import SwiftUI

struct ExerciseAISettingsView: View {

    @State private var apiKey: String = UserDefaults.standard.string(forKey: "exercise_ai_api_key") ?? ""
    @State private var model: String  = UserDefaults.standard.string(forKey: "exercise_ai_model")   ?? "gpt-4o"
    @State private var revealKey = false

    private let models = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            List {

                // MARK: API Key
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OpenAI API Key")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 10) {
                            Group {
                                if revealKey {
                                    TextField("sk-…", text: $apiKey)
                                } else {
                                    SecureField("sk-…", text: $apiKey)
                                }
                            }
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .foregroundColor(.white)
                            .onChange(of: apiKey) {
                                UserDefaults.standard.set($0, forKey: "exercise_ai_api_key")
                            }

                            Button {
                                revealKey.toggle()
                            } label: {
                                Image(systemName: revealKey ? "eye.slash" : "eye")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("OpenAI Configuration")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                } footer: {
                    Text("Your key is stored locally on this device and is never sent anywhere except directly to api.openai.com.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.separator)

                // MARK: Model
                SwiftUI.Section {
                    HStack {
                        Text("Model")
                            .foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $model) {
                            ForEach(models, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .onChange(of: model) {
                            UserDefaults.standard.set($0, forKey: "exercise_ai_model")
                        }
                    }
                } header: {
                    Text("Vision Model")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                } footer: {
                    Text("gpt-4o gives the best results. gpt-4o-mini is faster and cheaper.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.separator)

                // MARK: How it works
                SwiftUI.Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Upload a photo to a section", systemImage: "photo.badge.plus")
                        Label("Tap ✦ Suggest in the Name field", systemImage: "sparkles")
                        Label("AI reads the image and fills the name", systemImage: "checkmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                }
                .listRowBackground(Theme.surface)
                .listRowSeparatorTint(Theme.separator)
            }
            #if os(iOS)
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.listStyle(.insetGrouped)
#endif
#endif
#endif
            #endif
            .scrollContentBackground(.hidden)
        }
        #if os(iOS)
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
        #endif
    }
}

#Preview {
    NavigationStack { ExerciseAISettingsView() }
        .preferredColorScheme(.dark)
}
