import SwiftUI

struct RankedMatchHistoryView: View {
    @ObservedObject private var account = RankedAccountStore.shared
    @ObservedObject private var practice = RankedPracticeStore.shared
    @State private var mode: RankedMode
    @State private var matches: [RankedMatch] = []
    @State private var cursor: String?
    @State private var loading = false
    @State private var error: String?
    @State private var showsAccount = false
    @State private var version = 0

    init(mode: RankedMode = .duel) { _mode = State(initialValue: mode) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    Text("Recent rounds").font(TimeMasterFont.heading())
                    historyModePicker
                    if mode == .practice { practiceHistory }
                    if mode == .duel && account.identity == nil {
                        RankedInfoButton(label: "Sign in for your matches", message: "Competitive history is stored with your account, separately from workout history.", symbol: "person.crop.circle")
                        RankedIconAction(symbol: "person.badge.key", label: "Ranked account", id: "ranked-history-account") { showsAccount = true }
                    } else if mode == .duel && matches.isEmpty && !loading && error == nil {
                        RankedInfoButton(label: "No competitive rounds yet", message: "Your real matches, pending results and forfeits will appear here. Practice does not create competitive history.", symbol: "clock.arrow.circlepath")
                    }
                    ForEach(mode == .duel ? matches.filter { $0.you?.publicID == account.identity?.publicID && account.identity != nil } : []) { match in
                        NavigationLink {
                            RankedMatchDetailView(match: match)
                        } label: {
                            HStack(spacing: ProfileStyle.spacing) {
                                RankedMovementArt(variation: match.variation)
                                    .frame(width: ProfileStyle.touchTarget * 1.5, height: ProfileStyle.touchTarget * 1.5)
                                VStack(alignment: .leading, spacing: EverSpacing.x1) {
                                    Text(match.opponent?.displayName ?? "—").font(TimeMasterFont.rowTitle()).lineLimit(1)
                                    Text(match.variation.fullTitle)
                                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                                    Text("\(score(match.you?.score ?? 0, match.variation)) : \(score(match.opponent?.score ?? 0, match.variation))")
                                        .font(TimeMasterFont.title().monospacedDigit())
                                    Text(Date(timeIntervalSince1970: match.createdAt).formatted(date: .numeric, time: .shortened))
                                        .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                                    if let delta = match.you?.delta {
                                        Text("\(delta >= 0 ? "+" : "")\(delta) Elo")
                                            .font(TimeMasterFont.caption().monospacedDigit()).foregroundStyle(Theme.toolbarOrange)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                RankedOutcomeIcon(match: match).font(.title2)
                            }
                            .padding(ProfileStyle.inset).frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(TimeMasterCardSurface(flat: true)).contentShape(Rectangle())
                        }
                        .buttonStyle(TimeMasterCardButtonStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(match.variation.fullTitle), \(match.outcomeTitle)")
                        .accessibilityIdentifier("ranked-history-\(match.id)")
                    }
                    if loading { TmaxLoadingIndicator().frame(maxWidth: .infinity) }
                    if mode == .duel, let error { RankedServiceNotice(message: (matches.isEmpty ? "" : "Last fetched history · ") + error, retry: { Task { await load() } }) }
                    if mode == .duel && cursor != nil {
                        RankedIconAction(symbol: "chevron.down", label: "Load older rounds", id: "ranked-history-more") { Task { await load(more: true) } }.disabled(loading)
                    }
                    if mode == .duel && account.identity != nil {
                        RankedIconAction(symbol: "arrow.clockwise", label: "Refresh history", id: "ranked-history-refresh") { Task { await load() } }.disabled(loading)
                    }
                }
                .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden).background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
            .toolbar { AppToolbar.iconItem(placement: .confirmationAction) { RankedCloseButton() } }
            .sheet(isPresented: $showsAccount) { RankedAccountView() }
            .task(id: (account.identity?.publicID ?? "guest") + mode.rawValue) {
                version += 1
                matches = []; cursor = nil; loading = false; error = nil
                practice.reload()
                await account.restore()
                guard mode == .duel, account.identity != nil else { return }
                await load()
                while !Task.isCancelled && matches.contains(where: { !$0.terminal }) {
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                    await load()
                }
            }
        }.tint(Theme.toolbarOrange)
    }

    private var historyModePicker: some View {
        HStack(spacing: ProfileStyle.spacing) {
            ForEach(RankedMode.allCases) { option in
                Button { mode = option } label: {
                    Label(option.title, systemImage: option.symbol)
                        .font(TimeMasterFont.rowTitle())
                        .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                }
                .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: mode == option))
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
                .accessibilityIdentifier("ranked-history-mode-\(option.rawValue)")
            }
        }
    }

    private var practiceHistory: some View {
        let results = practice.results(for: account.identity?.publicID)
        return Group {
            if results.isEmpty && practice.error == nil {
                RankedInfoButton(label: "No solo rounds yet", message: "Started camera-tracked Practice rounds are saved on this device. Competitive Elo stays separate.", symbol: "figure.strengthtraining.traditional")
            }
            ForEach(results) { result in
                NavigationLink {
                    RankedPracticeDetailView(result: result)
                } label: {
                    HStack(spacing: ProfileStyle.spacing) {
                        RankedMovementArt(variation: result.variation)
                            .frame(width: ProfileStyle.touchTarget * 1.5, height: ProfileStyle.touchTarget * 1.5)
                        VStack(alignment: .leading, spacing: EverSpacing.x1) {
                            Text(result.variation.fullTitle).font(TimeMasterFont.rowTitle())
                            RankedMetric(value: result.variation.isTimedHold ? result.score.formatted(.number.precision(.fractionLength(1))) : Int(result.score).formatted(),
                                         unit: result.variation.isTimedHold ? "s" : "reps")
                            Text(result.startedAt.formatted(date: .numeric, time: .shortened))
                                .font(TimeMasterFont.micro()).foregroundStyle(ProfileStyle.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(spacing: EverSpacing.x1) {
                            Image(systemName: result.status == .completed ? "checkmark.circle" : "pause.circle")
                                .foregroundStyle(Theme.toolbarOrange)
                            Text(result.status.title)
                                .font(TimeMasterFont.micro())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                    }
                    .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(result.variation.fullTitle), \(result.status.title)")
                .accessibilityIdentifier("ranked-practice-history-\(result.id.uuidString)")
            }
            if let error = practice.error { RankedServiceNotice(message: error, retry: practice.reload) }
        }
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
                HStack {
                    RankedOutcomeIcon(match: match).font(.largeTitle)
                    Spacer()
                    Text(Date(timeIntervalSince1970: match.createdAt).formatted(date: .numeric, time: .shortened))
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                RankedMovementArt(variation: match.variation)
                    .frame(height: ProfileStyle.touchTarget * 3).frame(maxWidth: .infinity)
                Text(match.variation.fullTitle).font(TimeMasterFont.heading())
                ForEach(match.participants) { participant in
                    HStack(spacing: ProfileStyle.spacing) {
                        VStack(alignment: .leading, spacing: EverSpacing.x2) {
                            Text(participant.displayName).font(TimeMasterFont.rowTitle()).lineLimit(1)
                            RankedMetric(value: match.variation.isTimedHold ? participant.score.formatted(.number.precision(.fractionLength(1))) : Int(participant.score).formatted(), unit: match.variation.isTimedHold ? "s" : "reps")
                            if let delta = participant.delta {
                                Text("\(delta >= 0 ? "+" : "")\(delta) Elo")
                                    .font(TimeMasterFont.caption().monospacedDigit()).foregroundStyle(Theme.toolbarOrange)
                            }
                            RankedInfoButton(label: participant.verification == "motionValidated" ? "Movement evidence validated" : "Verification status", message: verification(participant.verification), symbol: participant.verification == "motionValidated" ? "checkmark.shield" : "shield.slash")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RankedEloBadge(variation: match.variation, elo: participant.afterRating ?? participant.beforeRating)
                            .frame(width: ProfileStyle.touchTarget * 2, height: ProfileStyle.touchTarget * 2)
                    }
                    .padding(ProfileStyle.inset).modifier(TimeMasterCardSurface(flat: true))
                }
                RankedInfoButton(label: match.outcomeTitle, message: (match.reason ?? "The service is still collecting and checking this round's evidence.") + "\nRules \(match.ruleVersion)\nMatch \(match.id)")
                if let error { RankedServiceNotice(message: "Last fetched match · " + error, retry: { Task { await refresh() } }) }
                HStack {
                    RankedIconAction(symbol: "list.number", label: "This movement's leaderboard", id: "ranked-details-leaderboard") { showsLeaderboard = true }
                    Spacer()
                    RankedIconAction(symbol: "arrow.clockwise", label: "Refresh result", id: "ranked-details-refresh") { Task { await refresh() } }
                }
                } else {
                    RankedInfoButton(label: "Sign in to the original account", message: "This match belongs to a different Ranked session.", symbol: "lock")
                }
            }
            .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
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

struct RankedPracticeDetailView: View {
    let result: RankedPracticeResult

    var body: some View {
        ScrollView {
            VStack(spacing: ProfileStyle.inset) {
                RankedMovementArt(variation: result.variation).frame(height: ProfileStyle.touchTarget * 3)
                Text(result.variation.fullTitle).font(TimeMasterFont.heading())
                RankedMetric(value: result.variation.isTimedHold ? result.score.formatted(.number.precision(.fractionLength(1))) : Int(result.score).formatted(),
                             unit: result.variation.isTimedHold ? "s" : "reps")
                RankedMetric(value: result.duration.formatted(.number.precision(.fractionLength(1))), unit: "s")
                    .accessibilityLabel("Round duration")
                Text(result.startedAt.formatted(date: .numeric, time: .shortened))
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                RankedInfoButton(label: result.status.title,
                                 message: "Camera-tracked solo Practice, saved on this device. Only complete validated movements count. Tracking is an estimate, not proof against assistance. No competitive Elo, allowance or workout history was changed. Rules \(result.ruleVersion).",
                                 symbol: result.status == .completed ? "checkmark.circle" : "pause.circle")
            }
            .padding(ProfileStyle.inset).frame(maxWidth: ProfileStyle.readableWidth).frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
        .accessibilityIdentifier("ranked-practice-details")
    }
}
