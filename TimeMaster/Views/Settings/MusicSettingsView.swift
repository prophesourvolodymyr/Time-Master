import SwiftUI
import UniformTypeIdentifiers

struct MusicSettingsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @ObservedObject private var manager = MusicManager.shared
    @StateObject private var library = MusicLibraryStore()
    @State private var showFilePicker = false
    @State private var importError: String?

    var body: some View {
        MusicLibraryScreen(library: library, importLocalMusic: { showFilePicker = true })
            .navigationBarBackButtonHidden(false)
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .onAppear { library.setWorkouts(workoutStore.workouts) }
            .onChange(of: workoutStore.workouts) { library.setWorkouts($0) }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio, .movie, .mp3, .mpeg4Audio],
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
                            library.adoptMusicManagerTracks()
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "Unknown error")
            }
    }
}

#Preview {
    NavigationStack {
        MusicSettingsView()
            .environmentObject(WorkoutStore())
    }
    .preferredColorScheme(.dark)
}
