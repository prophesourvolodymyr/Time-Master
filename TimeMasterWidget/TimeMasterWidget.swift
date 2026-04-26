import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared workout model (widget-side)

struct WidgetWorkout: Codable {
    var id: String
    var name: String
    var colorHex: String
    var type: String
}

// MARK: - AppEntity

struct WorkoutEntity: AppEntity {
    var id: String
    var name: String
    var colorHex: String
    var workoutType: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static var defaultQuery = WorkoutEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - EntityQuery

struct WorkoutEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WorkoutEntity] {
        allWorkouts().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WorkoutEntity] {
        allWorkouts()
    }

    private func allWorkouts() -> [WorkoutEntity] {
        let defaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        guard let data = defaults?.data(forKey: "widget_workouts"),
              let list = try? JSONDecoder().decode([WidgetWorkout].self, from: data) else {
            return []
        }
        return list.map { WorkoutEntity(id: $0.id, name: $0.name, colorHex: $0.colorHex, workoutType: $0.type) }
    }
}

// MARK: - Configuration Intent

struct SelectWorkoutIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Workout"
    static var description = IntentDescription("Choose the workout to open from the widget.")

    @Parameter(title: "Workout")
    var workout: WorkoutEntity?
}

// MARK: - Timeline Entry

struct TimeMasterEntry: TimelineEntry {
    let date: Date
    let workoutName: String
    let workoutID: String
    let colorHex: String
    let workoutType: String
}

// MARK: - AppIntent Timeline Provider

struct TimeMasterProvider: AppIntentTimelineProvider {
    typealias Intent = SelectWorkoutIntent

    func placeholder(in context: Context) -> TimeMasterEntry {
        TimeMasterEntry(date: .now, workoutName: "Morning HIIT", workoutID: "preview",
                        colorHex: "FFFFFF", workoutType: "HIIT")
    }

    func snapshot(for configuration: SelectWorkoutIntent, in context: Context) async -> TimeMasterEntry {
        entry(from: configuration)
    }

    func timeline(for configuration: SelectWorkoutIntent, in context: Context) async -> Timeline<TimeMasterEntry> {
        Timeline(entries: [entry(from: configuration)], policy: .never)
    }

    private func entry(from config: SelectWorkoutIntent) -> TimeMasterEntry {
        if let w = config.workout {
            return TimeMasterEntry(date: .now, workoutName: w.name, workoutID: w.id,
                                   colorHex: w.colorHex, workoutType: w.workoutType)
        }
        return TimeMasterEntry(date: .now, workoutName: "", workoutID: "",
                               colorHex: "FFFFFF", workoutType: "")
    }
}

// MARK: - Widget View

struct TimeMasterWidgetView: View {
    var entry: TimeMasterEntry

    private var hasWorkout: Bool { !entry.workoutID.isEmpty }
    private var accentColor: Color { Color(widgetHex: entry.colorHex) }

    /// White badge → black icon so it stays legible; any colored badge → white icon.
    private var badgeForeground: Color {
        entry.colorHex.uppercased() == "FFFFFF" ? .black : .white
    }

    /// Map the workout type string to the matching SF Symbol (mirrors WorkoutType.icon in the main app).
    private var typeIcon: String {
        switch entry.workoutType {
        case "Strength": return "dumbbell.fill"
        case "Stretch":  return "figure.cooldown"
        case "Cardio":   return "heart.fill"
        case "HIIT":     return "flame.fill"
        case "Yoga":     return "figure.mind.and.body"
        case "Face":     return "face.smiling.fill"
        default:         return "star.fill"   // "Other" + unknown
        }
    }

    var body: some View {
        ZStack {
            Color(widgetHex: "0A0A0A")
            if hasWorkout { filledView } else { emptyView }
        }
        .widgetURL(
            hasWorkout
                ? URL(string: "timemaster://detail?workoutID=\(entry.workoutID)")
                : URL(string: "timemaster://open")
        )
    }

    // MARK: - Filled state

    private var filledView: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Workout-type badge ───────────────────────────────────
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: typeIcon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(badgeForeground)
                )

            Spacer(minLength: 0)

            // ── Workout name ─────────────────────────────────────────
            Text(entry.workoutName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            // ── VIEW pill ────────────────────────────────────────────
            HStack(spacing: 5) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .black))
                Text("VIEW")
                    .font(.system(size: 11, weight: .black))
                    .kerning(0.8)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .padding(14)
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 42, height: 42)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white.opacity(0.15))
            }
            Text("Hold to choose\na workout")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.28))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }
}

// MARK: - Widget Declaration

struct TimeMasterWidget: Widget {
    let kind = "TimeMasterWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWorkoutIntent.self,
            provider: TimeMasterProvider()
        ) { entry in
            TimeMasterWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Quick Start")
        .description("Open your pinned workout instantly.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color helper (widget-local)

extension Color {
    init(widgetHex hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
