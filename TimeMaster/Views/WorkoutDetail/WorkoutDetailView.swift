import SwiftUI
import PhotosUI

struct WorkoutDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var workout: Workout
    @State private var showingSectionEditor = false
    @State private var editingSection: Section?
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: Section?
    @State private var showPlayer = false
    @State private var showingWorkoutSettings = false
    @State private var mediaPreviewSection: Section? = nil

    init(workout: Workout) {
        _workout = State(initialValue: workout)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if workout.sections.isEmpty {
                emptySectionsView
            } else {
                VStack(spacing: 0) {
                    sectionList
                    startButton
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showPlayer) {
            WorkoutPlayerView(workout: workout)
                .environmentObject(store)
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingSectionEditor) {
            SectionEditorView(section: editingSection) { savedSection in
                if editingSection != nil {
                    store.updateSection(in: workout, section: savedSection)
                } else {
                    store.addSection(to: workout, section: savedSection)
                }
                syncWorkout()
                autoSyncExerciseToDatabase(savedSection)
            }
            .environmentObject(DatabaseStore.shared)
        }
        .alert("Delete Section", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { sectionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let section = sectionToDelete {
                    store.deleteSection(in: workout, section: section)
                    syncWorkout()
                }
                sectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this section?")
        }
        .fullScreenCover(item: $mediaPreviewSection) { section in
            MediaPreviewSheet(items: section.mediaItems)
        }
        .sheet(isPresented: $showingWorkoutSettings) {
            WorkoutSettingsView(workout: $workout, store: store)
        }
        .onReceive(store.$workouts) { _ in syncWorkout() }
    }

    // MARK: - Sub-views

    private var emptySectionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            Text("No Sections Yet")
                .font(.title2).fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            Text("Tap + to add exercises")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var sectionList: some View {
        List {
            ForEach(workout.sections) { section in
                sectionCell(section)
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            sectionToDelete = section
                            showingDeleteAlert = true
                        } label: { Label("Delete", systemImage: "trash") }
                        .tint(.red)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            editingSection = section
                            showingSectionEditor = true
                        } label: { Label("Edit", systemImage: "pencil") }
                        .tint(Color.white.opacity(0.3))
                    }
            }
            .onMove(perform: moveSections)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func sectionCell(_ section: Section) -> some View {
        let idx = workout.sections.firstIndex(where: { $0.id == section.id }) ?? 0
        let isLast = idx == workout.sections.count - 1
        VStack(spacing: 0) {
            SectionRow(section: section, onThumbnailTap: section.mediaItems.isEmpty ? nil : {
                mediaPreviewSection = section
            })
            .contentShape(Rectangle())
            .onTapGesture {
                editingSection = section
                showingSectionEditor = true
            }
            if !isLast {
                RestSeparatorRow(
                    rest: restBinding(for: idx),
                    defaultRest: workout.restBetweenSections
                )
            }
        }
    }

    private func restBinding(for idx: Int) -> Binding<Int> {
        Binding<Int>(
            get: {
                guard idx < workout.sections.count else { return workout.restBetweenSections }
                return workout.sections[idx].customRestAfter ?? workout.restBetweenSections
            },
            set: { newVal in
                guard idx < workout.sections.count else { return }
                workout.sections[idx].customRestAfter = newVal
                store.updateWorkout(workout)
            }
        )
    }

    @ViewBuilder
    private var startButton: some View {
        if !workout.sections.isEmpty {
            Button { showPlayer = true } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showingWorkoutSettings = true } label: {
                    Label("Workout Settings", systemImage: "slider.horizontal.3")
                }
                Button { store.cloneWorkout(workout) } label: {
                    Label("Clone Workout", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) { store.deleteWorkout(workout) } label: {
                    Label("Delete Workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.white)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                editingSection = nil
                showingSectionEditor = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Helpers

    private func syncWorkout() {
        if let index = store.workouts.firstIndex(where: { $0.id == workout.id }) {
            workout = store.workouts[index]
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        store.reorderSections(in: workout, from: source, to: destination)
        syncWorkout()
    }

    private func autoSyncExerciseToDatabase(_ section: Section) {
        let db = DatabaseStore.shared
        let nameExists = exerciseExistsInDatabase(name: section.name, store: db)
        if !nameExists {
            let exercise = Exercise(
                name: section.name,
                duration: section.duration,
                mediaItems: section.mediaItems
            )
            db.addRootExercise(exercise)
        }
    }

    private func exerciseExistsInDatabase(name: String, store: DatabaseStore) -> Bool {
        if store.rootExercises.contains(where: { $0.name == name }) { return true }
        return folderContainsExercise(name: name, folders: store.rootFolders)
    }

    private func folderContainsExercise(name: String, folders: [ExerciseFolder]) -> Bool {
        for f in folders {
            if f.exercises.contains(where: { $0.name == name }) { return true }
            if folderContainsExercise(name: name, folders: f.subfolders) { return true }
        }
        return false
    }
}

private struct RestSeparatorRow: View {
    @Binding var rest: Int
    let defaultRest: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text("Rest")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Button {
                if rest >= 5 { rest -= 5 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest > 0 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest <= 0)
            .buttonStyle(.plain)
            Text("\(rest)s")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(rest == defaultRest ? Theme.textSecondary : .white)
                .frame(minWidth: 32)
            Button {
                if rest < 300 { rest += 5 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest < 300 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest >= 300)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.surface2.opacity(0.6))
    }
}

// MARK: - WorkoutSettingsView

private struct WorkoutSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var workout: Workout
    @ObservedObject var store: WorkoutStore
    @ObservedObject var musicManager = MusicManager.shared

    @State private var restBetweenSections: Int
    @State private var colorHex: String
    @State private var selectedTrackIndices: Set<Int>

    init(workout: Binding<Workout>, store: WorkoutStore) {
        _workout = workout
        _store = ObservedObject(wrappedValue: store)
        _restBetweenSections = State(initialValue: workout.wrappedValue.restBetweenSections)
        _colorHex = State(initialValue: workout.wrappedValue.colorHex)
        _selectedTrackIndices = State(initialValue: {
            var set = Set<Int>()
            for filename in workout.wrappedValue.musicTrackFilenames {
                if let idx = MusicManager.shared.trackFilenames.firstIndex(of: filename) {
                    set.insert(idx)
                }
            }
            return set
        }())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        restSection
                        colorSection
                        musicSection
                        infoSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Workout Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest Between Sections")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack {
                Text("\(restBetweenSections)s")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $restBetweenSections, in: 0...300, step: 5).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
            Text("Default rest applied between sections unless overridden per-section.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon Color")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            IconColorPicker(selectedHex: $colorHex)
        }
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Music")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            if musicManager.trackFilenames.isEmpty {
                Text("No music tracks added. Add tracks in Settings → Background Music.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(musicManager.trackFilenames.enumerated()), id: \.offset) { index, filename in
                        HStack(spacing: 12) {
                            Image(systemName: selectedTrackIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedTrackIndices.contains(index) ? .white : Color.white.opacity(0.28))
                            Text(filename)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTrackIndices.contains(index) {
                                selectedTrackIndices.remove(index)
                            } else {
                                selectedTrackIndices.insert(index)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                Text("Selected tracks play during this workout. If none selected, all tracks play.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(label: "Type", value: workout.type.rawValue)
            infoRow(label: "Sections", value: "\(workout.sections.count)")
            infoRow(label: "Total Duration", value: formatDuration(workout.totalDuration))
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textPrimary)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private func saveSettings() {
        workout.restBetweenSections = restBetweenSections
        workout.colorHex = colorHex
        workout.musicTrackFilenames = selectedTrackIndices.sorted().map {
            musicManager.trackFilenames[$0]
        }
        store.updateWorkout(workout)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Morning HIIT", sections: [
            Section(name: "Burpees",  duration: 45),
            Section(name: "Push-ups", duration: 30)
        ]))
    }
    .environmentObject(WorkoutStore())
    .preferredColorScheme(.dark)
}
