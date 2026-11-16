import SwiftUI

/// The saved workouts that train a page, most recently trained first (`PageWorkoutUsage`): what a tap on the Workouts
/// widget lists. A row shows the workout's cover, name, type and length and when it was last finished, and opens the
/// workout. It has no navigation of its own; put it in a tab, a section or a sheet.
struct PageWorkoutsList: View {
    let pageID: UUID

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    var body: some View {
        let usage = store.page(id: pageID).map {
            PageWorkoutUsage.of($0, library: SkillLibrary(pages: store.allPagesFlat), workoutStore: workoutStore)
        }
        VStack(alignment: .leading, spacing: 10) {
            if let usage, !usage.isEmpty {
                ForEach(usage.entries) { entry in
                    row(entry)
                }
            } else {
                ProfileEmptyState(
                    symbol: "figure.strengthtraining.traditional",
                    title: "Not in a workout yet",
                    detail: "Add this page to a workout and it shows up here, with the last time you trained it."
                )
            }
        }
    }

    private func row(_ entry: PageWorkoutUsage.Entry) -> some View {
        let workout = entry.workout
        return Button {
            NotificationCenter.default.post(name: .openWorkoutDetail, object: nil, userInfo: ["workoutID": workout.id])
        } label: {
            HStack(spacing: 12) {
                WorkoutCoverMosaic(workout: workout, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.name)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(details(of: workout))
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Text(PageWidgetFormat.trained(entry.lastTrained))
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(entry.lastTrained == nil ? Theme.textSecondary : Theme.toolbarOrange)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(TimeMasterCardSurface(cornerRadius: 20, flat: true))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .accessibilityHint("Opens the workout")
    }

    /// "Strength · 6 sections · 24 min".
    private func details(of workout: Workout) -> String {
        let minutes = max(1, Int((Double(workout.totalDuration) / 60).rounded()))
        return "\(workout.type.name) · \(SkillCopy.count(workout.sectionCount, "section", "sections")) · \(minutes) min"
    }
}
