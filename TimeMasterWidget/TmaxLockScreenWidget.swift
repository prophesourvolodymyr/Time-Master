import WidgetKit
import SwiftUI

struct TmaxGlanceEntry: TimelineEntry {
    enum Agenda {
        case next(WidgetToday)
        case finished(completed: Int, total: Int)
        case restDay
    }

    let date: Date
    let agenda: Agenda
    let streak: Int
    let weekSessions: Int
    let weeklyGoal: Int

    static let sample = TmaxGlanceEntry(
        date: .now,
        agenda: .next(
            WidgetToday(
                id: "sample",
                workoutID: "sample",
                workoutName: "Morning HIIT",
                durationMinutes: 45,
                timeRange: "7:00 AM – 7:45 AM",
                status: "pending",
                colorHex: "FF6A00"
            )
        ),
        streak: 5,
        weekSessions: 3,
        weeklyGoal: 4
    )
}

fileprivate extension WidgetToday {
    var clockTimes: (start: String, finish: String)? {
        let parts = timeRange.components(separatedBy: " – ")
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

fileprivate struct TmaxGlanceSchedule {
    struct Slot {
        let item: WidgetToday
        let window: DateInterval?
    }

    private let now: Date
    private let endOfDay: Date
    private let today: [WidgetToday]
    private let pending: [Slot]
    private let streak: Int
    private let weekSessions: Int
    private let weeklyGoal: Int

    init(now: Date = .now) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.isLenient = true

        func clock(_ text: String) -> Date? {
            let parsed = formatter.date(from: text)
                ?? formatter.date(from: text.replacingOccurrences(of: "\u{202F}", with: " "))
            guard let parsed else { return nil }
            let time = calendar.dateComponents([.hour, .minute], from: parsed)
            return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: now)
        }

        let today = WidgetSnapshotStore.today
        self.now = now
        self.today = today
        endOfDay = calendar.dateInterval(of: .day, for: now)?.end ?? now
        pending = today.filter { $0.status == "pending" }.map { item in
            guard let times = item.clockTimes,
                  let start = clock(times.start),
                  let finish = clock(times.finish) else {
                return Slot(item: item, window: nil)
            }
            let fallback = start.addingTimeInterval(TimeInterval(max(1, item.durationMinutes) * 60))
            return Slot(item: item, window: DateInterval(start: start, end: finish > start ? finish : fallback))
        }
        streak = WidgetSnapshotStore.streak
        weekSessions = WidgetSnapshotStore.weekSessions
        weeklyGoal = WidgetSnapshotStore.weeklyGoal
    }

    var changeDates: [Date] {
        let ends = pending.compactMap { $0.window?.end }.filter { $0 > now && $0 < endOfDay }
        return Set(ends).sorted()
    }

    func entry(at date: Date) -> TmaxGlanceEntry {
        let upcoming = pending.first { slot in
            guard let window = slot.window else { return true }
            return window.end > date
        }
        let agenda: TmaxGlanceEntry.Agenda
        if let next = upcoming ?? pending.first {
            agenda = .next(next.item)
        } else if today.isEmpty {
            agenda = .restDay
        } else {
            agenda = .finished(completed: today.filter { $0.status == "completed" }.count, total: today.count)
        }
        return TmaxGlanceEntry(
            date: date,
            agenda: agenda,
            streak: streak,
            weekSessions: weekSessions,
            weeklyGoal: weeklyGoal
        )
    }
}

struct TmaxGlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> TmaxGlanceEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (TmaxGlanceEntry) -> Void) {
        completion(context.isPreview ? .sample : TmaxGlanceSchedule().entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TmaxGlanceEntry>) -> Void) {
        let now = Date.now
        let schedule = TmaxGlanceSchedule(now: now)
        let entries = ([now] + schedule.changeDates).map { schedule.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(900))))
    }
}

struct TmaxGlanceView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: TmaxGlanceEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryInline:
                inlineView
            default:
                rectangularView
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular {
                AccessoryWidgetBackground()
            } else {
                Color.clear
            }
        }
        .widgetURL(URL(string: "timemaster://open"))
    }

    private var circularView: some View {
        Gauge(value: Double(min(entry.weekSessions, entry.weeklyGoal)), in: 0...Double(entry.weeklyGoal)) {
            Text("Weekly goal")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("\(entry.streak)")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(renderingMode == .fullColor ? Color(widgetHex: "FF6A00") : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly goal")
        .accessibilityValue("\(entry.weekSessions) of \(entry.weeklyGoal) sessions, \(entry.streak) day streak")
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            Text(detail)
                .font(.caption)
                .lineLimit(1)
            Label("\(entry.streak) day streak", systemImage: "flame.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineView: some View {
        Label(inlineText, systemImage: "flame.fill")
    }

    private var title: String {
        switch entry.agenda {
        case .next(let item): item.workoutName
        case .finished(let completed, let total): completed == total ? "All done" : "Nothing left"
        case .restDay: "Rest day"
        }
    }

    private var detail: String {
        switch entry.agenda {
        case .next(let item): item.timeRange
        case .finished(let completed, let total): "\(completed) of \(total) completed"
        case .restDay: "Nothing scheduled"
        }
    }

    private var inlineText: String {
        guard case .next(let item) = entry.agenda else {
            return "\(entry.streak) · \(title)"
        }
        let name = item.clockTimes.map { "\($0.start) \(item.workoutName)" } ?? item.workoutName
        return "\(entry.streak) · \(name)"
    }
}

struct TmaxLockScreenWidget: Widget {
    let kind = "TmaxLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TmaxGlanceProvider()) { entry in
            TmaxGlanceView(entry: entry)
        }
        .configurationDisplayName("Tmax Glance")
        .description("Your streak, weekly goal and next workout at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
