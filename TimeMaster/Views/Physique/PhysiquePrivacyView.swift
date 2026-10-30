import SwiftUI

@MainActor
struct PhysiquePrivacyView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @ObservedObject private var camera = PhysiqueCamera.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var receipts: [PhysiquePrivacyReceipt] = []
    @State private var receiptAccountID: String?
    @State private var receiptsLoadedAt: Date?
    @State private var receiptsLoading = false
    @State private var receiptsError: String?
    @State private var receiptLoadID = UUID()
    @State private var refreshID = UUID()
    @State private var confirmation: PrivacyRequest?
    @State private var confirmsAI = false
    @State private var confirmsSharing = false
    @State private var confirmsListing = false
    @State private var confirmsRemoval = false
    @State private var confirmsAllRemoval = false
    @State private var activeRequest: PrivacyRequest?
    @State private var unconfirmedRequests: [PrivacyRequest] = []
    @State private var acknowledgement: Acknowledgement?
    @State private var actionError: String?
    @State private var processingDetails = false
    @State private var opponentDetails = false
    @State private var listingDetails = false
    @AccessibilityFocusState private var accessibilityFocus: FocusTarget?

    private enum FocusTarget: Hashable {
        case activity, request
    }

    private enum RequestKind: Equatable {
        case ai, sharing, listing, removal
    }

    private struct PrivacyRequest: Identifiable {
        let id = UUID()
        let accountID: String
        let kind: RequestKind
        let operation: String
        let matchID: String?
        let value: Bool?
        let title: String
        let scope: String
        let consequence: String

        var isProtective: Bool { operation != "listing" || value == false }

        func hasSamePayload(as other: Self) -> Bool {
            accountID == other.accountID && operation == other.operation && matchID == other.matchID && value == other.value
        }
    }

    private struct Acknowledgement {
        let request: PrivacyRequest
        let reference: String?
        let message: String
    }

    private struct LoadContext: Hashable {
        let accountID: String?
        let refreshID: UUID
        let active: Bool
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var loadContext: LoadContext {
        LoadContext(accountID: activeAccountID, refreshID: refreshID, active: scenePhase == .active)
    }

    private var policy: PhysiquePolicy? { store.policy ?? store.snapshot?.policy }
    private var canMutate: Bool { activeAccountID != nil && activeRequest == nil }
    private var canReviewGrant: Bool {
        canMutate && unconfirmedRequests.isEmpty && !store.busy && !store.isStale && policy?.ready == true
    }
    private var authorizedReceipts: [PhysiquePrivacyReceipt] {
        receiptAccountID == activeAccountID && activeAccountID != nil ? receipts : []
    }
    private var supportURL: URL? {
        guard let value = policy?.supportURL, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "mailto",
              url.user == nil, url.password == nil else { return nil }
        if scheme == "https", url.host == nil { return nil }
        return url
    }

    var body: some View {
        VStack(spacing: 0) {
            if scenePhase == .active, activeAccountID != nil {
                matchStrip
            }
            PhysiqueScreen(title: "Privacy & sharing", subtitle: "Independent choices. No pose photos are loaded here.") {
                if scenePhase != .active {
                    PhysiqueStatusView(title: "Private controls", detail: "Return to review this account’s choices and requests.", systemImage: "lock.fill")
                } else if !accountStore.restored || accountStore.busy {
                    ProgressView("Resolving account access…")
                } else if activeAccountID == nil {
                    PhysiqueStatusView(title: "Sign in for private status", detail: "Your account owns its sharing choices, pose-removal requests and receipts. Signing out is not withdrawal or deletion.", systemImage: "person.crop.circle")
                    PhysiqueAction(title: "Open Tmax account", systemImage: "person.crop.circle") { open(.account) }
                    policySection
                    accountSection
                } else {
                    activitySection
                    if let account = store.account {
                        processingSection(account)
                        opponentSection(account)
                        listingSection(account)
                        posesSection
                    } else {
                        PhysiqueStatusView(title: store.loading ? "Loading choices" : "Choices not confirmed", detail: store.error ?? "No authorized account choices have been received. Nothing is assumed allowed or listed.", retry: requestRefresh)
                    }
                    requestSection
                    policySection
                    accountSection
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    store.suspendCapture()
                    dismiss()
                }
                .physiqueToolbarTarget()
            }
        }
        .onAppear {
            store.suspendCapture()
            accessibilityFocus = .activity
        }
        .onDisappear { store.suspendCapture() }
        .task(id: loadContext) { await load(context: loadContext) }
        .onChange(of: accountStore.accountID) { _ in clearPrivateState() }
        .onChange(of: accountStore.busy) { busy in
            if busy { clearPrivateState() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                store.suspendCapture()
                dismissConfirmations()
                accessibilityFocus = nil
            }
        }
    }

    @ViewBuilder
    private var matchStrip: some View {
        if let match = store.match, !match.stage.terminal {
            VStack(spacing: ProfileStyle.spacing) {
                PhysiqueTimerView(clock: clock(for: match))
                Button("Return to match & exit options") { open(matchRoute) }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
                Text("Reading does not pause the match. Returning never resumes the camera automatically.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
        } else if store.stage == .searching {
            VStack(spacing: ProfileStyle.spacing) {
                PhysiqueTimerView(clock: PhysiqueClock(mode: store.isStale ? .unavailable : .remaining, label: "Search · same deadline", endpoint: store.snapshot?.queueDeadline, serverOffset: store.serverOffset))
                Button("Return to search & cancellation") { open(.search) }
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
            }
            .padding(ProfileStyle.spacing)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
        }
    }

    private var activitySection: some View {
        PhysiqueSection(title: "Activity") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    statusLine("Camera on this device", value: camera.status.message, symbol: camera.status.isRunning ? "camera.fill" : "camera")
                    Text("Stopped while reading. This does not control a camera on another device. Resume only through the existing match flow.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    statusLine("New local processing", value: store.localProcessingStopped ? "Stopped on this device" : "No pending processing stop recorded on this device", symbol: "hand.raised")
                    if store.localOwnMediaHidden {
                        statusLine("Own pose media", value: "Hidden on this device. Remote removal or revocation is established only by the service receipt.", symbol: "eye.slash")
                    }
                    statusLine("Transfer activity", value: "Upload progress is not supplied by this response.", symbol: "arrow.up.doc")
                    Text("A local stop does not recall an upload or work already accepted by the service or processor.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    if let match = store.match {
                        statusLine("Service intake", value: "\(match.you.acceptedCount) accepted poses · \(match.you.submitted ? "final set submitted" : "final set not confirmed submitted")", symbol: "tray")
                        statusLine("Service stage", value: match.result?.title ?? match.stage.title, symbol: "server.rack")
                        if let reason = match.reason, !reason.isEmpty {
                            Text(reason).font(TimeMasterFont.secondary())
                        }
                    } else {
                        statusLine("Service activity", value: store.stage == .searching ? "Searching" : "No match in this snapshot. Processor activity is not separately reported.", symbol: "server.rack")
                    }
                    Text("Processor acceptance and cancellation are not separate receipts in this account response. Do not treat an unknown status as cancelled.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    if let time = store.lastRefreshedAt {
                        timestamp("Account state confirmed", date: time)
                    }
                    if store.isStale {
                        Label("Last confirmed state · refresh unavailable", systemImage: "exclamationmark.triangle")
                            .font(TimeMasterFont.secondary())
                    }
                    Button("Stop local capture now") { store.suspendCapture() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                    Button(store.loading || receiptsLoading ? "Checking status…" : "Check current status", action: requestRefresh)
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                        .disabled(store.loading || receiptsLoading)
                    if let error = store.error {
                        Text(error).font(TimeMasterFont.secondary()).foregroundStyle(.red)
                    }
                }
            }
        }
        .accessibilityFocused($accessibilityFocus, equals: .activity)
    }

    private func processingSection(_ account: PhysiqueAccount) -> some View {
        PhysiqueSection(title: "AI & safety processing") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    choiceStatus(allowed: account.consent.aiProcessing, consent: account.consent)
                    pendingChoice("withdrawAI")
                    Text(processorSummary)
                    DisclosureGroup("What is processed", isExpanded: $processingDetails) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("Necessary face-obscured candidates go to protected safety intake. Six accepted selected stills form one paired judgement. The judge uses neutral pose and participant labels, not your name, country, badges, Elo or private adult/attire declarations.")
                            Text("Face masking does not guarantee anonymity. Clothing, tattoos, reflections and the background can identify you. Limited authorized case review and any processor retention exceptions are separate from opponent viewing.")
                            policyFacts
                        }
                        .font(TimeMasterFont.secondary())
                        .padding(.top, ProfileStyle.spacing)
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { processingDetails.toggle() })
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: processingDetails)
                    PhysiqueAction(title: "Withdraw AI sharing…", systemImage: "hand.raised", role: .destructive, disabled: !canMutate) {
                        prepare(.ai)
                    }
                    .confirmationDialog("Withdraw AI sharing?", isPresented: $confirmsAI, titleVisibility: .visible, presenting: confirmation) { request in
                        Button("Withdraw AI sharing", role: .destructive) { submit(request) }
                        Button("Cancel", role: .cancel) { confirmation = nil }
                    } message: { request in
                        Text(request.scope + "\n\n" + request.consequence)
                    }
                    grantButton
                }
            }
        }
    }

    private func opponentSection(_ account: PhysiqueAccount) -> some View {
        PhysiqueSection(title: "Opponent pose access") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    choiceStatus(allowed: account.consent.opponentSharing, consent: account.consent)
                    pendingChoice("withdrawSharing")
                    Text("Only the paired participant, intentionally viewing currently authorized approved stills after a valid judged win, loss or draw. Never live video or a public photo feed.")
                    Text("Screenshots and external recordings cannot be recalled or absolutely prevented.")
                        .font(TimeMasterFont.secondary())
                    DisclosureGroup("Access and withdrawal details", isExpanded: $opponentDetails) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Text("No early stills, rejected attempts, forfeit gallery or no-contest gallery. Viewing must remain authorized for each image owner and within the original service expiry.")
                            Text("After Go, withdrawing only opponent access does not forfeit, cancel separately authorized AI processing or reverse Elo. Before Go it removes a required entry condition.")
                            Text("A later grant is for future authorized use. It does not restore removed photos, resend an old set or restart expiry.")
                        }
                        .font(TimeMasterFont.secondary())
                        .padding(.top, ProfileStyle.spacing)
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { opponentDetails.toggle() })
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: opponentDetails)
                    PhysiqueAction(title: "Withdraw opponent access…", systemImage: "eye.slash", role: .destructive, disabled: !canMutate) {
                        prepare(.sharing)
                    }
                    .confirmationDialog("Withdraw opponent access?", isPresented: $confirmsSharing, titleVisibility: .visible, presenting: confirmation) { request in
                        Button("Withdraw opponent access", role: .destructive) { submit(request) }
                        Button("Cancel", role: .cancel) { confirmation = nil }
                    } message: { request in
                        Text(request.scope + "\n\n" + request.consequence)
                    }
                    grantButton
                }
            }
        }
    }

    private func listingSection(_ account: PhysiqueAccount) -> some View {
        PhysiqueSection(title: "Public standings") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Label(listingStatus(account), systemImage: account.listed ? "list.number" : "person.crop.circle.badge.minus")
                        .font(TimeMasterFont.label())
                    pendingChoice("listing")
                    Text("Optional. You earn the same Physique Elo while unlisted. A paired opponent still receives permitted match identity.")
                    if account.listed, let reason = account.restrictedReason, !reason.isEmpty {
                        Text(reason).font(TimeMasterFont.secondary())
                    }
                    DisclosureGroup("Your public identity preview", isExpanded: $listingDetails) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            PhysiqueIdentityRail(identity: account.identity, ownerLabel: "Your permitted public identity") { _ in open(.badges) }
                            Text("Record: \(account.record.wins) wins · \(account.record.losses) losses · \(account.record.draws) draws · \(account.record.games) rated matches")
                            if let streak = account.identity.streak {
                                Text("Current streak: \(streak)")
                            }
                            Text("No pose photos, private adult/attire declarations, reports, email, local Profile photo or precise location are published.")
                        }
                        .font(TimeMasterFont.secondary())
                        .padding(.top, ProfileStyle.spacing)
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { listingDetails.toggle() })
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: listingDetails)
                    PhysiqueAction(title: account.listed ? "Remove me from standings…" : "List me…", systemImage: account.listed ? "eye.slash" : "list.number", role: account.listed ? .destructive : nil, disabled: !canMutate || (!account.listed && (!unconfirmedRequests.isEmpty || store.isStale))) {
                        prepare(.listing)
                    }
                    .confirmationDialog(confirmation?.value == true ? "Allow public listing?" : "Remove public listing?", isPresented: $confirmsListing, titleVisibility: .visible, presenting: confirmation) { request in
                        Button(request.value == true ? "Allow public listing" : "Remove me from standings", role: request.value == true ? nil : .destructive) { submit(request) }
                        Button("Cancel", role: .cancel) { confirmation = nil }
                    } message: { request in
                        Text(request.consequence)
                    }
                    Text("A saved listing choice is not proof of a live board position. Placement and current restrictions still apply; this response does not provide a public rank.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
        }
    }

    private var posesSection: some View {
        PhysiqueSection(title: "My shared poses") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    if let match = store.match {
                        Text("Match \(match.id)").font(TimeMasterFont.label()).textSelection(.enabled)
                        timestamp("Match created", date: Date(timeIntervalSince1970: match.createdAt))
                        if let expiry = match.mediaExpiresAt, expiry.isFinite {
                            timestamp("Original media expiry", date: Date(timeIntervalSince1970: expiry))
                        } else {
                            Text("Original media expiry is not supplied for this match.")
                                .font(TimeMasterFont.secondary())
                        }
                        if !match.galleryAvailable {
                            Text("This match does not currently offer a gallery. That does not prove all retained media has been deleted.")
                                .font(TimeMasterFont.secondary())
                        }
                        PhysiqueAction(title: "Remove my poses in this match…", systemImage: "trash", role: .destructive, disabled: !canMutate) {
                            prepare(.removal, matchID: match.id)
                        }
                        .confirmationDialog("Remove my poses in this match?", isPresented: $confirmsRemoval, titleVisibility: .visible, presenting: confirmation) { request in
                            Button("Remove my poses in this match", role: .destructive) { submit(request) }
                            Button("Cancel", role: .cancel) { confirmation = nil }
                        } message: { request in
                            Text(request.scope + "\n\n" + request.consequence)
                        }
                    }
                    Text("No account-wide stored-photo count is supplied. Removal does not require opening body photos.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                    PhysiqueAction(title: "Remove all my shared poses…", systemImage: "trash", role: .destructive, disabled: !canMutate) {
                        prepare(.removal)
                    }
                    .confirmationDialog("Remove all my shared poses?", isPresented: $confirmsAllRemoval, titleVisibility: .visible, presenting: confirmation) { request in
                        Button("Remove all my shared poses", role: .destructive) { submit(request) }
                        Button("Cancel", role: .cancel) { confirmation = nil }
                    } message: { request in
                        Text(request.scope + "\n\n" + request.consequence)
                    }
                    Text("Only your ordinary Physique media is in scope—not the opponent’s photos, the exercise library or the Tmax account. Future consent is a separate choice. Removed evidence is never automatically resent.")
                        .font(TimeMasterFont.secondary())
                }
            }
        }
    }

    private var requestSection: some View {
        PhysiqueSection(title: "Requests & receipts") {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                if let request = activeRequest {
                    ProgressView("Confirming \(request.title.lowercased())…")
                    Text(request.scope).font(TimeMasterFont.secondary())
                }
                ForEach(unconfirmedRequests) { request in
                    PhysiqueCard {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Label("Remote change not confirmed", systemImage: "exclamationmark.circle")
                                .font(TimeMasterFont.label())
                            Text(request.title)
                            Text(request.scope).font(TimeMasterFont.secondary())
                            if request.isProtective {
                                Text("Local capture remains stopped. This is not confirmation of remote revocation, deletion or recalled processor work.")
                                    .font(TimeMasterFont.secondary())
                            }
                            Button("Retry this exact request") { submit(request) }
                                .buttonStyle(TimeMasterToolbarTextButtonStyle())
                                .disabled(activeRequest != nil)
                        }
                    }
                }
                if let acknowledgement {
                    PhysiqueCard {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            Label("Service acknowledged", systemImage: "checkmark.circle")
                                .font(TimeMasterFont.label())
                            Text(acknowledgement.request.title)
                            Text(acknowledgement.request.scope).font(TimeMasterFont.secondary())
                            Text(acknowledgement.message).font(TimeMasterFont.secondary())
                            if let reference = acknowledgement.reference {
                                Text("Reference: \(reference)").font(TimeMasterFont.caption()).textSelection(.enabled)
                            }
                            Text("Acknowledgement is not a claim that every retained copy has been erased. The receipt below names the actual scope, status and residual reason.")
                                .font(TimeMasterFont.secondary())
                        }
                    }
                }
                if let actionError {
                    Label(actionError, systemImage: "exclamationmark.triangle")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(.red)
                }
                if receiptsLoading {
                    ProgressView("Checking privacy receipts…")
                }
                if let receiptsError {
                    PhysiqueStatusView(title: "Receipt status unavailable", detail: receiptsError + " Last confirmed receipts remain below; absence of an update is not completion.", retry: requestRefresh)
                }
                if authorizedReceipts.isEmpty, receiptsLoadedAt != nil, receiptsError == nil, !receiptsLoading {
                    Text("No privacy receipts were returned for this account. This does not establish an empty media store or completed erasure.")
                        .font(TimeMasterFont.secondary())
                }
                if let time = receiptsLoadedAt, receiptAccountID == activeAccountID {
                    timestamp("Receipts checked", date: time)
                }
                LazyVStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    ForEach(authorizedReceipts) { receipt in
                        PhysiqueCard {
                            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                                Text(receiptStatus(receipt.status)).font(TimeMasterFont.label())
                                Text("Scope: \(receipt.scope)")
                                Text(receipt.detail)
                                if let reason = receipt.retainedReason, !reason.isEmpty {
                                    Label("Retained scope: \(reason)", systemImage: "exclamationmark.shield")
                                        .font(TimeMasterFont.secondary())
                                }
                                timestamp("Received", date: Date(timeIntervalSince1970: receipt.createdAt))
                                timestamp("Updated", date: Date(timeIntervalSince1970: receipt.updatedAt))
                                Text("Reference: \(receipt.id)").font(TimeMasterFont.caption()).textSelection(.enabled)
                            }
                        }
                    }
                }
                Button("Check choices & request status", action: requestRefresh)
                    .buttonStyle(TimeMasterToolbarTextButtonStyle())
                    .disabled(store.loading || receiptsLoading)
            }
        }
        .accessibilityFocused($accessibilityFocus, equals: .request)
    }

    private var policySection: some View {
        PhysiqueSection(title: "Recipients & retention") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    if let policy {
                        if !policy.ready {
                            Label("Sharing details unavailable for new participation", systemImage: "exclamationmark.triangle")
                                .font(TimeMasterFont.label())
                            if let reason = policy.unavailableReason, !reason.isEmpty { Text(reason) }
                        }
                        policyFacts
                    } else {
                        Text("The current operator, processor, region and retention disclosures have not been received. New sharing cannot be authorized here.")
                    }
                    Text("App-controlled removal, limited lawful holds, processor retention and external copies are separate. No request here promises universal erasure or recall of accepted provider work. No policy is inferred from a provider’s marketing defaults.")
                        .font(TimeMasterFont.secondary())
                    if let supportURL {
                        Link("Operator privacy contact & support", destination: supportURL)
                            .buttonStyle(TimeMasterToolbarTextButtonStyle())
                    } else {
                        Text("The service has not supplied a usable privacy/contact link.")
                            .font(TimeMasterFont.secondary())
                    }
                    Button("Retry current disclosures") { Task { await store.loadPolicy() } }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var policyFacts: some View {
        if let policy {
            Text("Operator: \(disclosure(policy.operatorName))")
            Text("Processor: \(disclosure(policy.processor))")
            Text("Processing region: \(disclosure(policy.region))")
            Text("Retention & exceptions: \(disclosure(policy.retention))")
            Text("Policy: \(disclosure(policy.version)) · Judge: \(disclosure(policy.judgeVersion))")
                .font(TimeMasterFont.secondary())
        }
    }

    private var accountSection: some View {
        PhysiqueSection(title: "Tmax account") {
            PhysiqueAction(title: "Delete Tmax account…", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                open(.deletion)
            }
            Text("Deletes this account, not just Physique. Review consequences and actual status through the existing global account owner. This page does not make or confirm account deletion.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            Text("Physique choices do not change the exercise-duel image privacy promise or delete the local exercise library. OS-wide camera revocation can affect other camera features.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private var grantButton: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Button("Review choices for future use") { open(.consent) }
                .buttonStyle(TimeMasterToolbarTextButtonStyle())
                .disabled(!canReviewGrant)
            if !unconfirmedRequests.isEmpty {
                Text("Reconcile the unconfirmed request before a new grant. A retry uses the same account and scope.")
                    .font(TimeMasterFont.secondary())
            } else if policy?.ready != true {
                Text("New grants wait for complete current disclosures. Withdrawal and removal remain available.")
                    .font(TimeMasterFont.secondary())
            }
        }
    }

    private var processorSummary: String {
        guard let policy else { return "Recipients are not confirmed. Current permission is not a substitute for the missing disclosure." }
        return "\(disclosure(policy.operatorName)) · \(disclosure(policy.processor)). Protected safety checks and one paired image judgement, under the disclosed policy."
    }

    @ViewBuilder
    private func choiceStatus(allowed: Bool, consent: PhysiqueConsent) -> some View {
        let changed = !consent.policyVersion.isEmpty && policy?.version != nil && consent.policyVersion != policy?.version
        Label(changed ? "Review update · last confirmed choice: \(allowed ? "allowed" : "not allowed")" : allowed ? "Allowed · last confirmed" : consent.policyVersion.isEmpty ? "Not chosen in a recorded policy" : "Not allowed · last confirmed", systemImage: changed ? "exclamationmark.circle" : allowed ? "checkmark.circle" : "minus.circle")
            .font(TimeMasterFont.label())
        if !consent.policyVersion.isEmpty {
            Text("Recorded policy: \(consent.policyVersion)").font(TimeMasterFont.secondary())
        }
        if !allowed, !consent.policyVersion.isEmpty {
            Text("The account response does not distinguish a decline from withdrawal. Actual withdrawal requests are shown in receipts.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    @ViewBuilder
    private func pendingChoice(_ operation: String) -> some View {
        if activeRequest?.operation == operation {
            Label("Requested here · awaiting acknowledgement", systemImage: "hourglass")
                .font(TimeMasterFont.secondary())
        } else if unconfirmedRequests.contains(where: { $0.operation == operation }) {
            Label("Requested here · remote change not confirmed", systemImage: "exclamationmark.circle")
                .font(TimeMasterFont.secondary())
        }
    }

    private func listingStatus(_ account: PhysiqueAccount) -> String {
        guard account.listed else { return "Not listed · last confirmed choice" }
        if account.restrictedReason?.isEmpty == false { return "Allowed · not listed while restricted" }
        if account.record.games < 5 { return "Allowed · not listed yet — \(account.identity.placementLabel)" }
        return "Listing allowed · public position not supplied"
    }

    private func receiptStatus(_ status: String) -> String {
        switch status {
        case "notSent": return "Request not sent"
        case "notConfirmed": return "Remote change not confirmed"
        case "received": return "Received"
        case "inProgress": return "In progress"
        case "partiallyHeld": return "Partially held"
        case "completed": return "Completed in active systems"
        default: return status
        }
    }

    private func statusLine(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(TimeMasterFont.label())
            Text(value).font(TimeMasterFont.secondary()).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func timestamp(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            Text(date, format: .dateTime.year().month().day().hour().minute())
        }
        .font(TimeMasterFont.caption())
        .foregroundStyle(ProfileStyle.secondary)
        .accessibilityElement(children: .combine)
    }

    private func disclosure(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not supplied" : value
    }

    private func clock(for match: PhysiqueMatch) -> PhysiqueClock {
        if store.isStale {
            return PhysiqueClock(mode: .unavailable, label: "\(match.stage.title) · awaiting confirmation", endpoint: nil, serverOffset: store.serverOffset)
        }
        switch match.stage {
        case .countdown:
            return PhysiqueClock(mode: .countdown, label: "Match starts", endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture, .submitting:
            return PhysiqueClock(mode: .remaining, label: match.stage.title, endpoint: match.deadline, serverOffset: store.serverOffset)
        case .judging:
            return PhysiqueClock(mode: .elapsed, label: "Judging · elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        case .ready:
            return PhysiqueClock(mode: .remaining, label: "Ready room", endpoint: match.deadline, serverOffset: store.serverOffset)
        default:
            return PhysiqueClock(mode: .unavailable, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        }
    }

    private var matchRoute: PhysiqueRoute {
        switch store.stage {
        case .searching: return .search
        case .ready: return .ready
        case .judging, .submitting: return .judging
        default: return .battle
        }
    }

    private func open(_ route: PhysiqueRoute) {
        store.suspendCapture()
        onOpen(route)
    }

    private func prepare(_ kind: RequestKind, matchID: String? = nil) {
        guard canMutate, let accountID = activeAccountID else { return }
        let request: PrivacyRequest
        switch kind {
        case .ai:
            request = PrivacyRequest(accountID: accountID, kind: kind, operation: "withdrawAI", matchID: store.match?.id, value: nil, title: "Withdraw AI sharing", scope: "This account’s AI and safety-processing permission", consequence: stageConsequence(for: kind) + " New local capture stops immediately. Already accepted processor work may not be retractable. This is not an explicit forfeit or a promise of a particular outcome.")
            confirmsAI = true
        case .sharing:
            request = PrivacyRequest(accountID: accountID, kind: kind, operation: "withdrawSharing", matchID: store.match?.id, value: nil, title: "Withdraw opponent access", scope: "Future authorized opponent viewing of this account’s own pose stills", consequence: stageConsequence(for: kind) + " It does not recall screenshots or external recordings, remove another person’s photos, or restore a restricted gallery.")
            confirmsSharing = true
        case .listing:
            guard let account = store.account else { return }
            let allow = !account.listed
            guard !allow || unconfirmedRequests.isEmpty && !store.isStale else { return }
            request = PrivacyRequest(accountID: accountID, kind: kind, operation: "listing", matchID: nil, value: allow, title: allow ? "Allow public listing" : "Remove public listing", scope: "Physique public standings only", consequence: allow ? listingPreview(account) : "Request removal of your public Physique standings entry. Until acknowledged, public removal is not confirmed. Your paired match identity, Elo, legitimate record, pose permissions and Tmax account are unchanged.")
            listingDetails = true
            confirmsListing = true
        case .removal:
            request = PrivacyRequest(accountID: accountID, kind: kind, operation: "removeImages", matchID: matchID, value: nil, title: matchID == nil ? "Remove all my shared poses" : "Remove my poses in this match", scope: matchID.map { "Only my ordinary Physique pose media in match \($0)" } ?? "All my ordinary shared Physique candidate/selected media and viewable derivatives", consequence: stageConsequence(for: kind) + " Ordinary counterpart access is revoked as the service confirms removal. Limited lawful holds and processor retention are separately reported; external copies cannot be recalled. Legitimate Elo is not reset. Future participation choices stay separate, and removed evidence is not automatically resent.")
            if matchID == nil { confirmsAllRemoval = true }
            else { confirmsRemoval = true }
        }
        confirmation = request
    }

    private func stageConsequence(for kind: RequestKind) -> String {
        let stage = store.stage
        if stage == .searching || stage == .ready || stage == .countdown {
            if kind == .removal {
                return "Removing current evidence does not withdraw future permission. If evidence removal prevents entry, the service reconciles cancellation and reservation release. This action never silently becomes a confirmed forfeit if Go wins the race."
            }
            return "Before service Go, missing required sharing prevents or cancels entry. No Elo or started-slot charge applies only when cancellation is accepted before Go. A race with Go is reconciled by the service, never converted here into a forfeit."
        }
        if stage == .capture || stage == .submitting || stage == .judging {
            if kind == .sharing {
                return "After Go, withdrawing only opponent access does not forfeit, cancel separately authorized AI processing, or reverse Elo. The existing match and its deadlines continue under the service’s rules."
            }
            return "The match has started. Stopping or removing required evidence may prevent completion. The service determines validity, finality and any allowance consequence; safety, invalid evidence and service-aborted no-contest take precedence over rated departure. Already accepted work may still produce a confirmed outcome."
        }
        if stage.terminal {
            return "This does not reroll the confirmed result, reverse legitimate Elo, restart photo expiry or reopen the match."
        }
        return "This does not delete the Tmax account or affect unrelated app features. Required permissions must be current before new rated participation."
    }

    private func listingPreview(_ account: PhysiqueAccount) -> String {
        let rating = account.record.rating.map { "\($0) Physique Elo" } ?? "Unplaced; no earned Physique Elo supplied"
        let country = account.identity.countryCode.map { "Self-declared country/region: \($0)." } ?? "No country/region declared."
        let badges = account.identity.badges.isEmpty ? "No public earned badges supplied." : "Public badges: " + account.identity.badges.map(\.title).joined(separator: ", ") + "."
        let streak = account.identity.streak.map { " Current streak: \($0)." } ?? ""
        return "Allow the permitted Physique public identity: \(account.identity.displayName), \(rating), \(account.identity.placementLabel). \(account.record.wins) wins, \(account.record.losses) losses, \(account.record.draws) draws; \(account.record.games) rated matches. \(country) \(badges)\(streak) No pose photos, private eligibility, reports, email, precise location or local Profile photo. Listing waits for placement and applicable restrictions; no public rank is promised."
    }

    private func submit(_ request: PrivacyRequest) {
        guard activeRequest == nil, request.accountID == activeAccountID else { return }
        dismissConfirmations()
        store.suspendCapture()
        if request.operation == "withdrawAI" || request.operation == "removeImages" {
            camera.clear()
        }
        activeRequest = request
        acknowledgement = nil
        actionError = nil
        Task {
            let confirmed = await store.perform(request.operation, matchID: request.matchID, value: request.value)
            guard request.accountID == activeAccountID, activeRequest?.id == request.id else { return }
            activeRequest = nil
            if confirmed {
                unconfirmedRequests.removeAll { $0.hasSamePayload(as: request) }
                acknowledgement = Acknowledgement(request: request, reference: store.lastReceiptID, message: store.notice ?? "The service confirmed this request. Read the actual scope and status in its receipt; acknowledgement alone is not universal erasure.")
            } else {
                if !unconfirmedRequests.contains(where: { $0.hasSamePayload(as: request) }) {
                    unconfirmedRequests.append(request)
                }
                actionError = store.error ?? "The remote change is not confirmed. Check status or retry this exact request."
            }
            if scenePhase == .active { accessibilityFocus = .request }
            await loadReceipts(accountID: request.accountID)
        }
    }

    private func requestRefresh() { refreshID = UUID() }

    private func load(context: LoadContext) async {
        guard context.active else { return }
        if store.policy == nil { await store.loadPolicy() }
        guard !Task.isCancelled, let accountID = context.accountID, accountID == activeAccountID else { return }
        await store.refresh()
        guard !Task.isCancelled, accountID == activeAccountID else { return }
        await loadReceipts(accountID: accountID)
    }

    private func loadReceipts(accountID: String) async {
        guard accountID == activeAccountID else { return }
        let ticket = UUID()
        receiptLoadID = ticket
        receiptsLoading = true
        defer {
            if accountID == activeAccountID, receiptLoadID == ticket { receiptsLoading = false }
        }
        do {
            let response = try await store.privacyReceipts()
            guard !Task.isCancelled, accountID == activeAccountID, receiptLoadID == ticket else { return }
            receipts = response.sorted { $0.updatedAt > $1.updatedAt }
            receiptAccountID = accountID
            receiptsLoadedAt = Date()
            receiptsError = nil
        } catch is CancellationError {
        } catch {
            guard accountID == activeAccountID, receiptLoadID == ticket else { return }
            receiptsError = error.localizedDescription
        }
    }

    private func dismissConfirmations() {
        confirmsAI = false
        confirmsSharing = false
        confirmsListing = false
        confirmsRemoval = false
        confirmsAllRemoval = false
        confirmation = nil
    }

    private func clearPrivateState() {
        store.suspendCapture()
        receipts = []
        receiptAccountID = nil
        receiptsLoadedAt = nil
        receiptsLoading = false
        receiptsError = nil
        receiptLoadID = UUID()
        activeRequest = nil
        unconfirmedRequests = []
        acknowledgement = nil
        actionError = nil
        processingDetails = false
        opponentDetails = false
        listingDetails = false
        accessibilityFocus = nil
        dismissConfirmations()
    }
}
