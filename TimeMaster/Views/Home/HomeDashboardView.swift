import SwiftUI
import Combine

struct HomeDashboardView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onBrowseWorkouts: () -> Void
    let onBrowseDatabase: () -> Void
    let onCreateWorkout: () -> Void
    var onStartOutdoor: (OutdoorActivityKind, PlannedRoute?, UUID?) -> Void = { _, _, _ in }

    @StateObject private var widgetStore = HomeWidgetStore()
    @State private var playerWorkout: Workout?
    @State private var showingSettings = false
    @State private var showingWidgetPicker = false
    @State private var isEditing = false
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                HomeWidgetCanvas(
                    widgetStore: widgetStore,
                    workoutStore: store,
                    databaseStore: databaseStore,
                    outdoorStore: outdoorStore,
                    isEditing: $isEditing,
                    now: now,
                    skippedScheduledInstanceIDs: widgetStore.skippedScheduledInstanceIDs,
                    onStartWorkout: startWorkout,
                    onBrowseWorkouts: onBrowseWorkouts,
                    onBrowseDatabase: onBrowseDatabase,
                    onCreateWorkout: onCreateWorkout,
                    onStartOutdoor: onStartOutdoor
                )
            }
            .navigationTitle("")
            .toolbar {
                toolbarContent
            }
            .onAppear {
                now = Date()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.75)
                    .onEnded { _ in
                        guard !isEditing else { return }
                        setEditing(true)
                    }
            )
            .sheet(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(databaseStore)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(outdoorStore)
            }
            .sheet(isPresented: $showingWidgetPicker) {
                HomeWidgetPicker(widgetStore: widgetStore)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            AppToolbar.iconItem(placement: .primaryAction) {
                Button {
                    showingWidgetPicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Add Home widget")
            }
            AppToolbar.iconItem(placement: .primaryAction) {
                Button {
                    setEditing(false)
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Done editing Home")
            }
        } else {
            AppToolbar.iconItem(placement: .primaryAction) {
                Button {
                    setEditing(true)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Edit Home layout")
            }
            AppToolbar.iconItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Open Settings")
            }
        }
    }

    private func setEditing(_ editing: Bool) {
        let animation = reduceMotion
            ? Animation.easeOut(duration: 0.12)
            : Animation.spring(response: 0.32, dampingFraction: 0.88)
        withAnimation(animation) {
            isEditing = editing
        }
    }

    private func startWorkout(_ workout: Workout) {
        isEditing = false
        playerWorkout = workout
    }
}

#Preview {
    HomeDashboardView(
        onBrowseWorkouts: {},
        onBrowseDatabase: {},
        onCreateWorkout: {}
    )
    .environmentObject(WorkoutStore())
    .environmentObject(DatabaseStore.shared)
    .environmentObject(OutdoorActivityStore())
    .preferredColorScheme(.dark)
}
