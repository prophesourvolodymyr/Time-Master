import Foundation

enum HomeWidgetCategory: String, Codable, CaseIterable, Identifiable {
    case today
    case workouts
    case analytics
    case outdoor
    case database

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .workouts: "Workouts"
        case .analytics: "Analytics"
        case .outdoor: "Outdoor"
        case .database: "Database"
        }
    }
}

enum HomeWidgetFootprint: String, Codable, CaseIterable, Identifiable {
    case compact
    case square
    case wide

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self).lowercased()
        switch value {
        case "compact", "0.5:1", "0.5x1", "0.5:2", "0.5x2":
            self = .compact
        case "square", "1:1", "1x1", "standard":
            self = .square
        case "wide", "1:2", "1x2", "tall", "large":
            self = .wide
        default:
            self = .wide
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var id: String { rawValue }

    /// `compact` is the half-width, two-row footprint rendered as a square
    /// tile. `square` is full-width 1:1, and `wide` is the full-width 1:2
    /// footprint.
    var aspectRatio: CGFloat {
        switch self {
        case .compact, .square: 1
        case .wide: 2
        }
    }

    var columnSpan: Int {
        switch self {
        case .compact: 1
        case .square, .wide: 2
        }
    }

    var accessibilityName: String {
        switch self {
        case .compact: "compact, half-width, two-row"
        case .square: "square, full-width, one-row"
        case .wide: "wide, full-width, half-height"
        }
    }

    var menuTitle: String {
        switch self {
        case .compact: "Compact · 0.5:2"
        case .square: "Square · 1:1"
        case .wide: "Wide · 1:2"
        }
    }
}

enum HomeWidgetSizing {
    static let canvasPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 18
}

enum HomeWidgetKind: String, Codable, CaseIterable, Identifiable {
    case greeting
    case today
    case quickStart
    case activityShortcuts
    case recentWorkouts
    case resumeWorkout
    case selectedWorkout
    case metrics
    case streak
    case weeklyRhythm
    case activityHeatmap
    case lifetimeStats
    case typeBreakdown
    case outdoorSummary
    case recoverActivity
    case savedRoutes
    case exerciseDatabase
    case databaseOverview
    case buildFromDatabase

    var id: String { rawValue }

    var category: HomeWidgetCategory {
        switch self {
        case .greeting, .today, .quickStart: .today
        case .activityShortcuts, .recentWorkouts, .resumeWorkout, .selectedWorkout: .workouts
        case .metrics, .streak, .weeklyRhythm, .activityHeatmap, .lifetimeStats, .typeBreakdown: .analytics
        case .outdoorSummary, .recoverActivity, .savedRoutes: .outdoor
        case .exerciseDatabase, .databaseOverview, .buildFromDatabase: .database
        }
    }

    var title: String {
        switch self {
        case .greeting: "Greeting"
        case .today: "Today"
        case .quickStart: "Quick Start"
        case .activityShortcuts: "Activity Shortcuts"
        case .recentWorkouts: "Recent Workouts"
        case .resumeWorkout: "Resume Workout"
        case .selectedWorkout: "Selected Workout"
        case .metrics: "Metrics"
        case .streak: "Streak"
        case .weeklyRhythm: "Weekly Rhythm"
        case .activityHeatmap: "Activity"
        case .lifetimeStats: "Lifetime Stats"
        case .typeBreakdown: "Type Breakdown"
        case .outdoorSummary: "Outdoor Summary"
        case .recoverActivity: "Recover Activity"
        case .savedRoutes: "Saved Routes"
        case .exerciseDatabase: "Exercise Database"
        case .databaseOverview: "Database Overview"
        case .buildFromDatabase: "Build from Database"
        }
    }

    var systemImage: String {
        switch self {
        case .greeting: "sun.max.fill"
        case .today: "calendar"
        case .quickStart: "play.circle.fill"
        case .activityShortcuts: "figure.run"
        case .recentWorkouts: "clock.arrow.circlepath"
        case .resumeWorkout: "arrow.uturn.forward.circle.fill"
        case .selectedWorkout: "pin.fill"
        case .metrics: "chart.bar.fill"
        case .streak: "flame.fill"
        case .weeklyRhythm: "chart.line.uptrend.xyaxis"
        case .activityHeatmap: "square.grid.3x3.fill"
        case .lifetimeStats: "sum"
        case .typeBreakdown: "chart.pie.fill"
        case .outdoorSummary: "figure.outdoor.cycle"
        case .recoverActivity: "arrow.clockwise.circle.fill"
        case .savedRoutes: "map.fill"
        case .exerciseDatabase: "cylinder.split.1x2.fill"
        case .databaseOverview: "square.stack.3d.up.fill"
        case .buildFromDatabase: "plus.rectangle.on.rectangle"
        }
    }

    var defaultFootprint: HomeWidgetFootprint {
        switch self {
        case .greeting:
            .compact
        case .streak, .lifetimeStats, .databaseOverview:
            .square
        default:
            .wide
        }
    }

    var supportsOptions: Bool {
        switch self {
        case .greeting, .streak, .lifetimeStats, .databaseOverview, .buildFromDatabase, .recoverActivity: false
        default: true
        }
    }

    var supportedFootprints: [HomeWidgetFootprint] {
        HomeWidgetFootprint.allCases
    }

    static var catalog: [HomeWidgetKind] { allCases }
}
enum HomeActivityShortcut: String, Codable, CaseIterable, Identifiable {
    case workout
    case runWalk
    case bike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: "Workout"
        case .runWalk: "Run & Walk"
        case .bike: "Bike"
        }
    }

    var systemImage: String {
        switch self {
        case .workout: "figure.strengthtraining.traditional"
        case .runWalk: "figure.run"
        case .bike: "bicycle"
        }
    }
}

enum HomeMetricField: String, Codable, CaseIterable, Identifiable {
    case sessions
    case streak
    case activeMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions: "Sessions"
        case .streak: "Streak"
        case .activeMinutes: "Active time"
        }
    }
}

struct HomeWidgetConfiguration: Codable, Equatable {
    var showTypeIcon = true
    var showDetails = true
    var showStatus = true
    var showScheduledTime = true
    var visibleCount = 3
    var selectedTypeID: String?
    var selectedWorkoutID: UUID?
    var activityShortcuts: [HomeActivityShortcut] = [.workout, .runWalk, .bike]
    var metricFields: [HomeMetricField] = [.sessions, .streak, .activeMinutes]

    static func defaults(for kind: HomeWidgetKind) -> HomeWidgetConfiguration {
        var configuration = HomeWidgetConfiguration()
        switch kind {
        case .greeting:
            configuration.showTypeIcon = false
            configuration.showDetails = false
        case .today:
            configuration.visibleCount = 4
        case .recentWorkouts:
            configuration.visibleCount = 3
        case .activityShortcuts:
            configuration.activityShortcuts = [.workout, .runWalk, .bike]
        case .metrics:
            configuration.metricFields = [.sessions, .streak, .activeMinutes]
        case .weeklyRhythm, .typeBreakdown:
            configuration.selectedTypeID = nil
        default:
            break
        }
        return configuration
    }
}

struct HomeWidgetInstance: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: HomeWidgetKind
    var footprint: HomeWidgetFootprint
    var configuration: HomeWidgetConfiguration

    init(
        id: UUID = UUID(),
        kind: HomeWidgetKind,
        footprint: HomeWidgetFootprint? = nil,
        configuration: HomeWidgetConfiguration? = nil
    ) {
        self.id = id
        self.kind = kind
        self.footprint = footprint ?? kind.defaultFootprint
        self.configuration = configuration ?? .defaults(for: kind)
    }
}

enum HomeWidgetCatalog {
    static let initialLayout: [HomeWidgetInstance] = [
        HomeWidgetInstance(kind: .greeting),
        HomeWidgetInstance(kind: .today),
        HomeWidgetInstance(kind: .quickStart),
        HomeWidgetInstance(kind: .activityShortcuts),
        HomeWidgetInstance(kind: .metrics)
    ]

    static func options(for kind: HomeWidgetKind) -> [HomeWidgetKind] {
        HomeWidgetKind.catalog.filter { $0.category == kind.category }
    }
}
