import SwiftUI
import TimeMasterCore

struct WorkoutAttachmentBrowser: View {
    let workout: Workout
    let liveContext: WorkoutLiveContext?
    var onClose: (() -> Void)?
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = MusicLibraryStore.shared
    @StateObject private var navigationState = DatabaseNavigationState()
    let pageID: UUID
    @State private var showMusic = false

    init(workout: Workout, pageID: UUID, liveContext: WorkoutLiveContext? = nil, onClose: (() -> Void)? = nil) {
        self.workout = workout
        self.liveContext = liveContext
        self.onClose = onClose
        self.pageID = pageID
    }

    private var currentWorkout: Workout {
        workoutStore.workouts.first { $0.id == workout.id } ?? workout
    }

    var body: some View {
        NavigationStack(path: $navigationState.path) {
            ExercisePageDetailView(pageID: pageID, showsHero: false)
            .navigationDestination(for: DatabasePageRoute.self) { route in
                if let id = UUID(uuidString: route.pageID) { ExercisePageDetailView(pageID: id, showsHero: false) }
            }
            .navigationDestination(for: DatabaseCategoryRoute.self) { route in
                if let id = UUID(uuidString: route.containerID) {
                    ContainerCategoryPage(destination: ContainerCategoryDestination(containerID: id, tab: route.tab))
                }
            }
            .toolbar {
                AppToolbar.item(placement: .confirmationAction) { Button("Close") {
                    if let onClose { onClose() } else { dismiss() }
                }
                                 }
            }
            .modifier(WorkoutFloatingControlsOverlay(
                workoutName: currentWorkout.name,
                context: liveContext.map { context in
                    WorkoutLiveContext(
                        progress: context.progress, music: context.music,
                        onPause: context.onPause, onStop: context.onStop,
                        onOpenMusic: { showMusic = true }
                    )
                },
                library: library
            ))
        }
        .environmentObject(navigationState)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMusic) {
            if let liveContext {
                WorkoutMusicPlaybackSheet(workout: currentWorkout, isContinuationPrompt: false, library: library, session: liveContext.music)
            }
        }
    }
}

struct WorkoutAttachmentStrip: View {
    let workout: Workout
    @State private var selectedMediaIndex = 0
    @State private var showingMedia = false
    @EnvironmentObject private var databaseStore: DatabaseStore

    private var pageIDs: [UUID] {
        var result: [UUID] = []
        var seen: Set<UUID> = []
        func append(_ id: UUID?) {
            if let id, seen.insert(id).inserted { result.append(id) }
        }
        func appendSlot(_ slot: SetSlot) {
            append(slot.exercisePageID)
            append(slot.restExercisePageID)
            for drop in slot.drops { append(drop.exercisePageID) }
            for content in slot.restRow?.contents ?? [] { append(content.pageID) }
            for child in slot.children { appendSlot(child) }
        }
        for section in workout.sections {
            append(section.pageID)
            for slot in section.effectiveSlots { appendSlot(slot) }
            for content in section.bigRestRow?.contents ?? [] { append(content.pageID) }
        }
        return result
    }

    private var mediaURLs: [URL] {
        var result: [URL] = []
        var seen: Set<URL> = []
        for id in pageIDs {
            for url in databaseStore.page(id: id)?.mediaURLs ?? [] where seen.insert(url).inserted {
                result.append(url)
            }
        }
        for section in workout.sections {
            for item in section.mediaItems {
                let url = item.type == .video
                    ? PhotoManager.shared.videoURL(for: item.filename)
                    : PhotoManager.shared.photoURL(for: item.filename)
                if seen.insert(url).inserted { result.append(url) }
            }
        }
        return result
    }

    var body: some View {
        let urls = mediaURLs
        if !urls.isEmpty {
            PageMediaGalleryGrid(title: "", urls: urls, marksCover: false) { index in
                selectedMediaIndex = index
                showingMedia = true
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .sheet(isPresented: $showingMedia) {
                PageMediaGallery(urls: urls, selectedIndex: $selectedMediaIndex, isPresented: $showingMedia)
            }
        }
    }
}
