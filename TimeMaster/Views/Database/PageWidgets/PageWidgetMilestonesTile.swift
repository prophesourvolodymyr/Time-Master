import SwiftUI
import TimeMasterCore

/// Milestones: the next one to reach over its cover (or the picture of the workout or page it links, or its colour),
/// with its icon and title, and how many are reached as a bar. When all are reached, or there are none yet, it says so.
/// A tap opens the milestones.
struct PageWidgetMilestonesTile: View {
    let pageID: String
    let milestones: [Milestone]
    let onOpen: (PageWidgetTarget) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    var body: some View {
        let next = milestones.first { !$0.isSection && !$0.isDone }
        PageWidgetTile(kind: .milestones, target: .milestones, summary: summary(next: next), onOpen: onOpen) {
            if milestones.progressTotal == 0 {
                VStack(alignment: .leading, spacing: 0) {
                    PageWidgetHeader(kind: .milestones)
                    PageWidgetEmptyState(systemImage: "flag.checkered", title: "No milestones yet")
                }
                .padding(PageWidgetMetrics.inset)
            } else {
                content(next: next)
            }
        }
    }

    private func content(next: Milestone?) -> some View {
        let tint = next.map { ChecklistLook.tint($0) } ?? Theme.toolbarOrange
        let artwork = next.map { ChecklistArtwork.resolve($0, pageID: pageID, store: store, workouts: workoutStore.workouts) }
        let cover = artwork?.cover ?? ChecklistArtwork.Cover.none
        let overPicture = Self.isPicture(cover)
        return ZStack(alignment: .bottomLeading) {
            coverLayer(cover, tint: tint)
            VStack(alignment: .leading, spacing: 8) {
                PageWidgetHeader(kind: .milestones, overPicture: overPicture)
                Spacer(minLength: 0)
                if let next, let artwork {
                    HStack(spacing: 8) {
                        ChecklistIconTile(
                            icon: artwork.icon,
                            tintHex: ChecklistLook.tintHex(next),
                            side: 30,
                            fallbackSymbol: ChecklistLook.milestoneIconName,
                            onCard: true
                        )
                        Text(next.title)
                            .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.leading)
                            .shadow(color: overPicture ? .black.opacity(0.5) : .clear, radius: 2, y: 1)
                    }
                } else {
                    Label("All reached", systemImage: "checkmark.seal.fill")
                        .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.toolbarOrange)
                }
                HStack(spacing: 8) {
                    PageWidgetBar(fraction: milestones.progressFraction, tint: tint)
                    Text("\(milestones.progressDone) of \(milestones.progressTotal)")
                        .font(TimeMasterFont.black(11, relativeTo: .caption2).monospacedDigit())
                        .foregroundStyle(overPicture ? Color.white.opacity(0.85) : Theme.textSecondary)
                        .fixedSize()
                }
            }
            .padding(PageWidgetMetrics.inset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func coverLayer(_ cover: ChecklistArtwork.Cover, tint: Color) -> some View {
        switch cover {
        case .picture(let url):
            Color.clear
                .overlay {
                    if url.isFileURL {
                        SkillLocalImage(url: url, maxPixel: 640)
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            tint.opacity(0.2)
                        }
                    }
                }
                .clipped()
                .overlay { shade }
        case .workout(let workout):
            WorkoutWideCover(workout: workout, height: PageWidgetMetrics.tileHeight)
                .overlay { shade }
        case .missingFile, .none:
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [tint.opacity(0.32), tint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "flag.checkered")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(tint.opacity(0.16))
                    .offset(x: 10, y: 4)
            }
        }
    }

    /// Darkens a picture towards the foot of the tile, where the title and the bar sit.
    private var shade: some View {
        LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
    }

    private static func isPicture(_ cover: ChecklistArtwork.Cover) -> Bool {
        switch cover {
        case .picture, .workout: true
        case .missingFile, .none: false
        }
    }

    private func summary(next: Milestone?) -> String {
        guard milestones.progressTotal > 0 else { return "Milestones: none yet" }
        let reached = "\(milestones.progressDone) of \(milestones.progressTotal) reached"
        guard let next else { return "Milestones: all reached, \(reached)" }
        return "Milestones: next, \(next.title). \(reached)"
    }
}
