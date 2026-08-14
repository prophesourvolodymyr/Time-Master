import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var aiStore = AIStore.shared
    @State private var selectedTab = 0
    @State private var showingSettings = false

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
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { _ in
                selectedTab = 0
            }
        } detail: {
            detailView
        }
        .buttonStyle(.plain)
        #else
        TabView(selection: $selectedTab) {
            HomeDashboardView(
                onBrowseWorkouts: { selectedTab = 1 },
                onBrowseDatabase: { selectedTab = 2 },
                onCreateWorkout: openWorkoutCreator
            )
            .environmentObject(workoutStore)
            .environmentObject(databaseStore)
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            WorkoutListView()
                .environmentObject(workoutStore)
                .tabItem { Label("Workouts", systemImage: "figure.run") }
                .tag(1)

            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
                .tabItem { Label("Database", systemImage: "cylinder.split.1x2") }
                .tag(2)

            AnalyticsView()
                .environmentObject(workoutStore)
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                .tag(3)

            AICoachView()
                .environmentObject(aiStore)
                .tabItem { Label("AI Coach", systemImage: "brain.head.profile") }
                .tag(4)
        }
        .tint(.white)
        #if os(iOS)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { _ in
            selectedTab = 0
        }
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
            .environmentObject(workoutStore)
            .environmentObject(databaseStore)
        case 1:
            WorkoutListView()
                .environmentObject(workoutStore)
        case 2:
            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
        case 3:
            AnalyticsView()
                .environmentObject(workoutStore)
        case 4:
            AICoachView()
                .environmentObject(aiStore)
        default:
            WorkoutListView()
                .environmentObject(workoutStore)
        }
    }

    private func openWorkoutCreator() {
        selectedTab = 1
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
