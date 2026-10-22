import SwiftUI
import Combine

@MainActor
struct PhysiqueReportComposerView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let target: PhysiqueReportTarget

    @ObservedObject private var account = CloudAccountStore.shared
    @StateObject private var draft: PhysiqueReportDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.physiqueWindowID) private var windowID
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?
    @AccessibilityFocusState private var accessibleField: Field?
    @State private var confirmsClose = false
    @State private var confirmsBlock = false
    @State private var confirmsWithdrawal = false
    @State private var confirmsExit = false
    @State private var pendingRoute: PhysiqueRoute?
    @State private var contextMatch: PhysiqueMatch?
    @State private var exitIntent: ExitIntent?
    @State private var exitError: String?
    @State private var isExiting = false
    @State private var evidenceExpanded = false

    private enum Field: Hashable { case heading, reason, note }
    private enum ExitIntent { case cancelQueue, cancelMatch(String), forfeit(String) }

    init(store: PhysiqueStore, onOpen: @escaping (PhysiqueRoute) -> Void, target: PhysiqueReportTarget) {
        self.store = store
        self.onOpen = onOpen
        self.target = target
        _draft = StateObject(wrappedValue: PhysiqueReportDrafts.shared.draft(for: target))
    }

    private var sameAccount: Bool {
        draft.accountID != nil && draft.accountID == account.accountID && draft.valid
    }

    private var ownsDraft: Bool { draft.windowID == windowID }
    private var noteCount: Int { draft.note.unicodeScalars.count }
    private var isImage: Bool { target.kind == "image" || target.kind == "media" || target.kind == "pose" }
    private var isExplanation: Bool { target.kind == "explanation" }
    private var isIdentity: Bool { target.kind == "identity" || target.kind == "player" || target.kind == "profile" }
    private var matchID: String? {
        target.matchID ?? (target.kind == "match" || isExplanation ? target.id : nil)
    }
    private var referencedMatch: PhysiqueMatch? {
        guard sameAccount, let matchID else { return nil }
        if let match = store.match, match.id == matchID { return match }
        return contextMatch?.id == matchID ? contextMatch : nil
    }
    private var targetTitle: String {
        if isImage { return "Selected pose image" }
        if isExplanation { return "Match explanation" }
        if isIdentity { return "Player profile" }
        return "Selected match"
    }
    private var blockTargetID: String? {
        guard sameAccount, !isExplanation else { return nil }
        let candidate = isIdentity ? target.id : referencedMatch?.opponent.identity.id
        guard let candidate, !candidate.isEmpty, candidate != store.account?.identity.id else { return nil }
        return candidate
    }
    private var supportURL: URL? {
        guard let value = store.policy?.supportURL, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), ["https", "http", "mailto"].contains(scheme) else { return nil }
        return url
    }
    private var intakeConfigured: Bool {
        guard let policy = store.policy else { return false }
        return !policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !policy.retention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && supportURL != nil
    }
    private var unavailableReason: String? {
        if !sameAccount { return "Sign in with the account that opened this report. No other account can use this draft." }
        if !ownsDraft { return "This report is already open in another Tmax window. Continue there to keep one private draft." }
        if target.id.isEmpty { return "The selected item reference is unavailable. Nothing has been sent." }
        if store.policy == nil { return "The service policy is unavailable. Your draft has not been sent." }
        if !intakeConfigured { return "Report intake is unavailable because the service has not published its operator, retention policy and support contact." }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                matchStrip
                if sameAccount && ownsDraft {
                    reportForm
                } else {
                    PhysiqueStatusView(title: "Private report unavailable", detail: unavailableReason ?? "Close and reopen this report from its original account.", systemImage: "lock.shield")
                        .padding(ProfileStyle.inset)
                    Spacer(minLength: 0)
                }
            }
            .background(Theme.background)
            .foregroundStyle(Theme.textPrimary)
            .font(TimeMasterFont.body())
            .tint(Theme.toolbarOrange)
            .navigationTitle(draft.receiptID == nil ? "Report" : "Report received")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                #endif
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionFooter }
            .confirmationDialog("Keep this temporary draft?", isPresented: $confirmsClose, titleVisibility: .visible) {
                Button("Keep temporary draft") { finishClose() }
                Button("Discard unsent changes", role: .destructive) {
                    draft.discardEdits()
                    finishClose()
                }
                Button("Continue editing", role: .cancel) { pendingRoute = nil }
            } message: {
                Text("The text stays only in this signed-in account's memory while Tmax stays open, until the expiry shown in the form. It is not saved to disk or another device. Closing does not withdraw or cancel a report already being sent.")
            }
            .confirmationDialog("Block this player?", isPresented: $confirmsBlock, titleVisibility: .visible) {
                Button("Block player", role: .destructive) { blockPlayer() }
                Button("Cancel", role: .cancel) {}
            } message: { Text(blockExplanation) }
            .confirmationDialog("Withdraw this report?", isPresented: $confirmsWithdrawal, titleVisibility: .visible) {
                Button("Withdraw report", role: .destructive) {
                    Task { await draft.withdraw(using: store) }
                }
                Button("Keep report", role: .cancel) {}
            } message: {
                Text("You will no longer be pursuing this request. Necessary safety review or a lawful evidence hold may continue. Hiding and blocking remain unchanged. This does not erase records or change the match result.")
            }
            .confirmationDialog(exitConfirmationTitle, isPresented: $confirmsExit, titleVisibility: .visible) {
                Button(exitActionTitle, role: .destructive) { exitMatch() }
                Button("Stay", role: .cancel) {}
            } message: { Text(exitExplanation) }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        #if os(macOS)
        .onExitCommand { requestClose() }
        .frame(idealWidth: ProfileStyle.readableWidth, idealHeight: 520)
        #endif
        .interactiveDismissDisabled(sameAccount && ownsDraft && draft.hasEdits)
        .privacySensitive()
        .accessibilityHidden(!presentationActive || scenePhase != .active)
        .overlay {
            if !presentationActive || scenePhase != .active {
                Theme.background.ignoresSafeArea()
                    .overlay {
                        Label("Private report hidden", systemImage: "lock.fill")
                            .font(TimeMasterFont.heading())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Private report hidden")
            }
        }
        .onAppear {
            store.suspendCapture()
            if sameAccount {
                draft.claim(windowID)
                if isImage { store.hideMedia(target.id) }
                if isExplanation { store.hideExplanation(target.id) }
                accessibleField = .heading
            }
        }
        .onDisappear { draft.release(windowID) }
        .onChange(of: draft.reason) { _ in draft.didEdit() }
        .onChange(of: draft.note) { _ in draft.didEdit() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { draft.expireIfNeeded() }
        }
        .onChange(of: presentationActive) { active in
            if active { draft.expireIfNeeded() }
        }
        .onChange(of: account.accountID) { _ in
            contextMatch = nil
            focusedField = nil
            pendingRoute = nil
            confirmsClose = false
            confirmsBlock = false
            confirmsWithdrawal = false
            confirmsExit = false
        }
        .task {
            if store.policy == nil { await store.loadPolicy() }
            guard sameAccount else { return }
            if let matchID, store.match?.id != matchID {
                let owner = account.accountID
                if let match = try? await store.getMatch(matchID), owner == account.accountID, sameAccount {
                    contextMatch = match
                }
            }
            if draft.receiptID != nil { await draft.loadCase(using: store) }
        }
    }

    private var closeButton: some View {
        Button("Close") { requestClose() }
            #if os(macOS)
            .keyboardShortcut("w", modifiers: .command)
            #endif
    }

    private var reportForm: some View {
        Form {
            SwiftUI.Section {
                Label(targetTitle, systemImage: "flag")
                    .font(TimeMasterFont.heading())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibleField, equals: .heading)
                if let match = referencedMatch {
                    Text(Date(timeIntervalSince1970: match.createdAt), format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                Text("Item reference: \(target.id)")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Text("The original protected item reference is used. No photo, thumbnail or quoted explanation is attached.")
                    .foregroundStyle(ProfileStyle.secondary)
                if isImage || isExplanation {
                    Label(isExplanation ? "Explanation hidden on this device" : "Image hidden on this device", systemImage: "eye.slash")
                }
            } header: { Text("Report target") }
            .listRowBackground(Theme.surface)

            if draft.receiptID != nil { receiptSection }

            SwiftUI.Section {
                Picker("Reason — required", selection: $draft.reason) {
                    Text("Choose a reason").tag(PhysiqueReportReason?.none)
                    ForEach(PhysiqueReportReason.allCases) { reason in
                        Text(reason.title).tag(Optional(reason))
                    }
                }
                .pickerStyle(.menu)
                .focused($focusedField, equals: .reason)
                .accessibilityFocused($accessibleField, equals: .reason)
                if let reason = draft.reason {
                    Text(reason.title).font(TimeMasterFont.label())
                    Text(reason.help).foregroundStyle(ProfileStyle.secondary)
                        .transition(.opacity)
                }
                if draft.reasonError {
                    Label("Choose a reason to submit this report.", systemImage: "exclamationmark.circle")
                }
            } header: { Text("Reason") }
            .listRowBackground(Theme.surface)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: draft.reason)

            SwiftUI.Section {
                TextEditor(text: $draft.note)
                    .font(TimeMasterFont.body())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .focused($focusedField, equals: .note)
                    .accessibilityFocused($accessibleField, equals: .note)
                    .accessibilityLabel("Note — optional")
                    .accessibilityHint("Add safe context as text. No attachment is accepted.")
                Text("Add context, not screenshots or personal contact details. An empty note is valid.")
                    .foregroundStyle(ProfileStyle.secondary)
                Text("\(noteCount.formatted()) of 4,000 service characters")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(noteCount > 4_000 ? Theme.toolbarOrange : ProfileStyle.secondary)
                if noteCount > 4_000 {
                    Label("The service accepts at most 4,000 Unicode characters. Your text has not been shortened; edit it before sending.", systemImage: "exclamationmark.circle")
                }
                draftStatus
            } header: { Text("Note — optional") }
            .listRowBackground(Theme.surface)

            evidenceSection
            protectionSection

            if let match = referencedMatch, match.result?.isJudged == true {
                SwiftUI.Section {
                    Button("Request scoring review") {
                        requestClose(opening: .review(PhysiqueReviewTarget(kind: "dispute", id: match.id, matchID: match.id)))
                    }
                    Text("A scoring disagreement is a separate private review, not a safety allegation. This note is not sent to that review automatically.")
                        .foregroundStyle(ProfileStyle.secondary)
                }
                .listRowBackground(Theme.surface)
            }

            if let reason = unavailableReason {
                SwiftUI.Section {
                    PhysiqueStatusView(title: "Not sent", detail: reason, retry: {
                        Task { await store.loadPolicy() }
                    })
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: ProfileStyle.readableWidth)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var draftStatus: some View {
        if draft.expired {
            Label("The previous temporary draft expired and its text was cleared. This does not withdraw a report that may have been received.", systemImage: "clock")
        }
        if let expiry = draft.expiresAt, draft.hasEdits {
            VStack(alignment: .leading, spacing: 4) {
                Text("Temporary draft — not saved to disk")
                Text("Clears by \(expiry.formatted(date: .abbreviated, time: .shortened)), when Tmax exits, or when this account signs out or changes.")
            }
            .font(TimeMasterFont.secondary())
            .foregroundStyle(ProfileStyle.secondary)
        }
        if draft.hasEdits && (draft.delivery == .received || draft.delivery == .sending || draft.delivery == .unconfirmed) && !draft.matchesPendingEdits {
            Label("Your latest changes have not been sent.", systemImage: "square.and.pencil")
                .font(TimeMasterFont.secondary())
        }
    }

    private var evidenceSection: some View {
        SwiftUI.Section {
            if let policy = store.policy, intakeConfigured {
                Text("Your selected reference, reason and note go to \(policy.operatorName) for private safety handling. Necessary existing evidence may be used. No new photo is attached.")
                Text(policy.retention).foregroundStyle(ProfileStyle.secondary)
            } else {
                Text("The operator and evidence-retention disclosure must be available before this report can be sent.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            DisclosureGroup("Evidence and privacy", isExpanded: $evidenceExpanded) {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Reports use the existing authorized item and necessary decision records. They do not request a new capture, an unredacted original or your full photo history.")
                    Text("Report text is private to your case and authorized safety handling, not public or sent to the opponent. It is not appearance-judge input.")
                    Text("A draft or an unconfirmed send does not establish an evidence hold. Expired or deleted images cannot be restored by reporting. A case does not extend ordinary gallery access.")
                    Text("Duplicate reports, added context and appeals do not restart an evidence-hold clock. Case correspondence and necessary legal or urgent-safety records can follow different disclosed retention rules.")
                    Text("Do not download, screenshot, forward or reupload suspected exploitative material. Withdrawal does not guarantee that necessary safety review or lawful preservation stops.")
                    Button("Open privacy information") { requestClose(opening: .privacy) }
                }
                .padding(.top, ProfileStyle.spacing)
                .foregroundStyle(ProfileStyle.secondary)
            }
            if draft.reason == .urgent {
                Label("This app is not an emergency service and does not promise continuous monitoring. If someone is in immediate danger, contact your local emergency services.", systemImage: "exclamationmark.shield")
            }
            if let supportURL {
                Link("Published support contact", destination: supportURL)
            } else {
                Text("A support contact has not been published by the service.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } header: { Text("Before you send") }
        .listRowBackground(Theme.surface)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: evidenceExpanded)
    }

    private var protectionSection: some View {
        SwiftUI.Section {
            if isImage || isExplanation {
                Label(isExplanation ? "Explanation hidden locally" : "Image hidden locally", systemImage: "eye.slash.fill")
                Text("It stays hidden when you close this form or if sending fails. Hiding alone does not send a report or change a result.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if blockTargetID != nil {
                Button(draft.blockConfirmed ? "Player blocked" : draft.blockPending ? "Retry pending block" : isIdentity ? "Block player" : "Block match opponent", role: .destructive) {
                    confirmsBlock = true
                }
                .disabled(draft.blockSending || draft.blockConfirmed)
                .frame(minHeight: ProfileStyle.touchTarget)
                if draft.blockSending {
                    ProgressView("Confirming block…")
                } else if draft.blockPending {
                    Label("Block pending — this device is shielded. Future pairing and other devices are not confirmed yet.", systemImage: "shield.lefthalf.filled")
                } else if draft.blockConfirmed {
                    Label("Block confirmed by the service. Completed results remain unchanged.", systemImage: "checkmark.shield")
                }
                if let error = draft.blockError { Text(error).foregroundStyle(ProfileStyle.secondary) }
                Text("Block is separate from Report and needs no report reason. It does not send this note.")
                    .foregroundStyle(ProfileStyle.secondary)
                if !isIdentity {
                    Text("This protects you from the opponent identified by this match's record. It does not identify them as the owner of the selected image or as responsible for this report.")
                        .foregroundStyle(ProfileStyle.secondary)
                }
            } else if !isImage && !isExplanation {
                Text("Reporting does not block a player or change a competitive result.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
        } header: { Text("Independent protection") }
        .listRowBackground(Theme.surface)
    }

    private var receiptSection: some View {
        SwiftUI.Section {
            Label("Report received", systemImage: "checkmark.shield")
                .font(TimeMasterFont.heading())
            if let receiptID = draft.receiptID {
                Text(receiptID)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Case reference \(receiptID)")
            }
            if let record = draft.receivedCase {
                Text("Received \(Date(timeIntervalSince1970: record.createdAt).formatted(date: .abbreviated, time: .shortened))")
                Text(caseStatus(record.status)).font(TimeMasterFont.label())
                if record.canWithdraw && !draft.withdrawalConfirmed {
                    Button(draft.withdrawalUnknown ? "Retry withdrawal" : "Withdraw report", role: .destructive) {
                        confirmsWithdrawal = true
                    }
                    .disabled(draft.withdrawing || store.busy)
                }
            }
            Text("This is a service acknowledgement, not a promise that a person has started review or that the result will change. A duplicate resolves to the existing case, not another complaint vote.")
                .foregroundStyle(ProfileStyle.secondary)
            if draft.loadingCase { ProgressView("Loading confirmed case…") }
            if let error = draft.caseError {
                Text("Receipt confirmed. Current case details could not be loaded: \(error)")
                    .foregroundStyle(ProfileStyle.secondary)
                Button("Refresh case status") { Task { await draft.loadCase(using: store) } }
                    .disabled(draft.loadingCase)
            }
            if draft.withdrawing { ProgressView("Withdrawing request…") }
            if draft.withdrawalConfirmed {
                Label("Withdrawal acknowledged. Necessary safety handling may continue; hiding and blocking remain.", systemImage: "checkmark.circle")
            } else if draft.withdrawalUnknown {
                Label("Withdrawal not confirmed. The last confirmed case remains available; retry uses the same case.", systemImage: "questionmark.circle")
            }
            if let error = draft.withdrawalError { Text(error).foregroundStyle(ProfileStyle.secondary) }
        } header: { Text("Private receipt") }
        .listRowBackground(Theme.surface)
    }

    private var actionFooter: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Divider()
            if sameAccount && ownsDraft {
                deliveryStatus
                if let error = draft.deliveryError { Text(error).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary) }
                if let reason = unavailableReason { Text(reason).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary) }
                #if os(macOS)
                HStack {
                    Spacer(minLength: 0)
                    footerButton.buttonStyle(.borderedProminent)
                }
                #else
                footerButton.buttonStyle(TimeMasterActionButtonStyle(prominent: true, fillsWidth: true))
                #endif
            } else {
                if !store.signedIn {
                    Button("Open Tmax account") { requestClose(opening: .account) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, ProfileStyle.inset)
        .padding(.bottom, ProfileStyle.spacing)
        .frame(maxWidth: ProfileStyle.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    private var deliveryStatus: some View {
        switch draft.delivery {
        case .editing:
            Text(draft.reason == nil ? "Choose a reason. Nothing has been sent." : "Not sent — Submit sends only the version you choose now.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        case .sending:
            ProgressView("Sending report…")
            Text("The captured version is being sent. You may keep editing; later changes are not sent automatically.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        case .unconfirmed:
            Label("Receipt unknown", systemImage: "questionmark.circle")
                .font(TimeMasterFont.label())
            Text(draft.pending == nil
                 ? "The draft's text expired or was cleared. No receipt is confirmed here. Use Safety to inspect your private cases; do not assume the report was cancelled."
                 : "The service may have received the original version. Retry sends that same captured version, not your later edits, and resolves to one case.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        case .received:
            if draft.hasEdits {
                Text("Later edits remain unsent. Open the confirmed case for any additional context; they are not appended automatically.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        if let receiptID = draft.receiptID {
            Button("View case") { requestClose(opening: .caseDetail(receiptID)) }
                .frame(minHeight: ProfileStyle.touchTarget)
        } else if draft.delivery == .unconfirmed && draft.pending == nil {
            Button("Open Safety") { requestClose(opening: .safety) }
                .frame(minHeight: ProfileStyle.touchTarget)
        } else {
            Button(draft.delivery == .unconfirmed ? "Retry same report" : draft.delivery == .sending ? "Sending…" : "Submit report") {
                submit()
            }
            .frame(minHeight: ProfileStyle.touchTarget)
            .disabled(draft.delivery == .sending || unavailableReason != nil || store.busy)
            .accessibilityHint(draft.reason == nil ? "Choose a reason before sending. The note is optional." : "Sends a private safety report. Does not block or change the match.")
        }
    }

    @ViewBuilder
    private var matchStrip: some View {
        if sameAccount, let match = store.match, !match.stage.terminal {
            VStack(spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ProfileStyle.spacing) {
                        PhysiqueTimerView(clock: reportClock(match))
                        Button("Exit match") { prepareExit() }
                            .frame(minHeight: ProfileStyle.touchTarget)
                            .disabled(isExiting || !store.canControl(from: windowID))
                    }
                    VStack(spacing: 4) {
                        PhysiqueTimerView(clock: reportClock(match))
                        Button("Exit match") { prepareExit() }
                            .frame(minHeight: ProfileStyle.touchTarget)
                            .disabled(isExiting || !store.canControl(from: windowID))
                    }
                }
                Text("Camera stopped. Match time continues.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                if !store.canControl(from: windowID) {
                    Text("Match exit is controlled by the other active Tmax window. Safety protection remains available here.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
                if let exitError { Text(exitError).font(TimeMasterFont.secondary()) }
            }
            .padding(.horizontal, ProfileStyle.inset)
            .background(Theme.surface)
        } else if sameAccount, store.stage == .searching {
            VStack(spacing: 4) {
                PhysiqueTimerView(clock: PhysiqueClock(mode: store.isStale ? .unavailable : .remaining, label: "Opponent search", endpoint: store.snapshot?.queueDeadline, serverOffset: store.serverOffset))
                Button("Cancel search") { prepareExit() }
                    .disabled(isExiting || !store.canControl(from: windowID))
                if let exitError { Text(exitError).font(TimeMasterFont.secondary()) }
            }
            .padding(.horizontal, ProfileStyle.inset)
            .background(Theme.surface)
        }
    }

    private func reportClock(_ match: PhysiqueMatch) -> PhysiqueClock {
        if store.isStale { return PhysiqueClock(mode: .unavailable, label: "Match time not confirmed", endpoint: nil, serverOffset: store.serverOffset) }
        switch match.stage {
        case .countdown:
            return PhysiqueClock(mode: .countdown, label: "Match starts in", endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture, .submitting:
            return PhysiqueClock(mode: .remaining, label: match.stage.title, endpoint: match.deadline, serverOffset: store.serverOffset)
        case .judging:
            return PhysiqueClock(mode: .elapsed, label: "Judging elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        default:
            return PhysiqueClock(mode: .unavailable, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        }
    }

    private var blockExplanation: String {
        guard let match = store.match, !match.stage.terminal, match.opponent.identity.id == blockTargetID else {
            return "Hide this player's media and prevent future pairings after service confirmation. Completed results remain unchanged. Report and Block are separate; your note is not sent by blocking."
        }
        if match.stage == .ready || match.stage == .countdown || match.stage == .searching {
            return "Before Go, blocking cancels this pairing without a rating change. If Go has already occurred, the service applies the actual current stage: blocking shields the player but does not leave or finalize the match. Your note is not sent."
        }
        return "This match has started. Blocking shields this player's media and prevents future pairings after confirmation, but the match and its timer continue. Block alone does not leave, forfeit or change a rating. Your note is not sent."
    }

    private func submit() {
        guard sameAccount, ownsDraft, unavailableReason == nil else { return }
        if draft.delivery != .unconfirmed {
            guard draft.reason != nil else {
                draft.reasonError = true
                focusedField = .reason
                accessibleField = .reason
                return
            }
            guard noteCount <= 4_000 else {
                focusedField = .note
                accessibleField = .note
                return
            }
        }
        Task { await draft.send(using: store) }
    }

    private func blockPlayer() {
        guard sameAccount, let playerID = blockTargetID, !draft.blockSending else { return }
        store.suspendCapture()
        if isImage { store.hideMedia(target.id) }
        if isExplanation { store.hideExplanation(target.id) }
        draft.blockPending = true
        draft.blockSending = true
        draft.blockError = nil
        let owner = account.accountID
        Task {
            let success = await store.perform("block", targetID: playerID)
            guard sameAccount, owner == account.accountID else { return }
            draft.blockSending = false
            draft.blockConfirmed = success
            draft.blockPending = !success
            if !success { draft.blockError = store.error ?? "The block has not been confirmed. Local protection remains active." }
        }
    }

    private func requestClose(opening route: PhysiqueRoute? = nil) {
        pendingRoute = route
        focusedField = nil
        if sameAccount && ownsDraft && draft.hasEdits {
            confirmsClose = true
        } else {
            finishClose()
        }
    }

    private func finishClose() {
        let route = pendingRoute
        pendingRoute = nil
        draft.release(windowID)
        dismiss()
        if let route { onOpen(route) }
    }

    private func prepareExit() {
        guard sameAccount, store.canControl(from: windowID) else { return }
        if let match = store.match, !match.stage.terminal {
            switch match.stage {
            case .ready, .countdown, .searching:
                exitIntent = .cancelMatch(match.id)
            case .capture, .submitting, .judging:
                exitIntent = .forfeit(match.id)
            default: return
            }
        } else if store.stage == .searching {
            exitIntent = .cancelQueue
        } else { return }
        confirmsExit = true
    }

    private var exitConfirmationTitle: String {
        if case .forfeit = exitIntent { return "Forfeit and leave?" }
        return "Cancel this pairing?"
    }
    private var exitActionTitle: String {
        if case .forfeit = exitIntent { return "Forfeit and leave" }
        return "Cancel pairing"
    }
    private var exitExplanation: String {
        if case .forfeit = exitIntent {
            return "Leaving an otherwise eligible started match may record a rated forfeit. A service-established no-contest takes precedence. Reporting or blocking alone does not leave the match. Your temporary report draft stays within its existing expiry."
        }
        return "Cancellation before Go changes no rating. If Go races this request, it is not permission to forfeit; the service must confirm the actual state. Your temporary report draft stays within its existing expiry."
    }

    private func exitMatch() {
        guard sameAccount, store.canControl(from: windowID), !isExiting, let exitIntent else { return }
        isExiting = true
        exitError = nil
        let owner = account.accountID
        Task {
            let success: Bool
            switch exitIntent {
            case .cancelQueue:
                guard store.stage == .searching else { isExiting = false; return }
                success = await store.perform("cancel")
            case .cancelMatch(let id):
                guard store.match?.id == id else { isExiting = false; return }
                success = await store.perform("leave", matchID: id, reason: "cancel")
            case .forfeit(let id):
                guard store.match?.id == id else { isExiting = false; return }
                success = await store.perform("leave", matchID: id, reason: "forfeit")
            }
            guard sameAccount, owner == account.accountID else { return }
            isExiting = false
            if success {
                draft.release(windowID)
                dismiss()
                onOpen(.lobby)
            } else {
                exitError = store.error ?? "The match exit has not been confirmed. No result is assumed."
            }
        }
    }

    private func caseStatus(_ value: String) -> String {
        switch value {
        case "received": return "Received"
        case "queued": return "Queued"
        case "inReview", "in_review": return "In review"
        case "needsReply", "needs_reply": return "More safe information requested"
        case "withdrawn": return "Withdrawn"
        case "closed": return "Closed"
        default: return "Open the case for its current confirmed status"
        }
    }
}

private enum PhysiqueReportReason: String, CaseIterable, Identifiable {
    case nudity, sexual, eligibility, privacy, harassment, integrity, unsafeAI, urgent, spam, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nudity: return "Nudity or prohibited exposure"
        case .sexual: return "Sexual or exploitative content"
        case .eligibility: return "Adult eligibility concern"
        case .privacy: return "Nonconsensual image, bystander or privacy"
        case .harassment: return "Harassment, discrimination or bullying"
        case .integrity: return "Impersonation or manipulated evidence"
        case .unsafeAI: return "Unsafe or inappropriate AI explanation"
        case .urgent: return "Urgent personal safety"
        case .spam: return "Spam or coordinated abuse"
        case .other: return "Other safety concern"
        }
    }
    var help: String {
        switch self {
        case .nudity: return "Nonsexual shirtless adult men are permitted. Groin and buttocks must stay covered, and each participant must follow their privately declared attire rule. Appearance cannot prove age, sex, gender or a false declaration. You can report context without reopening the image."
        case .sexual: return "Report sexualized presentation, solicitation, intimate-image misuse or suspected exploitation. Do not attach, forward or describe graphic details."
        case .eligibility: return "Share only safe context relevant to adult eligibility. Do not guess age from appearance or send proof photos or identity documents."
        case .privacy: return "Report missing permission, another person in a capture, doxxing or misuse of an image. Do not add another person's private details or photo."
        case .harassment: return "Use safe context for threats, abusive names, discrimination or body shaming. This note is not sent to the opponent."
        case .integrity: return "Report substituted people, prerecorded material or prohibited manipulation. Ordinary face obscuring is a privacy measure, not cheating."
        case .unsafeAI: return "Report unsafe generated wording separately from disagreement with a numerical score. The original explanation is not repeated here."
        case .urgent: return "This app is not an emergency service. Contact local emergency services for immediate danger; the published support channel does not promise continuous monitoring."
        case .spam: return "Report spam or coordinated misuse. A report count is not proof of misconduct."
        case .other: return "Choose this for a relevant safety concern outside the named categories. Your note is optional."
        }
    }
}

private struct PhysiqueReportSubmission: Equatable {
    let reason: PhysiqueReportReason
    let note: String
}

@MainActor
private final class PhysiqueReportDraft: ObservableObject {
    enum Delivery { case editing, sending, unconfirmed, received }
    let accountID: String?
    let target: PhysiqueReportTarget
    @Published var valid = true
    @Published var windowID: UUID?
    @Published var reason: PhysiqueReportReason?
    @Published var note = ""
    @Published var reasonError = false
    @Published var expiresAt: Date?
    @Published var expired = false
    @Published var delivery: Delivery = .editing
    @Published var pending: PhysiqueReportSubmission?
    @Published var deliveryError: String?
    @Published var receiptID: String?
    @Published var receivedCase: PhysiqueCase?
    @Published var caseError: String?
    @Published var loadingCase = false
    @Published var blockPending = false
    @Published var blockSending = false
    @Published var blockConfirmed = false
    @Published var blockError: String?
    @Published var withdrawing = false
    @Published var withdrawalUnknown = false
    @Published var withdrawalConfirmed = false
    @Published var withdrawalError: String?
    private var expiryTask: Task<Void, Never>?

    init(accountID: String?, target: PhysiqueReportTarget) {
        self.accountID = accountID
        self.target = target
    }

    var hasEdits: Bool { reason != nil || !note.isEmpty }
    var matchesPendingEdits: Bool { pending?.reason == reason && pending?.note == note }
    private var authorized: Bool { valid && accountID != nil && accountID == CloudAccountStore.shared.accountID }

    func claim(_ id: UUID) {
        guard authorized, windowID == nil || windowID == id else { return }
        windowID = id
        expireIfNeeded()
    }

    func release(_ id: UUID) {
        if windowID == id { windowID = nil }
    }

    func expireIfNeeded() {
        if let expiresAt, expiresAt <= Date() { expire() }
    }

    func didEdit() {
        guard authorized else { return }
        if reason != nil { reasonError = false }
        guard hasEdits else { return }
        expired = false
        guard expiresAt == nil else { return }
        let expiry = Date().addingTimeInterval(24 * 60 * 60)
        expiresAt = expiry
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(max(0, expiry.timeIntervalSinceNow) * 1_000_000_000)) }
            catch { return }
            self?.expire()
        }
    }

    func discardEdits() {
        reason = nil
        note = ""
        reasonError = false
        pending = nil
        clearExpiry()
    }

    func send(using store: PhysiqueStore) async {
        guard authorized, delivery != .sending, receiptID == nil else { return }
        guard !store.busy else { deliveryError = "Another request is still being confirmed. Your draft has not been sent."; return }
        let submission: PhysiqueReportSubmission
        if delivery == .unconfirmed {
            guard let pending else { return }
            submission = pending
        } else {
            guard let reason, note.unicodeScalars.count <= 4_000 else { return }
            submission = PhysiqueReportSubmission(reason: reason, note: note)
            pending = submission
        }
        delivery = .sending
        deliveryError = nil
        let contextID = target.matchID ?? (target.kind == "match" || target.kind == "explanation" ? target.id : nil)
        let success = await store.perform("report", matchID: contextID, targetID: target.id, text: submission.note.isEmpty ? nil : submission.note, reason: submission.reason.rawValue)
        guard authorized else { return }
        guard success, let id = store.lastReceiptID, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            delivery = .unconfirmed
            deliveryError = store.error ?? "A report receipt was not acknowledged. No case reference or evidence hold is assumed."
            return
        }
        receiptID = id
        delivery = .received
        deliveryError = nil
        if reason == submission.reason && note == submission.note { discardEdits() }
        pending = nil
        if !hasEdits { clearExpiry() }
        await loadCase(using: store)
    }

    func loadCase(using store: PhysiqueStore) async {
        guard authorized, !loadingCase, let receiptID else { return }
        loadingCase = true
        caseError = nil
        defer { if authorized { loadingCase = false } }
        do {
            let record = try await store.caseDetail(receiptID)
            guard authorized, self.receiptID == receiptID, record.id == receiptID else { return }
            receivedCase = record
            withdrawalConfirmed = record.status == "withdrawn"
        } catch {
            guard authorized else { return }
            caseError = error.localizedDescription
        }
    }

    func withdraw(using store: PhysiqueStore) async {
        guard authorized, let receiptID, receivedCase?.canWithdraw == true, !withdrawing, !store.busy else { return }
        withdrawing = true
        withdrawalError = nil
        let success = await store.perform("withdrawCase", targetID: receiptID)
        guard authorized else { return }
        withdrawing = false
        withdrawalConfirmed = success
        withdrawalUnknown = !success
        if !success { withdrawalError = store.error ?? "Withdrawal was not acknowledged. The last confirmed case remains available." }
        await loadCase(using: store)
    }

    func invalidate() {
        valid = false
        clearExpiry()
        reason = nil
        note = ""
        pending = nil
        receiptID = nil
        receivedCase = nil
        deliveryError = nil
        caseError = nil
        blockError = nil
        withdrawalError = nil
        windowID = nil
    }

    private func expire() {
        reason = nil
        note = ""
        pending = nil
        reasonError = false
        expired = true
        clearExpiry()
    }

    private func clearExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
        expiresAt = nil
    }
}

@MainActor
private final class PhysiqueReportDrafts {
    static let shared = PhysiqueReportDrafts()
    private var accountID: String?
    private var drafts: [PhysiqueReportTarget: PhysiqueReportDraft] = [:]
    private var subscription: AnyCancellable?

    private init() {
        subscription = CloudAccountStore.shared.$session.map { $0?.userID }.removeDuplicates()
            .sink { [weak self] owner in self?.setAccount(owner) }
    }

    func draft(for target: PhysiqueReportTarget) -> PhysiqueReportDraft {
        let owner = CloudAccountStore.shared.accountID
        setAccount(owner)
        guard owner != nil else { return PhysiqueReportDraft(accountID: nil, target: target) }
        let contextID = target.matchID ?? (target.kind == "match" || target.kind == "explanation" ? target.id : nil)
        let key = PhysiqueReportTarget(kind: "report", id: target.id, matchID: contextID)
        if let draft = drafts[key] { return draft }
        let draft = PhysiqueReportDraft(accountID: owner, target: target)
        drafts[key] = draft
        return draft
    }

    private func setAccount(_ owner: String?) {
        guard accountID != owner else { return }
        drafts.values.forEach { $0.invalidate() }
        drafts.removeAll()
        accountID = owner
    }
}
