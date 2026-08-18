import SwiftUI

enum SlotNavigationPresentation: Equatable {
    case full
    case inline
    case hidden
}

struct SlotNavigationPresentationPreferenceKey: PreferenceKey {
    static let defaultValue: SlotNavigationPresentation? = nil

    static func reduce(
        value: inout SlotNavigationPresentation?,
        nextValue: () -> SlotNavigationPresentation?
    ) {
        if let next = nextValue() {
            value = next
        }
    }
}

extension View {
    func slotNavigationPresentation(_ presentation: SlotNavigationPresentation) -> some View {
        preference(key: SlotNavigationPresentationPreferenceKey.self, value: presentation)
    }
}

struct SlotNavigationItem: Identifiable, Hashable {
    let id: Int
    let symbolName: String
    let title: String
    let accessibilityHint: String

    static let timeMaster: [SlotNavigationItem] = [
        SlotNavigationItem(id: 4, symbolName: "brain.head.profile", title: "AI Coach", accessibilityHint: "Opens your AI coach."),
        SlotNavigationItem(id: 5, symbolName: "person.crop.circle", title: "Profile", accessibilityHint: "Shows your profile and history."),
        SlotNavigationItem(id: 0, symbolName: "house.fill", title: "Home", accessibilityHint: "Shows your daily dashboard."),
        SlotNavigationItem(id: 1, symbolName: "dumbbell.fill", title: "Workouts", accessibilityHint: "Shows your workouts."),
        SlotNavigationItem(id: 2, symbolName: "books.vertical.fill", title: "Database", accessibilityHint: "Shows your exercise database."),
        SlotNavigationItem(id: 3, symbolName: "chart.bar.fill", title: "Analytics", accessibilityHint: "Shows your workout analytics.")
    ]

    static func index(for destinationID: Int) -> Int {
        timeMaster.firstIndex { $0.id == destinationID } ?? 0
    }
}
