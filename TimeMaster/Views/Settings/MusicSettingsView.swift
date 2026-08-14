import SwiftUI
import UniformTypeIdentifiers

struct MusicSettingsView: View {

    @ObservedObject private var manager = MusicManager.shared

    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var showImportError = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            List {
                volumeSection
                tracksSection
            }
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.listStyle(.insetGrouped)
#endif
#endif
#endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Background Music")
        #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
        .fileImporter(
            isPresented: $showFilePicker,
             allowedContentTypes: [UTType.audio, UTType.movie, UTType.mp3, UTType.mpeg4Audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                 Task {
                     do {
                         for url in urls {
                             let isVideo = ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased())
                             if isVideo {
                                 try await manager.importTrackAsync(from: url)
                             } else {
                                 manager.importTrack(from: url)
                             }
                         }
                     } catch {
                         importError = error.localizedDescription
                         showImportError = true
                     }
                 }
            case .failure(let err):
                importError = err.localizedDescription
                showImportError = true
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Volume Section

    private var volumeSection: some View {
        SwiftUI.Section {
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 20)
                Slider(
                    value: $manager.volume,
                    in: 0...1,
                    step: 0.05
                )
                .tint(.white)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 20)
            }
        } header: {
            Text("Volume")
                .foregroundColor(Theme.textSecondary)
                .font(.caption)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.separator)
    }

    // MARK: - Tracks Section

    private var tracksSection: some View {
        SwiftUI.Section {
            if manager.trackFilenames.isEmpty {
                Text("No tracks added yet")
                    .foregroundColor(Theme.textSecondary)
                    .font(.subheadline)
            } else {
                ForEach(manager.trackFilenames, id: \.self) { fn in
                    HStack(spacing: 12) {
                         Image(systemName: fn.lowercased().hasSuffix(".mp3") ? "music.note" : "waveform")
                            .foregroundColor(.white)
                            .frame(width: 20)
                        Text(manager.displayName(for: fn))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
                .onDelete { offsets in
                    manager.deleteTrack(at: offsets)
                }
            }
        } header: {
            HStack {
                Text("Tracks (\(manager.trackFilenames.count))")
                    .foregroundColor(Theme.textSecondary)
                    .font(.caption)
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Import")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
            }
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.separator)
    }
}

#Preview {
    NavigationStack {
        MusicSettingsView()
    }
    .preferredColorScheme(.dark)
}
