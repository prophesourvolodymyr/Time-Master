import WidgetKit
import SwiftUI

struct TmaxStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

struct TmaxStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> TmaxStreakEntry {
        TmaxStreakEntry(date: .now, streak: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (TmaxStreakEntry) -> Void) {
        completion(TmaxStreakEntry(date: .now, streak: context.isPreview ? 5 : WidgetSnapshotStore.streak))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TmaxStreakEntry>) -> Void) {
        let now = Date.now
        let entry = TmaxStreakEntry(date: now, streak: WidgetSnapshotStore.streak)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600))))
    }
}

struct TmaxStreakView: View {
    let entry: TmaxStreakEntry

    static let look = TmaxWidgetLook(art: .flame)

    private var unit: String { entry.streak == 1 ? "day" : "days" }

    var body: some View {
        let tint = Self.look.tint
        VStack(alignment: .leading, spacing: 0) {
            TmaxWidgetHero(text: "\(entry.streak)", size: 56, tint: tint)
            TmaxWidgetLabel(text: unit, tint: tint)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak, \(entry.streak) \(unit)")
        .tmaxWidgetBackground(Self.look, family: .systemSmall)
        .widgetURL(URL(string: "timemaster://open"))
    }
}

struct TmaxStreakWidget: Widget {
    let kind = "TmaxStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TmaxStreakProvider()) { entry in
            TmaxStreakView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Days in a row you trained.")
        .supportedFamilies([.systemSmall])
    }
}
