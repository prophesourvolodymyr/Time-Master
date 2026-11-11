import SwiftUI
import TimeMasterCore

/// A top-level milestone: a big card with its cover across the top (or the picture of the workout or exercise it
/// links), its icon hanging over the cover's edge, the check on the cover, the title, a few lines of note, its
/// pictures and link chips and, when it holds sub-milestones, a progress bar and a row for each of them.
struct MilestoneCardView: View {
    let pageID: String
    let milestone: Milestone
    let actions: MilestoneActions
    /// The editor's preview: nothing responds to the pointer.
    var isPreview = false

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var isHovering = false
    @ScaledMetric(relativeTo: .title) private var coverHeight: CGFloat = 150
    @ScaledMetric(relativeTo: .title) private var iconSide: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var stripSide: CGFloat = 44

    static let corner: CGFloat = 26

    var body: some View {
        let workouts = workoutStore.workouts
        let artwork = ChecklistArtwork.resolve(milestone, pageID: pageID, store: store, workouts: workouts)
        let tint = ChecklistLook.tint(milestone)
        let shape = RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
        let page = store.page(manifestID: pageID)
        VStack(alignment: .leading, spacing: 0) {
            ChecklistCoverView(cover: artwork.cover, tintHex: ChecklistLook.tintHex(milestone), height: coverHeight)
                .overlay(alignment: .topTrailing) {
                    MilestoneCheckButton(milestone: milestone, overPicture: true) { actions.toggle(milestone) }
                        .padding(12)
                        .allowsHitTesting(!isPreview)
                }
                .overlay(alignment: .bottomLeading) {
                    ChecklistIconTile(icon: artwork.icon, tintHex: ChecklistLook.tintHex(milestone), side: iconSide, fallbackSymbol: ChecklistLook.milestoneIconName, onCard: true)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .padding(.leading, 18)
                        .offset(y: iconSide / 2)
                }
                .zIndex(1)
            VStack(alignment: .leading, spacing: 10) {
                Text(milestone.title)
                    .font(TimeMasterFont.black(22, relativeTo: .title2))
                    .foregroundStyle(milestone.isDone ? Theme.textSecondary : Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if milestone.isDone, let reached = milestone.doneAt {
                    Label(reached.formatted(.dateTime.month(.abbreviated).day().year()), systemImage: "checkmark.seal.fill")
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(Theme.toolbarOrange)
                }
                if !milestone.note.isEmpty {
                    Text(milestone.note)
                        .font(TimeMasterFont.body(15))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let pictures = milestone.imageFilenames.compactMap { store.checklistPictureURL($0, on: pageID) }
                if !pictures.isEmpty {
                    ChecklistImageStrip(urls: pictures, side: stripSide, onOpen: actions.openPicture)
                        .allowsHitTesting(!isPreview)
                }
                if !milestone.links.isEmpty {
                    ChecklistFlowLayout(spacing: 6) {
                        ForEach(milestone.links) { link in
                            let target = store.checklistTarget(of: link, on: pageID, workouts: workouts)
                            ChecklistLinkChip(
                                link: link,
                                target: target,
                                linkMetadata: page?.manifest.linkMetadata ?? [],
                                comments: page?.manifest.mediaComments ?? [:],
                                onOpen: { actions.openLink(link, target) },
                                onPlay: playAction(for: target),
                                onRemove: isPreview ? nil : { actions.removeLink(milestone, link) }
                            )
                            .allowsHitTesting(!isPreview)
                        }
                    }
                }
                if !milestone.children.isEmpty {
                    progressRow(tint: tint)
                    VStack(spacing: 8) {
                        ForEach(milestone.children) { child in
                            MilestoneRowView(pageID: pageID, milestone: child, depth: 1, actions: actions, isPreview: isPreview)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, iconSide / 2 + 10)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(shape)
        .modifier(TimeMasterCardSurface(cornerRadius: Self.corner, accent: tint, emphasized: !milestone.isDone))
        .overlay {
            shape.strokeBorder(Color.white.opacity(isHovering && !isPreview ? 0.22 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .opacity(milestone.isDone ? 0.84 : 1)
        .contentShape(shape)
        .onHover { isHovering = $0 }
        .onTapGesture { if !isPreview { actions.edit(milestone) } }
        .contextMenu { if !isPreview { MilestoneMenu(milestone: milestone, actions: actions) } }
        .keyNavTarget(id: "milestone-\(milestone.id)", shape: .roundedRectangle(cornerRadius: Self.corner)) {
            if !isPreview { actions.edit(milestone) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ChecklistLook.spokenSummary(milestone))
        .accessibilityAction(named: "Edit") { if !isPreview { actions.edit(milestone) } }
        .accessibilityAction(named: "Add sub-milestone") { if !isPreview { actions.addChild(milestone) } }
    }

    private func playAction(for target: ChecklistLinkTarget) -> (() -> Void)? {
        guard !isPreview, case .workout(let workout) = target else { return nil }
        return { actions.playWorkout(workout) }
    }

    private func progressRow(tint: Color) -> some View {
        let fraction = milestone.children.progressFraction
        return HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(tint).frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * fraction))
                }
            }
            .frame(height: 6)
            Text("\(milestone.children.progressDone)/\(milestone.children.progressTotal)")
                .font(TimeMasterFont.technical())
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityHidden(true)
    }
}
