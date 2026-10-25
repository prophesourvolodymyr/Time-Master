import Foundation

enum SettingsDestination: String, CaseIterable, Hashable, Identifiable {
    case profile
    case account
    case databaseSync
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
        case .account: "Tmax Account"
        case .databaseSync: "Database Sync"
        case .workoutTypes: "Workout Types"
        case .motivation: "Motivational Quotes"
        case .backup: "Backup & Transfer"
        case .notifications: "Workout Reminders"
        case .privacy: "Privacy"
        case .exerciseAI: "Exercise AI"
        case .about: "About Tmax"
        }
    }

    var detail: String {
        switch self {
        case .profile: "Local identity, collectibles, and verification"
        case .account: "One secure account for database sync and Ranked"
        case .databaseSync: "Cloud sync or fully local exercise data"
        case .workoutTypes: "Customize and create workout categories"
        case .motivation: "Spoken during workouts"
        case .backup: "Export or import your Tmax data"
        case .notifications: "Daily notifications on training days"
        case .privacy: "Choose what appears in your visitor preview"
        case .exerciseAI: "Name exercises from photos with OpenAI"
        case .about: "Version and build"
        }
    }

    var symbol: String {
        switch self {
        case .profile: "person.text.rectangle"
        case .account: "person.crop.circle"
        case .databaseSync: "arrow.triangle.2.circlepath.icloud"
        case .workoutTypes: "list.bullet.rectangle"
        case .motivation: "quote.bubble"
        case .backup: "archivebox"
        case .notifications: "bell.badge"
        case .privacy: "hand.raised"
        case .exerciseAI: "sparkles"
        case .about: "info.circle"
        }
    }

}
