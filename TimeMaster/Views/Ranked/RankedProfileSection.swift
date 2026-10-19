import SwiftUI

struct RankedProfileSection: View {
    @ObservedObject private var account = RankedAccountStore.shared
    let onOpenRanked: (RankedVariation) -> Void
    @State private var showsAccount = false
    @ScaledMetric(relativeTo: .body) private var artSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            Text("\(account.placedCount) earned movement ranks").font(TimeMasterFont.title())
            Text("Server-owned, exercise-specific ratings. Your previous local display choices are preserved in your profile archive, not used as competitive Elo.")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Button { showsAccount = true } label: {
                Label(account.identity == nil ? "Sign in to Ranked" : "Ranked account", systemImage: "person.crop.circle")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }.buttonStyle(EverPrimaryButtonStyle())
            if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
            ForEach(RankedFamily.allCases) { family in
                ProfileSettingsSection(title: family.title) {
                    ForEach(family.variations) { variation in
                        Button { onOpenRanked(variation) } label: {
                            HStack(spacing: ProfileStyle.spacing) {
                                RankedMovementArt(variation: variation).frame(width: artSize, height: artSize)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variation.title).font(TimeMasterFont.rowTitle())
                                    Text(account.rating(for: variation)?.label ?? "Unplaced")
                                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                }
                                Spacer()
                                RankedBadgeView(elo: account.rating(for: variation)?.rating)
                                Image(systemName: "arrow.up.right").font(.body.weight(.bold)).foregroundStyle(Theme.toolbarOrange)
                            }.padding(ProfileStyle.spacing).contentShape(Rectangle())
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityLabel("Open \(variation.fullTitle) in Ranked")
                        .accessibilityIdentifier("profile-compete-\(variation.rawValue)")
                    }
                }
            }
        }
        .sheet(isPresented: $showsAccount) { RankedAccountView() }
        .task { await account.restore(); if account.identity != nil { await account.refresh() } }
    }
}
