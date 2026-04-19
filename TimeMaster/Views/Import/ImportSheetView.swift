import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = ServerSettings.shared

    @State private var urlText        = ""
    @State private var isDownloading  = false
    @State private var downloadError: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingSettings = false
    @State private var showingEditor   = false
    @State private var videoURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        localPickerCard
                        downloadCard
                        if let err = downloadError {
                            errorLabel(err)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView(settings: settings)
            }
            .fullScreenCover(isPresented: $showingEditor) {
                editorCover
            }
        }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            loadLocalVideo(item)
        }
    }

    // MARK: - Editor Cover

    @ViewBuilder
    private var editorCover: some View {
        if let url = videoURL {
            VideoEditorView(videoURL: url) {
                showingEditor = false
            }
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    // MARK: - Cards

    private var localPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From Camera Roll")
                .font(.headline).foregroundColor(Theme.textPrimary)
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2).foregroundColor(Theme.textPrimary)
                    Text("Choose Video")
                        .font(.headline).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
            }
        }
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download from URL")
                .font(.headline).foregroundColor(Theme.textPrimary)
            Text("Paste a link from Instagram, YouTube, TikTok, or any yt-dlp supported site.")
                .font(.caption).foregroundColor(Theme.textSecondary)

            TextField("https://…", text: $urlText)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Button { startDownload() } label: {
                HStack {
                    if isDownloading {
                        ProgressView().scaleEffect(0.8).tint(Theme.textPrimary)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text(isDownloading ? "Downloading…" : "Download")
                        .font(.headline)
                }
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Theme.surface2)
                .cornerRadius(10)
            }
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isDownloading)
        }
    }

    private func errorLabel(_ msg: String) -> some View {
        Text(msg)
            .font(.caption)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func loadLocalVideo(_ item: PhotosPickerItem) {
        Task { @MainActor in
            if let file = try? await item.loadTransferable(type: MovieFile.self) {
                videoURL = file.url
                showingEditor = true
            }
            pickerItem = nil
        }
    }

    private func startDownload() {
        downloadError = nil
        isDownloading = true
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        Task { @MainActor in
            do {
                let url = try await VideoDownloadService.download(
                    socialURL: trimmed,
                    settings: settings
                )
                videoURL = url
                showingEditor = true
            } catch {
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }
}
