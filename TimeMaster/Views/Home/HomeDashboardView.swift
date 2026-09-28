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
    @State private var pendingWidget: HomeWidgetInstance?
    @State private var insertedWidgetID: UUID?
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
                    insertedWidgetID: insertedWidgetID,
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
            .preference(key: SlotNavigationEditingPreferenceKey.self, value: isEditing)
            .toolbar {
                toolbarContent
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .onAppear {
                now = Date()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6, maximumDistance: 10)
                    .onEnded { _ in setEditing(true) },
                including: isEditing ? .subviews : .all
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
            .sheet(isPresented: $showingWidgetPicker, onDismiss: insertPendingWidget) {
                HomeWidgetPicker(widgetStore: widgetStore) { kind, footprint in
                    pendingWidget = HomeWidgetInstance(kind: kind, footprint: footprint)
                    showingWidgetPicker = false
                }
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

    private func insertPendingWidget() {
        guard let pendingWidget else { return }
        self.pendingWidget = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.48, dampingFraction: 0.78)) {
            insertedWidgetID = widgetStore.add(pendingWidget.kind, footprint: pendingWidget.footprint)
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
