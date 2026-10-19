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

struct RankedMovementTile: View {
    let variation: RankedVariation
    let elo: Int?
    let mode: RankedMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RankedMovementArt(variation: variation)
                    .aspectRatio(1.35, contentMode: .fit)
                    .padding(.vertical, 8)
                Text(variation.title).font(TimeMasterFont.rowTitle())
                    .fixedSize(horizontal: false, vertical: true)
                Label(variation.isTimedHold ? "Hold time" : "Repetitions", systemImage: variation.isTimedHold ? "timer" : "repeat")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(mode == .practice ? "Practice" : elo.map { "\($0.formatted()) Elo" } ?? "Unplaced")
                    .font(TimeMasterFont.caption().monospacedDigit())
                    .foregroundStyle(isSelected ? .white : ProfileStyle.secondary)
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(TimeMasterCardSurface(flat: true))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous)
                        .strokeBorder(Theme.toolbarOrange, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").symbolRenderingMode(.palette)
                        .foregroundStyle(.black, Theme.toolbarOrange)
                        .padding(8).accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner, style: .continuous))
        }
        .buttonStyle(TimeMasterCardButtonStyle())
        .foregroundStyle(.white)
        .accessibilityLabel(variation.fullTitle)
        .accessibilityValue(mode == .practice ? "Practice" : elo.map { "\($0) Elo, profile level" } ?? "Unplaced")
        .accessibilityHint(variation.isTimedHold ? "Select a timed hold" : "Select a repetition-based movement")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("ranked-variation-\(variation.rawValue)")
    }
}

struct RankedProfileSummary: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: EverSpacing.x1) {
                Text("Elo")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(profileStore.rankedLevels.overall.map { $0.formatted() } ?? "Unplaced")
                    .font(profileStore.rankedLevels.overall == nil ? TimeMasterFont.rowTitle() : TimeMasterFont.title())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Local level")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(EverPressButtonStyle())
        .foregroundStyle(.white)
        .accessibilityIdentifier("profile-ranked-summary")
    }
}
