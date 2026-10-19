import SwiftUI

private enum RankedMatchStage: String {
    case camera, searching, ready, countdown, battle, verifying, result
    var title: String {
        switch self {
        case .camera, .searching: "MATCHMAKING"
        case .ready: "READY ROOM"
        case .countdown: "GET READY"
        case .battle: "DUEL"
        case .verifying: "ROUND COMPLETE"
        case .result: "RESULT"
        }
    }
}

private enum RankedFlowSheet: String, Identifiable {
    case rules, leaderboard, details, limit, opponent
    var id: String { rawValue }
}

struct RankedMatchFlowView: View {
    let variation: RankedVariation
    let mode: RankedMode
    @ObservedObject var session: RankedPreviewSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = RankedMatchStage.camera
    @State private var sheet: RankedFlowSheet?
    @State private var issue: RankedMatchIssue?
    @State private var confirmsLeave = false
    @State private var countdown = 3
    @State private var deadline: ContinuousClock.Instant?
    @State private var roundID = UUID()
    @State private var roundDate = Date()
    @State private var frame = RankedDuelFrame(remaining: 60, yourScore: 0, opponentScore: 0, feedback: .ready)
    @State private var outcome = RankedPreviewOutcome.pending

    private var remaining: Int { session.remaining(for: variation.family) }
    private var match: RankedPreviewMatch {
        RankedPreviewMatch(id: roundID, variation: variation, outcome: outcome,
                           yourScore: frame.yourScore, opponentScore: frame.opponentScore, date: roundDate)
    }

    var body: some View {
        Group {
            if stage == .battle {
                RankedDuelPlayerView(variation: variation, mode: mode, frame: frame,
                                     onLeave: { confirmsLeave = true },
                                     onFeedback: { frame.feedback = $0 }, onFinish: finishRound)
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        content
                            .padding(ProfileStyle.inset)
                            .frame(maxWidth: ProfileStyle.readableWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .tint(Theme.toolbarOrange)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(stage == .battle)
        .sheet(item: $sheet, content: sheetContent)
        .alert(mode == .duel ? "Leave this match?" : "End practice preview?", isPresented: $confirmsLeave) {
            Button("Continue", role: .cancel) { }
            Button(mode == .duel ? "Forfeit and leave" : "End preview", role: .destructive) {
                outcome = .forfeit
                if mode == .duel { session.record(match) }
                dismiss()
            }
        } message: {
            Text(mode == .duel ? "In a real match, leaving after Go is a forfeit and the match slot stays used. This preview changes no Elo." : "No competitive rating or match slot is affected.")
        }
        .task(id: stage) { await runClock() }
    }

    private var header: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Button(stage == .result || stage == .verifying ? "Close" : "Cancel") { dismiss() }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-flow-cancel")
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text(mode == .practice ? "PRACTICE" : stage.title).font(TimeMasterFont.caption())
                Text("UI PREVIEW").font(TimeMasterFont.micro()).foregroundStyle(Theme.toolbarOrange)
            }
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Menu {
                Button("Movement rules") { sheet = .rules }
                if stage == .verifying || stage == .result {
                    SwiftUI.Section("Example result") {
                        ForEach(RankedPreviewOutcome.allCases.filter { $0 != .pending }) { value in
                            Button(value.title) { showResult(value) }
                        }
                    }
                } else {
                    SwiftUI.Section("Preview a problem state") {
                        ForEach(RankedMatchIssue.allCases) { problem in
                            Button(problem.title) {
                                if problem == .limit { sheet = .limit }
                                else { issue = problem }
                            }
                        }
                    }
                }
            } label: {
                Label("Preview states", systemImage: "ellipsis").labelStyle(.iconOnly)
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .accessibilityIdentifier("ranked-flow-states")
        }
        .padding(ProfileStyle.inset)
    }

    @ViewBuilder private var content: some View {
        if let issue {
            RankedMatchIssueView(issue: issue, onRetry: {
                self.issue = nil
                stage = issue == .noOpponent ? .searching : .camera
            }, onCancel: { dismiss() })
        } else {
            switch stage {
            case .camera:
                RankedCameraSetupView(variation: variation, mode: mode, onContinue: {
                    if mode == .duel && remaining == 0 { sheet = .limit }
                    else { stage = mode == .duel ? .searching : .countdown }
                }, onRules: { sheet = .rules })
            case .searching:
                RankedSearchView(variation: variation, remaining: remaining,
                                 onOpponent: { stage = .ready }, onCancel: { dismiss() })
            case .ready:
                RankedOpponentReadyView(variation: variation, onReady: { stage = .countdown },
                                        onRules: { sheet = .rules }, onOpponent: { sheet = .opponent })
            case .countdown:
                countdownContent
            case .battle:
                EmptyView()
            case .verifying:
                verificationContent
            case .result:
                RankedMatchResultView(variation: variation, mode: mode, frame: frame, outcome: outcome,
                                      remaining: remaining, onAnother: restart, onLobby: { dismiss() },
                                      onLeaderboard: { sheet = .leaderboard }, onDetails: { sheet = .details })
            }
        }
    }

    private var countdownContent: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            Text(variation.fullTitle).font(TimeMasterFont.heading()).multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(Theme.separator, lineWidth: ProfileStyle.spacing)
                Text(countdown == 0 ? "GO" : String(countdown))
                    .font(.custom("Inter-Black", size: 96, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.toolbarOrange).minimumScaleFactor(0.5).lineLimit(1)
                    .padding(ProfileStyle.inset)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(ProfileStyle.inset)
            .accessibilityLabel(countdown == 0 ? "Go" : "Starting in \(countdown)")
            Label("Get into position", systemImage: "figure.stand")
                .font(TimeMasterFont.heading())
            Text(mode == .duel ? "Cancel before Go without using a preview slot." : "Practice preview · No match allowance used")
                .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var verificationContent: some View {
        VStack(spacing: ProfileStyle.inset * 2) {
            Image(systemName: "checkmark.shield").font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
            Text("Round complete").font(TimeMasterFont.display()).accessibilityAddTraits(.isHeader)
            HStack(spacing: ProfileStyle.inset) {
                Text(frame.yourScore.formatted())
                if mode == .duel {
                    Text("—").foregroundStyle(ProfileStyle.secondary)
                    Text(frame.opponentScore.formatted())
                }
            }
            .font(.custom("Inter-Black", size: 48, relativeTo: .largeTitle).monospacedDigit())
            Text("PROVISIONAL EXAMPLE SCORES").font(TimeMasterFont.micro())
                .foregroundStyle(Theme.toolbarOrange)
            VStack(spacing: ProfileStyle.spacing) {
                Label("Result verification", systemImage: "clock")
                    .font(TimeMasterFont.heading())
                Text("Verification is not connected. Preview a result without changing your profile levels.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            .padding(ProfileStyle.inset)
            .frame(maxWidth: .infinity)
            .modifier(TimeMasterCardSurface(flat: true))
            Button {
                showResult(frame.yourScore == frame.opponentScore ? .draw : frame.yourScore > frame.opponentScore ? .win : .loss)
            } label: {
                Text("Preview result").frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(TimeMasterToolbarWideButtonStyle())
            .accessibilityIdentifier("ranked-verify-result")
            Button("Return to lobby") { dismiss() }
                .buttonStyle(TimeMasterToolbarWideButtonStyle())
                .accessibilityIdentifier("ranked-verify-lobby")
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder private func sheetContent(_ destination: RankedFlowSheet) -> some View {
        switch destination {
        case .rules: RankedRulesView(variation: variation)
        case .leaderboard: RankedLeaderboardView(initialVariation: variation)
        case .details:
            NavigationStack {
                RankedMatchDetailView(match: match)
                    .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { sheet = nil } } }
            }
        case .limit:
            RankedMatchLimitView(family: variation.family, nextSlot: session.nextSlot(for: variation.family), isExample: remaining > 0)
        case .opponent:
            NavigationStack {
                VStack(spacing: ProfileStyle.inset * 2) {
                    RankedBadgeView(elo: 1_040, size: 112)
                    Text("Alex").font(TimeMasterFont.display())
                    Text("EXAMPLE OPPONENT").font(TimeMasterFont.caption()).foregroundStyle(Theme.toolbarOrange)
                    Text(variation.fullTitle).font(TimeMasterFont.heading())
                    Text("Silver · 1,040 example Elo").font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    Text("A public-identity layout preview, not a real player.")
                        .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                }
                .multilineTextAlignment(.center).padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea()).foregroundStyle(.white)
                .navigationTitle("Opponent")
                .toolbar { AppToolbar.item(placement: .confirmationAction) { Button("Close") { sheet = nil } } }
            }
        }
    }

    private func restart() {
        guard mode == .practice || remaining > 0 else { sheet = .limit; return }
        roundID = UUID()
        outcome = .pending
        frame = RankedDuelFrame(remaining: 60, yourScore: 0, opponentScore: 0, feedback: .ready)
        issue = nil
        deadline = nil
        countdown = 3
        stage = .camera
    }

    private func finishRound() {
        guard stage == .battle else { return }
        deadline = nil
        outcome = .pending
        if mode == .duel { session.record(match) }
        stage = .verifying
    }

    private func showResult(_ value: RankedPreviewOutcome) {
        if value != .unverified && value != .forfeit {
            if value == .win && frame.yourScore <= frame.opponentScore { frame.yourScore = frame.opponentScore + 2 }
            if value == .loss && frame.opponentScore <= frame.yourScore { frame.opponentScore = frame.yourScore + 2 }
            if value == .draw { frame.opponentScore = frame.yourScore }
        }
        outcome = value
        if mode == .duel { session.record(match) }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { stage = .result }
    }

    private func runClock() async {
        if stage == .countdown {
            countdown = 3
            for value in [3, 2, 1, 0] {
                guard !Task.isCancelled, stage == .countdown, issue == nil else { return }
                countdown = value
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            guard !Task.isCancelled, stage == .countdown, issue == nil else { return }
            guard mode == .practice || session.startRound(for: variation.family) else {
                stage = .camera
                sheet = .limit
                return
            }
            roundDate = Date()
            deadline = ContinuousClock.now.advanced(by: .seconds(60))
            stage = .battle
        } else if stage == .battle {
            while !Task.isCancelled, stage == .battle, let deadline {
                let duration = ContinuousClock.now.duration(to: deadline)
                let parts = duration.components
                let seconds = max(0, Int(parts.seconds) + (parts.attoseconds > 0 ? 1 : 0))
                frame.remaining = min(60, seconds)
                let elapsed = 60 - frame.remaining
                frame.yourScore = variation.isTimedHold ? elapsed : elapsed / 3
                frame.opponentScore = mode == .practice ? 0 : variation.isTimedHold ? max(0, elapsed - 2) : elapsed / 4
                if seconds == 0 { finishRound(); return }
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
        }
    }
}
