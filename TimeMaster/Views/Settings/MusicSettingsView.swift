import SwiftUI
import UniformTypeIdentifiers
import TimeMasterCore

struct MusicSettingsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @ObservedObject private var manager = MusicManager.shared
    @ObservedObject private var library: MusicLibraryStore
    @State private var showFilePicker = false
    @State private var importError: String?
    init(library: MusicLibraryStore) {
        self.library = library
    }

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
                                    try manager.importTrack(from: url)
                                }
                            }
                            library.adoptMusicManagerTracks()
                            await library.refreshLocalDurations()
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

struct WorkoutMusicImportSheet: View {
    let workout: Workout
    @ObservedObject var library: MusicLibraryStore
    let onSave: (MusicDestination, WorkoutMusicTimeline?) -> Void
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var initialItemIDs: Set<UUID>
    @State private var collected: [MusicLibraryItem] = []
    @State private var newItemIDs: Set<UUID> = []
    @State private var configuration: WorkoutMusicTimeline?
    @State private var configurationName: String?
    @State private var searching = false
    @State private var query = ""
    @State private var showFiles = false
    @State private var showServices = false
    @State private var showConfigurations = false
    @State private var showDestination = false
    @State private var importing = false
    @State private var error: String?
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 82

    init(workout: Workout, library: MusicLibraryStore, onSave: @escaping (MusicDestination, WorkoutMusicTimeline?) -> Void) {
        self.workout = workout
        self.library = library
        self.onSave = onSave
        _initialItemIDs = State(initialValue: Set(library.items.map(\.id)))
    }

    private var available: [MusicLibraryItem] {
        library.items.filter { item in
            query.isEmpty || item.title.localizedStandardContains(query)
                || item.tracks.contains { $0.title.localizedStandardContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        importOption("Files", symbol: "folder", color: .orange) { showFiles = true }
                        importOption("Music Services", symbol: "music.note", color: .green) { showServices = true }
                        importOption("Cloud Files", symbol: "icloud", color: .blue) { showFiles = true }
                        importOption("Workout Configuration", symbol: "timeline.selection", color: .purple) { showConfigurations = true }
                    }
                    Text("Cloud files use the installed locations in Files. Music services use the same connections as Settings.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                    if importing { ProgressView("Importing music…") }
                }
                .listRowBackground(Color.clear)
                if searching {
                    TextField("Search your music library", text: $query)
                        .accessibilityLabel("Search imported music and library")
                        .listRowBackground(Theme.surface)
                }
                SwiftUI.Section("Collected music") {
                    if let configurationName {
                        Label("Configuration from \(configurationName)", systemImage: "timeline.selection")
                        Text("Saving replaces this workout's music timeline exactly, including placement, lanes, and durations.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    if collected.isEmpty {
                        Text("Import music or choose tracks below. You will choose where to save before leaving.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(collected) { item in itemRow(item) }
                }
                .listRowBackground(Theme.surface)
                SwiftUI.Section("Your music library") {
                    ForEach(available) { item in
                        Button { collect(item) } label: {
                            HStack {
                                itemRow(item)
                                Spacer()
                                Image(systemName: collected.contains(where: { $0.id == item.id }) ? "checkmark.circle.fill" : "plus.circle")
                            }
                        }
                        .disabled(collected.contains(where: { $0.id == item.id }))
                        .accessibilityLabel("Collect \(item.title)")
                    }
                    if available.isEmpty { Text("No matching music").foregroundStyle(Theme.textSecondary) }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .navigationTitle("Add Music")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.iconItem(placement: .primaryAction) { Button { searching.toggle() } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Search music library")
                                 }
                AppToolbar.item(placement: .confirmationAction) { Button("Done") {
                    if collected.isEmpty && configuration == nil { dismiss() }
                    else { showDestination = true }
                }
                .disabled(importing)
                                 }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(importing || !collected.isEmpty || configuration != nil)
        .onAppear { library.setWorkouts(workoutStore.workouts) }
        .onChange(of: library.items) { _ in collectNewItems() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio, .movie], allowsMultipleSelection: true, onCompletion: importFiles)
        .sheet(isPresented: $showServices) {
            NavigationStack { MusicSettingsView(library: library) }
        }
        .sheet(isPresented: $showConfigurations) { configurationPicker }
        .sheet(isPresented: $showDestination) { destinationPicker }
        .alert("Music Import", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func importOption(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: cardHeight)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(importing)
    }

    private func itemRow(_ item: MusicLibraryItem) -> some View {
        HStack(spacing: 12) {
            WorkoutMusicCover(artwork: item.artwork, isCollection: item.isCollection, size: 44, tracks: item.tracks)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline).lineLimit(2)
                Text(musicTimestamp(item.totalDuration)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var configurationPicker: some View {
        NavigationStack {
            List {
                Text("Choose a saved workout to copy its complete music timeline. Your current timeline changes only after you save.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                ForEach(workoutStore.workouts.filter { $0.id != workout.id }) { source in
                    Button {
                        guard let timeline = source.musicTimeline else { return }
                        configuration = timeline
                        configurationName = source.name
                        for clip in timeline.clips { collect(libraryItem(for: clip)) }
                        showConfigurations = false
                    } label: {
                        HStack {
                            Image(systemName: source.type.iconName).foregroundStyle(Color(hex: source.type.colorHex))
                            Text(source.name)
                            Spacer()
                            Text(source.musicTimeline.map { musicTimestamp($0.end) } ?? "No configuration")
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .disabled(source.musicTimeline == nil)
                }
            }
            .navigationTitle("Import Configuration")
            .toolbar { AppToolbar.item(placement: .cancellationAction) { Button("Cancel") { showConfigurations = false } } }
        }
    }

    private var destinationPicker: some View {
        NavigationStack {
            List {
                SwiftUI.Section("Save collected music to") {
                    destinationButton(.general, title: "General")
                    destinationButton(.workout(id: workout.id), title: "Only \(workout.name)")
                }
                SwiftUI.Section("Workout type") {
                    ForEach(library.destinations(for: .type)) { destination in
                        destinationButton(destination, title: library.destinationName(destination))
                    }
                }
                Text("Workout-only music stays available under this workout in Settings. Existing library items are copied, not removed from their original destination.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .navigationTitle("Save Music")
            .toolbar { AppToolbar.item(placement: .cancellationAction) { Button("Keep Choosing") { showDestination = false } } }
        }
    }

    private func destinationButton(_ destination: MusicDestination, title: String) -> some View {
        Button(title) {
            for item in collected {
                library.add(item, to: destination)
                if destination != .general && newItemIDs.contains(item.id) {
                    library.remove(itemID: item.id, from: .general)
                }
            }
            library.select(destination: destination)
            showDestination = false
            onSave(destination, configuration)
        }
    }

    private func collect(_ item: MusicLibraryItem) {
        if let index = collected.firstIndex(where: { $0.id == item.id }) { collected[index] = item }
        else { collected.append(item) }
    }

    private func collectNewItems() {
        for item in library.items where !initialItemIDs.contains(item.id) {
            newItemIDs.insert(item.id)
            collect(item)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let failure): error = failure.localizedDescription
        case .success(let urls):
            importing = true
            Task { @MainActor in
                defer { importing = false }
                var failures: [String] = []
                for url in urls {
                    do {
                        if ["mov", "mp4", "m4v", "avi", "mkv"].contains(url.pathExtension.lowercased()) {
                            try await MusicManager.shared.importTrackAsync(from: url)
                        } else {
                            try MusicManager.shared.importTrack(from: url)
                        }
                    } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                }
                library.adoptMusicManagerTracks()
                await library.refreshLocalDurations()
                collectNewItems()
                if !failures.isEmpty { error = failures.joined(separator: "\n") }
            }
        }
    }

    private func libraryItem(for clip: WorkoutMusicClip) -> MusicLibraryItem {
        if let id = clip.sourceItemID, let item = library.item(id: id) { return item }
        let tracks = clip.tracks.map { track in
            let reference = track.filename.map { MusicLocalTrackReference(filename: $0, displayName: track.title, duration: track.duration) }
            let source: MusicSourceReference
            if let provider = track.provider.flatMap(MusicProvider.init(rawValue:)), let id = track.providerReference {
                source = .provider(provider: provider, id: id, title: track.title)
            } else { source = reference == nil ? .none : .local }
            return MusicCollectionTrack(id: track.id, title: track.title, duration: track.duration, source: source, localReference: reference)
        }
        return MusicLibraryItem(
            id: clip.sourceItemID ?? clip.id, title: clip.title, kind: tracks.count > 1 ? .playlist : .track,
            source: tracks.first?.source ?? .none, localReference: tracks.count == 1 ? tracks.first?.localReference : nil,
            duration: clip.sourceDuration, tracks: tracks
        )
    }
}

#Preview {
    NavigationStack {
        MusicSettingsView(library: MusicLibraryStore())
            .environmentObject(WorkoutStore())
    }
    .preferredColorScheme(.dark)
}
