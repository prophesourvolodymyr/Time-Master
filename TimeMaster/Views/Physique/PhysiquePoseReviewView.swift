import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiquePoseReviewView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let pose: PhysiquePose

    @ObservedObject private var camera = PhysiqueCamera.shared
    @ObservedObject private var accounts = CloudAccountStore.shared
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var summaryFocused: Bool
    @State private var inspectedPose: PhysiquePose
    @State private var reviewAccountID: String?
    @State private var reviewMatchID: String?
    @State private var reviewCaptureOwnerID: UUID?
    @State private var restored = false
    @State private var deadlineReached = false
    @State private var previewBytes: Data?
    @State private var previewImage: Image?
    @State private var sending = false
    @State private var transferUnconfirmed = false
    @State private var transferTask: Task<Void, Never>?
    @State private var preserveSelectionOnHandoff = false
    @State private var showsExitConfirmation = false
    @State private var badgeDetail: PhysiqueBadge?
    @State private var localError: String?
    @State private var knownEvidenceStates: [PhysiquePose: EvidenceStatus] = [:]

    init(store: PhysiqueStore, onOpen: @escaping (PhysiqueRoute) -> Void, pose: PhysiquePose) {
        self.store = store
        self.onOpen = onOpen
        self.pose = pose
        _inspectedPose = State(initialValue: pose)
    }

    private var evidence: PhysiqueEvidence? {
        store.match?.evidence.first { $0.pose == inspectedPose }
    }

    private var hasCandidate: Bool {
        camera.candidatePose == inspectedPose && camera.candidate != nil
    }

    private var sourceBytes: Data? {
        if camera.candidatePose == inspectedPose { return camera.candidate }
        return camera.selected[inspectedPose]
    }

    private var hasCurrentSelectedImage: Bool {
        guard let evidence else { return false }
        return !store.localOwnMediaHidden && camera.selectedEvidenceIDs[inspectedPose] == evidence.id
            && evidence.status != "removed" && evidence.status != "expired"
    }

    private var currentPolicy: PhysiquePolicy? { store.snapshot?.policy ?? store.policy }

    private var processingAuthorized: Bool {
        guard let account = store.account, let policy = currentPolicy else { return false }
        let consent = account.consent
        return consent.adult && consent.rulesAccepted && consent.aiProcessing
            && consent.policyVersion == policy.version && account.restrictedReason == nil
            && !store.localProcessingStopped
    }

    private var deadlineOpen: Bool {
        guard let deadline = store.match?.deadline, deadline.isFinite else { return false }
        return !deadlineReached && deadline > Date().timeIntervalSince1970 + store.serverOffset
    }

    private var mediaAuthorized: Bool {
        restored && !store.isStale && accounts.accountID != nil && accounts.accountID == reviewAccountID
            && store.match?.id == reviewMatchID && store.stage == .capture
            && processingAuthorized && deadlineOpen && presentationActive && scenePhase == .active
            && store.canControl(from: windowID) && camera.ownerID == reviewCaptureOwnerID
            && (camera.ownerID == windowID || (camera.ownerID == nil && !hasCandidate))
    }

    private var mayShowImage: Bool {
        mediaAuthorized && (hasCandidate || hasCurrentSelectedImage)
            && previewBytes == sourceBytes && previewImage != nil
    }

    private var mayEdit: Bool {
        mediaAuthorized && !store.isStale && !store.loading && !store.busy
            && !sending && store.match?.you.submitted == false
    }

    private var maySend: Bool {
        guard mayEdit, hasCandidate, mayShowImage, let policy = currentPolicy,
              policy.ready, !policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !policy.processor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let evidence else { return true }
        return (0..<2).contains(evidence.retakes) || transferUnconfirmed
    }

    private var mayRetake: Bool {
        guard mayEdit, camera.candidate == nil, !transferUnconfirmed, let evidence else { return false }
        return evidence.retakes >= 0 && evidence.retakes < 2
    }

    private var retakeLabel: String {
        guard !store.isStale, let evidence, (0...2).contains(evidence.retakes) else { return "Retakes unconfirmed" }
        if hasCandidate { return "Retakes pending confirmation" }
        let remaining = max(0, 2 - evidence.retakes)
        return remaining == 0 ? "No retakes left" : "\(remaining) retake\(remaining == 1 ? "" : "s") left"
    }

    private var statusTitle: String {
        if !mediaAuthorized { return unavailableTitle }
        if sending { return "Sending pose" }
        if hasCandidate { return transferUnconfirmed ? "Transfer not confirmed" : "Selected · Not sent" }
        if store.localOwnMediaHidden { return "Stored preview hidden" }
        guard let evidence else { return "No selected pose" }
        guard hasCurrentSelectedImage else { return "Local preview unconfirmed" }
        switch evidence.status {
        case "accepted": return "Accepted"
        case "checking": return "Checking"
        case "rejected": return "Needs retake"
        case "removed": return "Image removed"
        case "expired": return "Image expired"
        default: return "Status unconfirmed"
        }
    }

    private var statusSymbol: String {
        if !mediaAuthorized { return "lock.fill" }
        if sending || (!hasCandidate && evidence?.status == "checking") { return "arrow.up.circle" }
        if hasCandidate { return transferUnconfirmed ? "exclamationmark.arrow.triangle.2.circlepath" : "photo.badge.checkmark" }
        if store.localOwnMediaHidden && !hasCandidate { return "hand.raised.fill" }
        if !hasCurrentSelectedImage { return "questionmark.circle" }
        return evidence?.status == "accepted" ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.camera"
    }

    private var statusDetail: String {
        if !mediaAuthorized { return unavailableDetail }
        if sending { return "Sending only this exact masked still. A transfer receipt is not pose acceptance." }
        if hasCandidate && transferUnconfirmed { return "The service receipt is unconfirmed. Retry this same still; do not acquire another replacement until it is reconciled." }
        if hasCandidate { return "Inspect the mask and full pose before choosing Use pose. This selection has not been accepted." }
        if store.localOwnMediaHidden { return "Previously shared images are hidden on this device. A fresh local capture can be reviewed only under the current, separately authorized processing choice." }
        guard let evidence else { return "Return to the match guide to capture this named pose." }
        guard hasCurrentSelectedImage else { return "The service reports \(serviceStatus(evidence.status)), but this device cannot yet verify that its local still is the same candidate. No old image is substituted." }
        switch evidence.status {
        case "accepted": return "This current candidate passed the service checks. It is not a score, identity verification, or a submitted pose set."
        case "checking": return "The service is checking this current candidate. There is no body score or predicted finish time."
        case "rejected": return evidence.reason ?? "This pose needs a permitted retake before the original capture deadline."
        case "removed": return "This image is no longer available for review."
        case "expired": return "This image is no longer available."
        default: return "Refresh the same match to confirm its current evidence state."
        }
    }

    private var unavailableTitle: String {
        if accounts.accountID == nil { return "Sign in to review" }
        if !presentationActive || scenePhase != .active { return "Private review hidden" }
        if store.match == nil || store.match?.id != reviewMatchID { return "Review unavailable" }
        if store.stage != .capture { return "Capture closed" }
        if evidence?.status == "removed" { return "Image removed" }
        if evidence?.status == "expired" { return "Image expired" }
        if !processingAuthorized { return "Processing permission unavailable" }
        if store.isStale { return "Restore match status" }
        if store.match?.deadline?.isFinite != true { return "Capture time unavailable" }
        if !deadlineOpen { return "Capture ended" }
        if !store.canControl(from: windowID) || (camera.ownerID != nil && camera.ownerID != windowID) { return "Review is controlled in another window" }
        return "Private preview unavailable"
    }

    private var unavailableDetail: String {
        if accounts.accountID == nil { return "Use your existing Tmax account. No previous account's still is displayed." }
        if !presentationActive || scenePhase != .active { return "Camera acquisition and private presentation are stopped. Return and restore the same match before continuing." }
        if store.match == nil || store.match?.id != reviewMatchID { return "Restore the current match to confirm authorized evidence and timing." }
        if store.stage != .capture { return "The service reports \(store.stage.title). Review cannot reopen or change this pose set." }
        if evidence?.status == "removed" { return "This image is no longer available for review. No cached or earlier attempt is shown." }
        if evidence?.status == "expired" { return "This image has expired. A cached copy cannot reopen it." }
        if !processingAuthorized { return "New capture and image transfer are stopped. Review your current Privacy and sharing choices." }
        if store.isStale { return "The connection could not be refreshed. Private review remains paused until the same match is reconciled." }
        if store.match?.deadline?.isFinite != true { return "The service has not confirmed a usable capture deadline. No capture, replacement, or transfer can begin." }
        if !deadlineOpen { return "No more capture, replacement, or transfer can begin. The service must confirm what happens to this match." }
        if !store.canControl(from: windowID) || (camera.ownerID != nil && camera.ownerID != windowID) { return "The other window's private candidate is not shown here. Return to the match to deliberately transfer control." }
        return "The camera was stopped or the local still was cleared. Restore the match state; no original or earlier attempt is used as a fallback."
    }

    private var clock: PhysiqueClock {
        let usableDeadline = store.match?.deadline?.isFinite == true
        return PhysiqueClock(
            mode: store.stage == .capture ? (usableDeadline ? (deadlineOpen ? .remaining : .ended) : .unavailable) : .ended,
            label: store.stage == .capture ? (usableDeadline ? "Capture time left" : "Capture time unavailable") : "Capture ended",
            endpoint: store.match?.deadline,
            serverOffset: store.serverOffset
        )
    }

    private var postGo: Bool {
        store.stage == .capture || store.stage == .submitting || store.stage == .judging
    }

    private var nextPose: PhysiquePose? {
        guard mayEdit, camera.candidate == nil, evidence?.status == "accepted", let match = store.match else { return nil }
        return PhysiquePose.allCases.first { next in
            guard next != inspectedPose else { return false }
            guard let record = match.evidence.first(where: { $0.pose == next }) else { return true }
            return record.status == "rejected" && (0..<2).contains(record.retakes)
        }
    }


    private var deadlineIdentity: DeadlineIdentity {
        DeadlineIdentity(matchID: store.match?.id, stage: store.stage, endpoint: store.match?.deadline, offset: store.serverOffset)
    }

    private var reviewContent: some View {
        PhysiqueScreen(title: "Review pose", subtitle: inspectedPose.title) {
            if let match = store.match, let accountID = accounts.accountID, accountID == reviewAccountID {
                PhysiqueIdentityRail(identity: match.you.identity, ownerLabel: "You") { badgeDetail = $0 }
                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent") { badgeDetail = $0 }
                poseSlots
                PhysiquePlayerPanel(title: "You · \(inspectedPose.title)", status: mayShowImage ? "Masked preview · Submitted evidence orientation" : "Protected evidence preview") {
                    if mayShowImage, let previewImage {
                        previewImage.resizable().scaledToFit()
                            .accessibilityLabel("Your \(inspectedPose.title), exact face-obscured still")
                    } else {
                        VStack(spacing: ProfileStyle.spacing) {
                            Image(systemName: "lock.rectangle").font(.largeTitle).accessibilityHidden(true)
                            Text(statusTitle).font(TimeMasterFont.heading())
                            Text("No original or previous attempt is shown.").font(TimeMasterFont.secondary())
                        }
                        .foregroundStyle(ProfileStyle.secondary)
                        .multilineTextAlignment(.center)
                        .padding(ProfileStyle.inset)
                    }
                }
                reviewShelf
                transferDisclosure
                if store.isStale {
                    PhysiqueStatusView(title: "Last confirmed match state", detail: "The connection could not be refreshed. Timing continues; capture and transfers remain unavailable until the same match is reconciled.")
                }
                if let error = localError ?? store.error {
                    PhysiqueStatusView(title: "Request not confirmed", detail: error)
                }
                PhysiquePlayerPanel(title: "Opponent", status: opponentStatus(match)) {
                    PhysiqueAthleteIllustration(isOpponent: true)
                        .accessibilityLabel("Neutral opponent illustration. No opponent pose image is available during capture.")
                }
            } else {
                PhysiqueStatusView(title: unavailableTitle, detail: unavailableDetail, systemImage: "lock.fill")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { PhysiqueTimerView(clock: clock) }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
    }

    private var observedReview: some View {
        reviewContent
        .task { await restoreReview() }
        .task(id: deadlineIdentity) { await watchDeadline(deadlineIdentity) }
        .onChange(of: sourceBytes) { _ in updatePreview() }
        .onChange(of: camera.selectedEvidenceIDs) { _ in updatePreview() }
        .onChange(of: evidence?.id) { _ in updatePreview() }
        .onChange(of: evidence?.status) { value in
            if value == "removed" || value == "expired" { protectReview() }
            else { updatePreview() }
        }
        .onChange(of: store.privacyRevision) { _ in protectReview() }
        .onChange(of: store.isStale) { stale in
            if stale { protectReview() }
        }
        .onChange(of: store.lastRefreshedAt) { _ in announceEvidenceChanges() }
        .onChange(of: inspectedPose) { _ in
            localError = nil
            updatePreview()
            summaryFocused = true
        }
    }

    var body: some View {
        observedReview
        .onChange(of: accounts.accountID) { _ in protectReview() }
        .onChange(of: store.match?.id) { value in
            if reviewMatchID != nil && value != reviewMatchID { protectReview() }
        }
        .onChange(of: store.stage) { value in
            if value != .capture { protectReview() }
        }
        .onChange(of: processingAuthorized) { allowed in
            if !allowed { protectReview() }
        }
        .onChange(of: camera.ownerID) { owner in
            if owner != windowID {
                restored = false
                transferTask?.cancel()
                clearPresentation()
            }
        }
        .onChange(of: store.controllingWindowID) { _ in
            if !store.canControl(from: windowID) { protectReview() }
        }
        .onChange(of: presentationActive) { active in
            if !active { protectReview() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { protectReview() }
        }
        .onDisappear {
            transferTask?.cancel()
            clearPresentation()
            if preserveSelectionOnHandoff { camera.pause(owner: windowID) }
            else { camera.stop(owner: windowID) }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("Leave this match?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
            Button(postGo ? "Forfeit and leave" : "Cancel match", role: .destructive) { leaveMatch() }
            Button("Keep reviewing", role: .cancel) { }
        } message: {
            Text(postGo
                 ? "Leaving after Go requests a forfeit only if this match remains eligible. The service determines any no-contest or allowance consequence."
                 : "Cancelling before Go requests cancellation without a rating change. The service must confirm the cancellation.")
        }
        .alert(item: $badgeDetail) { badge in
            Alert(title: Text(badge.title), message: Text(badge.detail), dismissButton: .default(Text("Done")))
        }
    }

    private var poseSlots: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: ProfileStyle.spacing)], spacing: ProfileStyle.spacing) {
            ForEach(PhysiquePose.allCases) { slot in
                Button { inspectedPose = slot } label: {
                    VStack(spacing: 6) {
                        Text(slot.shortTitle).font(TimeMasterFont.rowTitle())
                        Text(slotStatus(slot)).font(TimeMasterFont.caption())
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: ProfileStyle.touchTarget)
                    .padding(ProfileStyle.spacing)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: ProfileStyle.corner))
                    .overlay {
                        RoundedRectangle(cornerRadius: ProfileStyle.corner)
                            .strokeBorder(inspectedPose == slot ? Theme.toolbarOrange : Theme.separator, lineWidth: inspectedPose == slot ? 2 : 1)
                    }
                }
                .buttonStyle(TimeMasterCardButtonStyle())
                .accessibilityLabel(slot.title)
                .accessibilityValue(slotStatus(slot))
                .accessibilityAddTraits(inspectedPose == slot ? [.isSelected] : [])
                .disabled(sending)
            }
        }
    }

    private var reviewShelf: some View {
        PhysiqueCard {
            HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                if (sending || (!hasCandidate && evidence?.status == "checking")) && mediaAuthorized && !reduceMotion {
                    ProgressView().controlSize(.small).accessibilityHidden(true)
                } else {
                    Image(systemName: statusSymbol).foregroundStyle(Theme.toolbarOrange).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(TimeMasterFont.heading())
                        .accessibilityAddTraits(.isHeader)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: statusTitle)
                    Text(retakeLabel).font(TimeMasterFont.rowTitle())
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(inspectedPose.title), \(statusTitle), \(retakeLabel)")
            .accessibilityFocused($summaryFocused)
            Text(statusDetail).fixedSize(horizontal: false, vertical: true)
            Label(camera.status.message, systemImage: camera.status.isRunning ? "camera.fill" : "camera")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            if let match = store.match {
                Text("\(currentAcceptedCount(match)) of 3 current poses accepted · \(match.you.submitted ? "Set submitted" : "Set not submitted")")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            }
            if evidence?.status == "rejected", let matchID = reviewMatchID,
               let caseID = evidence?.appealCaseID?.trimmingCharacters(in: .whitespacesAndNewlines), !caseID.isEmpty {
                Button {
                    protectReview()
                    onOpen(.review(PhysiqueReviewTarget(kind: "appeal", id: caseID, matchID: matchID)))
                } label: { Label("Review this decision", systemImage: "text.bubble") }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
            }
        }
    }

    private var transferDisclosure: some View {
        PhysiqueCard {
            if let policy = currentPolicy, policy.ready,
               !policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !policy.processor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Use pose sends this masked still to \(policy.operatorName) and \(policy.processor) for the disclosed checks.")
                    .font(TimeMasterFont.secondary()).fixedSize(horizontal: false, vertical: true)
                Text("The opponent cannot view pose images during capture. Later access requires an authorized judged result and current sharing permission.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(currentPolicy?.unavailableReason ?? "The service has not supplied a ready processing policy. Image transfer is unavailable.")
                    .font(TimeMasterFont.secondary()).fixedSize(horizontal: false, vertical: true)
            }
            Button {
                protectReview()
                onOpen(.privacy)
            } label: { Label("Privacy and sharing", systemImage: "hand.raised") }
            .buttonStyle(TimeMasterToolbarTextButtonStyle())
        }
    }

    private var actions: some View {
        VStack(spacing: ProfileStyle.spacing) {
            if accounts.accountID == nil {
                PhysiqueAction(title: "Sign in", systemImage: "person.crop.circle") { openProtected(.account) }
            } else if mediaAuthorized && hasCandidate {
                PhysiqueAction(title: transferUnconfirmed ? "Retry Use pose" : "Use pose", systemImage: "checkmark", disabled: !maySend, action: usePose)
                if !maySend && !sending {
                    Text(sendUnavailableReason).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if mediaAuthorized, let pendingPose = camera.candidatePose, camera.candidate != nil {
                PhysiqueAction(title: "Review selected \(pendingPose.shortTitle.lowercased())", systemImage: "photo") {
                    inspectedPose = pendingPose
                }
            } else if store.stage == .judging || store.stage == .submitting {
                PhysiqueAction(title: "View match status", systemImage: "hourglass") { openProtected(.judging) }
            } else if let match = store.match, match.stage.terminal {
                PhysiqueAction(title: "View match result", systemImage: "flag.checkered") { openProtected(.result(match.id)) }
            } else if !restored || store.isStale {
                PhysiqueAction(title: "Restore match status", systemImage: "arrow.clockwise", disabled: store.loading || sending) {
                    Task { await restoreReview() }
                }
            } else if let nextPose {
                PhysiqueAction(title: "Next pose · \(nextPose.shortTitle)", systemImage: "arrow.right") {
                    returnToBattle(opening: nextPose)
                }
            } else {
                PhysiqueAction(title: "Back to match", systemImage: "arrow.left", disabled: sending) { returnToBattle() }
            }
            HStack(spacing: ProfileStyle.spacing) {
                Button { retakePose() } label: { Label("Retake \(inspectedPose.shortTitle.lowercased())", systemImage: "arrow.triangle.2.circlepath.camera") }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
                    .disabled(!mayRetake)
                    .accessibilityHint("Replaces only this pose after a new capture. The original deadline and service retake limit do not change.")
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    if store.match?.stage.terminal == false { showsExitConfirmation = true }
                    else { openProtected(.lobby) }
                } label: { Label("Exit", systemImage: "xmark") }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
            }
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private var sendUnavailableReason: String {
        if store.busy { return "A service request is still being confirmed." }
        if store.isStale || store.loading { return "Restore the same match before transferring this image." }
        if store.match?.you.submitted == true { return "The submitted pose set is locked." }
        if (evidence?.retakes ?? 0) >= 2 { return "The service's replacement limit has been reached." }
        return "Image transfer needs current processing consent, a ready disclosed service, and capture time remaining."
    }

    private func serviceStatus(_ status: String) -> String {
        switch status {
        case "accepted": return "accepted"
        case "checking": return "checking"
        case "rejected": return "needs retake"
        case "removed": return "removed"
        case "expired": return "expired"
        default: return "an unconfirmed state"
        }
    }

    private func slotStatus(_ slot: PhysiquePose) -> String {
        if camera.candidatePose == slot && camera.candidate != nil { return "Selected · Not accepted" }
        guard let record = store.match?.evidence.first(where: { $0.pose == slot }) else { return "Not selected" }
        return serviceStatus(record.status).capitalized
    }

    private func currentAcceptedCount(_ match: PhysiqueMatch) -> Int {
        let replacingAccepted = camera.candidatePose.flatMap { candidatePose in
            match.evidence.first { $0.pose == candidatePose && $0.status == "accepted" }
        } != nil && camera.candidate != nil
        return max(0, match.you.acceptedCount - (replacingAccepted ? 1 : 0))
    }

    private func opponentStatus(_ match: PhysiqueMatch) -> String {
        if match.opponent.submitted { return "Pose set submitted · Opponent images remain private" }
        return "\(match.opponent.acceptedCount) of 3 poses accepted · No live or early pose images"
    }

    private func updatePreview() {
        guard mediaAuthorized, hasCandidate || hasCurrentSelectedImage, let bytes = sourceBytes else {
            clearPresentation()
            return
        }
        guard previewBytes != bytes else { return }
        previewBytes = nil
        previewImage = nil
        guard let image = PhotoPlatformImage(data: bytes) else {
            localError = "The exact masked still could not be displayed. No original image will be substituted or sent."
            return
        }
        previewBytes = bytes
        previewImage = platformImage(image)
    }

    private func clearPresentation() {
        previewImage = nil
        previewBytes = nil
        badgeDetail = nil
    }

    private func protectReview() {
        restored = false
        transferTask?.cancel()
        clearPresentation()
        transferUnconfirmed = false
        sending = false
        localError = nil
        knownEvidenceStates.removeAll()
        preserveSelectionOnHandoff = false
        showsExitConfirmation = false
        camera.stop(owner: windowID)
    }

    private func restoreReview() async {
        let accountID = accounts.accountID
        let matchID = store.match?.id
        guard accountID != nil, presentationActive, scenePhase == .active else {
            protectReview()
            return
        }
        await store.refresh()
        guard !Task.isCancelled, accounts.accountID == accountID,
              let match = store.match, matchID == nil || match.id == matchID else {
            protectReview()
            return
        }
        reviewAccountID = accountID
        reviewMatchID = match.id
        reviewCaptureOwnerID = camera.ownerID
        restored = !store.isStale
        knownEvidenceStates.removeAll(keepingCapacity: true)
        for record in match.evidence {
            knownEvidenceStates[record.pose] = EvidenceStatus(id: record.id, status: record.status)
        }
        guard processingAuthorized, match.stage == .capture, let deadline = match.deadline,
              deadline.isFinite, deadline > Date().timeIntervalSince1970 + store.serverOffset else {
            protectReview()
            return
        }
        if camera.ownerID == windowID && camera.status.isRunning { camera.pause(owner: windowID) }
        updatePreview()
        summaryFocused = true
    }

    private func usePose() {
        guard maySend, let bytes = camera.candidate, camera.candidatePose == inspectedPose,
              let accountID = reviewAccountID, let matchID = reviewMatchID else { return }
        let submittedPose = inspectedPose
        sending = true
        localError = nil
        let privacyRevision = store.privacyRevision
        transferTask = Task { @MainActor in
            guard !Task.isCancelled, accounts.accountID == accountID,
                  store.privacyRevision == privacyRevision, mediaAuthorized,
                  camera.candidatePose == submittedPose, camera.candidate == bytes else {
                sending = false
                return
            }
            let success = await store.perform("candidate", matchID: matchID, pose: submittedPose, imageBase64: bytes.base64EncodedString())
            sending = false
            guard !Task.isCancelled, success, accounts.accountID == accountID,
                  store.privacyRevision == privacyRevision, reviewMatchID == matchID, mediaAuthorized,
                  camera.candidatePose == submittedPose, camera.candidate == bytes,
                  let record = store.match?.evidence.first(where: { $0.pose == submittedPose }) else {
                if !Task.isCancelled && accounts.accountID == accountID && reviewMatchID == matchID {
                    transferUnconfirmed = true
                    localError = store.error ?? "The current selection could not be confirmed. Refresh the same match before retrying this exact still."
                }
                return
            }
            transferUnconfirmed = false
            camera.acceptCandidate(evidenceID: record.id)
            updatePreview()
            summaryFocused = true
        }
    }

    private func returnToBattle(opening requestedPose: PhysiquePose? = nil) {
        guard !sending, camera.candidate == nil else { return }
        preserveSelectionOnHandoff = mediaAuthorized
        store.requestPose(requestedPose ?? inspectedPose)
        camera.pause(owner: windowID)
        clearPresentation()
        onOpen(.battle)
    }

    private func retakePose() {
        guard mayRetake else { return }
        returnToBattle(opening: inspectedPose)
    }

    private func openProtected(_ route: PhysiqueRoute) {
        protectReview()
        onOpen(route)
    }

    private func leaveMatch() {
        let accountID = accounts.accountID
        let matchID = store.match?.id
        let pending = transferTask
        protectReview()
        Task { @MainActor in
            await pending?.value
            guard accounts.accountID == accountID, let match = store.match, match.id == matchID,
                  !match.stage.terminal else { return }
            let postGo = match.stage == .capture || match.stage == .submitting || match.stage == .judging
            if await store.perform("leave", matchID: match.id, reason: postGo ? "forfeit" : "cancel") {
                onOpen(.lobby)
            }
        }
    }

    private func announceEvidenceChanges() {
        guard restored, presentationActive, scenePhase == .active,
              accounts.accountID == reviewAccountID, let match = store.match else { return }
        for record in match.evidence {
            let state = EvidenceStatus(id: record.id, status: record.status)
            let previous = knownEvidenceStates.updateValue(state, forKey: record.pose)
            guard previous != nil, previous != state,
                  record.status == "accepted" || record.status == "rejected" else { continue }
            if camera.candidatePose == record.pose && camera.candidate != nil { continue }
            let message = record.status == "accepted"
                ? "\(record.pose.title) accepted by the service."
                : "\(record.pose.title) needs retake. \(record.reason ?? "Review the pose guidance.")"
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: message)
            #elseif os(macOS)
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ])
            #endif
        }
    }

    private func watchDeadline(_ identity: DeadlineIdentity) async {
        guard identity.stage == .capture, let deadline = identity.endpoint, deadline.isFinite else {
            deadlineReached = true
            return
        }
        let remaining = deadline - Date().timeIntervalSince1970 - identity.offset
        guard remaining.isFinite, remaining < Double(UInt64.max) / 1_000_000_000 else {
            deadlineReached = true
            return
        }
        deadlineReached = remaining <= 0
        if remaining > 0 {
            do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            catch { return }
        }
        guard !Task.isCancelled, deadlineIdentity == identity else { return }
        deadlineReached = true
        protectReview()
        await store.refresh()
    }

    private struct EvidenceStatus: Equatable {
        let id: String
        let status: String
    }

    private struct DeadlineIdentity: Equatable {
        let matchID: String?
        let stage: PhysiqueStage
        let endpoint: Double?
        let offset: Double
    }
}
