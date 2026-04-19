import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TimeMasterEntry: TimelineEntry {
    let date: Date
    let workoutName: String
    let workoutID: String
    let colorHex: String
}

// MARK: - Timeline Provider

struct TimeMasterProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeMasterEntry {
        TimeMasterEntry(date: .now, workoutName: "Morning HIIT", workoutID: "", colorHex: "FFFFFF")
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeMasterEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeMasterEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> TimeMasterEntry {
        let defaults = UserDefaults(suiteName: "group.com.timemaster.shared")
        let name  = defaults?.string(forKey: "pinned_workout_name")  ?? "No Workout Pinned"
        let id    = defaults?.string(forKey: "pinned_workout_id")    ?? ""
        let color = defaults?.string(forKey: "pinned_workout_color") ?? "FFFFFF"
        return TimeMasterEntry(date: .now, workoutName: name, workoutID: id, colorHex: color)
    }
}

// MARK: - Widget View

struct TimeMasterWidgetView: View {
    var entry: TimeMasterEntry

    private var iconColor: Color  { Color(widgetHex: entry.colorHex) }
    private var iconForeground: Color { entry.colorHex == "FFFFFF" ? .black : .white }

    var body: some View {
        ZStack {
            Color(widgetHex: "0A0A0A")
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconForeground)
                }
                Text(entry.workoutName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("Tap to start")
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(8)
        }
        .widgetURL(URL(string: "timemaster://start?workoutID=\(entry.workoutID)"))
    }
}

// MARK: - Widget Configuration

struct TimeMasterWidget: Widget {
    let kind = "TimeMasterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeMasterProvider()) { entry in
            TimeMasterWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Start")
        .description("Launch your pinned workout instantly.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Color helper (widget-local copy)

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
