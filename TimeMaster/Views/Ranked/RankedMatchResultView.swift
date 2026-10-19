import SwiftUI

struct RankedMatchResultView: View {
    let variation: RankedVariation
    let mode: RankedMode
    let frame: RankedDuelFrame
    let outcome: RankedPreviewOutcome
    let remaining: Int
    let onAnother: () -> Void
    let onLobby: () -> Void
    let onLeaderboard: () -> Void
    let onDetails: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat = 112

    private var isRatedExample: Bool { mode == .duel && [.win, .loss, .draw].contains(outcome) }
    private var exampleRating: Int { outcome == .win ? 944 : outcome == .loss ? 905 : 920 }

    var body: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            VStack(spacing: 8) {
                Image(systemName: mode == .practice ? "checkmark.circle.fill" : outcome.symbol)
                    .font(.largeTitle).foregroundStyle(Theme.toolbarOrange)
                    .accessibilityHidden(true)
                Text(mode == .practice ? "Practice complete" : outcome.title)
                    .font(TimeMasterFont.display()).accessibilityAddTraits(.isHeader)
                Text(variation.fullTitle).font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: ProfileStyle.inset) {
                if isRatedExample {
                    RankedBadgeView(elo: exampleRating, size: badgeSize)
                    Text("EXAMPLE RATING").font(TimeMasterFont.micro())
                        .foregroundStyle(Theme.toolbarOrange)
                    HStack(spacing: ProfileStyle.spacing) {
                        Text("920").foregroundStyle(ProfileStyle.secondary)
                        Image(systemName: "arrow.right").font(.body).accessibilityHidden(true)
                        Text(exampleRating.formatted())
                    }
                    .font(TimeMasterFont.display().monospacedDigit())
                    ProgressView(value: Double(exampleRating - 800), total: 200)
                        .tint(Theme.toolbarOrange)
                        .accessibilityLabel("Illustrative progress through Bronze")
                    HStack {
                        Text("BRONZE")
                        Spacer()
                        Text("SILVER · 1,000")
                    }
                    .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                } else {
                    Image(systemName: mode == .practice ? "figure.strengthtraining.traditional" : "shield.slash")
                        .font(.system(size: badgeSize * 0.6, weight: .light))
                        .foregroundStyle(ProfileStyle.secondary).accessibilityHidden(true)
                    Text("No rating change").font(TimeMasterFont.heading())
                }
                HStack(alignment: .firstTextBaseline) {
                    score(frame.yourScore, title: "YOU")
                    if mode == .duel {
                        Text("—").font(.title2).foregroundStyle(ProfileStyle.secondary)
                        score(frame.opponentScore, title: "ALEX · EXAMPLE")
                    }
                }
                Text(outcome == .unverified ? "Example: movement could not be verified." : "Example scores · Not a verified result")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(ProfileStyle.inset * 1.5)
            .frame(maxWidth: .infinity)
            .modifier(TimeMasterCardSurface(flat: true))
            VStack(spacing: ProfileStyle.spacing) {
                if mode == .duel {
                    Label("\(remaining) / 10 \(variation.family.title.lowercased()) preview slots", systemImage: "bolt.shield")
                        .font(TimeMasterFont.secondary().monospacedDigit())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                Button(action: onAnother) {
                    Label(mode == .practice ? "Practice again" : remaining > 0 ? "Find another match" : "View match limit", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-result-another")
                if mode == .duel {
                    HStack(spacing: ProfileStyle.spacing) {
                        Button("Leaderboard", action: onLeaderboard)
                            .accessibilityIdentifier("ranked-result-leaderboard")
                        Button("Match details", action: onDetails)
                            .accessibilityIdentifier("ranked-result-details")
                    }
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                }
                Button("Return to lobby", action: onLobby)
                    .buttonStyle(TimeMasterToolbarWideButtonStyle())
                    .accessibilityIdentifier("ranked-result-lobby")
                Text("UI preview only. Your saved profile levels are unchanged.")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func score(_ value: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value.formatted() + (variation.isTimedHold ? "s" : ""))
                .font(TimeMasterFont.display().monospacedDigit())
            Text(title).font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct RankedMatchLimitView: View {
    let family: RankedFamily
    let nextSlot: Date?
    let isExample: Bool
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ProfileStyle.inset * 2) {
                    Image(systemName: "hourglass").font(.system(size: iconSize, weight: .light))
                        .foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
                    Text("Time to recover").font(TimeMasterFont.display())
                        .accessibilityAddTraits(.isHeader)
                    Text("\(family.title) match limit").font(TimeMasterFont.heading())
                    VStack(spacing: ProfileStyle.spacing) {
                        HStack(spacing: 5) {
                            ForEach(0..<10) { _ in
                                RoundedRectangle(cornerRadius: 3).fill(Theme.toolbarOrange)
                                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.spacing)
                            }
                        }
                        .accessibilityLabel("Ten of ten example match slots used")
                        Text("10 / 10").font(TimeMasterFont.display().monospacedDigit())
                        if let nextSlot {
                            Text("Next preview slot")
                                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                            Text(nextSlot, style: .relative).font(TimeMasterFont.heading().monospacedDigit())
                        } else {
                            Text("Each slot returns four hours after that match starts.")
                                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        }
                    }
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: .infinity)
                    .modifier(TimeMasterCardSurface(flat: true))
                    Text(family == .core ? "Timed holds have their own preview allowance." : "All \(family.title.lowercased()) variations share this allowance. Switching variations does not reset it.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    Text(isExample ? "LIMIT-STATE PREVIEW · Your allowance has not been used." : "UI PREVIEW · No real competitive matches were played.")
                        .font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange)
                    Button("Return", action: { dismiss() })
                        .buttonStyle(TimeMasterToolbarWideButtonStyle())
                        .accessibilityIdentifier("ranked-limit-return")
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(ProfileStyle.inset * 2)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .navigationTitle("Match allowance")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Theme.toolbarOrange)
    }
}
