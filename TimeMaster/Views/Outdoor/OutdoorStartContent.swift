#if os(iOS)
import SwiftUI

struct OutdoorStartContent: View {
    let expansion: CGFloat
    let isDragging: Bool
    let committedKind: OutdoorActivityKind
    let activeFeature: OutdoorRouteFeature?
    let onLibrary: () -> Void
    let onStart: () -> Void
    let onFeature: (OutdoorRouteFeature) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var clampedExpansion: CGFloat {
        min(1, max(0, expansion))
    }

    private var startSize: CGFloat {
        76 + 42 * clampedExpansion
    }

    private var controlSize: CGFloat {
        44 + 10 * clampedExpansion
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onLibrary) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: false))
                .accessibilityLabel("Library")
                .accessibilityHint("Show established workouts in this route pane")

                Spacer(minLength: 0)

                Button(action: onStart) {
                    Text("Start")
                        .font(dynamicTypeSize.isAccessibilitySize ? .headline.weight(.bold) : .system(size: 14 + 4 * clampedExpansion, weight: .bold, design: .rounded))
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true, circular: true))
                .frame(width: startSize, height: startSize)
                .accessibilityLabel("Start \(committedKind.displayName) recording")

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: controlSize, height: controlSize)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            Spacer(minLength: 8)

            modeBar
        }
        .padding(.top, 44)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .animation(isDragging || reduceMotion ? .none : .spring(response: 0.34, dampingFraction: 0.9), value: clampedExpansion)
    }

    private var modeBar: some View {
        HStack(spacing: 2) {
            ForEach(OutdoorRouteFeature.allCases) { feature in
                Button {
                    onFeature(feature)
                } label: {
                    VStack(spacing: 3 + 3 * clampedExpansion) {
                        featureIcon(feature)
                            .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.semibold) : .system(size: 19 + 10 * clampedExpansion, weight: .semibold))
                            .frame(height: 26 + 10 * clampedExpansion)
                        Text(feature.title)
                            .font(dynamicTypeSize.isAccessibilitySize ? .caption2.weight(.semibold) : .system(size: 10 + 2 * clampedExpansion, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 13 + 2 * clampedExpansion)
                            .opacity(labelOpacity)
                            .offset(y: (1 - labelOpacity) * 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(activeFeature == feature ? Theme.restAccent : Theme.textPrimary.opacity(0.78))
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(activeFeature == feature ? Theme.restAccent.opacity(0.16) : .clear)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(feature.title)
                .accessibilityValue(activeFeature == feature ? "Open" : "Closed")
                .accessibilityHint("Open the \(feature.title) feature")
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.28))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var labelOpacity: CGFloat {
        min(1, max(0, (clampedExpansion - 0.08) / 0.22))
    }

    @ViewBuilder
    private func featureIcon(_ feature: OutdoorRouteFeature) -> some View {
        if #available(iOS 17.0, *), !reduceMotion {
            Image(systemName: feature.systemImage)
                .symbolEffect(.bounce, value: activeFeature == feature)
        } else {
            Image(systemName: feature.systemImage)
        }
    }
}

#endif
