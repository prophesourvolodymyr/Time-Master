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
            SectionRow(section: section)
            if !isLast {
                RestSeparatorRow(
                    rest: Binding(
                        get: {
                            idx < workout.sections.count
                                ? (workout.sections[idx].customRestAfter ?? workout.restBetweenSections)
                                : workout.restBetweenSections
                        },
                        set: { newVal in
                            guard idx < workout.sections.count else { return }
                            workout.sections[idx].customRestAfter = newVal
                            store.updateWorkout(workout)
                            syncWorkout()
                        }
                    ),
                    defaultRest: workout.restBetweenSections
                )
            }
        }
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
            Text("\(rest)s")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(rest == defaultRest ? Theme.textSecondary : .white)
            Stepper("", value: $rest, in: 0...300, step: 5)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.surface2.opacity(0.6))
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
