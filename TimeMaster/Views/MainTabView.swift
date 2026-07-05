import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared
    @StateObject private var aiStore = AIStore.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutListView()
                .environmentObject(workoutStore)
                .tabItem { Label("Workouts", systemImage: "figure.run") }
                .tag(0)

            DatabaseView()
                .environmentObject(databaseStore)
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
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        // When the widget deep-links to a workout detail, make sure we're on the Workouts tab first.
        .onReceive(NotificationCenter.default.publisher(for: .openWorkoutDetail)) { _ in
            selectedTab = 0
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}

