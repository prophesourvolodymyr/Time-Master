import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
struct PhysiqueMatchSearchView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @AccessibilityFocusState private var headingFocused: Bool
    @FocusState private var detailsFocused: Bool
    @State private var visible = false
    @State private var reconciled = false
    @State private var connectionUnconfirmed = false
    @State private var cutoffReached = false
    @State private var refreshRequest = 0
    @State private var cancellationRequested = false
    @State private var sendingCancellation = false
    @State private var cancellationError: String?
    @State private var showsDetails = false
    @State private var selectedBadge: PhysiqueBadge?
    @State private var routedMatchID: String?

    private struct PollContext: Equatable {
        let accountID: String?
        let active: Bool
        let controlsParticipation: Bool
        let refreshRequest: Int
    }

    private enum Presentation: Equatable {
        case signedOut, checking, searching, checkingCutoff, unconfirmed
        case cancelling, cancellationUnconfirmed, cancelled, noOpponent
        case paired, started, completed, unavailable, notQueued

        var title: String {
            switch self {
            case .signedOut: return "Sign in to search"
            case .checking: return "Checking search status"
            case .searching: return "Searching"
            case .checkingCutoff: return "Checking search status"
            case .unconfirmed: return "Search not confirmed"
            case .cancelling: return "Cancelling"
            case .cancellationUnconfirmed: return "Cancellation not confirmed"
            case .cancelled: return "Search cancelled"
            case .noOpponent: return "No opponent found"
            case .paired: return "Opponent found"
            case .started: return "Match started"
            case .completed: return "Match ended"
            case .unavailable: return "Search unavailable"
            case .notQueued: return "No active search"
            }
        }
    }

    private var active: Bool {
        visible && presentationActive && scenePhase == .active
    }

    private var controlsParticipation: Bool {
        store.canControl(from: windowID)
    }

    private var pollContext: PollContext {
        PollContext(accountID: cloudAccount.accountID, active: active,
                    controlsParticipation: controlsParticipation, refreshRequest: refreshRequest)
    }

    private var queued: Bool {
        store.snapshot?.queueStartedAt != nil || store.snapshot?.queueDeadline != nil
    }

    private var pendingCancellation: Bool {
        cancellationRequested || store.cancellationPending
    }

    private var postGo: Bool {
        guard let match = store.match else { return false }
        return match.stage == .capture || match.stage == .submitting || match.stage == .judging
    }

    private var preGoParticipation: Bool {
        queued || store.match?.stage == .ready || store.match?.stage == .countdown
    }

    private var released: Bool {
        guard reconciled, !store.isStale, !connectionUnconfirmed, !queued else { return false }
        guard let match = store.match else { return store.snapshot != nil }
        return match.stage == .cancelled || match.stage == .noOpponent
    }

    private var eligibilityIssue: String? {
        if let reason = store.account?.restrictedReason, !reason.isEmpty { return reason }
        if store.localProcessingStopped {
            return "AI processing is stopped on this device. Review sharing choices before searching."
        }
        if let opponentID = store.match?.opponent.identity.id, store.locallyBlockedIDs.contains(opponentID) {
            return "This opponent is blocked. Confirm cancellation before searching again."
        }
        if let policy = store.policy, !policy.ready {
            return policy.unavailableReason ?? "The service has not enabled rated Physique matching."
        }
        if let account = store.account, let policy = store.policy,
           !account.consent.accepted || account.consent.policyVersion != policy.version {
            return "Review the current rules and sharing choices before searching."
        }
        return nil
    }

    private var presentation: Presentation {
        guard cloudAccount.accountID != nil else { return .signedOut }
        if sendingCancellation { return .cancelling }
        if postGo { return .started }
        if let match = store.match,
           match.stage == .completed || match.stage == .forfeited || match.stage == .noContest {
            return .completed
        }
        if pendingCancellation { return .cancellationUnconfirmed }
        guard reconciled else { return .checking }
        if connectionUnconfirmed || store.isStale { return .unconfirmed }
        if let match = store.match {
            switch match.stage {
            case .ready, .countdown: return eligibilityIssue == nil ? .paired : .unavailable
            case .cancelled: return .cancelled
            case .noOpponent: return .noOpponent
            default: break
            }
        }
        if !queued, store.match == nil {
            if store.snapshot?.queueOutcome == "noOpponent" { return .noOpponent }
            if store.snapshot?.queueOutcome == "cancelled" { return .cancelled }
        }
        if eligibilityIssue != nil { return .unavailable }
        if queued { return cutoffReached ? .checkingCutoff : .searching }
        return store.snapshot == nil ? .unconfirmed : .notQueued
    }

    private var statusLine: String {
        if !controlsParticipation { return "Open in another window" }
        switch presentation {
        case .searching: return "Range unconfirmed"
        case .checkingCutoff: return "Search limit reached · awaiting the service"
        case .checking: return "Retrieving this account’s existing participation"
        case .unconfirmed: return "Connection or current participation unconfirmed"
        case .cancelling: return "Waiting for service confirmation"
        case .cancellationUnconfirmed: return "The search may still exist"
        case .cancelled, .noOpponent: return "Search ended by the service"
        case .paired: return "Readiness is a separate, explicit step"
        case .started: return "Rejoin the same match · no automatic forfeit"
        case .completed: return "Open the service-recorded outcome"
        case .unavailable: return "No new search will be started"
        case .signedOut: return "Your previous account’s search is not shown"
        case .notQueued: return "Continue through camera preparation to search"
        }
    }

    private var needsCancellation: Bool {
        cloudAccount.accountID != nil && !postGo && presentation != .completed && !released
    }

    private var canPrepareAgain: Bool {
        released && !pendingCancellation && controlsParticipation && !store.busy && !store.loading
            && eligibilityIssue == nil && (store.account?.allowance.remaining ?? 0) > 0
    }

    private var queueDeadline: Double? {
        guard let snapshot = store.snapshot, snapshot.serverTime.isFinite,
              let deadline = snapshot.queueDeadline, deadline.isFinite, deadline > 0,
              store.serverOffset.isFinite else { return nil }
        return deadline
    }

    private var cutoffTaskID: Double? {
        guard active else { return nil }
        return queueDeadline.map { $0 - store.serverOffset }
    }

    private var clock: PhysiqueClock {
        let endpoint = store.match == nil ? queueDeadline : nil
        let searchEnded = store.match != nil || presentation == .cancelled
        let uncertain = !reconciled || connectionUnconfirmed || store.isStale
        return PhysiqueClock(mode: endpoint == nil ? .unavailable : .remaining,
                             label: searchEnded ? "Search ended" : endpoint == nil ? "Time unconfirmed" : uncertain ? "Original search limit" : "Search left",
                             endpoint: endpoint, serverOffset: store.serverOffset)
    }

    private var opponentStatus: String {
        if pendingCancellation { return "Withdrawal requested · opponent not displayed" }
        switch presentation {
        case .paired: return "Pairing confirmed · open ready room"
        case .started: return "Match started · rejoin to continue"
        case .completed: return "See the recorded opponent in the result"
        case .unconfirmed, .checking: return "Pairing unconfirmed"
        default: return "Not paired"
        }
    }

    private var pairedOpponent: PhysiqueIdentity? {
        guard presentation == .paired, !pendingCancellation, let match = store.match,
              match.you.identity.id != match.opponent.identity.id else { return nil }
        return match.opponent.identity
    }

    var body: some View {
        VStack(spacing: 0) {
            clockBand
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    recoveryContext
                    if cloudAccount.accountID != nil, let account = store.account {
                        identityAndPlayers(account.identity)
                    }
                }
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(ProfileStyle.inset)
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Physique Duels")
        .interactiveDismissDisabled(controlsParticipation && (needsCancellation || pendingCancellation))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showsDetails = true
                } label: {
                    Label("Search details", systemImage: "info.circle")
                }
                .focused($detailsFocused)
            }
            #if os(macOS)
            ToolbarItemGroup(placement: .automatic) { actions }
            #endif
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(controlsParticipation && (needsCancellation || pendingCancellation))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: ProfileStyle.spacing) { actions }
                .buttonStyle(TimeMasterActionButtonStyle(fillsWidth: true))
                .frame(maxWidth: ProfileStyle.readableWidth)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
        }
        #else
        .onExitCommand(perform: handleEscape)
        #endif
        #if os(macOS)
        .popover(isPresented: $showsDetails) {
            searchDetails.frame(minWidth: 380, idealWidth: 460, maxWidth: 540, minHeight: 360, idealHeight: 520)
        }
        #else
        .sheet(isPresented: $showsDetails) { searchDetails }
        #endif
        .alert(item: $selectedBadge) { badge in
            Alert(title: Text(badge.title), message: Text(badge.detail), dismissButton: .default(Text("Done")))
        }
        .onAppear {
            visible = true
            store.camera.stop(owner: windowID)
            headingFocused = true
        }
        .onDisappear {
            visible = false
            store.camera.stop(owner: windowID)
        }
        .onChange(of: cloudAccount.accountID) { _ in resetAccountPresentation() }
        .onChange(of: presentation) { _ in
            if showsDetails || selectedBadge != nil { announce(presentation.title) }
            handOffPairIfPossible()
        }
        .onChange(of: store.match?.id) { _ in handOffPairIfPossible() }
        .onChange(of: selectedBadge) { badge in
            if badge == nil { handOffPairIfPossible() }
        }
        .onChange(of: showsDetails) { showing in
            if !showing { detailsDismissed() }
        }
        .task(id: presentation) {
            guard active, !showsDetails, selectedBadge == nil else { return }
            headingFocused = false
            await Task.yield()
            guard !Task.isCancelled, active else { return }
            headingFocused = true
        }
        .task(id: pollContext) { await poll(pollContext) }
        .task(id: cutoffTaskID) { await watchCutoff() }
    }

    private var clockBand: some View {
        VStack(spacing: ProfileStyle.spacing / 2) {
            Text(presentation.title)
                .font(TimeMasterFont.heading())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingFocused)
            if presentation == .noOpponent {
                VStack(spacing: 4) {
                    Text("SEARCH LEFT").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    Text("0:00").font(TimeMasterFont.display()).monospacedDigit()
                }
                .padding(ProfileStyle.spacing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Search time remaining")
                .accessibilityValue("Zero seconds. The service confirmed this search ended without an opponent.")
            } else {
                PhysiqueTimerView(clock: clock)
                    .accessibilityHint("This is the search limit, not an estimated time to find an opponent.")
            }
            Text(statusLine)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.vertical, ProfileStyle.spacing)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1).accessibilityHidden(true) }
    }

    @ViewBuilder
    private var recoveryContext: some View {
        if !controlsParticipation {
            PhysiqueStatusView(title: "Another window controls this participation",
                               detail: "You can check the current state here. Moving control here stops acquisition in the previous window.",
                               systemImage: "macwindow.on.rectangle")
        }
        switch presentation {
        case .signedOut:
            PhysiqueStatusView(title: "Tmax account required", detail: "Sign in to retrieve your current Physique participation.", systemImage: "person.crop.circle")
        case .unconfirmed:
            PhysiqueStatusView(title: "Current search unavailable",
                               detail: store.error ?? "Check the service before starting or leaving a search. No second attempt has been created.",
                               systemImage: "wifi.exclamationmark")
        case .cancelling, .cancellationUnconfirmed:
            PhysiqueStatusView(title: presentation.title,
                               detail: cancellationError ?? "Cancellation is not a release until the service confirms it. No new search will be started while it is unresolved.",
                               systemImage: "clock.arrow.circlepath")
        case .checkingCutoff:
            PhysiqueStatusView(title: "Waiting for the service",
                               detail: "Zero on this clock does not decide whether a pair was found or this search expired.",
                               systemImage: "clock")
        case .unavailable:
            PhysiqueStatusView(title: "Participation unavailable", detail: eligibilityIssue ?? "The service has not confirmed search availability.")
        case .cancelled, .noOpponent:
            if let account = store.account {
                PhysiqueMetric(label: "Available Physique matches", value: "\(account.allowance.remaining) of \(account.allowance.limit)")
                if !canPrepareAgain {
                    Text(eligibilityIssue ?? "Check current availability before another attempt.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        default:
            EmptyView()
        }
    }

    private func identityAndPlayers(_ identity: PhysiqueIdentity) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            if store.isStale || connectionUnconfirmed || !reconciled {
                Label("Identity and badges · last confirmed", systemImage: "clock.arrow.circlepath")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            PhysiqueIdentityRail(identity: identity, ownerLabel: "You") { selectedBadge = $0 }
            if let opponent = pairedOpponent {
                PhysiqueIdentityRail(identity: opponent, ownerLabel: "Opponent") { selectedBadge = $0 }
            } else {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing / 2) {
                    Text("OPPONENT").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    Text(opponentStatus).font(TimeMasterFont.heading())
                }
                .accessibilityElement(children: .combine)
            }
            PhysiquePlayerPanel(title: "You", status: "Camera off · identity illustration") {
                PhysiqueAthleteIllustration().accessibilityHidden(true)
            }
            PhysiquePlayerPanel(title: "Opponent", status: opponentStatus) {
                if pairedOpponent != nil {
                    PhysiqueAthleteIllustration(isOpponent: true).accessibilityHidden(true)
                } else {
                    Image(systemName: "square.dashed")
                        .font(.largeTitle)
                        .foregroundStyle(ProfileStyle.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if !controlsParticipation, cloudAccount.accountID != nil {
            Button("Use this window") {
                store.transferControl(to: windowID)
                refreshRequest += 1
            }
            Button("Return to lobby") { onOpen(.lobby) }
        } else if presentation == .signedOut {
            Button("Sign in") { onOpen(.account) }
            Button("Return to lobby") { onOpen(.lobby) }
        } else if presentation == .started {
            Button("Rejoin match") { openCurrentMatch() }
        } else if presentation == .completed {
            Button("Open result") { openCurrentMatch() }
            Button("Return to lobby") { onOpen(.lobby) }
        } else if pendingCancellation || presentation == .cancelling {
            if sendingCancellation {
                ProgressView("Cancelling search")
            } else {
                Button("Confirm cancellation", action: requestCancellation)
                    .disabled(store.busy || !active)
                Button("Check status") { refreshRequest += 1 }
                    .disabled(store.loading || store.busy || !active)
            }
        } else if released {
            if presentation == .noOpponent || presentation == .cancelled {
                Button("Try again") { onOpen(.camera) }.disabled(!canPrepareAgain)
            } else if eligibilityIssue == nil {
                Button("Camera preparation") { onOpen(.camera) }.disabled(!canPrepareAgain)
            } else if store.account?.restrictedReason == nil, store.policy?.ready == true {
                Button("Review sharing choices") { onOpen(.consent) }
            }
            Button("Return to lobby") { onOpen(.lobby) }
        } else {
            if presentation == .unconfirmed || presentation == .checkingCutoff || presentation == .unavailable {
                Button("Check status") { refreshRequest += 1 }
                    .disabled(store.loading || store.busy || !active)
            }
            Button("Cancel search", role: .cancel, action: requestCancellation)
                .disabled(!active)
        }
    }

    private var searchDetails: some View {
        NavigationStack {
            PhysiqueScreen(title: "Search details", subtitle: "A search limit, not an estimated wait") {
                PhysiqueSection(title: "This attempt") {
                    if let started = store.snapshot?.queueStartedAt, started.isFinite {
                        LabeledContent("Joined", value: Date(timeIntervalSince1970: started).formatted(date: .abbreviated, time: .standard))
                    }
                    if let deadline = queueDeadline {
                        LabeledContent("Original cutoff", value: Date(timeIntervalSince1970: deadline).formatted(date: .abbreviated, time: .standard))
                    }
                    Text("A match is not guaranteed. The clock uses the service’s cutoff and never starts a new attempt.")
                    Text("The service has not supplied the current maximum Physique Elo difference in this status. Range remains unconfirmed.")
                }
                PhysiqueSection(title: "Before Go") {
                    Text("No match is used before Go. Both participants must separately become Ready before the service can start a match.")
                    Text("Cancel requests withdrawal of this participation. Stay here until its release is confirmed. A failed connection is not a cancellation receipt.")
                    Text("If the match has already started, Cancel does not become a forfeit. Rejoin opens that same match and its state-aware exit controls.")
                }
                PhysiqueSection(title: "Privacy") {
                    Text("The camera is off during search. No pose still, video, microphone input or local Profile photo is sent by this screen.")
                    Text("The empty opponent position is not a preview of another player. Country and badges are identity presentation, not judging inputs or search filters.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsDetails = false }.keyboardShortcut(.cancelAction)
                }
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    if controlsParticipation, needsCancellation, !pendingCancellation {
                        Button("Cancel search", role: .cancel) {
                            showsDetails = false
                            requestCancellation()
                        }
                    }
                }
                #endif
            }
        }
    }

    private func poll(_ context: PollContext) async {
        guard context.active, let accountID = context.accountID else { return }
        reconciled = false
        while store.loading || store.busy {
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard contextIsCurrent(context) else { return }
        }
        await store.refresh()
        guard contextIsCurrent(context) else { return }
        reconciled = store.snapshot != nil
        connectionUnconfirmed = store.isStale || store.error != nil
        handOffPairIfPossible()
        if preGoParticipation, eligibilityIssue != nil, controlsParticipation, !pendingCancellation {
            requestCancellation()
        }
        while contextIsCurrent(context) {
            if released || presentation == .completed || postGo || presentation == .paired { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard contextIsCurrent(context), !store.loading, !store.busy else { continue }
            if context.controlsParticipation, !pendingCancellation, eligibilityIssue == nil {
                let succeeded = await store.perform("presence")
                guard contextIsCurrent(context) else { return }
                connectionUnconfirmed = !succeeded || store.isStale
            } else {
                await store.refresh()
                guard contextIsCurrent(context) else { return }
                connectionUnconfirmed = store.isStale || store.error != nil
            }
            guard cloudAccount.accountID == accountID else { return }
            reconciled = store.snapshot != nil
            handOffPairIfPossible()
            if preGoParticipation, eligibilityIssue != nil, controlsParticipation, !pendingCancellation {
                requestCancellation()
            }
        }
    }

    private func contextIsCurrent(_ context: PollContext) -> Bool {
        !Task.isCancelled && active && cloudAccount.accountID == context.accountID
            && controlsParticipation == context.controlsParticipation && refreshRequest == context.refreshRequest
    }

    private func watchCutoff() async {
        cutoffReached = false
        guard let endpoint = cutoffTaskID else { return }
        let remaining = endpoint - Date().timeIntervalSince1970
        if remaining > 0 {
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
        }
        guard !Task.isCancelled, active else { return }
        cutoffReached = true
    }

    private func requestCancellation() {
        guard active, controlsParticipation, !sendingCancellation, !postGo,
              let accountID = cloudAccount.accountID else { return }
        cancellationRequested = true
        cancellationError = nil
        sendingCancellation = true
        store.camera.stop(owner: windowID)
        Task {
            let succeeded = await store.perform("cancel")
            guard cloudAccount.accountID == accountID else { return }
            sendingCancellation = false
            reconciled = store.snapshot != nil
            connectionUnconfirmed = !succeeded || store.isStale
            if succeeded, released {
                cancellationRequested = false
                cancellationError = nil
                showsDetails = false
                if visible, active, controlsParticipation { onOpen(.lobby) }
            } else {
                cancellationError = store.error ?? "The service has not confirmed release. Check this same participation before leaving or starting again."
            }
        }
    }

    private func handOffPairIfPossible() {
        guard active, reconciled, controlsParticipation, !pendingCancellation, !sendingCancellation,
              !connectionUnconfirmed, !store.isStale, eligibilityIssue == nil,
              !showsDetails, selectedBadge == nil, let match = store.match,
              match.stage == .ready || match.stage == .countdown,
              !match.id.isEmpty, !match.you.identity.id.isEmpty, !match.opponent.identity.id.isEmpty,
              match.you.identity.id != match.opponent.identity.id,
              routedMatchID != match.id else { return }
        routedMatchID = match.id
        onOpen(.ready)
    }

    private func openCurrentMatch() {
        guard reconciled, let match = store.match, !store.isStale, !connectionUnconfirmed else {
            refreshRequest += 1
            return
        }
        switch match.stage {
        case .ready, .countdown: onOpen(.ready)
        case .capture, .submitting: onOpen(.battle)
        case .judging: onOpen(.judging)
        case .completed, .forfeited, .noContest: onOpen(.result(match.id))
        default: refreshRequest += 1
        }
    }

    private func detailsDismissed() {
        if presentation == .paired { handOffPairIfPossible() }
        else { detailsFocused = true }
    }

    private func announce(_ text: String) {
        guard active else { return }
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: text)
        #else
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        #endif
    }

    private func handleEscape() {
        if showsDetails { showsDetails = false }
        else if selectedBadge != nil { selectedBadge = nil }
        else if !controlsParticipation || released || presentation == .signedOut || presentation == .completed { onOpen(.lobby) }
        else if postGo { openCurrentMatch() }
        else if !pendingCancellation { requestCancellation() }
    }

    private func resetAccountPresentation() {
        reconciled = false
        connectionUnconfirmed = false
        cutoffReached = false
        cancellationRequested = false
        sendingCancellation = false
        cancellationError = nil
        selectedBadge = nil
        showsDetails = false
        routedMatchID = nil
        headingFocused = true
    }
}
