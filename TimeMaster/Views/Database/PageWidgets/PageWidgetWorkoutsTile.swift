import SwiftUI
import TimeMasterCore

struct PageWidgetWorkoutsTile: View {
    let usage: PageWorkoutUsage
    let onOpen: (PageWidgetTarget) -> Void

    static let namesInSummary = 2
    static let artSpot = WidgetArtSpot(alignment: .topTrailing, scale: 0.8, bleed: 0.1)

    var body: some View {
        PageWidgetTile(
            kind: .workouts,
            target: .workouts,
            summary: summary,
            art: .dumbbell,
            artSpot: usage.isEmpty ? .corner : Self.artSpot,
            onOpen: onOpen
        ) {
            if usage.isEmpty {
                PageWidgetEmptyState(systemImage: nil, title: "Not in a workout yet")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetHero(text: "\(usage.entries.count)", size: 40)
                    WidgetLabel(text: usage.entries.count == 1 ? "workout" : "workouts")
                    Spacer(minLength: 0)
                    if let last = usage.lastTrained {
                        WidgetChip(systemImage: "clock.arrow.circlepath", text: PageWidgetFormat.when(last))
                    }
                }
                .padding(PageWidgetMetrics.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    private var summary: String {
        guard !usage.isEmpty else { return "Workouts: not in a workout yet" }
        let names = usage.entries.prefix(Self.namesInSummary).map(\.workout.name).joined(separator: ", ")
        let count = SkillCopy.count(usage.entries.count, "workout", "workouts")
        return "In \(count): \(names). \(PageWidgetFormat.trained(usage.lastTrained))"
    }
}
