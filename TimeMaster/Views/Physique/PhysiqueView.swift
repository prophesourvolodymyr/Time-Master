import SwiftUI

struct PhysiqueView: View {
    @StateObject private var store = PhysiqueStore.shared
    @ObservedObject private var account = CloudAccountStore.shared
    @State private var path: [PhysiqueRoute] = []
    @State private var windowID = UUID()
    @State private var confirmsExit = false

    var body: some View {
        PhysiqueNativeShell(store: store, onOpen: open) {
            NavigationStack(path: $path) {
                PhysiqueLobbyView(store: store, onOpen: open)
                    .navigationDestination(for: PhysiqueRoute.self, destination: destination)
            }
            .toolbar {
                if let match = store.match, !match.stage.terminal {
                    ToolbarItem(placement: .automatic) {
                        Button(match.you.submitted ? "Return to lobby" : "Exit match") {
                            store.suspendCapture()
                            if match.you.submitted { open(.lobby) }
                            else { confirmsExit = true }
                        }
                        .physiqueToolbarTarget()
                    }
                }
            }
            .modifier(PhysiqueHeartbeat(store: store, windowID: windowID))
        }
        .environment(\.physiqueWindowID, windowID)
        .tint(Theme.toolbarOrange)
        .slotNavigationInteractionDisabled(store.match.map { !$0.stage.terminal && !$0.you.submitted } ?? (store.snapshot?.queueDeadline != nil))
        .task { await store.refresh() }
        .onChange(of: store.stage) { stage in transition(to: stage) }
        .onChange(of: account.accountID) { _ in
            if path.last != .account { path.removeAll() }
        }
        .confirmationDialog(exitTitle, isPresented: $confirmsExit, titleVisibility: .visible) {
            Button(exitAction, role: .destructive) { Task { await leave() } }
            Button("Stay", role: .cancel) {}
        } message: {
            Text(started ? "An explicit forfeit can change Physique Elo and use this match allowance. Safety, invalid evidence, or service no-contest takes precedence. Camera is stopped; staying does not restart the deadline." : "Cancel this pairing without a rating change. The service must confirm cancellation before you leave.")
        }
        .accessibilityIdentifier("physique-root")
    }

    private var started: Bool { store.match?.startAt.map { $0 <= Date().timeIntervalSince1970 + store.serverOffset } ?? false }
    private var exitTitle: String { started ? "Forfeit and leave?" : "Cancel match?" }
    private var exitAction: String { started ? "Forfeit and leave" : "Cancel match" }

    private func open(_ route: PhysiqueRoute) {
        if path.last == .ready, route != .battle, route != .ready, let match = store.match, match.you.ready, !started {
            store.suspendCapture()
            Task { _ = await store.perform("ready", matchID: match.id, value: false) }
        }
        if route == .lobby { store.suspendCapture(); path.removeAll(); return }
        if route == .battle, let index = path.lastIndex(of: .battle) {
            path.removeSubrange((index + 1)..<path.count)
            return
        }
        if case .result(let id) = route, hasLiveDestination, store.match?.id == id, store.match?.stage.terminal == true {
            store.armResultReveal(matchID: id)
            store.suspendCapture()
            path = [route]
            return
        }
        if route != .battle && route != .ready && route != .search {
            if case .poseReview = route {} else { store.suspendCapture() }
        }
        guard path.last != route else { return }
        path.append(route)
    }

    private var hasLiveDestination: Bool {
        switch path.last {
        case .search, .ready, .battle, .poseReview, .judging: return true
        default: return false
        }
    }

    private func transition(to stage: PhysiqueStage) {
        guard let current = path.last, hasLiveDestination else { return }
        if stage == .capture, store.cancellationPending || store.localProcessingStopped || store.match.map({ store.locallyBlockedIDs.contains($0.opponent.identity.id) }) == true { return }
        let next: PhysiqueRoute?
        switch stage {
        case .ready, .countdown: next = .ready
        case .capture: next = current == .ready || current == .search ? .battle : nil
        case .submitting, .judging: next = .judging
        case .completed, .forfeited, .noContest:
            next = store.match.map { .result($0.id) }
        default: next = nil
        }
        guard let next, next != current else { return }
        if case .poseReview = current { store.suspendCapture() }
        if stage.terminal {
            if let id = store.match?.id { store.armResultReveal(matchID: id) }
            path = [next]
        }
        else { path[path.count - 1] = next }
    }

    private func leave() async {
        guard let match = store.match else { open(.lobby); return }
        if await store.perform("leave", matchID: match.id, reason: started ? "forfeit" : "cancel") { open(.lobby) }
    }

    @ViewBuilder private func destination(_ route: PhysiqueRoute) -> some View {
        switch route {
        case .lobby: PhysiqueLobbyView(store: store, onOpen: open)
        case .account: PhysiqueAccountEntryView(store: store, onOpen: open)
        case .consent: PhysiqueEligibilityConsentView(store: store, onOpen: open)
        case .rules: PhysiqueRulesView(store: store, onOpen: open)
        case .guide: PhysiquePoseGuideView(store: store, onOpen: open)
        case .camera: PhysiqueCameraSetupView(store: store, onOpen: open)
        case .search: PhysiqueMatchSearchView(store: store, onOpen: open)
        case .ready: PhysiqueReadyRoomView(store: store, onOpen: open)
        case .battle: PhysiqueBattleStageView(store: store, onOpen: open)
        case .poseReview(let pose): PhysiquePoseReviewView(store: store, onOpen: open, pose: pose)
        case .judging: PhysiqueJudgingView(store: store, onOpen: open)
        case .result(let id): PhysiqueResultView(store: store, onOpen: open, matchID: id)
        case .breakdown(let id): PhysiqueScoreBreakdownView(store: store, onOpen: open, matchID: id)
        case .gallery(let id): PhysiquePoseGalleryView(store: store, onOpen: open, matchID: id)
        case .history: PhysiqueHistoryView(store: store, onOpen: open)
        case .standings: PhysiqueStandingsView(store: store, onOpen: open)
        case .player(let id): PhysiquePlayerSummaryView(store: store, onOpen: open, playerID: id)
        case .safety: PhysiqueSafetyHubView(store: store, onOpen: open)
        case .report(let target): PhysiqueReportComposerView(store: store, onOpen: open, target: target)
        case .cases: PhysiqueCaseCenterView(store: store, onOpen: open)
        case .caseDetail(let id): PhysiqueCaseDetailView(store: store, onOpen: open, caseID: id)
        case .review(let target): PhysiqueReviewComposerView(store: store, onOpen: open, target: target)
        case .privacy: PhysiquePrivacyView(store: store, onOpen: open)
        case .deletion: PhysiqueDeletionStatusView(store: store, onOpen: open)
        case .badges: PhysiqueBadgesCountryView(store: store, onOpen: open)
        }
    }
}

private struct PhysiqueHeartbeat: ViewModifier {
    @ObservedObject var store: PhysiqueStore
    let windowID: UUID
    @Environment(\.physiquePresentationActive) private var active
    private var runs: Bool { active && store.controllingWindowID == windowID && store.match != nil && !store.stage.terminal }
    func body(content: Content) -> some View {
        content.task(id: runs) {
            guard runs else { return }
            while !Task.isCancelled {
                if !store.busy { _ = await store.perform("presence", matchID: store.match?.id) }
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
            }
        }
    }
}
