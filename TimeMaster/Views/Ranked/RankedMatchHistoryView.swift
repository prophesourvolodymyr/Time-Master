import SwiftUI

struct RankedMatchHistoryView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var matches: [RankedMatch] = []
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    @State private var showsAccount = false
    @State private var version = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    if account.identity == nil {
                        ProfileEmptyState(symbol: "person.crop.circle", title: "Sign in for your matches", detail: "Competitive history is stored with your account, separately from workout history.")
                        Button("Ranked account") { showsAccount = true }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                    } else if matches.isEmpty && !loading && error == nil {
                        ProfileEmptyState(symbol: "clock.arrow.circlepath", title: "No competitive rounds yet", detail: "Your real matches, pending results and forfeits will appear here. Practice does not create competitive history.")
                    }
                    ForEach(matches.filter { $0.you?.publicID == account.identity?.publicID && account.identity != nil }) { match in
                        NavigationLink {
                            RankedMatchDetailView(match: match)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(match.variation.fullTitle).font(TimeMasterFont.rowTitle())
                                Text(match.outcomeTitle).font(TimeMasterFont.secondary()).foregroundStyle(Theme.toolbarOrange)
                                Text("You \(score(match.you?.score ?? 0, match.variation)) – \(match.opponent?.displayName ?? "Opponent") \(score(match.opponent?.score ?? 0, match.variation))")
                                    .font(TimeMasterFont.secondary().monospacedDigit())
                                HStack {
                                    Text(Date(timeIntervalSince1970: match.createdAt).formatted(date: .abbreviated, time: .shortened))
                                    Spacer()
                                    if let delta = match.you?.delta { Text("\(delta >= 0 ? "+" : "")\(delta) Elo") }
                                }.font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                            }
                            .padding(ProfileStyle.inset).frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(TimeMasterCardSurface(flat: true)).contentShape(Rectangle())
                        }.buttonStyle(TimeMasterCardButtonStyle()).accessibilityElement(children: .combine)
                    }
                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let error { RankedServiceNotice(message: (matches.isEmpty ? "" : "Last fetched history · ") + error, retry: { Task { await load() } }) }
                    if cursor != nil { Button("Load older rounds") { Task { await load(more: true) } }.buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading) }
                    if account.identity != nil { Button("Refresh history") { Task { await load() } }.buttonStyle(TimeMasterToolbarWideButtonStyle()).disabled(loading) }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden).background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .navigationTitle("Recent rounds")
            .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .task(id: account.identity?.publicID) {
                version += 1
                matches = []; cursor = nil; loading = false; error = nil
                await account.restore()
                guard account.identity != nil else { return }
                await load()
                while !Task.isCancelled && matches.contains(where: { !$0.terminal }) {
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                    await load()
                }
            }
        }.tint(Theme.toolbarOrange)
    }

    private func load(more: Bool = false) async {
        guard !loading else { return }
        let requestVersion = version
        loading = true
        defer { if requestVersion == version { loading = false } }
        do {
            let page = try await account.history(cursor: more ? cursor : nil)
            guard requestVersion == version, !Task.isCancelled else { return }
            if more {
                let ids = Set(matches.map(\.id))
                matches += page.matches.filter { !ids.contains($0.id) }
                cursor = page.nextCursor
            } else {
                let updated = Dictionary(uniqueKeysWithValues: page.matches.map { ($0.id, $0) })
                let older = matches.filter { updated[$0.id] == nil }
                matches = page.matches + older
                if older.isEmpty { cursor = page.nextCursor }
            }
            error = nil
        } catch { if requestVersion == version { self.error = error.localizedDescription } }
    }

    private func score(_ value: Double, _ variation: RankedVariation) -> String {
        variation.isTimedHold ? value.formatted(.number.precision(.fractionLength(1))) + "s" : Int(value).formatted()
    }
}

struct RankedMatchDetailView: View {
    @State private var match: RankedMatch
    @ObservedObject private var account = RankedAccountStore.shared
    @State private var error: String?
    @State private var showsLeaderboard = false
    init(match: RankedMatch) { _match = State(initialValue: match) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                if match.you?.publicID == account.identity?.publicID, account.identity != nil {
                Text(match.outcomeTitle).font(TimeMasterFont.title()).accessibilityAddTraits(.isHeader)
                Text(match.variation.fullTitle).font(TimeMasterFont.heading())
                Text(Date(timeIntervalSince1970: match.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                RankedMovementArt(variation: match.variation).frame(height: 140).frame(maxWidth: .infinity)
                ForEach(match.participants) { participant in
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text(participant.isYou ? "You" : participant.displayName).font(TimeMasterFont.rowTitle())
                        Text(match.variation.isTimedHold ? participant.score.formatted(.number.precision(.fractionLength(1))) + " seconds · Longest continuous hold" : "\(Int(participant.score)) complete reps")
                            .font(TimeMasterFont.heading().monospacedDigit())
                        Text(verification(participant.verification)).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        if let before = participant.beforeRating, let after = participant.afterRating {
                            Label("\(before) → \(after) Elo", systemImage: "shield.lefthalf.filled").font(TimeMasterFont.secondary())
                        }
                    }
                    .padding(ProfileStyle.inset).frame(maxWidth: .infinity, alignment: .leading).modifier(TimeMasterCardSurface(flat: true))
                }
                Text(match.reason ?? "The service is still collecting and checking this round's evidence.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                Text("Rules \(match.ruleVersion) · Match \(match.id)").font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary).textSelection(.enabled)
                if let error { RankedServiceNotice(message: "Last fetched match · " + error, retry: { Task { await refresh() } }) }
                Button("This movement's leaderboard") { showsLeaderboard = true }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                Button("Refresh result") { Task { await refresh() } }.buttonStyle(TimeMasterToolbarWideButtonStyle())
                } else {
                    ProfileEmptyState(symbol: "lock", title: "Sign in to the original account", detail: "This match belongs to a different Ranked session.")
                }
            }
            .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white).navigationTitle("Match details")
        .sheet(isPresented: $showsLeaderboard) { RankedLeaderboardView(initialVariation: match.variation) }
        .task(id: account.identity?.publicID) {
            guard match.you?.publicID == account.identity?.publicID, account.identity != nil else { return }
            await refresh()
            while !Task.isCancelled && !match.terminal {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                await refresh()
            }
        }
    }

    private func refresh() async {
        do {
            let response: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)")
            if !Task.isCancelled, response.match.you?.publicID == account.identity?.publicID { match = response.match; error = nil }
        } catch { self.error = error.localizedDescription }
    }
    private func verification(_ value: String) -> String {
        switch value {
        case "motionValidated": return "Movement evidence validated · Not proof against hidden assistance"
        case "insufficientEvidence": return "Insufficient evidence · Not an accusation of cheating"
        default: return match.state == "forfeited" ? "Round ended by forfeit" : match.state == "cancelled" ? "No competitive start" : "Verification pending"
        }
    }
}
