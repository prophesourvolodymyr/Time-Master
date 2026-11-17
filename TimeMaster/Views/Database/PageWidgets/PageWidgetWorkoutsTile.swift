import SwiftUI
import TimeMasterCore

/// Workouts: how many saved workouts train the page, the ones trained most lately, and when one was last finished. An
/// exercise in none says so. A tap lists them (`PageWorkoutsList`).
struct PageWidgetWorkoutsTile: View {
    let usage: PageWorkoutUsage
    let onOpen: (PageWidgetTarget) -> Void

    /// Workouts the tile has room to name.
    static let visibleRows = 2

    var body: some View {
        PageWidgetTile(kind: .workouts, target: .workouts, summary: summary, onOpen: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                PageWidgetHeader(kind: .workouts, trailing: usage.isEmpty ? nil : "\(usage.entries.count)")
                if usage.isEmpty {
                    PageWidgetEmptyState(systemImage: "plus.circle", title: "Not in a workout yet")
                } else {
                    ForEach(usage.entries.prefix(Self.visibleRows)) { entry in
                        HStack(spacing: 8) {
                            WorkoutCoverMosaic(workout: entry.workout, size: 24)
                            Text(entry.workout.name)
                                .font(TimeMasterFont.black(13, relativeTo: .subheadline))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(height: 24)
                    }
                    Spacer(minLength: 0)
                    Label {
                        Text(PageWidgetFormat.trained(usage.lastTrained))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(usage.lastTrained == nil ? Theme.textSecondary : Theme.toolbarOrange)
                }
            }
            .padding(PageWidgetMetrics.inset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var summary: String {
        guard !usage.isEmpty else { return "Workouts: not in a workout yet" }
        let names = usage.entries.prefix(Self.visibleRows).map(\.workout.name).joined(separator: ", ")
        let count = SkillCopy.count(usage.entries.count, "workout", "workouts")
        return "In \(count): \(names). \(PageWidgetFormat.trained(usage.lastTrained))"
    }
}
