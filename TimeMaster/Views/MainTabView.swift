import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @StateObject private var databaseStore = DatabaseStore.shared

    var body: some View {
        TabView {
            WorkoutListView()
                .environmentObject(workoutStore)
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            DatabaseView()
                .environmentObject(databaseStore)
                .tabItem {
                    Label("Database", systemImage: "cylinder.split.1x2")
                }

            AnalyticsView()
                .environmentObject(workoutStore)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }

            HistoryView()
                .environmentObject(workoutStore)
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .environmentObject(workoutStore)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.white)
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutStore())
        .preferredColorScheme(.dark)
}
