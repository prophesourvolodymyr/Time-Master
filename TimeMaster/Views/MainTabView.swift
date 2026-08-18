import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var aiStore = AIStore.shared
    @StateObject private var outdoorStore = OutdoorActivityStore()
    @State private var selectedTab = SlotNavigationItem.index(for: 0)
    @State private var showingSettings = false
    @State private var requestedWorkoutID: UUID?
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    @State private var activeOutdoorPlannedRoute: PlannedRoute?
#endif
#if os(macOS)
    private let macSlotBarHeight: CGFloat = 196
#endif


    var body: some View {
        Group {
        #if os(macOS)
        SlotNavigationContainer(
            selection: $selectedTab,
            barHeight: macSlotBarHeight
        ) {
            detailView
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { notification in
            routeToWorkoutDetail(notification)
        }
        #else
        SlotNavigationContainer(selection: $selectedTab) {
            detailView
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { notification in
            routeToWorkoutDetail(notification)
        }
        #if os(iOS)
        .sheet(item: $activeOutdoorKind, onDismiss: {
            activeOutdoorPlannedRoute = nil
        }) { kind in
            OutdoorRecorderView(kind: kind, store: outdoorStore, plannedRoute: activeOutdoorPlannedRoute)
        }
        #endif
        #endif
        }
#if os(macOS)
        .buttonStyle(.plain)
#endif
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsCommand)) { _ in
            showingSettings = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 520)
                #endif
        }
    }

    private var selectedDestinationID: Int {
        guard SlotNavigationItem.timeMaster.indices.contains(selectedTab) else { return 0 }
        return SlotNavigationItem.timeMaster[selectedTab].id
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedDestinationID {
        case 0:
            homeDestination
        case 1:
            WorkoutListView(requestedWorkoutID: $requestedWorkoutID)
                .environmentObject(outdoorStore)
                .environmentObject(workoutStore)
        case 2:
            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
        case 3:
            AnalyticsView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
        case 4:
            AICoachView()
                .environmentObject(aiStore)
        case 5:
            ProfileView()
                .environmentObject(outdoorStore)
        default:
            homeDestination
        }
    }
#if os(iOS)
    @ViewBuilder
    private var homeDestination: some View {
        HomeDashboardView(
            onBrowseWorkouts: { selectedTab = SlotNavigationItem.index(for: 1) },
            onBrowseDatabase: { selectedTab = SlotNavigationItem.index(for: 2) },
            onCreateWorkout: openWorkoutCreator,
            onStartOutdoor: { kind, route in
                activeOutdoorPlannedRoute = route
                activeOutdoorKind = kind
            }
        )
        .environmentObject(outdoorStore)
        .environmentObject(workoutStore)
        .environmentObject(databaseStore)
    }
#else
    @ViewBuilder
    private var homeDestination: some View {
        HomeDashboardView(
            onBrowseWorkouts: { selectedTab = SlotNavigationItem.index(for: 1) },
            onBrowseDatabase: { selectedTab = SlotNavigationItem.index(for: 2) },
            onCreateWorkout: openWorkoutCreator
        )
        .environmentObject(outdoorStore)
        .environmentObject(workoutStore)
        .environmentObject(databaseStore)
    }
#endif

    private func openWorkoutCreator() {
        selectedTab = SlotNavigationItem.index(for: 1)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
        }
    }

    private func routeToWorkoutDetail(_ notification: Notification) {
        guard let workoutID = notification.userInfo?["workoutID"] as? UUID else { return }
        selectedTab = SlotNavigationItem.index(for: 1)
        requestedWorkoutID = workoutID
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
