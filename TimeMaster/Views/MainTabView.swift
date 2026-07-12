import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var aiStore = AIStore.shared
    @State private var selectedTab = 0

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Workouts", systemImage: "figure.run")
                    .tag(0)
                Label("Database", systemImage: "cylinder.split.1x2")
                    .tag(1)
                Label("Analytics", systemImage: "chart.bar.xaxis")
                    .tag(2)
                Label("AI Coach", systemImage: "brain.head.profile")
                    .tag(3)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { _ in
                selectedTab = 0
            }
        } detail: {
            detailView
        }
        #else
        TabView(selection: $selectedTab) {
            WorkoutListView()
                .environmentObject(workoutStore)
                .tabItem { Label("Workouts", systemImage: "figure.run") }
                .tag(0)

            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
                .tabItem { Label("Database", systemImage: "cylinder.split.1x2") }
                .tag(1)

            AnalyticsView()
                .environmentObject(workoutStore)
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                .tag(2)

            AICoachView()
                .environmentObject(aiStore)
                .tabItem { Label("AI Coach", systemImage: "brain.head.profile") }
                .tag(3)
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

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case 0:
            WorkoutListView()
                .environmentObject(workoutStore)
        case 1:
            DatabaseView()
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
        case 2:
            AnalyticsView()
                .environmentObject(workoutStore)
        case 3:
            AICoachView()
                .environmentObject(aiStore)
        default:
            WorkoutListView()
                .environmentObject(workoutStore)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
