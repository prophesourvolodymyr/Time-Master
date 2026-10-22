import SwiftUI

@MainActor
struct PhysiqueJudgingView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var stageFocused: Bool
    @State private var ownerID: String?
    @State private var matchID: String?
    @State private var recoveredMatch: PhysiqueMatch?
    @State private var recoveryError: String?
    @State private var commandError: String?
    @State private var detailsExpanded = false
    @State private var selectedBadge: PhysiqueBadge?
    @State private var showingReturnConfirmation = false
    @State private var showingForfeitConfirmation = false
    @State private var submitting = false
    @State private var leaving = false
    @State private var visible = false
    @State private var accountChanged = false
    @State private var routedState: String?

    private var active: Bool {
        visible && presentationActive && scenePhase == .active
    }

    private var authorized: Bool {
        !accountChanged && store.signedIn && ownerID != nil && ownerID == accountStore.accountID
    }

    private var currentMatch: PhysiqueMatch? {
        guard authorized, let matchID, let publicID = store.account?.identity.id else { return nil }
        if let match = store.match, match.id == matchID, match.you.identity.id == publicID {
            return match
        }
        guard let recoveredMatch, recoveredMatch.id == matchID,
              recoveredMatch.you.identity.id == publicID else { return nil }
        return recoveredMatch
    }

    private var observationID: String {
        "\(ownerID ?? "")|\(matchID ?? "")|\(store.match?.id ?? "")|\(active)"
    }

    private var arenaMotionAllowed: Bool {
        guard active, authorized, !store.isStale, !store.loading,
              recoveryError == nil, commandError == nil, !leaving,
              !showingReturnConfirmation, !showingForfeitConfirmation,
              selectedBadge == nil, let match = currentMatch,
              let deadline = match.stage == .judging ? match.judgingDeadline : match.deadline,
              deadline.isFinite, store.serverOffset.isFinite else { return false }
        return deadline > Date().timeIntervalSince1970 + store.serverOffset
    }

    var body: some View {
        ZStack {
            PhysiqueBattleBackground(
                stage: currentMatch?.stage ?? .idle,
                cameraActive: false,
                motionAllowed: arenaMotionAllowed
            )
            if let match = currentMatch {
                matchContent(match)
            } else {
                unavailableContent
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.toolbarOrange)
        .navigationTitle("Physique Duels")
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(currentMatch?.stage.terminal == false)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            navigationActions
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        detailsExpanded.toggle()
                    } label: {
                        Label(detailsExpanded ? "Hide details" : "Show details", systemImage: "info.circle")
                    }
                    Button {
                        open(.privacy)
                    } label: {
                        Label("Privacy and sharing", systemImage: "hand.raised")
                    }
                    if let match = currentMatch, canRequestForfeit(match) {
                        Button(role: .destructive) {
                            showingForfeitConfirmation = true
                        } label: {
                            Label("Forfeit and leave", systemImage: "flag")
                        }
                    }
                } label: {
                    Label("Match options", systemImage: "ellipsis.circle")
                }
                .help("Match details, privacy and competitive exit")
            }
        }
        .alert("Return to Physique?", isPresented: $showingReturnConfirmation) {
            Button("Stay", role: .cancel) { }
            Button("Return to Physique") { open(.lobby) }
        } message: {
            Text(returnExplanation)
        }
        .confirmationDialog("Forfeit and leave?", isPresented: $showingForfeitConfirmation, titleVisibility: .visible) {
            Button("Keep waiting", role: .cancel) { }
            Button("Forfeit and leave", role: .destructive) {
                Task { await requestForfeit() }
            }
        } message: {
            Text("If this match is still eligible, an accepted forfeit loses this match, can change your Physique Elo and uses the started-match slot. The service confirms the actual outcome; an existing final result or safety decision takes precedence.")
        }
        .alert(selectedBadge?.title ?? "Badge", isPresented: Binding(
            get: { selectedBadge != nil },
            set: { if !$0 { selectedBadge = nil } }
        )) {
            Button("Done", role: .cancel) { selectedBadge = nil }
        } message: {
            Text(selectedBadge?.detail ?? "")
        }
        .onAppear {
            visible = true
            if ownerID == nil && !accountChanged {
                ownerID = accountStore.accountID
                matchID = store.match?.id
            }
            if store.canControl(from: windowID) || store.match?.stage == .submitting || store.match?.stage == .judging {
                store.suspendCapture()
            }
            stageFocused = true
            routeConfirmedState()
        }
        .onDisappear {
            visible = false
            if store.canControl(from: windowID) { store.suspendCapture() }
            recoveredMatch = nil
        }
        .onChange(of: accountStore.accountID) { _ in
            accountChanged = true
            ownerID = nil
            matchID = nil
            recoveredMatch = nil
            recoveryError = nil
            commandError = nil
            selectedBadge = nil
            showingReturnConfirmation = false
            showingForfeitConfirmation = false
            store.suspendCapture()
        }
        .onChange(of: store.match?.stage) { _ in routeConfirmedState() }
        .onChange(of: store.match?.finalizedAt) { _ in routeConfirmedState() }
        .onChange(of: store.match?.you.submitted) { submitted in
            if submitted == true, store.match?.id == matchID { commandError = nil }
        }
        .onChange(of: store.privacyRevision) { _ in
            selectedBadge = nil
            showingForfeitConfirmation = false
        }
        .onChange(of: showingReturnConfirmation) { showing in
            if !showing { routeConfirmedState() }
        }
        .onChange(of: showingForfeitConfirmation) { showing in
            if !showing { routeConfirmedState() }
        }
        .onChange(of: selectedBadge) { badge in
            if badge == nil { routeConfirmedState() }
        }
        .task(id: observationID) {
            guard active, authorized else { return }
            await refreshStatus()
        }
        #if os(macOS)
        .onExitCommand {
            if selectedBadge != nil {
                selectedBadge = nil
            } else if detailsExpanded {
                detailsExpanded = false
            } else {
                requestReturn()
            }
        }
        #endif
    }

    private func matchContent(_ match: PhysiqueMatch) -> some View {
        VStack(spacing: 0) {
            statusHeader(match)
            ScrollView {
                VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
                    if let message = recoveryError ?? commandError ?? store.error {
                        PhysiqueStatusView(
                            title: "Request not confirmed",
                            detail: message,
                            systemImage: "wifi.exclamationmark"
                        )
                    }
                    if !store.canControl(from: windowID) {
                        PhysiqueCard {
                            Label("Open in another window", systemImage: "macwindow.on.rectangle")
                                .font(TimeMasterFont.sectionTitle())
                            Text("You can follow this match here. Match-changing actions belong to the controlling window; Safety, Privacy and Return remain available.")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                            PhysiqueAction(title: "Control match in this window", systemImage: "macwindow") {
                                store.transferControl(to: windowID)
                            }
                        }
                    }
                    identityRails(match)
                    PhysiquePlayerPanel(title: "You", status: ownFooter(match)) {
                        PhysiqueAthleteIllustration(pose: .front, isOpponent: false)
                            .accessibilityHidden(true)
                    }
                    PhysiquePlayerPanel(title: "Opponent", status: opponentFooter(match)) {
                        if opponentHidden(match) {
                            Image(systemName: "person.crop.rectangle.badge.xmark")
                                .font(.largeTitle)
                                .foregroundStyle(ProfileStyle.secondary)
                                .accessibilityLabel("Opponent protected")
                        } else {
                            PhysiqueAthleteIllustration(pose: .front, isOpponent: true)
                                .accessibilityHidden(true)
                        }
                    }
                    matchDetails(match)
                }
                .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func statusHeader(_ match: PhysiqueMatch) -> some View {
        TimelineView(.animation(minimumInterval: 1, paused: !active)) { context in
            let now = context.date.timeIntervalSince1970 + store.serverOffset
            let status = waitingStatus(match, now: now)
            VStack(spacing: ProfileStyle.spacing) {
                PhysiqueTimerView(clock: clock(match, now: now))
                HStack(alignment: .firstTextBaseline, spacing: ProfileStyle.spacing) {
                    if status.working && active && !reduceMotion {
                        ProgressView().controlSize(.small).accessibilityHidden(true)
                    } else {
                        Image(systemName: status.symbol)
                            .foregroundStyle(Theme.toolbarOrange)
                            .accessibilityHidden(true)
                    }
                    Text(status.title)
                        .font(TimeMasterFont.heading())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($stageFocused)
                }
                Text(status.detail)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let origin = match.judgingStartedAt, origin.isFinite, origin <= now,
                   match.stage == .judging, !store.isStale, match.judgingDeadline.map({ now < $0 }) == true {
                    Text("Elapsed time is not a finish estimate.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                primaryAction(match)
            }
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.bottom, ProfileStyle.spacing)
            .frame(maxWidth: ProfileStyle.readableWidth)
            .frame(maxWidth: .infinity)
            .background(Theme.background)
        }
    }

    @ViewBuilder
    private func identityRails(_ match: PhysiqueMatch) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
            if store.isStale {
                Text("Identities and badges: last confirmed snapshot.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            PhysiqueIdentityRail(identity: match.you.identity, ownerLabel: "You") { selectedBadge = $0 }
            if opponentHidden(match) {
                PhysiqueStatusView(
                    title: "Opponent hidden",
                    detail: "Your safety settings protect this identity. The service still owns this match's outcome.",
                    systemImage: "person.crop.circle.badge.xmark"
                )
            } else {
                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent") { selectedBadge = $0 }
            }
        }
    }

    @ViewBuilder
    private func primaryAction(_ match: PhysiqueMatch) -> some View {
        if match.stage.terminal && match.result != nil && match.finalizedAt != nil {
            PhysiqueAction(title: "View result", systemImage: "checkmark.seal") {
                open(.result(match.id))
            }
        } else if recoveryError != nil || commandError != nil || store.error != nil || store.isStale {
            PhysiqueAction(title: "Retry status", systemImage: "arrow.clockwise", disabled: store.loading) {
                Task { await refreshStatus() }
            }
        } else if canSubmit(match) {
            PhysiqueAction(title: "Submit poses", systemImage: "paperplane", disabled: store.busy || submitting) {
                Task { await submitPoses() }
            }
        }
    }

    private func matchDetails(_ match: PhysiqueMatch) -> some View {
        DisclosureGroup(isExpanded: $detailsExpanded) {
            VStack(alignment: .leading, spacing: ProfileStyle.inset) {
                Text("Selected means a chosen version. Received means the service acknowledged it. Accepted means its checks passed; it is not a score.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                if selectedCount(match) == nil {
                    Text("Local selections are not confirmed for this match. Only current service receipts are shown; a selection from another device or match is never substituted.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                ForEach(PhysiquePose.allCases) { pose in
                    poseDetail(pose, match: match)
                }
                Text("Last confirmed stage: \(match.stage.title).")
                if let refreshedAt = store.lastRefreshedAt {
                    Text("Status refreshed \(refreshedAt.formatted(date: .abbreviated, time: .standard)).")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                if let deadline = match.deadline, deadline.isFinite {
                    Text("Original capture closes \(Date(timeIntervalSince1970: deadline).formatted(date: .omitted, time: .standard)).")
                }
                if let deadline = match.judgingDeadline, deadline.isFinite {
                    Text("Service decision limit: \(Date(timeIntervalSince1970: deadline).formatted(date: .omitted, time: .standard)). This is a rule, not an estimated finish time.")
                }
                Text("At a deadline, only a confirmed service record can establish a result. Retry status retrieves this same match; it does not request another judgement.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("Your camera is off. The illustrations are not camera feeds. No opponent pose is shown while waiting. Exercise images keep their separate on-device privacy promise.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("This match continues after Return to Physique when no client work remains. Open the pending match from Physique, or its exact record in History.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("Match reference: \(match.id)")
                    .font(TimeMasterFont.technical())
                    .textSelection(.enabled)
                PhysiqueAction(title: "Retry status", systemImage: "arrow.clockwise", disabled: store.loading) {
                    Task { await refreshStatus() }
                }
                if !opponentHidden(match) {
                    PhysiqueAction(title: "Report this opponent", systemImage: "flag", role: .cancel) {
                        open(.report(PhysiqueReportTarget(kind: "player", id: match.opponent.identity.id, matchID: match.id)))
                    }
                }
                PhysiqueAction(title: "Privacy and sharing", systemImage: "hand.raised", role: .cancel) {
                    open(.privacy)
                }
                if canRequestForfeit(match) {
                    PhysiqueAction(title: "Forfeit and leave", systemImage: "flag", role: .destructive, disabled: store.busy || leaving) {
                        showingForfeitConfirmation = true
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, ProfileStyle.spacing)
        } label: {
            Label("Match details", systemImage: "info.circle")
                .font(TimeMasterFont.sectionTitle())
        }
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }

    private func poseDetail(_ pose: PhysiquePose, match: PhysiqueMatch) -> some View {
        let evidence = match.evidence.first { $0.pose == pose }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                PhysiquePoseIcon(pose: pose, accepted: evidence?.status == "accepted")
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pose.title).font(TimeMasterFont.rowTitle())
                    Text(poseStatus(evidence))
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
            if let evidence {
                if let reason = evidence.reason, !reason.isEmpty {
                    Text(reason).font(TimeMasterFont.secondary())
                }
                Text("\(evidence.retakes.formatted()) of 2 retakes used. Retakes never restart capture time.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var navigationActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ProfileStyle.spacing) {
                returnButton
                safetyButton
            }
            VStack(spacing: ProfileStyle.spacing) {
                returnButton
                safetyButton
            }
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private var returnButton: some View {
        PhysiqueAction(title: "Return to Physique", systemImage: "arrow.uturn.backward", role: .cancel) {
            requestReturn()
        }
    }

    private var safetyButton: some View {
        PhysiqueAction(title: "Safety", systemImage: "shield", role: .cancel) {
            open(.safety)
        }
    }

    private var unavailableContent: some View {
        PhysiqueScreen(title: "Match status") {
            if !store.signedIn || accountChanged {
                PhysiqueStatusView(
                    title: accountChanged ? "Account changed" : "Sign in to restore this match",
                    detail: "Private match information is unavailable here. Return to Physique to restore only the current account's authorized record.",
                    systemImage: "lock"
                )
                if !store.signedIn {
                    PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { open(.account) }
                }
            } else {
                PhysiqueStatusView(
                    title: store.loading ? "Restoring match" : "Match not confirmed",
                    detail: recoveryError ?? store.error ?? "No authorized match is available in the current state. Retry the same record or open History; no result has been assumed.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                PhysiqueAction(title: "Retry status", systemImage: "arrow.clockwise", disabled: store.loading) {
                    Task { await refreshStatus() }
                }
                PhysiqueAction(title: "Open history", systemImage: "clock", role: .cancel) { open(.history) }
            }
        }
    }

    private func selectedCount(_ match: PhysiqueMatch) -> Int? {
        for pose in PhysiquePose.allCases {
            guard let evidence = match.evidence.first(where: { $0.pose == pose }) else { return nil }
            switch evidence.status {
            case "checking", "accepted", "rejected": break
            default: return nil
            }
        }
        return PhysiquePose.allCases.count
    }

    private func receivedCount(_ match: PhysiqueMatch) -> Int {
        PhysiquePose.allCases.reduce(0) { count, pose in
            count + (match.evidence.contains(where: { $0.pose == pose }) ? 1 : 0)
        }
    }

    private func ownFooter(_ match: PhysiqueMatch) -> String {
        let selected = selectedCount(match).map { "\($0)/3" } ?? "—/3 · Not confirmed"
        let suffix = store.isStale ? "\nLast confirmed service counts" : ""
        return "Camera off · Illustration\nSelected \(selected)\nReceived \(receivedCount(match))/3\nAccepted \(match.you.acceptedCount)/3\(suffix)"
    }

    private func opponentFooter(_ match: PhysiqueMatch) -> String {
        guard !opponentHidden(match) else { return "Opponent hidden\nAccepted —/3 · Not confirmed\nIllustration, not a camera feed" }
        let stage: String
        if match.stage == .judging {
            stage = "Paired judging"
        } else if match.opponent.submitted {
            stage = "Set submitted"
        } else {
            stage = "Not yet submitted"
        }
        let freshness = store.isStale ? "\nLast confirmed public status" : ""
        return "\(stage)\nAccepted \(match.opponent.acceptedCount)/3\nIllustration, not a camera feed\(freshness)"
    }

    private func poseStatus(_ evidence: PhysiqueEvidence?) -> String {
        guard let evidence else { return "Receipt not confirmed" }
        switch evidence.status {
        case "checking": return "Received · Checks pending"
        case "accepted": return "Received · Accepted"
        case "rejected": return "Received · Not accepted"
        case "removed": return "Removed"
        case "expired": return "Expired"
        default: return "Status not confirmed"
        }
    }

    private func clock(_ match: PhysiqueMatch, now: Double) -> PhysiqueClock {
        if match.stage.terminal {
            return PhysiqueClock(mode: .ended, label: "Match ended", endpoint: nil, serverOffset: store.serverOffset)
        }
        guard !store.isStale, store.lastRefreshedAt != nil, store.serverOffset.isFinite else {
            return PhysiqueClock(mode: .unavailable, label: "Time not confirmed", endpoint: nil, serverOffset: store.serverOffset)
        }
        if let deadline = match.judgingDeadline, deadline.isFinite, now >= deadline {
            return PhysiqueClock(mode: .unavailable, label: "Awaiting confirmed outcome", endpoint: nil, serverOffset: store.serverOffset)
        }
        if let origin = match.judgingStartedAt, origin.isFinite, origin <= now {
            return PhysiqueClock(mode: .elapsed, label: match.stage == .judging ? "Judging elapsed" : "Processing elapsed", endpoint: origin, serverOffset: store.serverOffset)
        }
        if let deadline = match.deadline, deadline.isFinite {
            return PhysiqueClock(mode: .remaining, label: now < deadline ? "Capture closes" : "Awaiting confirmed outcome", endpoint: deadline, serverOffset: store.serverOffset)
        }
        return PhysiqueClock(mode: .unavailable, label: "Time not confirmed", endpoint: nil, serverOffset: store.serverOffset)
    }

    private func waitingStatus(_ match: PhysiqueMatch, now: Double) -> (title: String, detail: String, symbol: String, working: Bool) {
        if match.stage.terminal {
            return (match.result == nil ? "Awaiting confirmed outcome" : "Result available", "Only the service's finalized record determines this match.", "checkmark.seal", false)
        }
        if store.localProcessingStopped {
            return ("Processing stopped on this device", "New capture and transfer are stopped. Remote work already accepted may continue until the service confirms otherwise.", "hand.raised", false)
        }
        if store.account?.consent.aiProcessing == false {
            return ("Processing withdrawn", "New capture and transfer are stopped. Awaiting this match's confirmed status.", "hand.raised", false)
        }
        if store.isStale || recoveryError != nil || commandError != nil || store.error != nil {
            return ("Result not confirmed", "Last confirmed stage: \(match.stage.title). Retry status for this same match.", "wifi.exclamationmark", false)
        }
        let deadline = match.judgingDeadline ?? match.deadline
        if let deadline, deadline.isFinite, now >= deadline {
            return ("Awaiting confirmed outcome", "The service deadline has passed; no outcome has been assumed.", "clock.badge.questionmark", false)
        }
        if match.stage == .judging {
            let slow = match.judgingStartedAt.map { $0.isFinite && now - $0 >= 5 } ?? false
            return ("Judging physiques", slow ? "Still judging. Your camera is off." : "Your camera is off. You can relax.", "hourglass", true)
        }
        if submitting {
            return ("Submitting poses", "Waiting for acknowledgement of this exact match and set.", "paperplane", true)
        }
        if !match.you.submitted {
            if canSubmit(match) {
                return ("Ready to submit", "Three poses are accepted. Submit deliberately to lock this set.", "paperplane", false)
            }
            return ("Submission not confirmed", "Received \(receivedCount(match))/3. Refresh status before resuming capture.", "arrow.up.doc", false)
        }
        if match.evidence.contains(where: { $0.status == "rejected" || $0.status == "removed" || $0.status == "expired" }) {
            return ("Set could not be accepted", "Your camera is off. Awaiting the service's confirmed outcome.", "exclamationmark.shield", false)
        }
        if match.you.acceptedCount < 3 {
            return ("Checking poses", "Accepted \(match.you.acceptedCount)/3. Receipt is not acceptance.", "checkmark.shield", true)
        }
        if !match.opponent.submitted {
            return ("Waiting for opponent", "Your set is ready. Your camera is off.", "person.crop.rectangle", true)
        }
        return ("Checking pose sets", "Both sets are submitted. Paired judging is not yet confirmed.", "checkmark.shield", true)
    }

    private func opponentHidden(_ match: PhysiqueMatch) -> Bool {
        store.locallyBlockedIDs.contains(match.opponent.identity.id)
    }

    private func canSubmit(_ match: PhysiqueMatch) -> Bool {
        guard authorized, active, !store.isStale, !store.localProcessingStopped, store.canControl(from: windowID),
              store.account?.consent.accepted == true, store.policy?.ready == true,
              match.stage == .submitting, !match.you.submitted, match.you.acceptedCount == 3,
              selectedCount(match) == 3, let deadline = match.deadline, deadline.isFinite else { return false }
        return Date().timeIntervalSince1970 + store.serverOffset < deadline
    }

    private func canRequestForfeit(_ match: PhysiqueMatch) -> Bool {
        let now = Date().timeIntervalSince1970 + store.serverOffset
        guard authorized, active, !store.isStale, !store.localProcessingStopped, store.canControl(from: windowID),
              store.policy?.ready == true, store.account?.restrictedReason == nil,
              store.account?.consent.aiProcessing == true,
              match.stage == .submitting || match.stage == .judging,
              let start = match.startAt, start.isFinite, start <= now,
              let deadline = match.judgingDeadline ?? match.deadline, deadline.isFinite, now < deadline else { return false }
        return !match.evidence.contains { $0.status == "rejected" || $0.status == "removed" || $0.status == "expired" }
    }

    private var returnExplanation: String {
        let opportunity: String
        if let deadline = currentMatch?.deadline, deadline.isFinite {
            opportunity = "The original capture closes at \(Date(timeIntervalSince1970: deadline).formatted(date: .omitted, time: .standard))."
        } else {
            opportunity = "The remaining capture opportunity is not confirmed."
        }
        return "Sending or receipt reconciliation may pause when this client cannot continue. \(opportunity) Resuming does not restart that deadline. Return is navigation, not a forfeit; open the same pending match from Physique."
    }

    private func requestReturn() {
        guard let match = currentMatch, !match.stage.terminal else { open(.lobby); return }
        if !match.you.submitted || submitting {
            showingReturnConfirmation = true
        } else {
            open(.lobby)
        }
    }

    private func open(_ route: PhysiqueRoute) {
        visible = false
        store.suspendCapture()
        onOpen(route)
    }

    private func refreshStatus() async {
        guard authorized, !store.loading else { return }
        let expectedOwner = ownerID
        let expectedMatch = matchID
        await store.refresh()
        guard !Task.isCancelled, expectedOwner == accountStore.accountID, authorized else { return }
        if matchID == nil { matchID = store.match?.id }
        if let expectedMatch, store.match?.id != expectedMatch {
            do {
                let restored = try await store.getMatch(expectedMatch)
                guard !Task.isCancelled, expectedOwner == accountStore.accountID, authorized else { return }
                recoveredMatch = restored
                recoveryError = nil
            } catch is CancellationError {
                return
            } catch {
                guard expectedOwner == accountStore.accountID, authorized else { return }
                recoveredMatch = nil
                recoveryError = error.localizedDescription
            }
        } else if !store.isStale && store.error == nil {
            recoveryError = nil
            commandError = nil
        }
        if recoveredMatch?.stage.terminal == true { commandError = nil }
        routeConfirmedState()
    }

    private func routeConfirmedState() {
        guard active, !showingReturnConfirmation, !showingForfeitConfirmation, selectedBadge == nil,
              let match = currentMatch else { return }
        let route: PhysiqueRoute
        let state: String
        if match.stage.terminal {
            guard match.finalizedAt != nil, match.result != nil else {
                if match.stage == .cancelled || match.stage == .noOpponent {
                    open(.lobby)
                }
                return
            }
            route = .result(match.id)
            state = "result:\(match.id)"
        } else {
            guard !store.isStale else { return }
            switch match.stage {
            case .capture:
                if let rejected = match.evidence.first(where: { $0.status == "rejected" && $0.retakes < 2 }),
                   let deadline = match.deadline, Date().timeIntervalSince1970 + store.serverOffset < deadline {
                    route = .poseReview(rejected.pose)
                    state = "review:\(match.id):\(rejected.pose.rawValue)"
                } else {
                    route = .battle
                    state = "battle:\(match.id)"
                }
            case .ready, .countdown:
                route = .ready
                state = "ready:\(match.id)"
            case .searching:
                route = .search
                state = "search:\(match.id)"
            default:
                return
            }
        }
        guard routedState != state else { return }
        routedState = state
        open(route)
    }

    private func submitPoses() async {
        guard let match = currentMatch, canSubmit(match), !store.busy, !submitting else { return }
        let expectedOwner = ownerID
        submitting = true
        commandError = nil
        defer { submitting = false }
        let accepted = await store.perform("submit", matchID: match.id)
        guard expectedOwner == accountStore.accountID, authorized else { return }
        if !accepted { commandError = store.error ?? "Submission not confirmed. Retry status before sending this same set again." }
        routeConfirmedState()
    }

    private func requestForfeit() async {
        guard let match = currentMatch, canRequestForfeit(match), !store.busy, !leaving else {
            routeConfirmedState()
            return
        }
        let expectedOwner = ownerID
        leaving = true
        commandError = nil
        defer { leaving = false }
        let accepted = await store.perform("leave", matchID: match.id, reason: "forfeit")
        guard expectedOwner == accountStore.accountID, authorized else { return }
        if !accepted { commandError = store.error ?? "Departure not confirmed. Return remains available without requesting a forfeit." }
        routeConfirmedState()
    }
}
