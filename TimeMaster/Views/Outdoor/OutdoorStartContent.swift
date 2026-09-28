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
            Spacer(minLength: 8)
            ZStack {
                Button(action: onStart) {
                    VStack(spacing: 4) {
                        Text("Start")
                            .font(dynamicTypeSize.isAccessibilitySize ? .headline.weight(.bold) : .system(size: 16 + 4 * clampedExpansion, weight: .bold, design: .rounded))
                        Text(committedKind.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary.opacity(0.8))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: startSize, height: startSize)
                    .background(Theme.restAccent, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .accessibilityLabel("Start \(committedKind.displayName) recording")

                Button(action: onLibrary) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: sideControlSize, height: sideControlSize)
                        .background(Theme.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .offset(x: -(startSize / 2 + 12 + sideControlSize / 2))
                .accessibilityLabel("Library")
                .accessibilityHint("Show established workouts in this route pane")

            }
            .frame(maxWidth: .infinity)
            .frame(height: startRowHeight)

            Spacer(minLength: 8)

            modeBar
        }
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

struct OutdoorModeConfirmation: View {
    let prompt: OutdoorModeReminder.Prompt
    @Binding var kind: OutdoorActivityKind
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        Text(prompt == .choose ? "What are you heading out for?" : "Ready for a \(kind.displayName.lowercased())?")
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Cancel", action: onCancel)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minHeight: 44)
                    }
                    Text(prompt == .choose ? "Choose the mode before your recording starts." : "Confirm the mode, or change it here. We won’t ask again during this session.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    if prompt == .choose {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { modeChoices }
                            VStack(spacing: 8) { modeChoices }
                        }
                    } else {
                        OutdoorActivityTypePicker(kind: $kind)
                    }
                }
                .padding(24)
                .padding(.top, 12)
            }
            Button(action: onConfirm) {
                Label("Start \(kind.displayName)", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .accessibilityIdentifier("confirm-outdoor-mode")
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.surface)
    }

    private var modeChoices: some View {
        ForEach(OutdoorActivityKind.newRecordingChoices) { option in
            Button {
                kind = option
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: option.iconName)
                        .font(.title2.weight(.semibold))
                    Text(option.displayName)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(kind == option ? Theme.restAccent : Theme.textPrimary)
                .background(kind == option ? Theme.restAccent.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(kind == option ? Theme.restAccent : Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(option.displayName)
            .accessibilityAddTraits(kind == option ? .isSelected : [])
        }
    }
}

#endif
