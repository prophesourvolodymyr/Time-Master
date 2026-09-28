#if os(iOS)
import SwiftUI

struct OutdoorStartContent: View {
    @ObservedObject var store: OutdoorActivityStore
    let isDragging: Bool
    let committedKind: OutdoorActivityKind
    let activeFeature: OutdoorRouteFeature?
    let onLibrary: () -> Void
    let onStart: () -> Void
    let onFeature: (OutdoorRouteFeature) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var recentRouteID: UUID?
    @State private var recentRoutePoints: [OutdoorTrackPoint] = []

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let diameter = max(44, min(136, proxy.size.width * 0.42, proxy.size.height * 0.9))
                HStack(spacing: 16) {
                    Button(action: onLibrary) {
                        Group {
                            if let recentRouteID, recentRoutePoints.count > 1 {
                                OutdoorRouteThumbnailView(
                                    points: recentRoutePoints,
                                    compact: true,
                                    cacheKey: recentRouteID.uuidString,
                                    aspectRatio: 1
                                )
                                .accessibilityHidden(true)
                            } else {
                                Image(systemName: "square.grid.2x2")
                                    .font(.title3)
                            }
                        }
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Library")
                    .accessibilityHint(recentRouteID == nil ? "Opens your recorded workouts" : "Shows your latest recorded route. Opens your workout library")

                    Button(action: onStart) {
                        VStack(spacing: 4) {
                            Text("Start").font(.headline.weight(.bold))
                            Text(committedKind.displayName).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: diameter, height: diameter)
                        .background(Theme.restAccent, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(committedKind.displayName) recording")

                    Button { onFeature(.route) } label: {
                        Image("LucideRoute")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Routes")
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }

            HStack(spacing: 4) {
                featureButton(.type)
                featureButton(.rate)
                featureButton(.music)
            }
            .padding(3)
            .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .foregroundStyle(Theme.textPrimary)
        .transaction { if isDragging { $0.animation = nil; $0.disablesAnimations = true } }
        .onAppear(perform: loadRecentRoute)
        .onChange(of: store.activities) { _ in loadRecentRoute() }
    }

    private func loadRecentRoute() {
        for activity in store.establishedActivities.sorted(by: {
            ($0.establishedAt ?? $0.startedAt) > ($1.establishedAt ?? $1.startedAt)
        }) {
            let points = store.trackPoints(for: activity)
            if points.count > 1 {
                recentRouteID = activity.id
                recentRoutePoints = points
                return
            }
        }
        recentRouteID = nil
        recentRoutePoints = []
    }

    private func featureButton(_ feature: OutdoorRouteFeature) -> some View {
        Button { onFeature(feature) } label: {
            Image(systemName: feature == .type ? committedKind.iconName : feature.systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(activeFeature == feature ? Theme.restAccent : Theme.textPrimary.opacity(0.8))
                .background(activeFeature == feature ? Theme.restAccent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature == .type ? "Workout type" : feature.title)
        .accessibilityValue(feature == .type ? committedKind.displayName : activeFeature == feature ? "Open" : "Closed")
    }
}
#endif
