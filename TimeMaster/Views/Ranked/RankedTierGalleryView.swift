import SwiftUI

struct RankedTierGalleryView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var selectedVariation: RankedVariation?
    @State private var showsAccount = false
    @State private var showsTiers = false
    @AppStorage("tm.ranked.family") private var family: RankedFamily = .pushUps

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset) {
                    TimeMasterPageTitle("Movement ranks", size: 26, relativeTo: .title3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        RankedMetric(value: "\(account.placedCount)/\(RankedFamily.allCases.reduce(0) { $0 + $1.variations.count })", unit: "ranks")
                            .accessibilityLabel("Earned exact-movement ranks")
                        Spacer()
                        RankedInfoButton(label: "Exercise-specific ranks", message: "Every exact movement has its own earned rating. The first five rated rounds are provisional placement. Unrelated ladders are never averaged. A dash means no earned rating.")
                        RankedIconAction(symbol: "square.grid.2x2", label: "Six-tier guide", id: "ranked-tier-guide") { showsTiers = true }
                        RankedIconAction(symbol: "person.badge.key", label: "Ranked account", id: "ranked-ranks-account") { showsAccount = true }
                    }
                    if account.loading { TmaxLoadingIndicator().accessibilityLabel("Loading earned ranks") }
                    if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
                    RankedFamilyPicker(family: $family)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                        ForEach(family.variations) { variation in
                            RankedRatingTile(variation: variation, rating: account.rating(for: variation)) { selectedVariation = variation }
                                .accessibilityHint("Open this movement's leaderboard")
                                .accessibilityIdentifier("ranked-rank-\(variation.rawValue)")
                        }
                    }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            .sheet(item: $selectedVariation) { RankedLeaderboardView(initialVariation: $0) }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .sheet(isPresented: $showsTiers) { tierGuide }
            .task { await account.restore(); if account.identity != nil { await account.refresh() } }
        }
        .tint(Theme.toolbarOrange)
    }

    private var tierGuide: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                    ForEach(RankedTier.allCases) { tier in
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(tier.assetName).resizable().scaledToFit().aspectRatio(1, contentMode: .fit)
                            Text(tier.title).font(TimeMasterFont.rowTitle())
                            RankedMetric(value: "\(tier.minimum.formatted())+", unit: "Elo")
                        }
                        .padding(ProfileStyle.spacing)
                        .modifier(TimeMasterCardSurface(flat: true))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tier.title)
                        .accessibilityValue("\(tier.minimum) Elo or higher")
                    }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
        }
        .tint(Theme.toolbarOrange)
    }
}
