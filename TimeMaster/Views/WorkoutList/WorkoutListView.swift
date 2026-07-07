import SwiftUI
import WidgetKit

struct WorkoutListView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var navigationPath: [Workout] = []
    @State private var showingAddWorkout = false
    @State private var newWorkoutName = ""
    @State private var newWorkoutType: WorkoutType = .strength
    @State private var newWorkoutColor: String = "FFFFFF"
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.background.ignoresSafeArea()

                if store.workouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.workouts) { workout in
                                NavigationLink(value: workout) {
                                    WorkoutCard(workout: workout)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button {
                                        pinToWidget(workout)
                                    } label: {
                                        Label("Pin to Widget", systemImage: "pin")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        store.deleteWorkout(workout)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddWorkout = true } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .sheet(isPresented: $showingAddWorkout) {
                addWorkoutSheet
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(store)
            }
            // Widget deep-link: push straight to the workout detail
            .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { notif in
                guard let id = notif.userInfo?["workoutID"] as? UUID,
                      let workout = store.workouts.first(where: { $0.id == id }) else { return }
                navigationPath = [workout]
            }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            Text("No Workouts Yet")
                .font(.title2).fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            Text("Tap + to create your first workout")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var addWorkoutSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        TextField("e.g., Morning HIIT", text: $newWorkoutName)
                            .padding(16)
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .foregroundColor(Theme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                             ForEach(WorkoutType.all(custom: store.customWorkoutTypes), id: \.id) { type in
                                 Button {
                                     newWorkoutType = type
                                 } label: {
                                     HStack {
                                         Image(systemName: type.icon)
                                         Text(type.name)
                                     }
                                    .font(.subheadline)
                                    .fontWeight(newWorkoutType == type ? .semibold : .regular)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(newWorkoutType == type ? Color.white.opacity(0.2) : Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(newWorkoutType == type ? Color.white : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon Color")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        IconColorPicker(selectedHex: $newWorkoutColor)
                    }

                    Spacer()

                    Button {
                        if !newWorkoutName.isEmpty {
                            store.addWorkout(name: newWorkoutName, type: newWorkoutType, colorHex: newWorkoutColor)
                            newWorkoutName = ""
                            newWorkoutType = .strength
                            newWorkoutColor = "FFFFFF"
                            showingAddWorkout = false
                        }
                    } label: {
                        Text("Create Workout")
                            .font(.headline)
                            .foregroundColor(newWorkoutName.isEmpty ? Color.white.opacity(0.3) : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(newWorkoutName.isEmpty ? Theme.surface : Color.white)
                            .cornerRadius(12)
                    }
                    .disabled(newWorkoutName.isEmpty)
                }
                .padding(16)
            }
            .navigationTitle("New Workout")
            #if os(iOS)
#if os(iOS)
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
#endif
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newWorkoutName = ""
                        newWorkoutType = .strength
                        newWorkoutColor = "FFFFFF"
                        showingAddWorkout = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Actions

    private func pinToWidget(_ workout: Workout) {
        let defaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        defaults?.set(workout.name,           forKey: "pinned_workout_name")
        defaults?.set(workout.id.uuidString,  forKey: "pinned_workout_id")
        defaults?.set(workout.colorHex,       forKey: "pinned_workout_color")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    WorkoutListView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
