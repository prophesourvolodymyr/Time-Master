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
    static var title: LocalizedStringResource = "TimeMaster Widget"
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
}

private enum WidgetSnapshotStore {
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
            weeklyGoal: 5
        )
    }

    func snapshot(for configuration: SelectWorkoutIntent, in context: Context) async -> TimeMasterEntry {
        entry(from: configuration)
    }

    func timeline(for configuration: SelectWorkoutIntent, in context: Context) async -> Timeline<TimeMasterEntry> {
        Timeline(entries: [entry(from: configuration)], policy: .after(.now.addingTimeInterval(900)))
    }

    private func entry(from configuration: SelectWorkoutIntent) -> TimeMasterEntry {
        let selected = configuration.workout.flatMap { selectedID in
            WidgetSnapshotStore.workouts.first { $0.id == selectedID.id }
        }
        let workout = selected ?? WidgetSnapshotStore.workouts.first
        return TimeMasterEntry(
            date: .now,
            mode: configuration.mode,
            workout: workout,
            today: WidgetSnapshotStore.today,
            streak: WidgetSnapshotStore.streak,
            weeklyGoal: WidgetSnapshotStore.weeklyGoal
        )
    }
}

struct TimeMasterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimeMasterEntry

    var body: some View {
        Group {
            switch entry.mode {
            case .quickStart:
                quickStartView
            case .today:
                todayView
            case .progress:
                progressView
            }
        }
        .foregroundStyle(.white)
        .containerBackground(Color(widgetHex: "0A0A0A"), for: .widget)
        .widgetURL(destinationURL)
    }

    private var quickStartView: some View {
        Group {
            if let workout = entry.workout {
                if family == .systemSmall {
                    VStack(alignment: .leading, spacing: 8) {
                        workoutIcon(workout)
                        Spacer(minLength: 0)
                        Text(workout.name)
                            .font(.headline.weight(.bold))
                            .lineLimit(2)
                        workoutDetails(workout)
                    }
                    .padding(14)
                } else {
                    HStack(spacing: 14) {
                        workoutIcon(workout)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Quick Start")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                            Text(workout.name)
                                .font(.title3.weight(.bold))
                                .lineLimit(2)
                            workoutDetails(workout)
                        }
                        Spacer(minLength: 0)
                        actionPill(title: "START", icon: "play.fill")
                    }
                    .padding(16)
                }
            } else {
                emptyView(icon: "bolt.fill", title: "Choose a workout")
            }
        }
    }

    private var todayView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.headline.weight(.bold))
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(.white.opacity(0.5))
            }
            if entry.today.isEmpty {
                Spacer(minLength: 0)
                emptyView(icon: "checkmark.circle", title: "Nothing scheduled")
                Spacer(minLength: 0)
            } else {
                ForEach(entry.today.prefix(family == .systemSmall ? 2 : 4)) { item in
                    todayRow(item)
                }
                if family != .systemSmall {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.headline.weight(.bold))
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.white.opacity(0.5))
            }
            if let workout = entry.workout {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    stat(value: "\(workout.sessionsThisWeek)", label: "sessions")
                    stat(value: "\(entry.streak)", label: "day streak")
                    stat(value: "\(entry.weeklyGoal)", label: "weekly goal")
                }
                Spacer(minLength: 0)
                ProgressView(value: Double(workout.sessionsThisWeek), total: Double(max(1, entry.weeklyGoal)))
                    .tint(Color(widgetHex: workout.colorHex))
            } else {
                emptyView(icon: "chart.bar", title: "No workout data")
            }
        }
        .padding(14)
    }

    private func workoutIcon(_ workout: WidgetWorkout) -> some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color(widgetHex: workout.colorHex))
            .frame(width: family == .systemSmall ? 38 : 48, height: family == .systemSmall ? 38 : 48)
            .overlay {
                Image(systemName: typeIcon(workout.type))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(workout.colorHex.uppercased() == "FFFFFF" ? .black : .white)
            }
    }

    private func workoutDetails(_ workout: WidgetWorkout) -> some View {
        Text("\(workout.durationMinutes) min · \(workout.sectionCount) \(workout.sectionCount == 1 ? "section" : "sections")")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.58))
            .lineLimit(1)
    }

    private func todayRow(_ item: WidgetToday) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(widgetHex: item.colorHex))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.workoutName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(item.timeRange) · \(item.durationMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.status == "completed" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if item.status == "missed" {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
    }

    private func emptyView(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.2))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func typeIcon(_ type: String) -> String {
        switch type {
        case "Strength": "dumbbell.fill"
        case "Stretch": "figure.cooldown"
        case "Cardio": "heart.fill"
        case "HIIT": "flame.fill"
        case "Yoga": "figure.mind.and.body"
        case "Face": "face.smiling.fill"
        default: "star.fill"
        }
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
        .configurationDisplayName("TimeMaster")
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
