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
            .navigationDestination(for: DatabaseSkillGroupRoute.self) { route in
                SkillGroupPageView(route: route)
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
        .environment(\.workoutMedia, WorkoutMediaEnvironment(workout: currentWorkout, liveContext: liveContext))
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMusic) {
            if let liveContext {
                WorkoutMusicPlaybackSheet(workout: currentWorkout, isContinuationPrompt: false, library: library, session: liveContext.music)
            }
        }
        .keyNavHost()
    }
}

struct WorkoutAttachmentStrip: View {
    let workout: Workout
    var liveContext: WorkoutLiveContext? = nil
    @State private var selectedMediaIndex = 0
    @State private var showingMedia = false
    @State private var opensEditor = false
    @EnvironmentObject private var databaseStore: DatabaseStore
    @ObservedObject private var notes = MediaNotesStore.shared

    private var catalog: WorkoutMediaCatalog {
        WorkoutMediaCatalog(
            pageIDs: WorkoutMediaCatalog.pageIDs(in: workout),
            sections: workout.sections,
            databaseStore: databaseStore,
            notes: notes
        )
    }

    var body: some View {
        let catalog = catalog
        if !catalog.entries.isEmpty {
            MediaStrip(
                title: "",
                urls: catalog.urls,
                marksCover: false,
                comments: catalog.comments,
                onOpen: { index in
                    selectedMediaIndex = index
                    opensEditor = false
                    showingMedia = true
                },
                onOpenNotes: { index in
                    selectedMediaIndex = index
                    opensEditor = true
                    showingMedia = true
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .mediaViewerCover(isPresented: $showingMedia) {
                PageMediaGallery(
                    urls: catalog.urls,
                    selectedIndex: $selectedMediaIndex,
                    isPresented: $showingMedia,
                    comments: catalog.comments,
                    onSaveComment: { url, text in
                        try catalog.save(text, for: url, databaseStore: databaseStore, notes: notes)
                    },
                    opensEditor: opensEditor,
                    notesAssets: { catalog.assets(for: $0, databaseStore: databaseStore, notes: notes) },
                    workout: workout,
                    liveContext: liveContext,
                    databasePageID: { catalog.pageID(for: $0) ?? catalog.firstPageID }
                )
                .keyNavHost()
            }
        }
    }
}
