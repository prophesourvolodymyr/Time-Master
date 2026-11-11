import SwiftUI
import TimeMasterCore

/// A sub-milestone inside a card: a check, its icon, title and note, its cover as a thumbnail, and its own
/// sub-milestones one level further in.
struct MilestoneRowView: View {
    let pageID: String
    let milestone: Milestone
    let depth: Int
    let actions: MilestoneActions
    var isPreview = false

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var thumbSide: CGFloat = 46

    var body: some View {
        let artwork = ChecklistArtwork.resolve(milestone, pageID: pageID, store: store, workouts: workoutStore.workouts)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MilestoneCheckButton(milestone: milestone, size: 28) { actions.toggle(milestone) }
                    .allowsHitTesting(!isPreview)
                ChecklistIconTile(icon: artwork.icon, tintHex: ChecklistLook.tintHex(milestone), side: iconSide, fallbackSymbol: ChecklistLook.milestoneIconName, onCard: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(TimeMasterFont.black(15, relativeTo: .body))
                        .foregroundStyle(milestone.isDone ? Theme.textSecondary : Theme.textPrimary)
                        .strikethrough(milestone.isDone, color: Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !milestone.note.isEmpty {
                        Text(milestone.note)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if !milestone.children.isEmpty {
                    Text("\(milestone.children.progressDone)/\(milestone.children.progressTotal)")
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(Theme.textSecondary)
                }
                if artwork.hasCover {
                    ChecklistThumbnail(cover: artwork.cover, tintHex: ChecklistLook.tintHex(milestone), side: thumbSide, marksWorkout: artwork.workout != nil)
                }
            }
            .padding(10)
            .background(shape.fill(Theme.surface2.opacity(0.62)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
            .contentShape(shape)
            .onTapGesture { if !isPreview { actions.edit(milestone) } }
            .contextMenu { if !isPreview { MilestoneMenu(milestone: milestone, actions: actions) } }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(ChecklistLook.spokenSummary(milestone))
            .accessibilityAction(named: "Edit") { if !isPreview { actions.edit(milestone) } }
            if !milestone.children.isEmpty {
                VStack(spacing: 8) {
                    ForEach(milestone.children) { child in
                        MilestoneRowView(pageID: pageID, milestone: child, depth: depth + 1, actions: actions, isPreview: isPreview)
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
}
