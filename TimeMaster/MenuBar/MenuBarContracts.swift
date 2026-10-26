import Combine
import Foundation
import SwiftUI

enum MenuBarLevel: String, CaseIterable, Identifiable {
    case quiet
    case glance
    case alert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: "Quiet"
        case .glance: "Glance"
        case .alert: "Alert"
        }
    }

    var detail: String {
        switch self {
        case .quiet: "Icon only. No pop-ups or sound."
        case .glance: "Silent tips. Never takes focus."
        case .alert: "Tips with sound. Never takes focus."
        }
    }
}

enum MenuBarMomentKind: String, CaseIterable, Identifiable {
    case countdown
    case restStarted
    case sectionChanged
    case halfway
    case lastMinute
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown: "Countdown"
        case .restStarted: "Rest starts"
        case .sectionChanged: "New section"
        case .halfway: "Halfway"
        case .lastMinute: "Last minute"
        case .finished: "Finished"
        }
    }

    var detail: String {
        switch self {
        case .countdown: "The last 5 seconds before the next exercise starts."
        case .restStarted: "When a rest begins, with a quote."
        case .sectionChanged: "When the workout moves on to its next section."
        case .halfway: "When half of the workout is done."
        case .lastMinute: "When one minute of the workout is left."
        case .finished: "When the workout is complete."
        }
    }

    static let defaults: Set<MenuBarMomentKind> = [.countdown, .restStarted, .sectionChanged, .finished]
}

enum MenuBarPage: String, CaseIterable, Identifiable {
    case home
    case activity
    case workouts
    case schedule
    case coach
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .activity: "Activity"
        case .workouts: "Workouts"
        case .schedule: "Schedule"
        case .coach: "Coach"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .activity: "chart.bar.fill"
        case .workouts: "dumbbell.fill"
        case .schedule: "calendar"
        case .coach: "brain.head.profile"
        case .settings: "gearshape.fill"
        }
    }
}

enum MenuBarPopupMetrics {
    static let width: CGFloat = 380
    static let height: CGFloat = 560
}

enum MenuBarFormat {
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func minutes(_ seconds: Int) -> String {
        let total = max(0, seconds)
        if total < 60 { return "\(total) sec" }
        let minutes = Int((Double(total) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

struct MenuBarPopupActions {
    var startWorkout: (UUID?) -> Void = { _ in }
    var openPage: (SlotNavigationDestination, String?) -> Void = { _, _ in }
    var openWorkoutDetail: (UUID) -> Void = { _ in }
    var newWorkout: () -> Void = {}
    var showMainWindow: () -> Void = {}
    var quit: () -> Void = {}
    var requestKeyboard: () -> Void = {}
}

private struct MenuBarPopupActionsKey: EnvironmentKey {
    static let defaultValue = MenuBarPopupActions()
}

extension EnvironmentValues {
    var menuBarActions: MenuBarPopupActions {
        get { self[MenuBarPopupActionsKey.self] }
        set { self[MenuBarPopupActionsKey.self] = newValue }
    }
}

@MainActor
final class MenuBarPreferences: ObservableObject {
    static let shared = MenuBarPreferences()

    private enum Key {
        static let enabled = "menuBar.enabled"
        static let level = "menuBar.level"
        static let moments = "menuBar.moments"
        static let quotes = "menuBar.quotes"
        static let suggestions = "menuBar.suggestions"
        static let calmWhenFront = "menuBar.calmWhenTmaxIsFront"
        static let showsLabel = "menuBar.showsLabel"
    }

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    @Published var level: MenuBarLevel {
        didSet { defaults.set(level.rawValue, forKey: Key.level) }
    }

    @Published var enabledMoments: Set<MenuBarMomentKind> {
        didSet { defaults.set(enabledMoments.map(\.rawValue).sorted(), forKey: Key.moments) }
    }

    @Published var showsQuotes: Bool {
        didSet { defaults.set(showsQuotes, forKey: Key.quotes) }
    }

    @Published var showsSuggestions: Bool {
        didSet { defaults.set(showsSuggestions, forKey: Key.suggestions) }
    }

    @Published var calmWhenTmaxIsFront: Bool {
        didSet { defaults.set(calmWhenTmaxIsFront, forKey: Key.calmWhenFront) }
    }

    @Published var showsLabel: Bool {
        didSet { defaults.set(showsLabel, forKey: Key.showsLabel) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        level = defaults.string(forKey: Key.level).flatMap(MenuBarLevel.init(rawValue:)) ?? .quiet
        if let stored = defaults.array(forKey: Key.moments) as? [String] {
            enabledMoments = Set(stored.compactMap(MenuBarMomentKind.init(rawValue:)))
        } else {
            enabledMoments = MenuBarMomentKind.defaults
        }
        showsQuotes = defaults.object(forKey: Key.quotes) as? Bool ?? true
        showsSuggestions = defaults.object(forKey: Key.suggestions) as? Bool ?? true
        calmWhenTmaxIsFront = defaults.object(forKey: Key.calmWhenFront) as? Bool ?? true
        showsLabel = defaults.object(forKey: Key.showsLabel) as? Bool ?? true
    }

    func isMomentEnabled(_ kind: MenuBarMomentKind) -> Bool {
        enabledMoments.contains(kind)
    }

    func setMoment(_ kind: MenuBarMomentKind, enabled: Bool) {
        if enabled {
            enabledMoments.insert(kind)
        } else {
            enabledMoments.remove(kind)
        }
    }
}
