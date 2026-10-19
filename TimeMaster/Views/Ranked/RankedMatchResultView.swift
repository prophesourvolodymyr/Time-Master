import SwiftUI

struct RankedMatchResultView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let match: RankedMatch?
    let frame: RankedDuelFrame
    let onAnother: () -> Void
    let onLobby: () -> Void
    let onLeaderboard: () -> Void
    let onDetails: () -> Void

    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            Image(systemName: mode == .practice ? "checkmark.circle" : match?.state == "completed" ? "trophy" : "shield.slash")
                .font(.system(size: 56, weight: .light)).foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
            Text(mode == .practice ? "Practice complete" : match?.outcomeTitle ?? "Verification pending")
                .font(TimeMasterFont.display()).accessibilityAddTraits(.isHeader)
            Text(variation.fullTitle).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            VStack(spacing: ProfileStyle.inset) {
                if let you = match?.you, let after = you.afterRating, let before = you.beforeRating {
                    RankedBadgeView(elo: after, size: 88)
                    HStack(spacing: ProfileStyle.spacing) {
                        Text(before.formatted()).foregroundStyle(ProfileStyle.secondary)
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                        Text(after.formatted())
                    }.font(TimeMasterFont.title().monospacedDigit())
                    if let delta = you.delta {
                        Text("\(delta >= 0 ? "+" : "")\(delta) Elo · \(RankedTier.level(for: after)?.title ?? "Unplaced")")
                            .font(TimeMasterFont.secondary()).foregroundStyle(Theme.toolbarOrange)
                    }
                    if let tier = RankedTier.level(for: after), let next = RankedTier.allCases.first(where: { $0.minimum > after }) {
                        ProgressView(value: Double(after - tier.minimum), total: Double(next.minimum - tier.minimum))
                            .tint(Theme.toolbarOrange).accessibilityLabel("Progress toward \(next.title)")
                        Text("\(next.title) at \(next.minimum.formatted()) Elo").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    }
                } else { Text("No competitive rating change").font(TimeMasterFont.rowTitle()) }
                HStack {
                    score(frame.yourScore, name: "You")
                    if mode == .duel { score(frame.opponentScore, name: match?.opponent?.displayName ?? "Opponent") }
                }
                Text(mode == .practice ? "Solo camera-tracked activity. No competitive allowance, Elo or workout history was changed." : match?.reason ?? "Waiting for the service to verify this round.")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .padding(ProfileStyle.inset).frame(maxWidth: .infinity).modifier(TimeMasterCardSurface(flat: true))
            Button(mode == .practice ? "Practice again" : "Find another match", action: onAnother)
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
            if mode == .duel {
                HStack {
                    Button("Leaderboard", action: onLeaderboard)
                    Button("Match details", action: onDetails)
                }.buttonStyle(TimeMasterToolbarWideButtonStyle())
            }
            Button("Return to lobby", action: onLobby).buttonStyle(TimeMasterToolbarWideButtonStyle())
        }.multilineTextAlignment(.center)
    }

    private func score(_ value: Double, name: String) -> some View {
        VStack(spacing: 4) {
            Text(variation.isTimedHold ? value.formatted(.number.precision(.fractionLength(1))) : Int(value).formatted())
                .font(TimeMasterFont.display().monospacedDigit())
            Text("\(name) · \(variation.isTimedHold ? "seconds" : "reps")")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

struct RankedMatchLimitView: View {
    let family: RankedFamily
    @ObservedObject private var account = RankedAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset) {
                    Image(systemName: "hourglass").font(.system(size: 56, weight: .light)).foregroundStyle(Theme.toolbarOrange)
                    Text("\(family.title) allowance").font(TimeMasterFont.title())
                    if family == .core {
                        Text("The push-up and squat rolling limits do not apply to Core. Practice never uses competitive slots.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    } else if let allowance = account.allowance(for: family), let remaining = allowance.remaining {
                        Text("\(remaining) / 10 remaining").font(TimeMasterFont.title().monospacedDigit())
                        HStack(spacing: 5) {
                            ForEach(0..<10) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(index < remaining ? Theme.toolbarOrange : Theme.surface2)
                                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.spacing)
                            }
                        }.accessibilityHidden(true)
                        if let next = allowance.nextSlot {
                            Text("Next slot: \(Date(timeIntervalSince1970: next).formatted(date: .abbreviated, time: .shortened))")
                                .font(TimeMasterFont.secondary())
                        }
                        Text("All \(family.title.lowercased()) variations share ten started matches in a rolling four-hour window. Only Go consumes a slot. Forfeits remain charged.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        if account.stale { Text("Last fetched values · Connection interrupted").font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange) }
                    } else if account.loading { ProgressView() }
                    else { Text("Sign in to load your server allowance.").font(TimeMasterFont.secondary()) }
                    if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
                    Button("Refresh") { Task { await account.refresh() } }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                    Button("Return") { dismiss() }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                }
                .multilineTextAlignment(.center).padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white).navigationTitle("Match allowance")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .task { await account.restore(); if account.identity != nil { await account.refresh() } }
        }.tint(Theme.toolbarOrange)
    }
}
