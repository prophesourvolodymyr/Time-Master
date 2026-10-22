import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiqueReviewComposerView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let target: PhysiqueReviewTarget

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: PhysiqueReviewDraft?

    private var accountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    var body: some View {
        Group {
            if scenePhase != .active || !presentationActive {
                PhysiqueScreen(title: "Private review") {
                    PhysiqueStatusView(title: "Review hidden", detail: "Return to this window to check account access and continue.", systemImage: "lock.fill")
                }
            } else if let accountID, let draft, draft.accountID == accountID,
                      draft.target.kind == target.kind, draft.target.id == target.id {
                PhysiqueReviewDocument(store: store, draft: draft, onOpen: onOpen)
                    .id(ObjectIdentifier(draft))
            } else {
                PhysiqueScreen(title: target.kind == "appeal" ? "Appeal decision" : "Dispute result") {
                    if !accountStore.restored || accountStore.busy {
                        ProgressView("Resolving account access…")
                    } else {
                        PhysiqueStatusView(title: "Sign in to request review", detail: "Only the account entitled to this decision or match can send a private request.", systemImage: "lock")
                        PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") {
                            dismiss()
                            onOpen(.account)
                        }
                    }
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            store.suspendCapture()
            bindDraft()
        }
        .onChange(of: accountID) { _ in bindDraft() }
        .onChange(of: target) { _ in bindDraft() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { bindDraft() }
        }
        .onChange(of: presentationActive) { active in
            if active { bindDraft() }
        }
        .onDisappear { store.suspendCapture() }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private func bindDraft() {
        draft = accountID.map { PhysiqueReviewDrafts.shared.draft(accountID: $0, target: target) }
    }
}

@MainActor
private struct PhysiqueReviewDocument: View {
    @ObservedObject var store: PhysiqueStore
    @ObservedObject var draft: PhysiqueReviewDraft
    let onOpen: (PhysiqueRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editorID = UUID()
    @State private var originalCase: PhysiqueCase?
    @State private var originalMatch: PhysiqueMatch?
    @State private var currentCase: PhysiqueCase?
    @State private var loading = false
    @State private var loadError: String?
    @State private var statusError: String?
    @State private var loaded = false
    @State private var decisionChanged = false
    @State private var confirmsClose = false
    @State private var confirmsWithdrawal = false
    @State private var withdrawing = false
    @State private var withdrawalUnconfirmed = false
    @State private var destination: PhysiqueRoute?
    @State private var copied = false
    @FocusState private var noteFocused: Bool
    @AccessibilityFocusState private var statusFocused: Bool

    private var appeal: Bool { draft.target.kind == "appeal" }
    private var validMode: Bool { appeal || draft.target.kind == "dispute" }
    private var title: String { appeal ? "Appeal decision" : "Dispute result" }
    private var sendTitle: String { appeal ? "Send appeal" : "Send dispute" }
    private var receiptTitle: String { appeal ? "Appeal received" : "Dispute received" }
    private var ownsEditor: Bool { draft.editorID == editorID }
    private var currentAccount: Bool { draft.accountID == CloudAccountStore.shared.accountID && !CloudAccountStore.shared.busy }
    private var editable: Bool { draft.phase == .editing && !draft.isExpired && ownsEditor }
    private var supportURL: URL? {
        guard let value = store.policy?.supportURL, let url = URL(string: value),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
    private var operationDisclosed: Bool {
        guard let policy = store.policy else { return false }
        return !policy.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !policy.retention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && supportURL != nil
    }
    private var targetEligible: Bool {
        guard loaded, !decisionChanged, validMode, !draft.target.id.isEmpty else { return false }
        if appeal { return originalCase?.canAppeal == true }
        return originalMatch?.stage.terminal == true && originalMatch?.result != nil
    }
    private var disabledReason: String? {
        if !currentAccount { return "Current account access must be confirmed." }
        if !ownsEditor { return "This request is already open in another window. Close it there to continue here." }
        if draft.isExpired { return "This local draft expired. Start a new draft to continue." }
        if loading { return "Checking the authorized decision…" }
        if !loaded { return "Load the authorized decision before sending." }
        if decisionChanged { return "The decision changed. Review the current context before continuing." }
        if !targetEligible { return appeal ? "This decision is not currently open to appeal." : "A confirmed final match result is required." }
        if !operationDisclosed { return "Review intake is unavailable until the operator, retention and secure support contact are published." }
        if draft.reason == nil { return "Choose a reason. Context is optional." }
        if draft.note.unicodeScalars.count > 4_000 { return "Context exceeds the service limit of 4,000 Unicode characters. Shorten it to send; your text has not been cut." }
        if store.busy { return "Another service request is still being confirmed." }
        return nil
    }
    private struct Reason: Identifiable {
        let id: String
        let title: String
    }
    private static let appealReasons = [
        Reason(id: "coverage", title: "Allowed clothing or context"),
        Reason(id: "identity", title: "Wrong item or decision"),
        Reason(id: "restriction", title: "Restriction seems incorrect"),
        Reason(id: "other", title: "Other decision concern")
    ]
    private static let disputeReasons = [
        Reason(id: "evidence", title: "Evidence or pose handling"),
        Reason(id: "identity", title: "Player assignment"),
        Reason(id: "arithmetic", title: "Score or rating calculation"),
        Reason(id: "forfeit", title: "Forfeit or match ending"),
        Reason(id: "judgement", title: "Disagree with judgement"),
        Reason(id: "other", title: "Other result issue")
    ]
    private var reasons: [Reason] { appeal ? Self.appealReasons : Self.disputeReasons }

    var body: some View {
        PhysiqueScreen(title: title, subtitle: subtitle) {
            if draft.phase == .received {
                receipt
            } else if draft.phase == .sending || draft.phase == .uncertain {
                unresolved
            } else {
                originalContext
                if draft.isExpired {
                    PhysiqueStatusView(title: "Draft expired", detail: "The unsent reason and context were removed after 24 hours. Nothing was sent by keeping this draft.")
                    PhysiqueAction(title: "Start new draft", systemImage: "square.and.pencil", disabled: !ownsEditor) { draft.restart() }
                } else if loaded && validMode {
                    reasonField
                    noteField
                }
                disclosure
                if let issue = draft.issue {
                    PhysiqueStatusView(title: "Not sent", detail: issue)
                        .accessibilityFocused($statusFocused)
                }
            }
            publicContact
        }
        .safeAreaInset(edge: .top, spacing: 0) { liveMatchContext }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(draft.phase == .editing ? "Cancel" : "Close") { requestClose() }
            }
        }
        .interactiveDismissDisabled(editable && draft.hasContent)
        #if os(iOS)
        .navigationBarBackButtonHidden(editable && draft.hasContent)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .frame(idealWidth: ProfileStyle.readableWidth, idealHeight: 560)
        .onExitCommand { requestClose() }
        #endif
        .task {
            if draft.editorID == nil { draft.editorID = editorID }
            if draft.phase == .sending && !store.busy {
                draft.phase = .uncertain
                draft.issue = "The previous transmission has no confirmed receipt. Check private cases before retrying the same request."
            }
            await loadContext()
            if draft.phase == .received { await refreshReceipt() }
        }
        .onAppear {
            store.suspendCapture()
            draft.expireIfNeeded()
        }
        .onChange(of: draft.editorID) { owner in
            if owner == nil && currentAccount { draft.editorID = editorID }
        }
        .onDisappear {
            noteFocused = false
            if draft.editorID == editorID { draft.editorID = nil }
        }
        .confirmationDialog("Keep this unsent review?", isPresented: $confirmsClose, titleVisibility: .visible) {
            Button("Keep draft") { close() }
            Button("Discard draft", role: .destructive) {
                draft.discard()
                close()
            }
            Button("Continue editing", role: .cancel) { destination = nil }
        } message: {
            Text("A text-only draft stays in this app session for at most 24 hours from creation. It clears on sign-out or account change. It is not sent and creates no evidence hold.")
        }
        .confirmationDialog("Withdraw this request?", isPresented: $confirmsWithdrawal, titleVisibility: .visible) {
            Button("Withdraw request", role: .destructive) { Task { await withdraw() } }
            Button("Keep request", role: .cancel) {}
        } message: {
            Text("This stops pursuing this request, not the underlying decision. Authorized safety or legal work and a justified hold may continue. Withdrawal does not change the result, remove a restriction or delete all correspondence.")
        }
    }

    private var subtitle: String {
        switch draft.phase {
        case .editing: return draft.reason == nil ? "Choose a reason. The mode and target are locked." : "Add context if helpful. No new photos needed."
        case .sending: return appeal ? "Sending appeal…" : "Sending dispute…"
        case .uncertain: return "Receipt not confirmed"
        case .received: return "A receipt acknowledges intake, not a completed review."
        }
    }

    @ViewBuilder
    private var originalContext: some View {
        if loading && !loaded {
            ProgressView("Loading authorized decision…")
        } else if !loaded {
            PhysiqueStatusView(title: "Private request unavailable", detail: loadError ?? "This target could not be authorized for the current account.", retry: { Task { await loadContext() } })
        } else {
            PhysiqueCard {
                Label(appeal ? "Original decision" : "Confirmed match result", systemImage: "doc.text")
                    .font(TimeMasterFont.sectionTitle())
                Text(draft.target.id).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if let item = originalCase {
                    Text(Date(timeIntervalSince1970: item.createdAt), format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(ProfileStyle.secondary)
                    Text(item.summary)
                    if let decision = item.decision, !decision.isEmpty { Text(decision) }
                    Text("Status: \(statusLabel(item.status))")
                }
                if let match = originalMatch, let result = match.result {
                    Text(Date(timeIntervalSince1970: match.finalizedAt ?? match.createdAt), format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(ProfileStyle.secondary)
                    Text(result.title).font(TimeMasterFont.heading())
                    if result.outcome == "noContest" {
                        Text("No rating change")
                    } else if let rating = result.rating {
                        Text("Confirmed rating effect: \(rating.change > 0 ? "+" : "")\(rating.change) Elo")
                    } else {
                        Text("Rating effect unavailable")
                    }
                    if result.isJudged, let version = result.judgeVersion, !version.isEmpty {
                        Text("Judging version: \(version)")
                    }
                    if result.corrected { Text("The service marks this result as corrected.") }
                    Text(match.galleryAvailable ? "Gallery access does not confirm which evidence remains available to reviewers." : "Participant media is unavailable. Review does not restore it.")
                        .foregroundStyle(ProfileStyle.secondary)
                }
                Button(copied ? "Reference copied" : "Copy reference", action: copyReference)
                Button(appeal ? "Open decision" : "Open result") {
                    requestClose(to: appeal ? .caseDetail(draft.target.id) : .result(draft.target.id))
                }
                if decisionChanged {
                    Label("Decision changed", systemImage: "arrow.triangle.2.circlepath")
                        .font(TimeMasterFont.sectionTitle())
                    Text("Your note has been kept. The displayed context is now current; review it before continuing.")
                    Button("Use this current decision") { decisionChanged = false }
                }
                Button("Refresh decision") { Task { await loadContext() } }
                    .disabled(loading)
            }
        }
    }

    private var reasonField: some View {
        PhysiqueCard {
            Text("Reason · Required").font(TimeMasterFont.sectionTitle())
            Picker("Reason", selection: $draft.reason) {
                Text("Choose a reason").tag(String?.none)
                ForEach(reasons) { reason in
                    Text(reason.title).tag(Optional(reason.id))
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.menu)
            .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
            #endif
            .disabled(!editable || loading)
            .tint(Theme.toolbarOrange)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: draft.reason)
        }
    }

    private var noteField: some View {
        PhysiqueCard {
            Text("Context · Optional").font(TimeMasterFont.sectionTitle())
            Text("Describe the issue. No new photos or identifying documents needed.")
                .foregroundStyle(ProfileStyle.secondary)
            TextEditor(text: $draft.note)
                .font(TimeMasterFont.body())
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .focused($noteFocused)
                .accessibilityLabel("Context, optional")
                .disabled(!editable || loading)
                .padding(8)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
            Text("\(draft.note.unicodeScalars.count.formatted()) / 4,000 Unicode characters")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            if draft.note.unicodeScalars.count > 4_000 {
                Label("Context is too long. Shorten it to send; all text is preserved.", systemImage: "exclamationmark.circle")
            }
            Text("Draft only · Not sent. Kept in this app session for at most 24 hours; sign-out or account change clears it.")
                .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
        }
    }

    private var disclosure: some View {
        PhysiqueCard {
            Label("Private review", systemImage: "lock.doc").font(TimeMasterFont.sectionTitle())
            if let policy = store.policy, operationDisclosed {
                Text("Operator: \(policy.operatorName)")
                Text("Your decision or match reference, reason and optional context go to the operator's authorized private case reviewers. Minimum necessary existing lawful records may be used; no new photo is requested.")
                Text(policy.retention).textSelection(.enabled)
            } else {
                Text("The actual operator, retention information and secure support contact have not all been confirmed. Sending is unavailable.")
            }
            Text(appeal ? "Review does not pause the match or remove a restriction." : "The confirmed result and rating stay in effect during review.")
                .font(TimeMasterFont.label())
            Text("This request does not rerun the judge or promise reversal. Evidence availability and any originating hold deadline are not supplied here; review cannot restore deleted media or restart an existing hold.")
            Text("A receipt is not a guarantee of immediate human attention or a response time.")
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private var unresolved: some View {
        PhysiqueCard {
            if draft.phase == .sending {
                ProgressView(appeal ? "Sending appeal…" : "Sending dispute…")
                Text("The submitted reason and context are locked while receipt is being confirmed. Closing does not cancel an accepted transmission.")
            } else {
                Label("Receipt not confirmed", systemImage: "questionmark.circle")
                    .font(TimeMasterFont.heading()).accessibilityFocused($statusFocused)
                Text(draft.issue ?? "The service may have accepted this request, but no canonical receipt was confirmed.")
                Text("Check your private cases before retrying. A retry uses the same target and submitted payload, not a new review vote.")
                PhysiqueAction(title: "Check status in cases", systemImage: "tray") { close(to: .cases) }
                if !draft.isExpired {
                    PhysiqueAction(title: "Retry same request", systemImage: "arrow.clockwise", disabled: store.busy || !ownsEditor) {
                        Task { await send(retry: true) }
                    }
                } else {
                    Text("The draft text expired and was removed. Check cases using the original reference; no text will be reconstructed or resent.")
                }
            }
            Text("Target: \(draft.target.id)").textSelection(.enabled)
            Text(appeal ? "The current restriction stays in effect unless the service revises it." : "The confirmed result and rating stay in effect pending an authorized correction.")
        }
    }

    private var receipt: some View {
        PhysiqueCard {
            Label(receiptTitle, systemImage: "checkmark.circle")
                .font(TimeMasterFont.heading()).accessibilityFocused($statusFocused)
            if let message = draft.receiptMessage { Text(message) }
            if let id = draft.receiptID {
                Text("Case reference").font(TimeMasterFont.sectionTitle())
                Text(id).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if let item = currentCase {
                    Text("Status: \(statusLabel(item.status))").font(TimeMasterFont.label())
                    Text("Received \(Date(timeIntervalSince1970: item.createdAt).formatted(date: .abbreviated, time: .shortened))")
                    Text("Last case update \(Date(timeIntervalSince1970: item.updatedAt).formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(ProfileStyle.secondary)
                    if let decision = item.decision, !decision.isEmpty { Text(decision) }
                    if item.canWithdraw {
                        Button("Withdraw request", role: .destructive) { confirmsWithdrawal = true }
                            .disabled(store.busy || withdrawing || withdrawalUnconfirmed)
                    }
                } else {
                    Text("The receipt was acknowledged, but current case status and received time have not been loaded.")
                }
                if withdrawing { ProgressView("Confirming withdrawal…") }
                if withdrawalUnconfirmed {
                    Label("Withdrawal not confirmed", systemImage: "questionmark.circle")
                    Text("The last confirmed case state remains shown. Check status before trying again.")
                }
                if let statusError { Text(statusError) }
                Button("Check status") { Task { await refreshReceipt() } }.disabled(loading || withdrawing)
                PhysiqueAction(title: "View case", systemImage: "doc.text.magnifyingglass") { close(to: .caseDetail(id)) }
            }
            Text(appeal ? "Receipt does not remove a restriction or restore media." : "Receipt does not change the confirmed result or award rating.")
            Text("Closing this receipt does not withdraw the request.")
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    @ViewBuilder
    private var publicContact: some View {
        if let supportURL {
            Link(destination: supportURL) { Label("Published operator support", systemImage: "arrow.up.right.square") }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            if draft.phase == .editing {
                if let disabledReason {
                    Text(disabledReason).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                }
                #if os(macOS)
                HStack {
                    Button("Cancel") { requestClose() }
                    Spacer()
                    Button(sendTitle) { Task { await send() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(disabledReason != nil)
                }
                #else
                PhysiqueAction(title: sendTitle, systemImage: "paperplane", disabled: disabledReason != nil) {
                    Task { await send() }
                }
                #endif
            } else {
                Button(draft.phase == .received ? "Done" : "Close") { requestClose() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: ProfileStyle.readableWidth)
        .padding(ProfileStyle.inset)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    private var liveMatchContext: some View {
        if let match = store.match, !match.stage.terminal {
            VStack(spacing: 4) {
                PhysiqueTimerView(clock: clock(for: match))
                Text("\(match.stage.title) · Camera stopped")
                    .font(TimeMasterFont.secondary())
                Button("Return to match") {
                    requestClose(to: match.stage == .judging ? .judging : match.stage == .ready || match.stage == .countdown ? .ready : .battle)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, ProfileStyle.spacing)
            .background(Theme.background)
        }
    }

    private func clock(for match: PhysiqueMatch) -> PhysiqueClock {
        switch match.stage {
        case .countdown:
            return PhysiqueClock(mode: .countdown, label: "Match starts in", endpoint: match.startAt, serverOffset: store.serverOffset)
        case .capture, .submitting:
            return PhysiqueClock(mode: .remaining, label: "Capture time remaining", endpoint: match.deadline, serverOffset: store.serverOffset)
        case .judging:
            return PhysiqueClock(mode: match.judgingStartedAt == nil ? .unavailable : .elapsed, label: "Judging elapsed", endpoint: match.judgingStartedAt, serverOffset: store.serverOffset)
        default:
            return PhysiqueClock(mode: .unavailable, label: match.stage.title, endpoint: nil, serverOffset: store.serverOffset)
        }
    }

    private func loadContext() async {
        guard currentAccount, !loading else { return }
        loading = true
        loadError = nil
        defer { loading = false }
        if store.policy == nil { await store.loadPolicy() }
        guard currentAccount, !Task.isCancelled else { return }
        guard validMode, !draft.target.id.isEmpty else {
            loaded = false
            loadError = "The review mode or original reference is invalid. Open review from the authorized decision or match."
            return
        }
        do {
            if appeal {
                let item = try await store.caseDetail(draft.target.id)
                guard currentAccount, !Task.isCancelled else { return }
                if let previous = originalCase, previous.updatedAt != item.updatedAt { decisionChanged = true }
                originalCase = item
            } else {
                let match = try await store.getMatch(draft.target.id)
                guard currentAccount, !Task.isCancelled else { return }
                if let previous = originalMatch,
                   previous.result?.outcome != match.result?.outcome || previous.result?.corrected != match.result?.corrected
                    || previous.result?.rating?.after != match.result?.rating?.after { decisionChanged = true }
                originalMatch = match
            }
            loaded = true
        } catch {
            guard currentAccount, !Task.isCancelled else { return }
            loaded = false
            originalCase = nil
            originalMatch = nil
            loadError = error.localizedDescription
        }
    }

    private func send(retry: Bool = false) async {
        draft.expireIfNeeded()
        guard currentAccount, ownsEditor, !store.busy, !draft.isExpired else { return }
        if retry {
            guard draft.phase == .uncertain else { return }
        } else {
            guard draft.phase == .editing, disabledReason == nil else { statusFocused = true; return }
            await loadContext()
            guard disabledReason == nil else { statusFocused = true; return }
        }
        if !retry { draft.submittedMatchID = appeal ? originalCase?.matchID : draft.target.id }
        guard let reason = draft.reason, reasons.contains(where: { $0.id == reason }) else { return }
        noteFocused = false
        draft.phase = .sending
        draft.issue = nil
        let text = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let accepted = await store.perform("review", matchID: draft.submittedMatchID,
                                           targetID: draft.target.id, text: text.isEmpty ? nil : text,
                                           reason: "\(draft.target.kind):\(reason)")
        guard currentAccount else { return }
        if accepted, let id = store.lastReceiptID, !id.isEmpty {
            draft.receiptID = id
            draft.receiptMessage = store.notice
            draft.phase = .received
            draft.eraseText()
            statusFocused = true
            await refreshReceipt()
        } else {
            draft.phase = .uncertain
            draft.issue = store.error ?? "No canonical case reference was returned. Receipt is not confirmed; check your private cases."
            statusFocused = true
        }
    }

    private func refreshReceipt() async {
        guard currentAccount, let id = draft.receiptID, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let item = try await store.caseDetail(id)
            guard currentAccount, !Task.isCancelled else { return }
            currentCase = item
            statusError = nil
            withdrawalUnconfirmed = false
        } catch {
            guard currentAccount, !Task.isCancelled else { return }
            statusError = "Unable to refresh. Any status shown is last confirmed. \(error.localizedDescription)"
        }
    }

    private func withdraw() async {
        guard currentAccount, let item = currentCase, item.canWithdraw, !store.busy, !withdrawing else { return }
        withdrawing = true
        withdrawalUnconfirmed = true
        let confirmed = await store.perform("withdrawCase", targetID: item.id)
        guard currentAccount else { return }
        withdrawing = false
        if !confirmed {
            withdrawalUnconfirmed = true
            statusError = store.error ?? "Withdrawal could not be confirmed."
            return
        }
        await refreshReceipt()
    }

    private func requestClose(to route: PhysiqueRoute? = nil) {
        noteFocused = false
        destination = route
        if editable && draft.hasContent { confirmsClose = true } else { close() }
    }

    private func close(to route: PhysiqueRoute? = nil) {
        let next = route ?? destination
        dismiss()
        if let next { onOpen(next) }
    }

    private func copyReference() {
        #if os(iOS)
        UIPasteboard.general.string = draft.target.id
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draft.target.id, forType: .string)
        #endif
        copied = true
    }

    private func statusLabel(_ raw: String) -> String {
        switch raw {
        case "received": return "Received"
        case "queued": return "Queued"
        case "inReview": return "In review"
        case "needsReply", "moreInformation": return "More safe information requested"
        case "upheld": return "Decision stands"
        case "revised": return "Decision revised"
        case "withdrawn": return "Withdrawn"
        case "closed": return "Closed"
        case "inconclusive": return "Inconclusive"
        default: return raw
        }
    }
}

@MainActor
private final class PhysiqueReviewDraft: ObservableObject {
    enum Phase { case editing, sending, uncertain, received }
    let accountID: String
    let target: PhysiqueReviewTarget
    @Published var reason: String?
    @Published var note = ""
    @Published var phase: Phase = .editing
    @Published var receiptID: String?
    @Published var receiptMessage: String?
    var submittedMatchID: String?
    @Published var issue: String?
    @Published var expired = false
    @Published var editorID: UUID?
    private var expiry: Task<Void, Never>?
    private var expiresAt = Date(timeIntervalSinceNow: 86_400)
    var isExpired: Bool { expired || Date() >= expiresAt }
    var hasContent: Bool { reason != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(accountID: String, target: PhysiqueReviewTarget) {
        self.accountID = accountID
        self.target = target
        scheduleExpiry()
    }

    func eraseText() {
        reason = nil
        note = ""
    }

    func discard() {
        eraseText()
        issue = nil
    }

    func invalidate() {
        expiry?.cancel()
        discard()
        receiptID = nil
        receiptMessage = nil
        submittedMatchID = nil
        editorID = nil
        expired = true
    }

    func restart() {
        guard phase == .editing else { return }
        discard()
        expiresAt = Date(timeIntervalSinceNow: 86_400)
        expired = false
        scheduleExpiry()
    }

    func expireIfNeeded() {
        guard isExpired else { return }
        eraseText()
        expired = true
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        expiry = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 86_400_000_000_000) } catch { return }
            guard let self else { return }
            self.eraseText()
            self.expired = true
        }
    }

    deinit { expiry?.cancel() }
}

@MainActor
private final class PhysiqueReviewDrafts {
    static let shared = PhysiqueReviewDrafts()
    private var accountID: String?
    private var drafts: [PhysiqueReviewTarget: PhysiqueReviewDraft] = [:]
    private var identitySubscription: AnyCancellable?

    private init() {
        identitySubscription = CloudAccountStore.shared.$session.map { $0?.userID }.removeDuplicates()
            .sink { [weak self] owner in
                guard let self, self.accountID != owner else { return }
                self.drafts.values.forEach { $0.invalidate() }
                self.drafts.removeAll()
                self.accountID = owner
            }
    }

    func draft(accountID: String, target: PhysiqueReviewTarget) -> PhysiqueReviewDraft {
        if self.accountID != accountID {
            drafts.values.forEach { $0.invalidate() }
            drafts.removeAll()
            self.accountID = accountID
        }
        let key = PhysiqueReviewTarget(kind: target.kind, id: target.id)
        if let existing = drafts[key] {
            existing.expireIfNeeded()
            return existing
        }
        let draft = PhysiqueReviewDraft(accountID: accountID, target: key)
        drafts[key] = draft
        return draft
    }
}
