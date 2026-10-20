import SwiftUI

struct RankedMatchResultView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let match: RankedMatch?
    let frame: RankedDuelFrame
    var practiceResult: RankedPracticeResult? = nil
    var practiceSaved = false
    let onAnother: () -> Void
    let onLobby: () -> Void
    let onLeaderboard: () -> Void
    let onDetails: () -> Void

    var body: some View {
        VStack(spacing: ProfileStyle.inset) {
            RankedOutcomeIcon(match: match, practice: mode == .practice)
                .font(.largeTitle)
            if let you = match?.you, let after = you.afterRating {
                RankedEloBadge(variation: variation, elo: after)
                    .frame(width: ProfileStyle.touchTarget * 4, height: ProfileStyle.touchTarget * 4)
                if let delta = you.delta {
                    RankedMetric(value: "\(delta >= 0 ? "+" : "")\(delta)", unit: "Elo", emphasized: delta > 0)
                }
                if let tier = RankedTier.level(for: after), let next = RankedTier.allCases.first(where: { $0.minimum > after }) {
                    ProgressView(value: Double(after - tier.minimum), total: Double(next.minimum - tier.minimum))
                        .tint(Theme.toolbarOrange)
                        .accessibilityLabel("Progress toward \(next.title)")
                        .accessibilityValue("\(after) of \(next.minimum) Elo")
                    RankedMetric(value: next.minimum.formatted(), unit: "Elo")
                }
            } else {
                RankedMovementArt(variation: variation).frame(height: ProfileStyle.touchTarget * 3)
            }
            HStack(spacing: ProfileStyle.inset) {
                score(mode == .duel ? match?.you?.score ?? frame.yourScore : frame.yourScore, name: match?.you?.displayName ?? "You")
                if mode == .duel {
                    Image(systemName: "bolt.horizontal").foregroundStyle(ProfileStyle.secondary)
                    score(match?.opponent?.score ?? frame.opponentScore, name: match?.opponent?.displayName ?? "Opponent")
                }
            }
            .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
            HStack(spacing: ProfileStyle.spacing) {
                RankedInfoButton(label: mode == .practice ? practiceSaved ? "Practice saved" : "Practice result not saved" : match?.outcomeTitle ?? "Verification pending",
                                 message: mode == .practice ? "\(practiceResult?.status.title ?? "Practice") · \(Int(practiceResult?.duration ?? 0)) seconds. \(practiceSaved ? "Saved on this device in Recent rounds." : "Retry saving before leaving.") Competitive Elo, match allowance and workout history are unchanged." : match?.reason ?? "Waiting for the service to verify this round.",
                                 symbol: mode == .practice ? practiceSaved ? "checkmark.circle" : "exclamationmark.triangle" : "info")
                Spacer(minLength: 0)
                if mode == .duel {
                    RankedIconAction(symbol: "list.number", label: "Leaderboard", id: "ranked-result-leaderboard", action: onLeaderboard)
                }
                if mode == .duel || practiceResult != nil {
                    RankedIconAction(symbol: "doc.text.magnifyingglass", label: "Match details", id: "ranked-result-details", action: onDetails)
                }
                RankedIconAction(symbol: "house", label: "Return to lobby", id: "ranked-result-lobby", action: onLobby)
            }
            Button(action: onAnother) {
                Image(systemName: "arrow.clockwise").font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityLabel(mode == .practice ? "Practice again" : "Find another match")
            .accessibilityIdentifier("ranked-result-again")
        }
        .frame(maxWidth: .infinity)
    }

    private func score(_ value: Double, name: String) -> some View {
        VStack(spacing: EverSpacing.x1) {
            Text(name).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary).lineLimit(1)
            RankedMetric(value: variation.isTimedHold ? value.formatted(.number.precision(.fractionLength(1))) : Int(value).formatted(), unit: variation.isTimedHold ? "s" : "reps")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct RankedMatchLimitView: View {
    let family: RankedFamily
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset) {
                    RankedMovementArt(variation: family.variations[0]).frame(height: ProfileStyle.touchTarget * 3)
                    if family == .core {
                        RankedMetric(value: "∞", unit: "")
                            .accessibilityLabel("Core has no competitive family limit")
                    } else if let allowance = account.allowance(for: family), let remaining = allowance.remaining {
                        RankedMetric(value: "\(remaining)/10", unit: "", emphasized: true)
                            .accessibilityLabel("\(remaining) of 10 matches remaining")
                        HStack(spacing: EverSpacing.x1) {
                            ForEach(0..<10) { index in
                                Capsule().fill(index < remaining ? Theme.toolbarOrange : Theme.surface2)
                                    .frame(maxWidth: .infinity).frame(height: EverSpacing.x3)
                            }
                        }.accessibilityHidden(true)
                        RankedMetric(value: "4", unit: "h")
                        if let next = allowance.nextSlot {
                            Label(Date(timeIntervalSince1970: next).formatted(date: .numeric, time: .shortened), systemImage: "clock.arrow.circlepath")
                                .font(TimeMasterFont.secondary().monospacedDigit())
                                .accessibilityLabel("Next slot: \(Date(timeIntervalSince1970: next).formatted(date: .abbreviated, time: .shortened))")
                        }
                    } else if account.loading {
                        ProgressView().accessibilityLabel("Loading allowance")
                    } else {
                        RankedMetric(value: "—/10", unit: "")
                        RankedIconAction(symbol: "person.badge.key", label: "Sign in to load allowance", id: "ranked-allowance-account") { showsAccount = true }
                    }
                    if account.stale {
                        RankedInfoButton(label: "Last fetched allowance", message: "Connection interrupted. These values may be out of date; refresh to get your current server allowance.", symbol: "wifi.exclamationmark")
                    }
                    if let error = account.error { RankedServiceNotice(message: error, retry: { Task { await account.refresh() } }) }
                    HStack {
                        RankedInfoButton(label: "Rolling allowance", message: family == .core ? "The push-up and squat rolling limits do not apply to Core. Practice never uses competitive slots." : "All \(family.title.lowercased()) variations share ten started matches in a rolling four-hour window. Only Go consumes a slot. Cancelling before Go does not. Forfeits remain charged.", symbol: "hourglass")
                        Spacer()
                        RankedIconAction(symbol: "arrow.clockwise", label: "Refresh allowance", id: "ranked-allowance-refresh") { Task { await account.refresh() } }
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .task { await account.restore(); if account.identity != nil { await account.refresh() } }
        }
        .tint(Theme.toolbarOrange)
    }
}
