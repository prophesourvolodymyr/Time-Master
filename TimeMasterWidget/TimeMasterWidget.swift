import WidgetKit
import SwiftUI
import AppIntents

struct WidgetWorkout: Codable {
    var id: String
    var name: String
    var colorHex: String
    var type: String
    var durationMinutes: Int
    var sectionCount: Int
    var setCount: Int
    var sessionsThisWeek: Int

    init(
        id: String,
        name: String,
        colorHex: String,
        type: String,
        durationMinutes: Int = 0,
        sectionCount: Int = 0,
        setCount: Int = 0,
        sessionsThisWeek: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.type = type
        self.durationMinutes = durationMinutes
        self.sectionCount = sectionCount
        self.setCount = setCount
        self.sessionsThisWeek = sessionsThisWeek
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "FFFFFF"
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "Other"
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        sectionCount = try c.decodeIfPresent(Int.self, forKey: .sectionCount) ?? 0
        setCount = try c.decodeIfPresent(Int.self, forKey: .setCount) ?? 0
        sessionsThisWeek = try c.decodeIfPresent(Int.self, forKey: .sessionsThisWeek) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, colorHex, type, durationMinutes, sectionCount, setCount, sessionsThisWeek
    }
}

struct WidgetToday: Codable, Identifiable {
    var id: String
    var workoutID: String
    var workoutName: String
    var durationMinutes: Int
    var timeRange: String
    var status: String
    var colorHex: String

    init(
        id: String,
        workoutID: String,
        workoutName: String,
        durationMinutes: Int,
        timeRange: String,
        status: String,
        colorHex: String
    ) {
        self.id = id
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.durationMinutes = durationMinutes
        self.timeRange = timeRange
        self.status = status
        self.colorHex = colorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        workoutID = try c.decodeIfPresent(String.self, forKey: .workoutID) ?? ""
        workoutName = try c.decodeIfPresent(String.self, forKey: .workoutName) ?? "Workout"
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        timeRange = try c.decodeIfPresent(String.self, forKey: .timeRange) ?? "Today"
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "FFFFFF"
    }

    private enum CodingKeys: String, CodingKey {
        case id, workoutID, workoutName, durationMinutes, timeRange, status, colorHex
    }
}

enum TimeMasterWidgetMode: String, AppEnum {
    case quickStart
    case today
    case progress

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content"
    static var caseDisplayRepresentations: [TimeMasterWidgetMode: DisplayRepresentation] = [
        .quickStart: "Quick Start",
        .today: "Today",
        .progress: "Progress"
    ]
}

struct WorkoutEntity: AppEntity {
    var id: String
    var name: String
    var colorHex: String
    var workoutType: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static var defaultQuery = WorkoutEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(workoutType)")
    }
}

struct WorkoutEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WorkoutEntity] {
        allWorkouts().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WorkoutEntity] {
        allWorkouts()
    }

    private func allWorkouts() -> [WorkoutEntity] {
        WidgetSnapshotStore.workouts.map {
            WorkoutEntity(id: $0.id, name: $0.name, colorHex: $0.colorHex, workoutType: $0.type)
        }
    }
}

struct SelectWorkoutIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Tmax Widget"
    static var description = IntentDescription("Choose the information shown by this widget.")

    @Parameter(title: "Content", default: .quickStart)
    var mode: TimeMasterWidgetMode

    @Parameter(title: "Workout")
    var workout: WorkoutEntity?
}

struct TimeMasterEntry: TimelineEntry {
    let date: Date
    let mode: TimeMasterWidgetMode
    let workout: WidgetWorkout?
    let today: [WidgetToday]
    let streak: Int
    let weeklyGoal: Int
    let weekSessions: Int
}

enum WidgetSnapshotStore {
    private static let defaults = UserDefaults(suiteName: "group.com.timemaster.shared")

    static var workouts: [WidgetWorkout] {
        guard let data = defaults?.data(forKey: "widget_workouts"),
              let workouts = try? JSONDecoder().decode([WidgetWorkout].self, from: data) else {
            return []
        }
        return workouts
    }

    static var today: [WidgetToday] {
        guard let data = defaults?.data(forKey: "widget_today"),
              let today = try? JSONDecoder().decode([WidgetToday].self, from: data) else {
            return []
        }
        return today
    }

    static var streak: Int {
        defaults?.integer(forKey: "widget_streak") ?? 0
    }

    static var weeklyGoal: Int {
        max(1, defaults?.integer(forKey: "widget_weekly_goal") ?? 4)
    }

    static var weekSessions: Int {
        if let sessions = defaults?.object(forKey: "widget_week_sessions") as? Int {
            return sessions
        }
        return workouts.reduce(0) { $0 + $1.sessionsThisWeek }
    }

    static var pinnedWorkoutID: String? {
        defaults?.string(forKey: "pinned_workout_id")
    }
}

struct TimeMasterProvider: AppIntentTimelineProvider {
    typealias Intent = SelectWorkoutIntent

    func placeholder(in context: Context) -> TimeMasterEntry {
        TimeMasterEntry(
            date: .now,
            mode: .quickStart,
            workout: WidgetWorkout(
                id: "preview",
                name: "Morning HIIT",
                colorHex: "FF2D55",
                type: "HIIT",
                durationMinutes: 18,
                sectionCount: 6,
                setCount: 6,
                sessionsThisWeek: 2
            ),
            today: [
                WidgetToday(
                    id: "preview-today",
                    workoutID: "preview",
                    workoutName: "Morning HIIT",
                    durationMinutes: 18,
                    timeRange: "Today",
                    status: "pending",
                    colorHex: "FF2D55"
                )
            ],
            streak: 4,
            weeklyGoal: 5,
            weekSessions: 2
        )
    }

    func snapshot(for configuration: SelectWorkoutIntent, in context: Context) async -> TimeMasterEntry {
        entry(from: configuration)
    }

    func timeline(for configuration: SelectWorkoutIntent, in context: Context) async -> Timeline<TimeMasterEntry> {
        Timeline(entries: [entry(from: configuration)], policy: .after(.now.addingTimeInterval(900)))
    }

    private func entry(from configuration: SelectWorkoutIntent) -> TimeMasterEntry {
        let workouts = WidgetSnapshotStore.workouts
        let selected = configuration.workout.flatMap { selectedID in
            workouts.first { $0.id == selectedID.id }
        }
        let pinned = WidgetSnapshotStore.pinnedWorkoutID.flatMap { pinnedID in
            workouts.first { $0.id == pinnedID }
        }
        return TimeMasterEntry(
            date: .now,
            mode: configuration.mode,
            workout: selected ?? pinned ?? workouts.first,
            today: WidgetSnapshotStore.today,
            streak: WidgetSnapshotStore.streak,
            weeklyGoal: WidgetSnapshotStore.weeklyGoal,
            weekSessions: WidgetSnapshotStore.weekSessions
        )
    }
}

struct TimeMasterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let entry: TimeMasterEntry

    var body: some View {
        TimeMasterWidgetFace(entry: entry, family: family, showsBackground: showsBackground)
    }
}

struct TimeMasterWidgetFace: View {
    let entry: TimeMasterEntry
    let family: WidgetFamily
    let showsBackground: Bool

    private enum Agenda {
        case next(WidgetToday)
        case finished(completed: Int, total: Int)
        case rest
    }

    var body: some View {
        let look = self.look
        content(showsBackground ? look.tint : .graphite)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tmaxWidgetBackground(look, family: family)
            .widgetURL(destinationURL)
    }

    var look: TmaxWidgetLook {
        switch entry.mode {
        case .quickStart:
            guard let workout = entry.workout else { return TmaxWidgetLook(art: .dumbbell) }
            return TmaxWidgetLook(art: WidgetArt.forWorkout(type: workout.type))
        case .today:
            if case .finished(let completed, let total) = agenda, completed == total {
                return TmaxWidgetLook(art: .trophy)
            }
            return TmaxWidgetLook(art: .calendar)
        case .progress:
            return family == .systemSmall ? TmaxWidgetLook(tint: .graphite) : TmaxWidgetLook(art: .flame)
        }
    }

    private var agenda: Agenda {
        if let next = entry.today.first(where: { $0.status == "pending" }) {
            return .next(next)
        }
        if entry.today.isEmpty {
            return .rest
        }
        return .finished(completed: entry.today.filter { $0.status == "completed" }.count, total: entry.today.count)
    }

    @ViewBuilder
    private func content(_ tint: WidgetTint) -> some View {
        switch entry.mode {
        case .quickStart:
            quickStart(tint)
        case .today:
            today(tint)
        case .progress:
            progress(tint)
        }
    }

    @ViewBuilder
    private func quickStart(_ tint: WidgetTint) -> some View {
        if let workout = entry.workout {
            switch family {
            case .systemSmall:
                VStack(alignment: .leading, spacing: 2) {
                    TmaxWidgetTitle(text: workout.name, size: 17, lines: 3, tint: tint)
                    TmaxWidgetLabel(text: "\(workout.durationMinutes) min", tint: tint)
                    Spacer(minLength: 0)
                    TmaxWidgetPlayGlyph(tint: tint)
                }
            case .systemMedium:
                VStack(alignment: .leading, spacing: 4) {
                    TmaxWidgetTitle(text: workout.name, size: 22, lines: 2, tint: tint)
                    TmaxWidgetLabel(text: "\(workout.durationMinutes) min", tint: tint)
                    Spacer(minLength: 0)
                    Link(destination: startURL(for: workout)) {
                        TmaxWidgetPill(title: "Start", systemImage: "play.fill", tint: tint)
                    }
                    .accessibilityLabel("Start \(workout.name)")
                }
                .padding(.trailing, TmaxWidgetLayout.sideRoom)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Spacer(minLength: 0)
                    TmaxWidgetTitle(text: workout.name, size: 30, lines: 2, tint: tint)
                    TmaxWidgetLabel(text: "\(workout.durationMinutes) min", tint: tint)
                    Link(destination: startURL(for: workout)) {
                        TmaxWidgetPill(title: "Start", systemImage: "play.fill", tint: tint, fillsWidth: true)
                    }
                    .padding(.top, 8)
                    .accessibilityLabel("Start \(workout.name)")
                }
            }
        } else {
            message("Choose a workout", tint: tint)
        }
    }

    @ViewBuilder
    private func today(_ tint: WidgetTint) -> some View {
        let pending = entry.today.filter { $0.status == "pending" }
        switch family {
        case .systemSmall:
            switch agenda {
            case .next(let item):
                VStack(alignment: .leading, spacing: 2) {
                    TmaxWidgetLabel(text: item.timeRange, tint: tint)
                    TmaxWidgetTitle(text: item.workoutName, size: 17, lines: 2, tint: tint)
                    Spacer(minLength: 0)
                    if pending.count > 1 {
                        TmaxWidgetLabel(text: "+\(pending.count - 1)", tint: tint)
                    }
                }
            case .finished(let completed, let total):
                message(completed == total ? "All done" : "Nothing left", tint: tint)
            case .rest:
                message("Rest day", tint: tint)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                TmaxWidgetLabel(text: "Today", tint: tint)
                if entry.today.isEmpty {
                    TmaxWidgetTitle(text: "Rest day", size: 22, lines: 1, tint: tint)
                } else {
                    ForEach(entry.today.prefix(2)) { item in
                        row(item, tint: tint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, TmaxWidgetLayout.sideRoom)
        default:
            if entry.today.isEmpty {
                message("Rest day", tint: tint)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if pending.isEmpty {
                        TmaxWidgetTitle(text: "All done", size: 30, lines: 1, tint: tint)
                    } else {
                        TmaxWidgetHero(text: "\(pending.count)", size: 56, tint: tint)
                        TmaxWidgetLabel(text: "to go today", tint: tint)
                    }
                    Spacer(minLength: 0)
                    ForEach(entry.today.prefix(5)) { item in
                        row(item, tint: tint)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func progress(_ tint: WidgetTint) -> some View {
        let goal = max(1, entry.weeklyGoal)
        let ring = ZStack {
            TmaxWidgetRing(fraction: Double(entry.weekSessions) / Double(goal), lineWidth: 12, tint: tint)
            VStack(spacing: 0) {
                TmaxWidgetHero(text: "\(entry.weekSessions)", size: 34, tint: tint)
                TmaxWidgetLabel(text: "of \(goal)", tint: tint)
            }
            .padding(.horizontal, 18)
        }
        switch family {
        case .systemSmall:
            ring
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progressSummary(goal: goal))
        case .systemMedium:
            HStack(spacing: 16) {
                ring
                    .frame(width: 120, height: 120)
                streakText(tint, size: 40)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progressSummary(goal: goal))
        default:
            VStack(alignment: .leading, spacing: 10) {
                streakText(tint, size: 56)
                Spacer(minLength: 0)
                ring
                    .frame(width: 170, height: 170)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progressSummary(goal: goal))
        }
    }

    private func streakText(_ tint: WidgetTint, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TmaxWidgetHero(text: "\(entry.streak)", size: size, tint: tint)
            HStack(spacing: 4) {
                if !showsBackground {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WidgetTint.orange.base)
                }
                TmaxWidgetLabel(text: entry.streak == 1 ? "day" : "days", tint: tint)
            }
        }
    }

    private func progressSummary(goal: Int) -> String {
        var summary = "\(entry.weekSessions) of \(goal) sessions this week, \(entry.streak) day streak"
        if family != .systemSmall && family != .systemMedium, let workout = entry.workout {
            summary += ", \(workout.name) \(workout.sessionsThisWeek) this week"
        }
        return summary
    }

    private func row(_ item: WidgetToday, tint: WidgetTint) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: statusSymbol(item.status))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint.ink)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.workoutName)
                    .font(TmaxWidgetFont.black(15, relativeTo: .subheadline))
                    .foregroundStyle(tint.ink)
                    .lineLimit(1)
                TmaxWidgetLabel(text: item.timeRange, tint: tint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.workoutName), \(item.timeRange), \(statusName(item.status))")
    }

    private func message(_ text: String, tint: WidgetTint) -> some View {
        let isLarge = family != .systemSmall && family != .systemMedium
        return VStack(alignment: .leading, spacing: 0) {
            if isLarge {
                Spacer(minLength: 0)
            }
            TmaxWidgetTitle(text: text, size: family == .systemSmall ? 18 : (isLarge ? 30 : 24), lines: 2, tint: tint)
            if !isLarge {
                Spacer(minLength: 0)
            }
        }
        .padding(.trailing, family == .systemMedium ? TmaxWidgetLayout.sideRoom : 0)
    }

    private func statusSymbol(_ status: String) -> String {
        switch status {
        case "completed": "checkmark.circle.fill"
        case "missed": "xmark.circle"
        default: "circle"
        }
    }

    private func statusName(_ status: String) -> String {
        switch status {
        case "completed": "done"
        case "missed": "missed"
        default: "to do"
        }
    }

    private var destinationURL: URL? {
        if case .today = entry.mode {
            return URL(string: "timemaster://open")
        }
        guard let workout = entry.workout else {
            return URL(string: "timemaster://open")
        }
        return URL(string: "timemaster://detail?workoutID=\(workout.id)")
    }

    private func startURL(for workout: WidgetWorkout) -> URL {
        URL(string: "timemaster://start?workoutID=\(workout.id)") ?? URL(string: "timemaster://open")!
    }
}

struct TimeMasterWidget: Widget {
    let kind = "TimeMasterWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWorkoutIntent.self,
            provider: TimeMasterProvider()
        ) { entry in
            TimeMasterWidgetView(entry: entry)
        }
        .configurationDisplayName("Tmax")
        .description("Quick start a workout, review Today, or check progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension Color {
    init(widgetHex hex: String) {
        let normalized = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
