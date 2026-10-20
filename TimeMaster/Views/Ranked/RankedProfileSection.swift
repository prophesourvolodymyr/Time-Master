import SwiftUI

struct RankedProfileSection: View {
    @ObservedObject private var account = RankedAccountStore.shared
    let onOpenRanked: (RankedVariation) -> Void
    @State private var showsAccount = false
    @AppStorage("tm.ranked.family") private var family: RankedFamily = .pushUps

    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            HStack {
                RankedMetric(value: "\(account.placedCount)/\(RankedFamily.allCases.reduce(0) { $0 + $1.variations.count })", unit: "")
                    .accessibilityLabel("Earned exact-movement ranks")
                Spacer()
                RankedInfoButton(label: "Earned movement ratings", message: "Every exact movement has a separate server-earned Elo. Your previous local display choices remain preserved in your profile archive; they never become competitive Elo.")
                RankedIconAction(symbol: "person.badge.key", label: "Ranked account", id: "profile-ranked-account") { showsAccount = true }
            }
            if account.loading { TmaxLoadingIndicator().accessibilityLabel("Loading earned ratings") }
            if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
            RankedFamilyPicker(family: $family)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: ProfileStyle.touchTarget * 3))], spacing: ProfileStyle.spacing) {
                ForEach(family.variations) { variation in
                    RankedRatingTile(variation: variation, rating: account.rating(for: variation)) { onOpenRanked(variation) }
                        .accessibilityHint("Open this exact movement in Ranked")
                        .accessibilityIdentifier("profile-compete-\(variation.rawValue)")
                }
            }
        }
        .sheet(isPresented: $showsAccount) { RankedAccountView() }
        .task { await account.restore(); if account.identity != nil { await account.refresh() } }
    }
}
