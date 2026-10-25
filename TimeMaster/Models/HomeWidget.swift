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
        case .compact: "Small"
        case .square: "Large"
        case .wide: "Medium"
        }
    }

    var menuTitle: String {
        switch self {
        case .compact: "Small"
        case .square: "Large"
        case .wide: "Medium"
        }
    }
}

enum HomeWidgetSizing {
    static let canvasPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 26
    static let spacing: CGFloat = 14

    #if os(macOS)
    private static let maximumCanvasWidth: CGFloat = 1100
    private static let minimumCellWidth: CGFloat = 340
    #else
    private static let maximumCanvasWidth: CGFloat = 760
    #endif

    static func contentWidth(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        max(1, min(viewportWidth, maximumCanvasWidth) - canvasPadding * 2)
    }

    /// Number of wide-footprint columns ("cells") that fit the content width. A cell is one
    /// phone-sized canvas: Small widgets pair up inside it, Medium and Large fill it.
    static func cellCount(forContentWidth width: CGFloat) -> Int {
        #if os(macOS)
        max(1, Int(((width + spacing) / (minimumCellWidth + spacing)).rounded(.down)))
        #else
        1
        #endif
    }
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
    case outdoorMap
    case exerciseDatabase
    case databaseOverview
    case buildFromDatabase
    var id: String { rawValue }

    var category: HomeWidgetCategory {
        switch self {
        case .greeting, .today, .quickStart: .today
        case .activityShortcuts, .recentWorkouts, .resumeWorkout, .selectedWorkout: .workouts
        case .metrics, .streak, .weeklyRhythm, .activityHeatmap, .lifetimeStats, .typeBreakdown: .analytics
        case .outdoorSummary, .recoverActivity, .savedRoutes, .outdoorMap: .outdoor
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
        case .outdoorMap: "Map"
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
        case .outdoorMap: "map"
        case .exerciseDatabase: "cylinder.split.1x2.fill"
        case .databaseOverview: "square.stack.3d.up.fill"
        case .buildFromDatabase: "plus.rectangle.on.rectangle"
        }
    }

    var defaultFootprint: HomeWidgetFootprint {
        switch self {
        case .greeting:
            .wide
        case .streak, .lifetimeStats, .databaseOverview:
            .square
        default:
            .wide
        }
    }

    var supportsOptions: Bool {
        switch self {
        case .greeting, .streak, .lifetimeStats, .databaseOverview, .buildFromDatabase, .recoverActivity, .outdoorMap: false
        default: true
        }
    }

    var supportedFootprints: [HomeWidgetFootprint] {
        switch self {
        case .greeting: [.wide]
        case .activityHeatmap, .activityShortcuts: [.wide, .square]
        default: [.compact, .wide, .square]
        }
    }

    static var catalog: [HomeWidgetKind] { allCases }
}
enum HomeActivityShortcut: String, Codable, CaseIterable, Identifiable {
    case workout
    case runWalk
    case walk
    case bike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: "Workout"
        case .runWalk: "Run"
        case .walk: "Walk"
        case .bike: "Bike"
        }
    }

    var systemImage: String {
        switch self {
        case .workout: "figure.strengthtraining.traditional"
        case .runWalk: "figure.run"
        case .walk: "figure.walk"
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
    var activityShortcuts: [HomeActivityShortcut] = [.workout, .runWalk, .walk, .bike]
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
            configuration.activityShortcuts = [.workout, .runWalk, .walk, .bike]
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
        HomeWidgetInstance(kind: .outdoorMap),
        HomeWidgetInstance(kind: .metrics),
    ]

    static func options(for kind: HomeWidgetKind) -> [HomeWidgetKind] {
        HomeWidgetKind.catalog.filter { $0.category == kind.category }
    }
}


struct HomeWidgetGrid {
    let frames: [UUID: CGRect]
    let trailingSlotIDs: Set<UUID>
    let height: CGFloat
    let width: CGFloat
    let cells: Int
    let cellWidth: CGFloat

    init(widgets: [HomeWidgetInstance], width: CGFloat, cells: Int, greetingHeight: CGFloat) {
        let gap = HomeWidgetSizing.spacing
        let cells = max(1, cells)
        let cellWidth = (width - gap * CGFloat(cells - 1)) / CGFloat(cells)
        var frames: [UUID: CGRect] = [:]
        var trailing: Set<UUID> = []
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var cell = 0
        var leftTaken = false

        func startRow() {
            y += rowHeight + gap
            rowHeight = 0
            cell = 0
            leftTaken = false
        }

        for widget in widgets {
            let size: CGSize
            let x: CGFloat
            if widget.kind == .greeting {
                if cell > 0 || leftTaken { startRow() }
                size = CGSize(width: width, height: greetingHeight)
                x = 0
                cell = cells
            } else if widget.footprint.columnSpan == 1 {
                size = Self.size(widget.footprint, cellWidth: cellWidth)
                if leftTaken {
                    x = CGFloat(cell) * (cellWidth + gap) + (cellWidth + gap) / 2
                    trailing.insert(widget.id)
                    leftTaken = false
                    cell += 1
                } else {
                    if cell == cells { startRow() }
                    x = CGFloat(cell) * (cellWidth + gap)
                    leftTaken = true
                }
            } else {
                if leftTaken {
                    leftTaken = false
                    cell += 1
                }
                if cell == cells { startRow() }
                size = Self.size(widget.footprint, cellWidth: cellWidth)
                x = CGFloat(cell) * (cellWidth + gap)
                cell += 1
            }
            frames[widget.id] = CGRect(origin: CGPoint(x: x, y: y), size: size)
            rowHeight = max(rowHeight, size.height)
            if cell == cells && !leftTaken { startRow() }
        }

        self.frames = frames
        self.trailingSlotIDs = trailing
        self.width = width
        self.cells = cells
        self.cellWidth = cellWidth
        height = max(0, cell > 0 || leftTaken ? y + rowHeight : y - gap)
    }

    func size(_ footprint: HomeWidgetFootprint) -> CGSize {
        Self.size(footprint, cellWidth: cellWidth)
    }

    func nearestFootprint(to size: CGSize, supported: [HomeWidgetFootprint]) -> HomeWidgetFootprint {
        supported.min { left, right in
            let lhs = self.size(left)
            let rhs = self.size(right)
            return hypot(lhs.width - size.width, lhs.height - size.height)
                < hypot(rhs.width - size.width, rhs.height - size.height)
        } ?? .wide
    }

    private static func size(_ footprint: HomeWidgetFootprint, cellWidth: CGFloat) -> CGSize {
        let small = (cellWidth - HomeWidgetSizing.spacing) / 2
        switch footprint {
        case .compact: return CGSize(width: small, height: small)
        case .wide: return CGSize(width: cellWidth, height: small)
        case .square: return CGSize(width: cellWidth, height: cellWidth)
        }
    }
}