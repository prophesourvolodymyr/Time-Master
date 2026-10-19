import SwiftUI

struct RankedMatchHistoryView: View {
    @ObservedObject var session: RankedPreviewSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Preview rounds · Not competitive history", systemImage: "eye")
                            .font(TimeMasterFont.rowTitle()).foregroundStyle(Theme.toolbarOrange)
                            .accessibilityAddTraits(.isHeader)
                        Text("Only UI demonstrations from this in-memory session appear here. They do not change ratings, save workouts or become verified matches. They disappear when the preview session ends.")
                            .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if session.matches.isEmpty {
                        ProfileEmptyState(symbol: "clock.arrow.circlepath", title: "No preview rounds yet", detail: "Close this screen and run a round from the Ranked UI preview. Its example result will appear here for this session only.")
                    } else {
                        LazyVStack(spacing: ProfileStyle.spacing) {
                            ForEach(session.matches) { match in
                                NavigationLink(value: match.id) {
                                    historyRow(match)
                                }
                                .buttonStyle(TimeMasterCardButtonStyle())
                                .accessibilityIdentifier("ranked-history-\(match.id)")
                            }
                        }
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("ranked-history-list")
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("Preview history")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .navigationDestination(for: UUID.self) { id in
                if let match = session.matches.first(where: { $0.id == id }) {
                    RankedMatchDetailView(match: match)
                }
            }
        }
        .tint(Theme.toolbarOrange)
    }

    private func historyRow(_ match: RankedPreviewMatch) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: match.outcome.symbol)
                .font(.title2).foregroundStyle(Theme.toolbarOrange)
                .frame(width: ProfileStyle.touchTarget, height: ProfileStyle.touchTarget)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(match.variation.fullTitle).font(TimeMasterFont.rowTitle())
                Text("\(match.outcome.title) · Preview round")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                Text("You \(match.yourScore) – Alex \(match.opponentScore) \(match.variation.isTimedHold ? "seconds" : "reps")")
                    .font(TimeMasterFont.body().monospacedDigit())
                Text(match.date.formatted(date: .abbreviated, time: .shortened))
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(ProfileStyle.secondary)
                .padding(.top, ProfileStyle.spacing).accessibilityHidden(true)
        }
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(flat: true))
        .contentShape(RoundedRectangle(cornerRadius: ProfileStyle.corner))
        .accessibilityElement(children: .combine)
    }
}

struct RankedMatchDetailView: View {
    let match: RankedPreviewMatch
    @State private var showsLeaderboard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                Label("Example result · Not a verified match", systemImage: "eye")
                    .font(TimeMasterFont.rowTitle()).foregroundStyle(Theme.toolbarOrange)
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Label(match.outcome.title, systemImage: match.outcome.symbol)
                        .font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
                    Text(match.variation.fullTitle).font(TimeMasterFont.heading())
                    Text(match.date.formatted(date: .abbreviated, time: .shortened))
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    RankedMovementArt(variation: match.variation)
                        .frame(height: 160).frame(maxWidth: .infinity)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: ProfileStyle.inset) {
                            score(name: "You", value: match.yourScore)
                            score(name: "Alex · Example opponent", value: match.opponentScore)
                        }
                        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                            score(name: "You", value: match.yourScore)
                            score(name: "Alex · Example opponent", value: match.opponentScore)
                        }
                    }
                }
                .padding(ProfileStyle.inset)
                .modifier(TimeMasterCardSurface(flat: true))
                VStack(alignment: .leading, spacing: 8) {
                    Label("No real rating change", systemImage: "equal.circle")
                        .font(TimeMasterFont.rowTitle())
                    Text(resultExplanation)
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                    Text("All scores and outcomes are UI examples. Your editable local profile levels, workout history and activity totals are unchanged.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                }
                .padding(ProfileStyle.inset)
                .modifier(TimeMasterCardSurface(flat: true))
                Button { showsLeaderboard = true } label: {
                    Label("View this movement’s leaderboard", systemImage: "list.number")
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-history-leaderboard")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(ProfileStyle.inset)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Preview round")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showsLeaderboard) {
            RankedLeaderboardView(initialVariation: match.variation)
        }
    }

    private func score(name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(TimeMasterFont.rowTitle()).fixedSize(horizontal: false, vertical: true)
            Text(value.formatted()).font(TimeMasterFont.display().monospacedDigit())
            Text(match.variation.isTimedHold ? "seconds · Longest hold" : "complete reps")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var resultExplanation: String {
        switch match.outcome {
        case .pending:
            "Verification is not connected. Pending is an illustrative result state, not a request awaiting server confirmation."
        case .win, .loss, .draw:
            "This outcome demonstrates the result layout only. No competitive Elo was earned or lost."
        case .forfeit:
            "This demonstrates leaving a round early. It does not apply a real forfeit penalty or affect your profile."
        case .unverified:
            "This demonstrates an unverified result. Live movement verification is unavailable, so no verified result or rating adjustment can be issued."
        }
    }
}
