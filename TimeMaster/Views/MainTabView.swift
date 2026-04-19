import SwiftUI
import UniformTypeIdentifiers

struct MainTabView: View {
    @StateObject private var databaseStore = DatabaseStore.shared

    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            DatabaseView()
                .environmentObject(databaseStore)
                .tabItem {
                    Label("Database", systemImage: "cylinder.split.1x2")
                }

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
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
