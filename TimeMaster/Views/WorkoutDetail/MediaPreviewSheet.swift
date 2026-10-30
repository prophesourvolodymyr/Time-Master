import SwiftUI

struct MediaPreviewSheet: View {
    let items: [MediaItem]
    var workout: Workout? = nil
    var liveContext: WorkoutLiveContext? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notes = MediaNotesStore.shared
    @State private var index = 0

    private var urls: [URL] {
        items.map { item in
            item.type == .video
                ? PhotoManager.shared.videoURL(for: item.filename)
                : PhotoManager.shared.photoURL(for: item.filename)
        }
    }

    private var comments: [URL: String] {
        urls.reduce(into: [:]) { result, url in
            if let note = notes.note(for: url) { result[url] = note }
        }
    }

    var body: some View {
        PageMediaGallery(
            urls: urls,
            selectedIndex: $index,
            isPresented: Binding(get: { true }, set: { if !$0 { dismiss() } }),
            comments: comments,
            onSaveComment: { url, text in try notes.set(text, for: url) },
            notesAssets: { _ in notes.assets },
            workout: workout,
            liveContext: liveContext,
            databasePageID: { _ in workout.flatMap { WorkoutMediaCatalog.pageIDs(in: $0).first } }
        )
        .keyNavHost()
    }
}
