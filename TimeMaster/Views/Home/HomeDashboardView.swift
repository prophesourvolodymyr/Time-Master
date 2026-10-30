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
                    onStartOutdoor: onStartOutdoor,
                    chromeHeader: homeHeader
                )
            }
            .navigationTitle("")
            .preference(key: SlotNavigationEditingPreferenceKey.self, value: isEditing)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
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
            .oneHandedActions(id: "home", actions: homeActions)
            .workoutPlayerPage(item: $playerWorkout) { workout in
                WorkoutPlayerView(workout: workout)
                    .environmentObject(store)
                    .environmentObject(databaseStore)
            }
            .sheet(isPresented: $showingWidgetPicker, onDismiss: insertPendingWidget) {
                HomeWidgetPicker(widgetStore: widgetStore) { kind, footprint in
                    pendingWidget = HomeWidgetInstance(kind: kind, footprint: footprint)
                    showingWidgetPicker = false
                }
                .keyNavHost()
            }
        }
    }

    private func homeHeader(progress: CGFloat, metrics: ScrollingChromeMetrics) -> some View {
        let morph = metrics.morph(progress)
        let width = metrics.controlWidth(morph)
        let height = metrics.controlHeight(morph)
        return ScrollingChromeHeader(title: "Home", progress: morph, metrics: metrics) {
            HStack(spacing: metrics.controlSpacing) {
                if isEditing {
                    addWidgetButton(progress: morph, width: width, height: height)
                    doneEditingButton(progress: morph, width: width, height: height)
                } else {
                    editLayoutButton(progress: morph, width: width, height: height)
                    settingsButton(progress: morph, width: width, height: height)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea(edges: .top))
    }

    private var homeActions: [ReachabilityAction] {
        var actions = [
            ReachabilityAction("add-widget", title: "Add Widget") {
                addWidgetButton()
            }
        ]
        if isEditing {
            actions.append(ReachabilityAction("done-editing", title: "Done") {
                doneEditingButton()
            })
        } else {
            actions.append(ReachabilityAction("edit-layout", title: "Edit Layout") {
                editLayoutButton()
            })
            actions.append(ReachabilityAction("settings", title: "Settings") {
                settingsButton()
            })
        }
        return actions
    }

    private func addWidgetButton(progress: CGFloat = 1, width: CGFloat = 48, height: CGFloat = 48) -> some View {
        Button {
            showingWidgetPicker = true
        } label: {
            ScrollingChromeControl(systemImage: "plus", title: "Add Widget", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Add Home widget")
    }

    private func doneEditingButton(progress: CGFloat = 1, width: CGFloat = 48, height: CGFloat = 48) -> some View {
        Button {
            setEditing(false)
        } label: {
            ScrollingChromeControl(systemImage: "checkmark", title: "Done", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Done editing Home")
    }

    private func editLayoutButton(progress: CGFloat = 1, width: CGFloat = 48, height: CGFloat = 48) -> some View {
        Button {
            setEditing(true)
        } label: {
            ScrollingChromeControl(systemImage: "pencil", title: "Edit", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Edit Home layout")
    }

    private func settingsButton(progress: CGFloat = 1, width: CGFloat = 48, height: CGFloat = 48) -> some View {
        Button {
            NotificationCenter.default.post(name: .openSettingsCommand, object: nil)
        } label: {
            ScrollingChromeControl(systemImage: "gearshape", title: "Settings", progress: progress, width: width, height: height)
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .scrollingChromeRing(progress: progress, width: width, height: height)
        .accessibilityLabel("Open Settings")
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
