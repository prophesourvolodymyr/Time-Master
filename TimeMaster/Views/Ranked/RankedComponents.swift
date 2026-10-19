import SwiftUI

struct RankedBadgeView: View {
    let elo: Int?
    var size: CGFloat = ProfileStyle.touchTarget

    var body: some View {
        Group {
            if let tier = RankedTier.level(for: elo) {
                Image(tier.assetName).resizable().scaledToFit()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .resizable().scaledToFit().padding(size * 0.2)
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(RankedTier.level(for: elo)?.title ?? "Unplaced")
    }
}

struct RankedMovementArt: View {
    let variation: RankedVariation
    var body: some View {
        Image(variation.assetName).resizable().scaledToFit().accessibilityHidden(true)
    }
}

struct RankedActionStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TimeMasterFont.label())
            .foregroundStyle(.black)
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            .background(Theme.toolbarOrange, in: RoundedRectangle(cornerRadius: ProfileStyle.inset))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct RankedMovementTile: View {
    let variation: RankedVariation
    let elo: Int?
    let mode: RankedMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                RankedMovementArt(variation: variation).aspectRatio(1.35, contentMode: .fit)
                Text(variation.title).font(TimeMasterFont.rowTitle())
                    .fixedSize(horizontal: false, vertical: true)
                if variation.isTimedHold {
                    Label("Hold time", systemImage: "timer").font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                Text(mode == .practice ? "Practice" : elo.map { "\($0.formatted()) Elo" } ?? "Unplaced")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(isSelected ? .white : ProfileStyle.secondary)
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
            .overlay {
                RoundedRectangle(cornerRadius: ProfileStyle.corner)
                    .strokeBorder(isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isSelected ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette)
                        .foregroundStyle(.black, Theme.toolbarOrange)
                        .padding(8).accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .foregroundStyle(.white)
        .accessibilityLabel(variation.fullTitle)
        .accessibilityValue(mode == .practice ? "Practice" : elo.map { "\($0) Elo, profile level" } ?? "Unplaced")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("ranked-variation-\(variation.rawValue)")
    }
}

struct RankedProfileSummary: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RankedBadgeView(elo: profileStore.rankedLevels.overall)
                VStack(alignment: .leading, spacing: 2) {
                    Text(RankedTier.level(for: profileStore.rankedLevels.overall)?.title ?? "Unplaced")
                        .font(TimeMasterFont.rowTitle())
                    Text(profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo · Profile level" } ?? "Set your Ranked profile level")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .padding(.horizontal, ProfileStyle.spacing)
            .padding(.vertical, 4)
            .background(Theme.surface2, in: Capsule())
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .foregroundStyle(.white)
        .accessibilityIdentifier("profile-ranked-summary")
    }
}
