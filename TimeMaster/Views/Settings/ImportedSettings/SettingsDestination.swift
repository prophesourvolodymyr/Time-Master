import Foundation

enum SettingsDestination: String, CaseIterable, Hashable, Identifiable {
    case profile
    case workoutTypes
    case motivation
    case backup
    case notifications
    case privacy
    case exerciseAI
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "Profile"
        case .workoutTypes: "Workout Types"
        case .motivation: "Motivational Quotes"
        case .backup: "Backup & Transfer"
        case .notifications: "Workout Reminders"
        case .privacy: "Privacy"
        case .exerciseAI: "Exercise AI"
        case .about: "About TimeMaster"
        }
    }

    var detail: String {
        switch self {
        case .profile: "Local identity, collectibles, and verification"
        case .workoutTypes: "Customize and create workout categories"
        case .motivation: "Spoken during workouts"
        case .backup: "Export or import your TimeMaster data"
        case .notifications: "Daily notifications on training days"
        case .privacy: "Choose what appears in your visitor preview"
        case .exerciseAI: "Name exercises from photos with OpenAI"
        case .about: "Version and build"
        }
    }

    var symbol: String {
        switch self {
        case .profile: "person.text.rectangle"
        case .workoutTypes: "list.bullet.rectangle"
        case .motivation: "quote.bubble"
        case .backup: "arrow.triangle.2.circlepath.icloud"
        case .notifications: "bell.badge"
        case .privacy: "hand.raised"
        case .exerciseAI: "sparkles"
        case .about: "info.circle"
        }
    }

}
