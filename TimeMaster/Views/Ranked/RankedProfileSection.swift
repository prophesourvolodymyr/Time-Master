import SwiftUI

struct RankedProfileSection: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    let onOpenRanked: (RankedVariation) -> Void
    @State private var showsEditor = false
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 88
    @ScaledMetric(relativeTo: .body) private var artSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            HStack(spacing: ProfileStyle.spacing) {
                RankedBadgeView(elo: profileStore.rankedLevels.overall, size: badgeSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall profile level").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    Text(profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo" } ?? "Unplaced")
                        .font(TimeMasterFont.title().monospacedDigit())
                    Text(RankedTier.level(for: profileStore.rankedLevels.overall)?.title ?? "Choose your starting look")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
            Button { showsEditor = true } label: {
                Label("Edit Elo levels", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(EverPrimaryButtonStyle())
            .disabled(profileStore.isReadOnly)
            .accessibilityIdentifier("profile-ranked-edit")
            Text("Manually set on this device. Not a verified competitive rating.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(RankedFamily.allCases) { family in
                ProfileSettingsSection(title: family.title) {
                    ForEach(family.variations) { variation in
                        Button { onOpenRanked(variation) } label: {
                            HStack(spacing: ProfileStyle.spacing) {
                                RankedMovementArt(variation: variation).frame(width: artSize, height: artSize)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variation.title).font(TimeMasterFont.rowTitle())
                                    Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) Elo" } ?? "Unplaced")
                                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                }
                                Spacer()
                                RankedBadgeView(elo: profileStore.rankedLevels[variation])
                                Image(systemName: "arrow.up.right").font(.body.weight(.bold))
                                    .foregroundStyle(Theme.toolbarOrange)
                            }
                            .padding(ProfileStyle.spacing)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityLabel("Open \(variation.fullTitle) in Ranked")
                        .accessibilityIdentifier("profile-compete-\(variation.rawValue)")
                    }
                }
            }
        }
        .sheet(isPresented: $showsEditor) { RankedLevelsEditorView() }
    }
}
