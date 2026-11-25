import SwiftUI
import TimeMasterCore

struct PageWidgetMilestonesTile: View {
    let pageID: String
    let milestones: [Milestone]
    let onOpen: (PageWidgetTarget) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore

    var body: some View {
        let next = milestones.first { !$0.isSection && !$0.isDone }
        let cover = next.map { ChecklistArtwork.resolve($0, pageID: pageID, store: store, workouts: workoutStore.workouts).cover }
            ?? ChecklistArtwork.Cover.none
        let picture = Self.isPicture(cover)
        PageWidgetTile(
            kind: .milestones,
            target: .milestones,
            summary: summary(next: next),
            art: picture ? nil : (milestones.progressTotal > 0 && next == nil ? .trophy : .medal),
            onOpen: onOpen
        ) {
            if milestones.progressTotal == 0 {
                PageWidgetEmptyState(systemImage: nil, title: "No milestones yet")
            } else if picture {
                ZStack(alignment: .bottomLeading) {
                    coverLayer(cover)
                    VStack(alignment: .leading, spacing: 8) {
                        title(next)
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        WidgetBar(fraction: milestones.progressFraction, height: 6)
                    }
                    .padding(PageWidgetMetrics.inset)
                    .environment(\.widgetTint, .graphite)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    title(next)
                    Spacer(minLength: 0)
                    WidgetBar(fraction: milestones.progressFraction, height: 6)
                        .frame(width: 88)
                }
                .padding(PageWidgetMetrics.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    private func title(_ next: Milestone?) -> some View {
        WidgetTitle(text: next?.title ?? "All reached", size: 17, lines: 2)
    }

    @ViewBuilder
    private func coverLayer(_ cover: ChecklistArtwork.Cover) -> some View {
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
                            Theme.surface2
                        }
                    }
                }
                .clipped()
                .overlay { shade }
        case .workout(let workout):
            WorkoutWideCover(workout: workout, height: PageWidgetMetrics.tileHeight)
                .overlay { shade }
        case .missingFile, .none:
            EmptyView()
        }
    }

    private var shade: some View {
        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
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
