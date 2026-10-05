#if os(iOS)
import SwiftUI

struct OutdoorStartContent: View, Animatable {
    @ObservedObject var store: OutdoorActivityStore
    let isDragging: Bool
    var expansion: CGFloat
    var labelProgress: CGFloat
    let committedKind: OutdoorActivityKind
    let activeFeature: OutdoorRouteFeature?
    let onLibrary: () -> Void
    let onStart: () -> Void
    let onFeature: (OutdoorRouteFeature) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 16
    @State private var recentRouteID: UUID?
    @State private var recentRoutePoints: [OutdoorTrackPoint] = []

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(expansion, labelProgress) }
        set {
            expansion = newValue.first
            labelProgress = newValue.second
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let featureHeight = 44 + (max(44, min(96, geometry.size.height * 0.28)) - 44) * labelProgress
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let sideSize = max(44, min(44 + 28 * expansion, proxy.size.width * 0.19, proxy.size.height * 0.6))
                    let diameter = max(44, min(94 + 138 * expansion, proxy.size.width * (0.42 + 0.06 * expansion), proxy.size.height * 0.9, proxy.size.width - 2 * sideSize - 32 - 8 * expansion))
                    HStack(spacing: 16 + 4 * expansion) {
                        Button(action: onLibrary) {
                            VStack(spacing: 6 * labelProgress) {
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
                                            .font(.system(size: 17 + 5 * expansion, weight: .semibold))
                                    }
                                }
                                .frame(width: sideSize, height: sideSize)
                                .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text("Library")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(width: sideSize, height: labelHeight * labelProgress)
                                    .opacity(labelProgress)
                                    .clipped()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Library")
                        .accessibilityHint(recentRouteID == nil ? "Opens your recorded workouts" : "Shows your latest recorded route. Opens your workout library")

                        Button(action: onStart) {
                            VStack(spacing: 4) {
                                Text("Start").font(.system(size: 24, weight: .bold, design: .rounded))
                                Text(committedKind.displayName).font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(94 * 0.14)
                            .frame(width: 94, height: 94)
                            .scaleEffect(diameter / 94)
                            .frame(width: diameter, height: diameter)
                            .background(Theme.restAccent, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(committedKind.displayName) recording")

                        Button { onFeature(.route) } label: {
                            VStack(spacing: 6 * labelProgress) {
                                Image("LucideRoute")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24 + (sideSize * 0.5 - 24) * expansion, height: 24 + (sideSize * 0.5 - 24) * expansion)
                                    .frame(width: sideSize, height: sideSize)
                                    .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text("Routes")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(width: sideSize, height: labelHeight * labelProgress)
                                    .opacity(labelProgress)
                                    .clipped()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Routes")
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }

                HStack(spacing: 4) {
                    featureButton(.type, height: featureHeight)
                    featureButton(.rate, height: featureHeight)
                    featureButton(.music, height: featureHeight)
                }
                .padding(3)
                .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
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

    private func featureButton(_ feature: OutdoorRouteFeature, height: CGFloat) -> some View {
        Button { onFeature(feature) } label: {
            VStack(spacing: 6 * labelProgress) {
                Image(systemName: feature == .type ? committedKind.iconName : feature.systemImage)
                    .font(.system(size: 17 + 5 * expansion, weight: .semibold))
                Text(feature.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: labelHeight * labelProgress)
                    .opacity(labelProgress)
                    .clipped()
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(activeFeature == feature ? Theme.restAccent : Theme.textPrimary.opacity(0.8))
            .background(activeFeature == feature ? Theme.restAccent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature == .type ? "Workout type" : feature.title)
        .accessibilityValue(feature == .type ? committedKind.displayName : activeFeature == feature ? "Open" : "Closed")
    }
}
#endif
