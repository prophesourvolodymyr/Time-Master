import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var aiStore = AIStore.shared
    @StateObject private var outdoorStore = OutdoorActivityStore()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var requestedWorkoutID: UUID?
    #if os(iOS)
    @State private var activeOutdoorKind: OutdoorActivityKind?
    @State private var activeOutdoorPlannedRoute: PlannedRoute?
#endif


    var body: some View {
        Group {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Home", systemImage: "house.fill")
                    .tag(0)
                Label("Workouts", systemImage: "figure.run")
                    .tag(1)
                Label("Database", systemImage: "cylinder.split.1x2")
                    .tag(2)
                Label("Analytics", systemImage: "chart.bar.xaxis")
                    .tag(3)
                Label("AI Coach", systemImage: "brain.head.profile")
                    .tag(4)
                Label("Profile", systemImage: "person.crop.circle")
                    .tag(5)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { notification in
                routeToWorkoutDetail(notification)
            }
        } detail: {
            detailView
                .appOpeningFade(id: selectedTab)
        }
        .buttonStyle(.plain)
        #else
        TabView(selection: $selectedTab) {
            HomeDashboardView(
                onBrowseWorkouts: { selectedTab = 1 },
                onBrowseDatabase: { selectedTab = 2 },
                onCreateWorkout: openWorkoutCreator,
                onStartOutdoor: { kind, route in
                    activeOutdoorPlannedRoute = route
                    activeOutdoorKind = kind
                }
            )
            .environmentObject(workoutStore)
            .environmentObject(databaseStore)
            .environmentObject(outdoorStore)
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            WorkoutListView(requestedWorkoutID: $requestedWorkoutID)
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
                .tabItem { Label("Workouts", systemImage: "figure.run") }
                .tag(1)

            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
                .tabItem { Label("Database", systemImage: "cylinder.split.1x2") }
                .tag(2)

            AnalyticsView()
                .environmentObject(workoutStore)
                .environmentObject(outdoorStore)
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                .tag(3)

            AICoachView()
                .environmentObject(aiStore)
                .tabItem { Label("AI Coach", systemImage: "brain.head.profile") }
                .tag(4)

            ProfileView()
                .environmentObject(outdoorStore)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(5)
        }
        .tint(.white)
        #if os(iOS)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        #endif
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
        .appHeaderFade()
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

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case 0:
            HomeDashboardView(
                onBrowseWorkouts: { selectedTab = 1 },
                onBrowseDatabase: { selectedTab = 2 },
                onCreateWorkout: openWorkoutCreator
            )
            .environmentObject(outdoorStore)
            .environmentObject(workoutStore)
            .environmentObject(databaseStore)
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
            WorkoutListView(requestedWorkoutID: $requestedWorkoutID)
                .environmentObject(workoutStore)
        }
    }

    private func openWorkoutCreator() {
        selectedTab = 1
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
        }
    }

    private func routeToWorkoutDetail(_ notification: Notification) {
        guard let workoutID = notification.userInfo?["workoutID"] as? UUID else { return }
        selectedTab = 1
        requestedWorkoutID = workoutID
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
