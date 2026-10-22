import SwiftUI

@MainActor
struct PhysiqueResultView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let matchID: String

    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.physiqueLiveResizing) private var liveResizing
    @State private var fetchedMatch: PhysiqueMatch?
    @State private var fetchedAccountID: String?
    @State private var fetchedAt: Date?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var refreshNumber = 0
    @State private var isVisible = false
    @State private var authorizedForPresentation = false
    @State private var pendingAction: PendingAction?
    @State private var lastAction: PendingAction?
    @State private var revealMatchID: String?
    @State private var selectedBadge: PhysiqueBadge?
    @State private var showsBadge = false
    @State private var mediaExpired = false
    @State private var showsContext = false
    @AccessibilityFocusState private var outcomeFocused: Bool

    init(store: PhysiqueStore, onOpen: @escaping (PhysiqueRoute) -> Void, matchID: String) {
        self.store = store
        self.onOpen = onOpen
        self.matchID = matchID
    }

    private struct LoadKey: Hashable {
        let accountID: String?
        let matchID: String
        let refreshNumber: Int
        let active: Bool
    }

    private enum PendingAction: Hashable {
        case gallery, next, resume
    }

    private var active: Bool {
        isVisible && presentationActive && scenePhase == .active
    }

    private var loadKey: LoadKey {
        LoadKey(accountID: cloudAccount.accountID, matchID: matchID, refreshNumber: refreshNumber, active: active)
    }

    private var visibleMatch: PhysiqueMatch? {
        guard authorizedForPresentation, active, let accountID = cloudAccount.accountID,
              fetchedAccountID == accountID, fetchedMatch?.id == matchID else { return nil }
        return fetchedMatch
    }

    var body: some View {
        VStack(spacing: 0) {
            if let match = visibleMatch, confirmedResult(in: match) != nil {
                terminalBand
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
                        content
                    }
                    .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: actionError) { message in
                    if lastAction == .next, message != nil {
                        proxy.scrollTo("physique-result-availability", anchor: .top)
                    }
                }
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle("Result")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { close() } label: { Label("Close", systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction)
                    .disabled(!isVisible)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { reportMatch() } label: { Label("Report", systemImage: "flag") }
                    .disabled(cloudAccount.accountID == nil)
            }
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let match = visibleMatch, confirmedResult(in: match) != nil {
                nextActionRegion
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: .infinity)
                    .background(Theme.background)
            }
        }
        #endif
        .alert(selectedBadge?.title ?? "Badge", isPresented: $showsBadge, presenting: selectedBadge) { _ in
            Button("Close", role: .cancel) { selectedBadge = nil }
        } message: { badge in
            Text(badge.detail)
        }
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            authorizedForPresentation = false
            pendingAction = nil
            revealMatchID = nil
        }
        .onChange(of: cloudAccount.accountID) { _ in clearPrivateState() }
        .onChange(of: active) { enabled in
            if !enabled {
                authorizedForPresentation = false
                revealMatchID = nil
                pendingAction = nil
                selectedBadge = nil
                showsBadge = false
            }
        }
        .onChange(of: showsContext) { _ in revealMatchID = nil }
        .onReceive(store.$snapshot) { acceptLiveMatch($0) }
        .task(id: loadKey) { await loadMatch() }
        .task(id: pendingAction) {
            guard let pendingAction else { return }
            switch pendingAction {
            case .gallery: await openGallery()
            case .next: await checkNextAction()
            case .resume: await restorePendingMatch()
            }
        }
        .task(id: visibleMatch?.mediaExpiresAt) { await watchMediaExpiry() }
    }

    @ViewBuilder
    private var content: some View {
        if cloudAccount.accountID == nil {
            PhysiqueStatusView(title: "Private result", detail: "Sign in to authorize this exact match. No other account’s result is retained.", systemImage: "lock")
            PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { onOpen(.account) }
        } else if let match = visibleMatch {
            if let result = confirmedResult(in: match) {
                resultContent(match: match, result: result)
            } else {
                unresolvedContent(match)
            }
        } else if isLoading || loadError == nil {
            PhysiqueCard {
                ProgressView()
                    .accessibilityLabel("Restoring result")
                Text("Restoring result").font(TimeMasterFont.heading())
                Text("Retrieving the authorized record for this match.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } else {
            PhysiqueStatusView(title: "Unable to load result", detail: loadError ?? "The authorized match could not be retrieved.", retry: retry)
            Button { onOpen(.account) } label: { Label("Account and sign-in", systemImage: "person.crop.circle") }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
        }
    }

    private var terminalBand: some View {
        HStack(alignment: .center, spacing: ProfileStyle.inset) {
            PhysiqueTimerView(clock: PhysiqueClock(mode: .ended, label: "Finished", endpoint: nil, serverOffset: store.serverOffset))
            #if os(macOS)
            nextActionRegion.frame(maxWidth: 320, alignment: .leading)
            #endif
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, ProfileStyle.spacing)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    private func resultContent(match: PhysiqueMatch, result: PhysiqueResult) -> some View {
        PhysiqueResultCelebration(
            outcome: result.outcome,
            isJudged: isJudged(match, result: result),
            corrected: result.corrected || result.correction != nil,
            revealID: revealMatchID,
            animate: shouldReveal(match),
            newBadges: newlyEarnedBadges(for: match)
        )
        .accessibilityFocused($outcomeFocused)

        freshnessNotice
        if lastAction == .next, let actionError {
            PhysiqueStatusView(title: "Availability not confirmed", detail: actionError, systemImage: "exclamationmark.circle")
                .id("physique-result-availability")
        }

        if isJudged(match, result: result), let you = result.you, let opponent = result.opponent {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Text("FINAL TOTALS")
                    .font(TimeMasterFont.technical())
                    .tracking(1.4)
                    .foregroundStyle(ProfileStyle.secondary)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 0) {
                    PhysiqueScoreValue(value: you.total, label: "You", unit: "points out of 100", revealID: revealMatchID, animate: shouldReveal(match), prominent: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ProfileStyle.inset * 1.25)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.toolbarOrange).frame(width: 3)
                                .accessibilityHidden(true)
                        }
                    Divider().overlay(Theme.separator)
                    PhysiqueScoreValue(value: opponent.total, label: "Opponent", unit: "points out of 100", revealID: revealMatchID, animate: shouldReveal(match), prominent: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ProfileStyle.inset * 1.25)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color(red: 0.97, green: 0.94, blue: 0.87)).frame(width: 3)
                                .accessibilityHidden(true)
                        }
                }
                .background(Theme.surface)
                Text("Gap · \(abs(you.total - opponent.total).formatted(.number.precision(.fractionLength(1)))) points")
                    .font(TimeMasterFont.secondary().monospacedDigit())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } else {
            PhysiqueCard {
                Text(isScoredOutcome(result) ? "Accepted totals unavailable" : "No physique scores")
                    .font(TimeMasterFont.heading())
                Text(nonScoreExplanation(result))
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if result.outcome == "noContest" {
            PhysiqueCard {
                Text("No Physique Elo change for the effective match").font(TimeMasterFont.label())
                Text("This no-contest does not advance your rated match count. A separately settled review adjustment is shown when supplied.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        if let correction = result.correction {
            correctionNotice(correction)
            if let receipt = result.rating {
                DisclosureGroup {
                    PhysiqueRatingReceiptView(receipt: receipt, isFirstRating: receipt.games == 1 || receipt.before == nil, animate: false)
                    Text("This original transaction was superseded by the review. It is historical, not your current Physique Elo.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } label: {
                    Text("Original match receipt · Superseded").font(TimeMasterFont.sectionTitle())
                }
            }
        } else {
            if result.corrected {
                PhysiqueStatusView(title: "Review audit unavailable", detail: "The service marked this result corrected but did not supply the separate review adjustment. No adjustment is inferred.")
            }
            if result.outcome != "noContest" {
                PhysiqueRatingReceiptView(
                    receipt: result.rating,
                    isFirstRating: result.rating.map { $0.games == 1 || $0.before == nil } ?? false,
                    revealID: revealMatchID,
                    animate: shouldReveal(match)
                )
            }
        }

        DisclosureGroup(isExpanded: $showsContext) {
            VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                if let finalizedAt = match.finalizedAt {
                    Text(Date(timeIntervalSince1970: finalizedAt), format: .dateTime.year().month(.abbreviated).day().hour().minute())
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .accessibilityLabel("Match finalized \(Date(timeIntervalSince1970: finalizedAt).formatted(date: .abbreviated, time: .shortened))")
                }
                if let receipt = result.rating {
                    Text(result.correction == nil ? "This match’s transaction, not your current rating." : "The original match transaction was superseded by review.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Confirmed rated matches at original settlement: \(receipt.games.formatted())")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                explanationContent(match: match, result: result)
            }
            .padding(.top, ProfileStyle.spacing)
        } label: {
            Label("Receipt and judging context", systemImage: "doc.text")
                .font(TimeMasterFont.rowTitle())
                .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, 4)
        .background(Theme.surface)
        detailActions(match: match, result: result)

        VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
            Text("Identity and badges")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            Text(currentOwnIdentity(for: match) == nil ? "At match start; not a current badge or streak claim." : "Your latest confirmed identity. Opponent identity is from match start.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PhysiqueIdentityRail(identity: currentOwnIdentity(for: match) ?? match.you.identity, ownerLabel: currentOwnIdentity(for: match) == nil ? "You · At match start" : "You · Latest confirmed", newBadgeIDs: revealMatchID == match.id && currentOwnIdentity(for: match) != nil ? store.newlyEarnedBadgeIDs(matchID: match.id) : [], onBadge: showBadge)
            if store.locallyBlockedIDs.contains(match.opponent.identity.id) {
                PhysiqueStatusView(title: "Opponent hidden", detail: "Your local safety protection is active. The settled result has not changed.", systemImage: "person.crop.circle.badge.xmark")
            } else {
                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent · At match start", onBadge: showBadge)
            }
        }

        PhysiquePlayerPanel(title: "You", status: participantStatus(result, isYou: true)) {
            PhysiqueAthleteIllustration(pose: .front, isOpponent: false)
                .accessibilityHidden(true)
        }
        PhysiquePlayerPanel(title: "Opponent", status: participantStatus(result, isYou: false)) {
            PhysiqueAthleteIllustration(pose: .front, isOpponent: false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var freshnessNotice: some View {
        if let loadError {
            PhysiqueStatusView(title: "Saved result · Not refreshed", detail: loadError, systemImage: "wifi.slash", retry: retry)
            if let fetchedAt {
                Text("Last retrieved \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } else if isLoading {
            Label("Refreshing this match", systemImage: "arrow.clockwise")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func correctionNotice(_ correction: PhysiqueCorrection) -> some View {
        let change = correction.adjustment == 0 ? "No change" : correction.adjustment > 0 ? "Gained" : "Lost"
        return PhysiqueCard {
            Label("Settled review adjustment", systemImage: "arrow.triangle.2.circlepath")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            Text(Date(timeIntervalSince1970: correction.createdAt), format: .dateTime.year().month(.abbreviated).day().hour().minute())
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .accessibilityLabel("Review settled \(Date(timeIntervalSince1970: correction.createdAt).formatted(date: .abbreviated, time: .shortened))")
            Text("Original: \(outcomeTitle(correction.originalOutcome)) · Corrected: \(outcomeTitle(correction.correctedOutcome))")
                .font(TimeMasterFont.secondary())
                .fixedSize(horizontal: false, vertical: true)
            PhysiqueMetric(label: "Review adjustment · \(change)", value: "\(correction.adjustment.formatted(.number.sign(strategy: .always()))) Physique Elo")
            PhysiqueMetric(label: "Physique Elo at review settlement", value: correction.after.formatted())
            Text("Original match change: \(correction.originalChange.formatted(.number.sign(strategy: .always()))) Physique Elo · Superseded")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The review adjustment is separate from the original transaction. The rating shown is from review settlement, not today.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { openResultRoute(.breakdown(matchID)) } label: { Label("Review details in Breakdown", systemImage: "list.bullet.rectangle") }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
        }
    }

    private func explanationContent(match: PhysiqueMatch, result: PhysiqueResult) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if store.isExplanationHidden(matchID) {
                Text("Explanation hidden by you").foregroundStyle(ProfileStyle.secondary)
            } else if let explanation = result.explanation, !explanation.isEmpty {
                Text(explanation).fixedSize(horizontal: false, vertical: true)
                Button { store.hideExplanation(matchID) } label: { Label("Hide explanation", systemImage: "eye.slash") }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
                Button { reportExplanation() } label: { Label("Report explanation", systemImage: "flag") }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
            } else if let reason = match.reason, !reason.isEmpty {
                Text(reason).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Explanation unavailable").foregroundStyle(ProfileStyle.secondary)
            }
            if let version = result.judgeVersion, !version.isEmpty {
                Text("Judging version: \(version)")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if isScoredOutcome(result) {
                Text("Subjective scores of the selected poses, not a measurement of health or personal worth.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailActions(match: PhysiqueMatch, result: PhysiqueResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { openResultRoute(.breakdown(matchID)) } label: {
                HStack(spacing: ProfileStyle.spacing) {
                    Label(isScoredOutcome(result) ? "Breakdown" : "Match details", systemImage: "list.bullet.rectangle")
                        .font(TimeMasterFont.label())
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
                .foregroundStyle(Theme.toolbarOrange)
            }
            .buttonStyle(.plain)
            Divider().overlay(Theme.separator)
            if isJudged(match, result: result) {
                if store.locallyBlockedIDs.contains(match.opponent.identity.id) {
                    Label("Pose access hidden by safety settings", systemImage: "eye.slash")
                        .foregroundStyle(ProfileStyle.secondary)
                } else if posesExpired(match) {
                    Label("Poses expired", systemImage: "clock.badge.xmark")
                        .foregroundStyle(ProfileStyle.secondary)
                } else if match.galleryAvailable {
                    Button { begin(.gallery) } label: {
                        Label(pendingAction == .gallery ? "Checking pose access" : "View poses", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(pendingAction != nil || isLoading || loadError != nil)
                    Text("Opens only after a fresh authorization check. No poses are loaded on this result.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                } else {
                    Label("Pose access unavailable", systemImage: "eye.slash")
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
            Button { openResultRoute(.review(PhysiqueReviewTarget(kind: "dispute", id: matchID, matchID: matchID))) } label: {
                Label("Request scoring review", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            }
            .buttonStyle(.plain)
            if lastAction == .gallery, let actionError {
                Text(actionError)
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Action unavailable. \(actionError)")
            }
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, 6)
        .background(Theme.surface)
    }

    @ViewBuilder
    private func unresolvedContent(_ match: PhysiqueMatch) -> some View {
        if match.stage == .cancelled || match.stage == .noOpponent {
            PhysiqueStatusView(title: match.stage.title, detail: match.reason ?? "No scored match was finalized.")
            PhysiqueAction(title: "Return to Physique", systemImage: "arrow.left") { onOpen(.lobby) }
        } else {
            PhysiqueStatusView(title: match.stage.terminal ? "Confirmed result unavailable" : "Awaiting confirmed result", detail: match.reason ?? "No outcome or rating is inferred while this match is being restored.", systemImage: "clock", retry: isLoading ? nil : { retry() })
            if resumeRoute(match.stage) != nil {
                PhysiqueAction(title: pendingAction == .resume ? "Restoring active match" : "Return to active match", systemImage: "arrow.right", disabled: pendingAction != nil || store.loading || store.busy) { begin(.resume) }
            }
            Button { onOpen(.lobby) } label: { Label("Return to Physique", systemImage: "arrow.left") }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
            if lastAction == .resume, let actionError {
                Text(actionError).foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nextActionRegion: some View {
        PhysiqueAction(title: pendingAction == .next ? "Checking availability" : nextActionTitle, systemImage: "arrow.right", disabled: pendingAction != nil || isLoading || store.loading || store.busy) { begin(.next) }
            .frame(maxWidth: ProfileStyle.readableWidth)
    }

    private var nextActionTitle: String {
        if !store.canControl(from: windowID) { return "Open Physique controls" }
        if lastAction == .next, actionError != nil { return "Check availability" }
        if let match = store.match, !match.stage.terminal { return "Resume active match" }
        if store.stage == .searching { return "Return to search" }
        if store.cancellationPending { return "Check previous request" }
        if store.localProcessingStopped || store.localOwnMediaHidden { return "Review privacy choices" }
        if let policy = store.policy, !policy.ready { return "Check availability" }
        if let account = store.account {
            if account.restrictedReason != nil { return "Check account status" }
            if !account.consent.accepted || account.consent.policyVersion != store.policy?.version { return "Review eligibility and sharing" }
            if account.allowance.remaining <= 0 { return "Check availability" }
        }
        return "Find another opponent"
    }

    private func confirmedResult(in match: PhysiqueMatch) -> PhysiqueResult? {
        guard match.stage.terminal, let result = match.result else { return nil }
        switch result.outcome {
        case "win", "loss", "draw", "forfeitWin", "forfeitLoss", "noContest": return result
        default: return nil
        }
    }

    private func outcomeTitle(_ outcome: String) -> String {
        switch outcome {
        case "win": return "Won"
        case "loss": return "Lost"
        case "draw": return "Draw"
        case "forfeitWin": return "Won by forfeit"
        case "forfeitLoss": return "Forfeited"
        case "noContest": return "No contest"
        default: return "Result unavailable"
        }
    }

    private func isScoredOutcome(_ result: PhysiqueResult) -> Bool {
        result.outcome == "win" || result.outcome == "loss" || result.outcome == "draw"
    }

    private func isJudged(_ match: PhysiqueMatch, result: PhysiqueResult) -> Bool {
        match.stage == .completed && result.isJudged
    }

    private func nonScoreExplanation(_ result: PhysiqueResult) -> String {
        switch result.outcome {
        case "forfeitWin": return "The opponent ended this match by forfeit. No physique comparison was scored."
        case "forfeitLoss": return "You ended this match by forfeit. No physique comparison was scored."
        case "noContest": return "No valid scored comparison was finalized. This is not a draw."
        default: return "The service did not supply both accepted score sets. Match details can be checked without inventing missing values."
        }
    }

    private func participantStatus(_ result: PhysiqueResult, isYou: Bool) -> String {
        let status: String
        switch result.outcome {
        case "win": status = isYou ? "Won this match" : "Match complete"
        case "loss": status = isYou ? "Match complete" : "Won this match"
        case "draw": status = "Draw"
        case "forfeitWin": status = isYou ? "Won by forfeit" : "Forfeited"
        case "forfeitLoss": status = isYou ? "Forfeited" : "Won by forfeit"
        default: status = "No contest"
        }
        return "\(status) · Neutral illustration, not a participant photo"
    }

    private func currentOwnIdentity(for match: PhysiqueMatch) -> PhysiqueIdentity? {
        guard !store.isStale, let refreshedAt = store.lastRefreshedAt, let fetchedAt, refreshedAt >= fetchedAt,
              let current = store.match, current.id == match.id,
              current.result?.corrected == match.result?.corrected,
              current.result?.correction?.id == match.result?.correction?.id,
              let identity = store.account?.identity, identity.id == match.you.identity.id else { return nil }
        return identity
    }

    private func shouldReveal(_ match: PhysiqueMatch) -> Bool {
        guard let result = match.result, result.outcome == "win", isJudged(match, result: result) else { return false }
        let process = ProcessInfo.processInfo
        return revealMatchID == match.id && active && !reduceMotion && !liveResizing && !process.isLowPowerModeEnabled
            && process.thermalState != .serious && process.thermalState != .critical
            && !result.corrected && result.correction == nil
    }

    private func newlyEarnedBadges(for match: PhysiqueMatch) -> [PhysiqueBadge] {
        guard revealMatchID == match.id, let result = match.result, result.outcome == "win",
              isJudged(match, result: result), !result.corrected, result.correction == nil,
              let identity = currentOwnIdentity(for: match) else { return [] }
        let earnedIDs = store.newlyEarnedBadgeIDs(matchID: match.id)
        return identity.badges.filter { earnedIDs.contains($0.id) }
    }

    private func openResultRoute(_ route: PhysiqueRoute) {
        revealMatchID = nil
        pendingAction = nil
        onOpen(route)
    }

    private func posesExpired(_ match: PhysiqueMatch) -> Bool {
        guard let expires = match.mediaExpiresAt else { return false }
        return mediaExpired || expires <= Date().timeIntervalSince1970 + store.serverOffset
    }

    private func showBadge(_ badge: PhysiqueBadge) {
        revealMatchID = nil
        selectedBadge = badge
        showsBadge = true
    }

    private func begin(_ action: PendingAction) {
        guard pendingAction == nil, active else { return }
        actionError = nil
        lastAction = action
        revealMatchID = nil
        pendingAction = action
    }

    private func retry() {
        guard !isLoading else { return }
        actionError = nil
        refreshNumber += 1
    }

    private func reportMatch() {
        revealMatchID = nil
        pendingAction = nil
        onOpen(.report(PhysiqueReportTarget(kind: "match", id: matchID, matchID: matchID)))
    }

    private func reportExplanation() {
        store.hideExplanation(matchID)
        revealMatchID = nil
        pendingAction = nil
        onOpen(.report(PhysiqueReportTarget(kind: "explanation", id: matchID, matchID: matchID)))
    }

    private func close() {
        pendingAction = nil
        revealMatchID = nil
        dismiss()
    }

    private func clearPrivateState() {
        fetchedMatch = nil
        fetchedAccountID = nil
        fetchedAt = nil
        authorizedForPresentation = false
        isLoading = false
        loadError = nil
        actionError = nil
        pendingAction = nil
        lastAction = nil
        revealMatchID = nil
        selectedBadge = nil
        showsBadge = false
        mediaExpired = false
        showsContext = false
    }

    private func acceptLiveMatch(_ snapshot: PhysiqueSnapshot?) {
        guard active, authorizedForPresentation, let accountID = cloudAccount.accountID,
              fetchedAccountID == accountID, let match = snapshot?.match, match.id == matchID else { return }
        fetchedMatch = match
        fetchedAt = Date()
        loadError = nil
        if match.result?.corrected == true || match.result?.correction != nil {
            revealMatchID = nil
        } else if confirmedResult(in: match) != nil, match.result?.outcome != "noContest", store.claimReveal(matchID: matchID) {
            revealMatchID = matchID
            outcomeFocused = true
        }
    }

    private func restorePendingMatch() async {
        guard active, let accountID = cloudAccount.accountID else { pendingAction = nil; return }
        defer { pendingAction = nil }
        guard !store.loading else { actionError = "This session is already being refreshed."; return }
        await store.refresh()
        guard !Task.isCancelled, active, cloudAccount.accountID == accountID, pendingAction == .resume else { return }
        guard store.error == nil, !store.isStale else {
            actionError = store.error ?? "The active match could not be confirmed."
            return
        }
        guard let match = store.match, match.id == matchID else {
            actionError = "This record is not the current active match. Return to Physique to inspect the current session."
            return
        }
        if confirmedResult(in: match) != nil {
            acceptLiveMatch(store.snapshot)
            return
        }
        guard store.canControl(from: windowID) else { onOpen(.lobby); return }
        guard let route = resumeRoute(match.stage) else {
            actionError = "This match has no active capture or judging session to resume."
            return
        }
        onOpen(route)
    }

    private func loadMatch() async {
        if fetchedMatch?.id != matchID || fetchedAccountID != cloudAccount.accountID {
            clearPrivateState()
        }
        guard active, let accountID = cloudAccount.accountID else { return }
        let key = loadKey
        isLoading = true
        loadError = nil
        defer { if loadKey == key { isLoading = false } }
        do {
            let value = try await store.getMatch(matchID)
            try Task.checkCancellation()
            guard loadKey == key, cloudAccount.accountID == accountID else { return }
            guard value.id == matchID else {
                clearPrivateState()
                loadError = "The service did not return the requested match."
                return
            }
            fetchedMatch = value
            fetchedAccountID = accountID
            fetchedAt = Date()
            mediaExpired = false
            authorizedForPresentation = true
            if confirmedResult(in: value) != nil, value.result?.corrected == false, value.result?.correction == nil, value.result?.outcome != "noContest", store.claimReveal(matchID: value.id) {
                revealMatchID = value.id
                outcomeFocused = true
            }
            await store.refresh()
        } catch is CancellationError {
        } catch {
            guard loadKey == key, cloudAccount.accountID == accountID else { return }
            if isConnectivityFailure(error), fetchedAccountID == accountID, fetchedMatch?.id == matchID {
                authorizedForPresentation = true
            } else {
                clearPrivateState()
            }
            revealMatchID = nil
            loadError = error.localizedDescription
        }
    }

    private func openGallery() async {
        guard active, let accountID = cloudAccount.accountID else { pendingAction = nil; return }
        let privacyRevision = store.privacyRevision
        defer { pendingAction = nil }
        do {
            let value = try await store.getMatch(matchID)
            try Task.checkCancellation()
            guard active, cloudAccount.accountID == accountID, pendingAction == .gallery, value.id == matchID else { return }
            fetchedMatch = value
            fetchedAccountID = accountID
            fetchedAt = Date()
            loadError = nil
            guard let result = confirmedResult(in: value), isJudged(value, result: result) else {
                actionError = "Poses are available only for a valid, finalized scored result."
                return
            }
            guard !posesExpired(value) else { actionError = "Poses expired."; return }
            guard !store.locallyBlockedIDs.contains(value.opponent.identity.id) else {
                actionError = "Pose access is hidden by your safety settings."
                return
            }
            guard value.galleryAvailable else { actionError = "Pose access is not currently authorized."; return }
            guard store.privacyRevision == privacyRevision else {
                actionError = "Privacy choices changed. Check pose access again before opening."
                return
            }
            onOpen(.gallery(matchID))
        } catch is CancellationError {
        } catch {
            guard active, cloudAccount.accountID == accountID else { return }
            if !isConnectivityFailure(error) {
                clearPrivateState()
                loadError = error.localizedDescription
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    private func checkNextAction() async {
        guard active, let accountID = cloudAccount.accountID else { pendingAction = nil; return }
        defer { pendingAction = nil }
        guard !store.loading else { actionError = "Availability is already being refreshed. Try again when it finishes."; return }
        await store.refresh()
        guard !Task.isCancelled, active, cloudAccount.accountID == accountID, pendingAction == .next else { return }
        guard store.error == nil, !store.isStale, let snapshot = store.snapshot else {
            actionError = store.error ?? "Availability could not be confirmed. Your result has not changed."
            return
        }
        guard store.canControl(from: windowID) else { onOpen(.lobby); return }
        if store.localProcessingStopped || store.localOwnMediaHidden { onOpen(.privacy); return }
        if let match = snapshot.match, let route = resumeRoute(match.stage) {
            onOpen(route)
            return
        }
        if snapshot.queueDeadline != nil {
            onOpen(.search)
            return
        }
        guard !store.cancellationPending else { onOpen(.lobby); return }
        guard snapshot.policy.ready else {
            actionError = snapshot.policy.unavailableReason ?? "The service is not ready for another match."
            return
        }
        if let restriction = snapshot.account.restrictedReason, !restriction.isEmpty {
            actionError = restriction
            return
        }
        guard snapshot.account.consent.accepted, snapshot.account.consent.policyVersion == snapshot.policy.version else {
            onOpen(.consent)
            return
        }
        guard snapshot.account.allowance.remaining > 0 else {
            if let next = snapshot.account.allowance.nextAvailableAt {
                actionError = "No matches available. Next availability: \(Date(timeIntervalSince1970: next).formatted(date: .abbreviated, time: .shortened))."
            } else {
                actionError = "No matches are currently available for this account."
            }
            return
        }
        onOpen(.camera)
    }

    private func resumeRoute(_ stage: PhysiqueStage) -> PhysiqueRoute? {
        switch stage {
        case .searching: return .search
        case .ready: return .ready
        case .countdown, .capture: return .battle
        case .submitting, .judging: return .judging
        default: return nil
        }
    }

    private func watchMediaExpiry() async {
        guard let match = visibleMatch, let expires = match.mediaExpiresAt else { return }
        let remaining = expires - Date().timeIntervalSince1970 - store.serverOffset
        guard remaining > 0, remaining.isFinite else { mediaExpired = true; return }
        mediaExpired = false
        let seconds = min(remaining, Double(UInt64.max / 1_000_000_000))
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard active, fetchedMatch?.id == match.id, fetchedMatch?.mediaExpiresAt == expires else { return }
            mediaExpired = true
        } catch is CancellationError {
        } catch {
        }
    }

    private func isConnectivityFailure(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed: return true
        default: return false
        }
    }
}
