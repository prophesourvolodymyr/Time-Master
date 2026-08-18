import SwiftUI

struct SlotNavigationItem: Identifiable, Hashable {
    let id: Int
    let emoji: String
    let title: String
    let accessibilityHint: String

    static let timeMaster: [SlotNavigationItem] = [
        SlotNavigationItem(id: 4, emoji: "🧠", title: "AI Coach", accessibilityHint: "Opens your AI coach."),
        SlotNavigationItem(id: 5, emoji: "👤", title: "Profile", accessibilityHint: "Shows your profile and history."),
        SlotNavigationItem(id: 0, emoji: "🏠", title: "Home", accessibilityHint: "Shows your daily dashboard."),
        SlotNavigationItem(id: 1, emoji: "🏋️", title: "Workouts", accessibilityHint: "Shows your workouts."),
        SlotNavigationItem(id: 2, emoji: "🗄️", title: "Database", accessibilityHint: "Shows your exercise database."),
        SlotNavigationItem(id: 3, emoji: "📊", title: "Analytics", accessibilityHint: "Shows your workout analytics.")
    ]

    static func index(for destinationID: Int) -> Int {
        timeMaster.firstIndex { $0.id == destinationID } ?? 0
    }
}
