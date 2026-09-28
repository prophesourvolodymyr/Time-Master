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
        OutdoorAdaptivePane { compact in
            GeometryReader { proxy in
                let diameter = max(44, min(compact ? 94 : 136, proxy.size.width * 0.58, proxy.size.height * 0.82))
                HStack(spacing: 12) {
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
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } actions: { compact in
            Group {
                if compact {
                    LazyVGrid(columns: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 6) {
                        featureButtons(compact: true)
                    }
                } else {
                    HStack(spacing: 4) { featureButtons(compact: false) }
                }
            }
            .padding(3)
            .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .transaction { if isDragging { $0.animation = nil; $0.disablesAnimations = true } }
    }

    private func featureButtons(compact: Bool) -> some View {
        ForEach(OutdoorRouteFeature.allCases) { feature in
            Button { onFeature(feature) } label: {
                VStack(spacing: 5) {
                    Image(systemName: feature.systemImage)
                        .font(.title3.weight(.semibold))
                    if !compact {
                        Text(feature.title).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                }
                .frame(width: compact ? 44 : nil)
                .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 60)
                .foregroundStyle(activeFeature == feature ? Theme.restAccent : Theme.textPrimary.opacity(0.8))
                .background(activeFeature == feature ? Theme.restAccent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(feature.title)
            .accessibilityValue(activeFeature == feature ? "Open" : "Closed")
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
