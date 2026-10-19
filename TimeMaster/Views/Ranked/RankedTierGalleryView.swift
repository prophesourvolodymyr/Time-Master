import SwiftUI

struct RankedTierGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsEditor = false
    @State private var selectedVariation: RankedVariation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Text("LOCAL PROFILE LEVELS").font(TimeMasterFont.sectionTitle())
                        .accessibilityAddTraits(.isHeader)
                    overallLevel
                    Text("Your editable exercise-specific display values—not earned or verified competitive ratings. Each movement opens its own leaderboard.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(RankedFamily.allCases) { family in
                        ProfileSettingsSection(title: family.title) {
                            ForEach(family.variations) { variation in
                                Button { selectedVariation = variation } label: {
                                    variationRow(variation)
                                }
                                .buttonStyle(TimeMasterCardButtonStyle())
                                .accessibilityHint("Opens the leaderboard for this exact movement")
                                .accessibilityIdentifier("ranked-rank-\(variation.rawValue)")
                                if variation != family.variations.last {
                                    Divider().overlay(Theme.surface2).padding(.horizontal, ProfileStyle.inset)
                                }
                            }
                        }
                    }
                    DisclosureGroup {
                        tierGuide.padding(.top, ProfileStyle.spacing)
                    } label: {
                        Label("Six-tier guide", systemImage: "shield.lefthalf.filled")
                            .font(TimeMasterFont.rowTitle())
                            .frame(minHeight: ProfileStyle.touchTarget)
                    }
                    .padding(ProfileStyle.inset)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .accessibilityIdentifier("ranked-tier-guide")
                    if profileStore.isReadOnly {
                        Text("Level editing is unavailable because the saved profile could not be read. Your original file is preserved.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { showsEditor = true } label: {
                    Text("Edit profile levels")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .disabled(profileStore.isReadOnly)
                .accessibilityIdentifier("ranked-gallery-edit")
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Your ranks")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showsEditor) { RankedLevelsEditorView() }
            .sheet(item: $selectedVariation) { variation in
                RankedLeaderboardView(initialVariation: variation)
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private var overallLevel: some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            RankedBadgeView(elo: profileStore.rankedLevels.overall).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall profile level").font(TimeMasterFont.rowTitle())
                Text(RankedTier.level(for: profileStore.rankedLevels.overall)?.title ?? "Unplaced")
                    .font(TimeMasterFont.heading())
                Text(profileStore.rankedLevels.overall.map { "\($0.formatted()) Elo · Local display value" } ?? "No overall level selected")
                    .font(TimeMasterFont.secondary().monospacedDigit())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
        .accessibilityElement(children: .combine)
    }

    private func variationRow(_ variation: RankedVariation) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            if !dynamicTypeSize.isAccessibilitySize {
                RankedMovementArt(variation: variation)
                    .frame(width: 56, height: 64)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(variation.title).font(TimeMasterFont.rowTitle())
                Text(profileStore.rankedLevels[variation].map { "\($0.formatted()) Elo · \(RankedTier.level(for: $0)?.title ?? "Unplaced")" } ?? "Unplaced · No local level")
                    .font(TimeMasterFont.secondary().monospacedDigit())
                    .foregroundStyle(ProfileStyle.secondary)
                Text(variation.isTimedHold ? "Timed hold" : variation.isAdvanced ? "Advanced · Repetitions" : "Repetitions")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            RankedBadgeView(elo: profileStore.rankedLevels[variation])
                .accessibilityHidden(true)
            Image(systemName: "chevron.right").font(.caption)
                .foregroundStyle(ProfileStyle.secondary)
                .padding(.top, ProfileStyle.spacing).accessibilityHidden(true)
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(variation.fullTitle)
        .accessibilityValue(profileStore.rankedLevels[variation].map { "\($0) Elo, \(RankedTier.level(for: $0)?.title ?? "Unplaced"), local profile level" } ?? "Unplaced, no local profile level")
    }

    private var tierGuide: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Badge thresholds for local profile levels. Choosing a level is not a competitive placement.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 144), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
                ForEach(RankedTier.allCases) { tier in
                    VStack(spacing: 8) {
                        Image(tier.assetName).resizable().scaledToFit()
                            .frame(maxHeight: 144).accessibilityHidden(true)
                        Text(tier.title).font(TimeMasterFont.rowTitle())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(tier.minimum.formatted())+ Elo")
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .foregroundStyle(ProfileStyle.secondary)
                        if RankedTier.level(for: profileStore.rankedLevels.overall) == tier {
                            Label("Your overall level", systemImage: "checkmark.circle.fill")
                                .font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(ProfileStyle.spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .modifier(TimeMasterCardSurface(flat: true))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
