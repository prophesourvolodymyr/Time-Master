import SwiftUI

@main
struct TimeMasterApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var databaseStore = DatabaseStore.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(databaseStore)
                .preferredColorScheme(.dark)
        }
    }
}