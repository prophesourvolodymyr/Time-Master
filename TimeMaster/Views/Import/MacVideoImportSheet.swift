#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacVideoImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var source: MacVideoSource?
    @State private var isShowingFileImporter = false
    @State private var urlText = ""
    @State private var isDownloading = false
    @State private var isCheckingDownloader = true
    @State private var downloaderVersion: String?
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        Group {
            if let source {
                MacVideoEditorView(
                    source: source,
                    onBack: discardCurrentSource,
                    onSaved: completeImport
                )
            } else {
                sourcePicker
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false,
            onCompletion: receiveLocalVideo
        )
        .alert("Couldn’t import video", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var sourcePicker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Video Import", systemImage: "video.badge.plus")
                            .font(.title.bold())
                        Text("Add a source video, trim the moments you need, and save the result as a page in your exercise database.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose an existing video from this Mac. The original file stays where it is.")
                                .foregroundStyle(.secondary)
                            Button("Choose Video…", systemImage: "folder.badge.plus") {
                                isShowingFileImporter = true
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } label: {
                        Label("From a File", systemImage: "folder")
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Paste a link from YouTube, Instagram, TikTok, or another yt-dlp-supported site.")
                                .foregroundStyle(.secondary)

                            TextField("https://…", text: $urlText)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()

                            HStack {
                                downloaderStatus
                                Spacer()
                                Button {
                                    downloadVideo()
                                } label: {
                                    if isDownloading {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Downloading…")
                                    } else {
                                        Label("Download Video", systemImage: "arrow.down.circle")
                                    }
                                }
                                .disabled(!canDownload)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } label: {
                        Label("Download with yt-dlp", systemImage: "arrow.down.to.line")
                    }

                    Label("Downloads run directly on this Mac. TimeMaster does not use a server.", systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .navigationTitle("Import Video")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .task {
            downloaderVersion = await MacVideoDownloadService.installedVersion()
            isCheckingDownloader = false
        }
    }

    @ViewBuilder
    private var downloaderStatus: some View {
        if isCheckingDownloader {
            Label("Checking yt-dlp…", systemImage: "gearshape")
                .foregroundStyle(.secondary)
        } else if let downloaderVersion {
            Label("yt-dlp \(downloaderVersion)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("Install: brew install yt-dlp ffmpeg", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var canDownload: Bool {
        !isDownloading &&
        downloaderVersion != nil &&
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func receiveLocalVideo(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            source = MacVideoSource(url: url)
        case .failure(let error):
            presentError(error.localizedDescription)
        }
    }

    private func downloadVideo() {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text) else {
            presentError("Enter a valid http or https video link.")
            return
        }

        Task {
            isDownloading = true
            defer { isDownloading = false }

            do {
                source = try await MacVideoDownloadService.download(from: url)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func discardCurrentSource() {
        source?.discardManagedFiles()
        source = nil
    }

    private func completeImport() {
        source?.discardManagedFiles()
        source = nil
        dismiss()
    }

    private func presentError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
#endif
