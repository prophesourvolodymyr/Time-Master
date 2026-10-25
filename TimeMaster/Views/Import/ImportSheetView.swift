import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ImportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = ServerSettings.shared

    @State private var urlText        = ""
    @State private var isDownloading  = false
    @State private var downloadError: String?
    #if os(iOS)
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingSourceChoice = false
    #endif
    @State private var showingFilePicker = false
    @State private var isLoadingVideo = false
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
            .timeMasterNavigationTitle("Import Video")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                AppToolbar.iconItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView(settings: settings)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingEditor, onDismiss: discardVideo) {
                editorCover
            }
            #else
            .sheet(isPresented: $showingEditor, onDismiss: discardVideo) {
                editorCover
            }
            #endif
        }
        #if os(iOS)
        .confirmationDialog("Choose video from", isPresented: $showingSourceChoice, titleVisibility: .visible) {
            Button("Photos") { showingPhotoPicker = true }
            Button("Files") { showingFilePicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickerItem, matching: .videos)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            loadLocalVideo(item)
        }
        #endif
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadFileVideo(url)
            case .failure(let error):
                downloadError = error.localizedDescription
            }
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
            #if os(iOS)
            Text("From Your Device")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
            Button { showingSourceChoice = true } label: {
                pickerRow(title: isLoadingVideo ? "Opening Video…" : "Choose Video", systemImage: "video.badge.plus")
            }
            #else
            Text("From This Mac")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
            Button { showingFilePicker = true } label: {
                pickerRow(title: "Choose Video", systemImage: "folder")
            }
            #endif
            if isLoadingVideo {
                TmaxLoadingIndicator("Preparing video…")
            }
        }
        .disabled(isLoadingVideo || isDownloading)
    }

    private func pickerRow(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2).foregroundColor(Theme.textPrimary)
            Text(title)
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download from URL")
                .font(TimeMasterFont.sectionTitle()).foregroundColor(Theme.textPrimary)
            Text("Paste a link from Instagram, YouTube, TikTok, or any yt-dlp supported site.")
                .font(TimeMasterFont.caption()).foregroundColor(Theme.textSecondary)

            TextField("https://…", text: $urlText)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
            #if os(iOS)
            .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()

            Button { startDownload() } label: {
                HStack {
                    if isDownloading {
                        TmaxLoadingIndicator(size: 18)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text(isDownloading ? "Downloading…" : "Download")
                        .font(TimeMasterFont.sectionTitle())
                }
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Theme.surface2)
                .cornerRadius(10)
            }
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isDownloading || isLoadingVideo)
        }
    }

    private func errorLabel(_ msg: String) -> some View {
        Text(msg)
            .font(TimeMasterFont.caption())
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    #if os(iOS)
    private func loadLocalVideo(_ item: PhotosPickerItem) {
        isLoadingVideo = true
        downloadError = nil
        Task { @MainActor in
            defer {
                isLoadingVideo = false
                pickerItem = nil
            }
            do {
                guard let file = try await item.loadTransferable(type: MovieFile.self) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                await openVideo(file.url)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }
    #endif

    private func loadFileVideo(_ url: URL) {
        isLoadingVideo = true
        downloadError = nil
        Task { @MainActor in
            defer { isLoadingVideo = false }
            do {
                let stagedURL = try await Task.detached(priority: .userInitiated) {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension)
                    var coordinationError: NSError?
                    var copyError: Error?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
                        do {
                            try FileManager.default.copyItem(at: readableURL, to: destination)
                        } catch {
                            copyError = error
                        }
                    }
                    if let error = coordinationError ?? copyError as NSError? {
                        try? FileManager.default.removeItem(at: destination)
                        throw error
                    }
                    return destination
                }.value
                await openVideo(stagedURL)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }

    private func openVideo(_ url: URL) async {
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard duration.isFinite, duration > 0, !tracks.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            videoURL = url
            showingEditor = true
        } catch {
            try? FileManager.default.removeItem(at: url)
            downloadError = "Could not open this video. \(error.localizedDescription)"
        }
    }

    private func discardVideo() {
        if let videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        videoURL = nil
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
                await openVideo(url)
            } catch {
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }
}

