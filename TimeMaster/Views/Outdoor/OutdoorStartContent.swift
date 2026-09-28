#if os(iOS)
import SwiftUI

struct OutdoorStartContent: View {
    let isDragging: Bool
    let committedKind: OutdoorActivityKind
    let activeFeature: OutdoorRouteFeature?
    let onLibrary: () -> Void
    let onStart: () -> Void
    let onFeature: (OutdoorRouteFeature) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let diameter = max(44, min(136, proxy.size.width * 0.42, proxy.size.height * 0.9))
                HStack(spacing: 16) {
                    Button(action: onLibrary) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Library")

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
                        Image(systemName: OutdoorRouteFeature.route.systemImage)
                            .font(.title3.weight(.semibold))
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
