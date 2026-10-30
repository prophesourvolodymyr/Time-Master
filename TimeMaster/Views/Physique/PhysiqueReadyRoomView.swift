import SwiftUI
import Combine

@MainActor
struct PhysiqueReadyRoomView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    private let camera = PhysiqueCamera.shared
    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @State private var cameraStatus = PhysiqueCameraStatus.idle
    @State private var cameraOwnerID: UUID?
    @State private var hasPrivateFrame = false
    @State private var cameraCapturing = false
    @State private var framingMessage = "Stand alone in a private space with your full body in frame."
    @State private var checkingMatch = false
    @State private var readinessRequest: Bool?
    @State private var withdrawalPending = false
    @State private var withdrawalQueued = false
    @State private var startInhibited = false
    @State private var previewAllowed = true
    @State private var cancellationRequested = false
    @State private var cancelling = false
    @State private var blockRequested = false
    @State private var blocking = false
    @State private var blockConfirmed = false
    @State private var showsBlockConfirmation = false
    @State private var blockConfirmationMatchID: String?
    @State private var blockConfirmationWasPreGo = true
    @State private var showsForfeitConfirmation = false
    @State private var forfeitConfirmationMatchID: String?
    @State private var localMessage: String?
    @State private var forwardedState: String?
    @State private var contextAccountID: String?
    @State private var contextMatchID: String?

    private var match: PhysiqueMatch? {
        guard store.signedIn else { return nil }
        return store.match
    }

    private var preGo: Bool {
        match?.stage == .ready || match?.stage == .countdown
    }

    private var postGo: Bool {
        match?.stage == .capture || match?.stage == .submitting || match?.stage == .judging
    }

    private var controlsWindow: Bool { store.canControl(from: windowID) }

    private var cameraActive: Bool {
        cameraOwnerID == windowID && cameraStatus.isRunning && previewAllowed && presentationActive
            && !store.localProcessingStopped && !store.localOwnMediaHidden
    }

    private var opponentHidden: Bool {
        blockRequested || match.map { store.locallyBlockedIDs.contains($0.opponent.identity.id) } == true
    }

    private var observationID: String {
        "\(cloudAccount.accountID ?? "signed-out"):\(match?.id ?? "no-match"):\(presentationActive)"
    }

    private var arenaMotionAllowed: Bool {
        guard presentationActive, controlsWindow, match?.stage == .ready,
              !store.isStale, !store.loading, !checkingMatch, !startInhibited,
              !cancellationRequested, !blockRequested, !withdrawalPending,
              !showsBlockConfirmation, !showsForfeitConfirmation,
              readinessRequest == nil else { return false }
        guard let deadline = match?.deadline else { return true }
        return deadline.isFinite && store.serverOffset.isFinite
            && deadline > Date().timeIntervalSince1970 + store.serverOffset
    }

    private var clock: PhysiqueClock {
        let authorized = preGo && match?.stage == .countdown && !store.isStale && !checkingMatch
            && presentationActive && !startInhibited && !cancellationRequested && !blockRequested
        return PhysiqueClock(
            mode: authorized ? .countdown : .unavailable,
            label: "Start in",
            endpoint: authorized ? match?.startAt : nil,
            serverOffset: store.serverOffset
        )
    }

    private var instruction: String {
        if cancelling { return "Cancelling · Waiting for confirmation" }
        if blocking { return "Block pending · Waiting for confirmation" }
        if cancellationRequested && postGo { return "Match started · Cancel was not accepted before Go" }
        if blockRequested && postGo { return "Match started · Blocking does not leave this match" }
        if withdrawalPending { return "Ready withdrawal pending" }
        if checkingMatch || store.isStale { return "Checking match" }
        if !controlsWindow { return "Active in another window" }
        if let match, match.stage.terminal { return match.stage.title }
        guard let match else { return "Checking match" }
        if match.stage == .countdown && !startInhibited { return "Waiting for the service to confirm Go" }
        if match.you.ready && match.opponent.ready { return "Waiting for start" }
        if match.you.ready { return "Waiting for opponent" }
        return "Mark ready when set"
    }

    private var ownStatus: String {
        if readinessRequest == true { return "Sending Ready" }
        if readinessRequest == false || withdrawalPending { return "Ready withdrawal pending" }
        if store.isStale || checkingMatch { return "Readiness unconfirmed" }
        guard let match else { return "Checking match" }
        return match.you.ready ? "Ready · Confirmed" : "Not ready"
    }

    private var opponentStatus: String {
        if opponentHidden { return blockConfirmed ? "Blocked · No live opponent preview" : "Hidden locally · Block not confirmed" }
        if store.isStale || checkingMatch { return "Readiness unconfirmed · No live opponent preview" }
        guard let match else { return "Checking match · No live opponent preview" }
        return match.opponent.ready ? "Ready · Confirmed · No live opponent preview" : "Not ready · No live opponent preview"
    }

    private var readinessBlocker: String? {
        guard store.signedIn else { return "Sign in to restore your match." }
        guard let account = store.account, let match else { return "Restore the existing match before marking Ready." }
        guard preGo else { return "This match is no longer in preparation." }
        guard !store.localProcessingStopped, !store.localOwnMediaHidden else {
            return "Review your current privacy and sharing choices before resuming this match."
        }
        guard account.identity.id == match.you.identity.id else { return "The match identity needs to be checked." }
        if let reason = account.restrictedReason { return reason }
        guard let policy = store.policy else { return "The current service policy is unavailable." }
        guard policy.ready else { return policy.unavailableReason ?? "Rated participation is unavailable." }
        guard account.consent.accepted, account.consent.policyVersion == policy.version else {
            return "Review and accept the current rules and sharing choices before Ready."
        }
        guard !store.isStale, !checkingMatch else { return "Check the current match before marking Ready." }
        guard presentationActive else { return "Return to this active window before marking Ready." }
        guard controlsWindow else { return "Another window controls this match. Use this window only after stopping the other camera." }
        guard !cancellationRequested, !blockRequested else { return "Confirm the pending protection or cancellation before continuing." }
        guard !withdrawalPending else { return "Confirm that readiness has stopped before marking Ready again." }
        guard cameraOwnerID == windowID, cameraStatus.isRunning, previewAllowed else { return cameraStatus.message }
        guard hasPrivateFrame, !cameraCapturing else { return framingMessage }
        return nil
    }

    private var roomContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: ProfileStyle.spacing) {
                PhysiqueTimerView(clock: clock)
                Text(instruction)
                    .font(TimeMasterFont.label())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.bottom, ProfileStyle.spacing)
            .background(Theme.background)

            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                    roomStatus
                    if let match {
                        identityRails(match)
                        Button { openDetails(.guide) } label: {
                            Label("Three poses · Pose guide", systemImage: "figure.strengthtraining.traditional")
                                .font(TimeMasterFont.label())
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget, alignment: .leading)
                        }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())

                        PhysiquePlayerPanel(title: "You", status: ownStatus) {
                            if cameraActive && !store.isStale {
                                PhysiqueCameraPreview(camera: camera)
                            } else {
                                PhysiqueAthleteIllustration()
                                    .accessibilityHidden(true)
                            }
                        }
                        Text(cameraActive ? framingMessage : cameraStatus.message)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        PhysiquePlayerPanel(title: "Opponent", status: opponentStatus) {
                            PhysiqueAthleteIllustration(isOpponent: true)
                                .accessibilityHidden(true)
                        }
                        Text("No live opponent preview. No pose images are shared in the ready room.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !opponentHidden {
                            PhysiqueAction(title: "Player details", systemImage: "person.crop.circle", role: .cancel) {
                                openDetails(.player(match.opponent.identity.id))
                            }
                            PhysiqueAction(title: "Report identity", systemImage: "flag", role: .cancel) {
                                openDetails(.report(PhysiqueReportTarget(kind: "identity", id: match.opponent.identity.id, matchID: match.id)))
                            }
                        }
                        if !blockConfirmed {
                            PhysiqueAction(title: blockRequested ? "Retry block" : "Block opponent", systemImage: "hand.raised", role: .cancel, disabled: blocking) {
                                prepareBlockConfirmation()
                            }
                        }
                    } else {
                        PhysiqueStatusView(
                            title: store.signedIn ? "Match unavailable" : "Sign in to restore your match",
                            detail: "No opponent or readiness is assumed. Check your account and the current service state.",
                            systemImage: "person.crop.circle.badge.questionmark"
                        )
                        PhysiqueAction(title: store.signedIn ? "Check match" : "Account", systemImage: "arrow.clockwise") {
                            if store.signedIn { Task { await checkMatch() } }
                            else { openDetails(.account) }
                        }
                    }

                    PhysiqueAction(title: "Rules", systemImage: "list.bullet.rectangle", role: .cancel) { openDetails(.rules) }
                    PhysiqueAction(title: "Privacy and sharing", systemImage: "hand.raised", role: .cancel) { openDetails(.privacy) }
                    PhysiqueAction(title: "Camera setup", systemImage: "camera", role: .cancel) { openDetails(.camera) }
                }
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(ProfileStyle.inset)
            }
        }
        .background {
            PhysiqueBattleBackground(
                stage: match?.stage ?? .ready,
                cameraActive: cameraActive,
                motionAllowed: arenaMotionAllowed
            )
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationTitle("Ready room")
        .safeAreaInset(edge: .bottom, spacing: 0) { actionDock }
        .interactiveDismissDisabled(preGo || postGo || cancellationRequested || blockRequested)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { requestCancel() } label: {
                    Label(cancelling ? "Cancelling" : "Cancel match", systemImage: "xmark")
                }
                .physiqueToolbarTarget()
                .disabled(cancelling || !preGo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { openDetails(.safety) } label: { Label("Safety", systemImage: "shield") }
                    .physiqueToolbarTarget()
            }
        }
    }

    private var confirmedRoom: some View {
        roomContent
        .confirmationDialog(
            blockConfirmationWasPreGo ? "Block and cancel match?" : "Block opponent?",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(blockConfirmationWasPreGo ? "Block and cancel match" : "Block opponent", role: .destructive) {
                Task { await blockOpponent() }
            }
            Button("Keep match", role: .cancel) { }
        } message: {
            Text(blockConfirmationWasPreGo
                 ? "Blocking prevents future pairings. There is no rating change or consumed allowance if cancellation is accepted before Go. A late block does not leave an active match."
                 : "Blocking hides this opponent and prevents future pairings. It does not leave this match or change its rating. Leaving requires a separate confirmed forfeit.")
        }
        .confirmationDialog("Forfeit and leave?", isPresented: $showsForfeitConfirmation, titleVisibility: .visible) {
            Button("Forfeit and leave", role: .destructive) { Task { await forfeitMatch() } }
            Button("Keep match", role: .cancel) { }
        } message: {
            Text("In an otherwise eligible active match, leaving records a forfeit loss and consumes this match's allowance. A service-confirmed safety abort, invalid capture, or unavailable service takes precedence.")
        }
    }

    private var cameraObservedRoom: some View {
        confirmedRoom
        .task(id: observationID) { await observeMatch() }
        .onChange(of: presentationActive) { active in
            if !active { disarm() }
        }
        .onReceive(camera.$status.removeDuplicates()) { status in
            cameraStatus = status
            if !status.isRunning && (match?.you.ready == true || readinessRequest == true) { disarm(stopCamera: false) }
        }
        .onReceive(camera.$ownerID.removeDuplicates()) { owner in
            cameraOwnerID = owner
            if owner != windowID && (match?.you.ready == true || readinessRequest == true) { disarm(stopCamera: false) }
        }
        .onReceive(camera.$previewImage.map { $0 != nil }.removeDuplicates()) { available in
            hasPrivateFrame = available
            if !available && cameraStatus.isRunning && (match?.you.ready == true || readinessRequest == true) { disarm(stopCamera: false) }
        }
        .onReceive(camera.$isCapturing.removeDuplicates()) { cameraCapturing = $0 }
        .onReceive(camera.$framingMessage.removeDuplicates()) { framingMessage = $0 }
    }

    var body: some View {
        cameraObservedRoom
        .onChange(of: store.isStale) { stale in
            if stale { disarm() }
        }
        .onChange(of: store.controllingWindowID) { _ in
            if !controlsWindow { disarm() }
        }
        .onChange(of: store.busy) { busy in
            if !busy && withdrawalQueued && readinessRequest == nil { Task { await withdrawReadiness() } }
        }
        .onChange(of: store.match?.you.ready) { ready in
            if ready == true && (!cameraActive || !hasPrivateFrame) { disarm() }
            if ready == false && readinessRequest != true {
                withdrawalPending = false
                withdrawalQueued = false
            }
        }
        .onChange(of: store.match?.stage) { _ in
            showsBlockConfirmation = false
            showsForfeitConfirmation = false
            routeAuthoritativeState()
        }
        .onChange(of: store.account?.consent) { _ in
            if store.account?.consent.accepted != true || store.account?.consent.policyVersion != store.policy?.version { disarm() }
        }
        .onChange(of: store.policy?.version) { _ in
            if store.account?.consent.policyVersion != store.policy?.version { disarm() }
        }
        .onChange(of: store.policy?.ready) { ready in
            if ready != true { disarm() }
        }
        .onChange(of: store.account?.restrictedReason) { reason in
            if reason != nil { disarm() }
        }
        .onChange(of: store.privacyRevision) { _ in
            if store.localProcessingStopped || store.localOwnMediaHidden { disarm() }
        }
        .onChange(of: cloudAccount.accountID) { _ in
            camera.stop(owner: windowID)
            resetLocalState()
        }
        .onDisappear {
            camera.stop(owner: windowID)
            if forwardedState == nil { disarm() }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(preGo || postGo)
        #endif
        #if os(macOS)
        .onExitCommand {
            if preGo { requestCancel() }
            else if postGo { prepareForfeitConfirmation() }
        }
        #endif
    }

    @ViewBuilder
    private var roomStatus: some View {
        if let message = localMessage ?? store.error {
            PhysiqueStatusView(title: "Match update", detail: message)
        }
        if cancellationRequested && postGo {
            PhysiqueStatusView(title: "Match started", detail: "Cancel was not accepted before Go. Nothing has been forfeited by this request. Resume the same match, or choose the separate forfeit action.")
        } else if blockRequested && postGo {
            PhysiqueStatusView(title: blockConfirmed ? "Opponent blocked" : "Block not confirmed", detail: "The opponent is hidden locally. Blocking does not leave an active match. Resume or use the separate forfeit action.")
        } else if let blocker = readinessBlocker, preGo {
            PhysiqueStatusView(title: "Before Ready", detail: blocker, systemImage: "checklist")
            if !controlsWindow {
                PhysiqueAction(title: "Use this window", systemImage: "macwindow") {
                    store.transferControl(to: windowID)
                    startInhibited = true
                    previewAllowed = false
                }
            } else if store.localProcessingStopped || store.localOwnMediaHidden || store.account?.consent.accepted != true || store.account?.consent.policyVersion != store.policy?.version {
                PhysiqueAction(title: "Review consent", systemImage: "checkmark.shield") { openDetails(.consent) }
            }
        }
        if withdrawalPending || cancellationRequested || blockRequested || store.isStale {
            PhysiqueAction(title: "Check match", systemImage: "arrow.clockwise", role: .cancel, disabled: checkingMatch) {
                Task { await checkMatch() }
            }
        }
        if let match, match.stage.terminal {
            PhysiqueStatusView(title: match.stage.title, detail: match.reason ?? "The service has ended this pairing.")
            PhysiqueAction(title: "Return to Physique", systemImage: "arrow.left", role: .cancel) { onOpen(.lobby) }
        }
    }

    private func identityRails(_ match: PhysiqueMatch) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            PhysiqueIdentityRail(identity: match.you.identity, ownerLabel: "You") { _ in openDetails(.badges) }
            if opponentHidden {
                PhysiqueStatusView(title: "Opponent hidden", detail: blockConfirmed ? "Block confirmed." : "Local protection is active. Service protection is not yet confirmed.", systemImage: "hand.raised.fill")
            } else {
                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent") { _ in
                    openDetails(.player(match.opponent.identity.id))
                }
            }
        }
    }

    private var actionDock: some View {
        VStack(spacing: ProfileStyle.spacing) {
            Label(cameraActive ? "Camera active · Local only" : "Camera stopped", systemImage: cameraActive ? "camera.fill" : "camera.slash")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if preGo {
                PhysiqueAction(
                    title: readinessRequest == true ? "Sending Ready" : readinessRequest == false ? "Stopping readiness" : withdrawalPending ? "Confirm not ready" : match?.you.ready == true ? "Not ready" : "Ready",
                    systemImage: readinessRequest == true ? "paperplane" : match?.you.ready == true && !withdrawalPending ? "checkmark.circle.fill" : "circle",
                    disabled: !controlsWindow || readinessRequest != nil || store.busy || (match?.you.ready != true && !withdrawalPending && readinessBlocker != nil)
                ) {
                    Task { await setReadiness(withdrawalPending ? false : match?.you.ready != true) }
                }
                .accessibilityIdentifier("physique-ready")
            } else if postGo {
                PhysiqueAction(title: "Resume match", systemImage: "arrow.right") { resumeAuthoritativeMatch() }
                if cancellationRequested || blockRequested || startInhibited {
                    PhysiqueAction(title: "Forfeit and leave", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, disabled: store.busy) {
                        prepareForfeitConfirmation()
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ProfileStyle.spacing) { cameraAndSafetyActions }
                VStack(spacing: ProfileStyle.spacing) { cameraAndSafetyActions }
            }
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var cameraAndSafetyActions: some View {
        if preGo {
            PhysiqueAction(title: cameraActive ? "Stop camera" : "Resume camera", systemImage: cameraActive ? "camera.slash" : "camera", role: .cancel, disabled: !cameraActive && (!controlsWindow || !presentationActive || cancellationRequested || blockRequested)) {
                if cameraActive { disarm() }
                else { Task { await resumeCamera() } }
            }
        }
        PhysiqueAction(title: "Safety", systemImage: "shield", role: .cancel) { openDetails(.safety) }
    }

    private func observeMatch() async {
        let accountID = cloudAccount.accountID
        if contextAccountID != accountID || (match?.id != nil && contextMatchID != match?.id) {
            resetLocalState()
            contextAccountID = accountID
            contextMatchID = match?.id
        }
        guard presentationActive, accountID != nil else { return }
        await checkMatch()
    }

    private func checkMatch() async {
        guard !checkingMatch else { return }
        let accountID = cloudAccount.accountID
        checkingMatch = true
        await store.refresh()
        guard cloudAccount.accountID == accountID else { return }
        checkingMatch = false
        if !store.isStale && store.error == nil {
            if match?.you.ready == false { withdrawalPending = false; withdrawalQueued = false }
            if cancellationRequested && (match == nil || match?.stage == .cancelled) {
                onOpen(.lobby)
                return
            }
            routeAuthoritativeState()
        }
    }

    private func setReadiness(_ ready: Bool) async {
        guard let match, preGo, controlsWindow, readinessRequest == nil, !store.busy else { return }
        if ready {
            guard readinessBlocker == nil, store.claimControl(for: windowID) else { return }
            startInhibited = false
        } else {
            startInhibited = true
            withdrawalPending = true
            withdrawalQueued = false
        }
        let accountID = cloudAccount.accountID
        let matchID = match.id
        readinessRequest = ready
        let accepted = await store.perform("ready", matchID: matchID, value: ready)
        guard cloudAccount.accountID == accountID, self.match?.id == matchID else { return }
        readinessRequest = nil
        if !accepted {
            localMessage = store.error ?? "Readiness is not confirmed. Check the same match before retrying."
            startInhibited = true
            await checkMatch()
        } else if !ready {
            withdrawalPending = self.match?.you.ready != false && preGo
        }
        if withdrawalQueued { await withdrawReadiness() }
        routeAuthoritativeState()
    }

    private func disarm(stopCamera: Bool = true) {
        startInhibited = true
        if stopCamera {
            previewAllowed = false
            camera.stop(owner: windowID)
        }
        guard preGo, controlsWindow, match?.you.ready == true || readinessRequest == true || match?.stage == .countdown else { return }
        withdrawalPending = true
        withdrawalQueued = true
        if !store.busy && readinessRequest == nil { Task { await withdrawReadiness() } }
    }

    private func withdrawReadiness() async {
        guard withdrawalQueued, !store.busy, readinessRequest == nil, preGo else { return }
        withdrawalQueued = false
        await setReadiness(false)
    }

    private func resumeCamera() async {
        let accountID = cloudAccount.accountID
        let matchID = match?.id
        await checkMatch()
        guard cloudAccount.accountID == accountID, match?.id == matchID, preGo, controlsWindow,
              presentationActive, !cancellationRequested, !blockRequested,
              store.account?.consent.accepted == true, store.account?.consent.policyVersion == store.policy?.version,
              store.account?.restrictedReason == nil, !store.localProcessingStopped, !store.localOwnMediaHidden,
              store.policy?.ready == true, !store.isStale, store.claimControl(for: windowID) else { return }
        previewAllowed = true
        await camera.start(owner: windowID)
    }

    private func openDetails(_ route: PhysiqueRoute) {
        disarm()
        onOpen(route)
    }

    private func requestCancel() {
        guard preGo, !cancelling, let match else { return }
        startInhibited = true
        previewAllowed = false
        camera.stop(owner: windowID)
        cancellationRequested = true
        cancelling = true
        let accountID = cloudAccount.accountID
        let matchID = match.id
        Task {
            let accepted = await store.perform("leave", matchID: matchID, reason: "cancel")
            guard cloudAccount.accountID == accountID else { return }
            cancelling = false
            if accepted && (self.match == nil || self.match?.id == matchID && self.match?.stage == .cancelled) {
                onOpen(.lobby)
            } else {
                localMessage = store.error ?? "Cancellation is not confirmed. Check the current match."
                await checkMatch()
            }
        }
    }

    private func prepareBlockConfirmation() {
        guard let match else { return }
        disarm()
        blockConfirmationMatchID = match.id
        blockConfirmationWasPreGo = preGo
        showsBlockConfirmation = true
    }

    private func blockOpponent() async {
        guard let match, match.id == blockConfirmationMatchID, preGo == blockConfirmationWasPreGo else {
            localMessage = "The match stage changed. Review the current block consequences before confirming again."
            return
        }
        disarm()
        blockRequested = true
        blocking = true
        let accountID = cloudAccount.accountID
        let accepted = await store.perform("block", matchID: match.id, targetID: match.opponent.identity.id)
        guard cloudAccount.accountID == accountID else { return }
        blocking = false
        blockConfirmed = accepted
        if accepted && self.match?.id == match.id && self.match?.stage == .cancelled {
            onOpen(.lobby)
        } else {
            localMessage = accepted ? "Block confirmed. Blocking does not leave an already started match." : store.error ?? "Block not confirmed. Local protection remains active."
            await checkMatch()
        }
    }

    private func prepareForfeitConfirmation() {
        guard postGo, let match else { return }
        disarm()
        forfeitConfirmationMatchID = match.id
        showsForfeitConfirmation = true
    }

    private func forfeitMatch() async {
        guard postGo, let match, match.id == forfeitConfirmationMatchID else { return }
        let accountID = cloudAccount.accountID
        let accepted = await store.perform("leave", matchID: match.id, reason: "forfeit")
        guard cloudAccount.accountID == accountID else { return }
        if accepted { routeAuthoritativeState(allowInterrupted: true) }
        else { localMessage = store.error ?? "Leaving is not confirmed. Check the current match." }
    }

    private func resumeAuthoritativeMatch() {
        guard !store.isStale, presentationActive, controlsWindow else {
            Task { await checkMatch() }
            return
        }
        routeAuthoritativeState(allowInterrupted: true)
    }

    private func routeAuthoritativeState(allowInterrupted: Bool = false) {
        guard let match, !store.isStale, !checkingMatch, presentationActive else { return }
        let route: PhysiqueRoute
        switch match.stage {
        case .capture:
            guard controlsWindow, allowInterrupted || !startInhibited && !cancellationRequested && !blockRequested else { return }
            route = .battle
        case .submitting, .judging:
            guard allowInterrupted || !cancellationRequested && !blockRequested else { return }
            route = .judging
        case .completed, .forfeited, .noContest:
            route = .result(match.id)
        default:
            return
        }
        let key = "\(match.id):\(match.stage.rawValue)"
        guard forwardedState != key else { return }
        forwardedState = key
        onOpen(route)
    }

    private func resetLocalState() {
        checkingMatch = false
        readinessRequest = nil
        withdrawalPending = false
        withdrawalQueued = false
        startInhibited = false
        previewAllowed = true
        cancellationRequested = false
        cancelling = false
        blockRequested = false
        blocking = false
        blockConfirmed = false
        showsBlockConfirmation = false
        showsForfeitConfirmation = false
        localMessage = nil
        forwardedState = nil
    }
}
