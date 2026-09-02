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
        94 + 42 * clampedExpansion
    }

    private var sideControlSize: CGFloat {
        48 + 10 * clampedExpansion
    }

    private var modeIconHeight: CGFloat {
        26 + 10 * clampedExpansion
    }

    private var modeLabelHeight: CGFloat {
        labelOpacity * (13 + 2 * clampedExpansion)
    }

    private var modeBarContentHeight: CGFloat {
        max(44, modeIconHeight + 3 + 3 * clampedExpansion + modeLabelHeight)
    }

    private var modeBarHeight: CGFloat {
        modeBarContentHeight + 6
    }

    private var startRowHeight: CGFloat {
        startSize + 4
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Button(action: onStart) {
                    Text("Start")
                        .font(dynamicTypeSize.isAccessibilitySize ? .headline.weight(.bold) : .system(size: 16 + 4 * clampedExpansion, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .buttonStyle(OutdoorPineButtonStyle(prominent: true, circular: true, minimumSize: startSize))
                .frame(width: startSize, height: startSize)
                .accessibilityLabel("Start \(committedKind.displayName) recording")

                Button(action: onLibrary) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(OutdoorPineButtonStyle(circular: false, minimumSize: sideControlSize))
                .frame(width: sideControlSize, height: sideControlSize)
                .offset(x: -(startSize / 2 + 12 + sideControlSize / 2))
                .accessibilityLabel("Library")
                .accessibilityHint("Show established workouts in this route pane")
            }
            .frame(maxWidth: .infinity)
            .frame(height: startRowHeight)

            Spacer(minLength: 8)

            modeBar
        }
        .padding(.top, 44)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .animation(isDragging || reduceMotion ? .none : .spring(response: 0.34, dampingFraction: 0.9), value: clampedExpansion)
        .transaction { transaction in
            if isDragging {
                transaction.animation = nil
            }
        }
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
                            .frame(height: modeIconHeight)
                        Text(feature.title)
                            .font(dynamicTypeSize.isAccessibilitySize ? .caption2.weight(.semibold) : .system(size: 10 + 2 * clampedExpansion, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(height: modeLabelHeight)
                            .opacity(labelOpacity)
                            .offset(y: (1 - labelOpacity) * 3)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(height: modeBarContentHeight)
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.28))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: modeBarHeight)
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
