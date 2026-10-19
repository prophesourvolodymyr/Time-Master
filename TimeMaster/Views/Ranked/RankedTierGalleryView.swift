import SwiftUI

struct RankedTierGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var account = RankedAccountStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedVariation: RankedVariation?
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Text("\(account.placedCount) earned movement ranks").font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
                    Text("Every exact movement has its own rating. Placement is provisional for the first five rated rounds. Unrelated ladders are never averaged.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    if account.identity == nil {
                        Button("Sign in to load ranks") { showsAccount = true }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                    }
                    if account.loading { ProgressView() }
                    if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
                    ForEach(RankedFamily.allCases) { family in
                        ProfileSettingsSection(title: family.title) {
                            ForEach(family.variations) { variation in
                                Button { selectedVariation = variation } label: {
                                    HStack(spacing: ProfileStyle.spacing) {
                                        if !dynamicTypeSize.isAccessibilitySize { RankedMovementArt(variation: variation).frame(width: 56, height: 64) }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(variation.title).font(TimeMasterFont.rowTitle())
                                            Text(account.rating(for: variation)?.label ?? "Unplaced")
                                                .font(TimeMasterFont.caption().monospacedDigit()).foregroundStyle(ProfileStyle.secondary)
                                            if variation.isAdvanced {
                                                Text("Practice · Verification evidence required for Ranked")
                                                    .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                                            }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        RankedBadgeView(elo: account.rating(for: variation)?.rating)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(ProfileStyle.secondary)
                                    }.padding(ProfileStyle.inset).contentShape(Rectangle())
                                }
                                .buttonStyle(TimeMasterCardButtonStyle())
                                .accessibilityLabel(variation.fullTitle).accessibilityValue(account.rating(for: variation)?.label ?? "Unplaced")
                                .accessibilityIdentifier("ranked-rank-\(variation.rawValue)")
                            }
                        }
                    }
                    DisclosureGroup {
                        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 144))], spacing: ProfileStyle.spacing) {
                            ForEach(RankedTier.allCases) { tier in
                                VStack(spacing: ProfileStyle.spacing) {
                                    Image(tier.assetName).resizable().scaledToFit().frame(maxHeight: 144).accessibilityHidden(true)
                                    Text(tier.title).font(TimeMasterFont.rowTitle())
                                    Text("\(tier.minimum.formatted())+ Elo").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                }
                                .padding(ProfileStyle.inset).frame(maxWidth: .infinity, maxHeight: .infinity)
                                .modifier(TimeMasterCardSurface(flat: true)).accessibilityElement(children: .combine)
                            }
                        }.padding(.top, ProfileStyle.spacing)
                    } label: { Label("Six-tier guide", systemImage: "shield.lefthalf.filled").font(TimeMasterFont.rowTitle()).frame(minHeight: ProfileStyle.touchTarget) }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white).navigationTitle("Your ranks")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .sheet(item: $selectedVariation) { RankedLeaderboardView(initialVariation: $0) }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .task { await account.restore(); if account.identity != nil { await account.refresh() } }
        }.tint(Theme.toolbarOrange)
    }
}
