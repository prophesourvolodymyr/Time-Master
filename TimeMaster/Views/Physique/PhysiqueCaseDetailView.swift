import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct PhysiqueCaseDetailView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let caseID: String

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.physiquePresentationActive) private var presentationActive
    @State private var item: PhysiqueCase?
    @State private var savedMatch: PhysiqueMatch?
    @State private var accountSnapshot: PhysiqueSnapshot?
    @State private var loadedAccountID: String?
    @State private var loadedCaseID: String?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var matchError: String?
    @State private var refreshID = UUID()
    @State private var factsExpanded = false
    @State private var earlierUpdatesExpanded = false
    @State private var draft = ""
    @State private var draftStartedAt: Date?
    @State private var responseRequest: RequestRevision?
    @State private var pendingResponse: PendingResponse?
    @State private var responseState: ResponseState = .closed
    @State private var responseError: String?
    @State private var responseReceivedAt: Double?
    @State private var responseReceipt: String?
    @State private var isMutating = false
    @State private var mutationID: UUID?
    @State private var withdrawalRevision: RequestRevision?
    @State private var withdrawalUnconfirmed = false
    @State private var withdrawalReceipt: String?
    @State private var actionMessage: String?
    @State private var confirmsWithdrawal = false
    @State private var confirmsDraftCancellation = false
    @State private var copyFeedbackID: UUID?
    @State private var supportError: String?
    @FocusState private var responseFocused: Bool
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityTarget?

    private enum ResponseState: Equatable {
        case closed, editing, sending, unconfirmed, received, changed
    }

    private enum AccessibilityTarget: Hashable {
        case status, response, responseError, responseReceipt, withdrawalReceipt, changed
    }

    private struct LoadContext: Hashable {
        let accountID: String?
        let caseID: String
        let refreshID: UUID
        let active: Bool
    }

    private struct RequestRevision: Equatable {
        let caseID: String
        let updatedAt: Double
        let needsReply: Bool
        let status: String
        let latestStaffMessageID: String?
        let latestStaffText: String?
        let summary: String
        let decision: String?

        init(_ item: PhysiqueCase) {
            caseID = item.id
            updatedAt = item.updatedAt
            needsReply = item.needsReply
            status = item.status
            latestStaffMessageID = item.messages.last(where: \.fromStaff)?.id
            latestStaffText = item.messages.last(where: \.fromStaff)?.text
            summary = item.summary
            decision = item.decision
        }
    }

    private struct PendingResponse {
        let text: String
        let revision: RequestRevision
        let existingMessageIDs: Set<String>
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var presentationIsActive: Bool {
        scenePhase == .active && presentationActive
    }

    private var loadContext: LoadContext {
        LoadContext(accountID: activeAccountID, caseID: caseID, refreshID: refreshID, active: presentationIsActive)
    }

    private var authorizedItem: PhysiqueCase? {
        guard presentationIsActive, let accountID = activeAccountID,
              loadedAccountID == accountID, loadedCaseID == caseID else { return nil }
        return item
    }

    private var supportURL: URL? {
        guard let value = (store.policy ?? store.snapshot?.policy)?.supportURL,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "mailto",
              url.user == nil, url.password == nil else { return nil }
        if scheme == "https", url.host == nil { return nil }
        return url
    }

    var body: some View {
        PhysiqueScreen(title: "Case status") {
            if !presentationIsActive {
                PhysiqueStatusView(title: "Private case", detail: "Return to check the current case status.", systemImage: "lock")
            } else if !accountStore.restored || accountStore.busy {
                ProgressView("Resolving account access…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if activeAccountID == nil {
                PhysiqueStatusView(title: "Sign in to view cases", detail: "Private case information is available only to the authorized account.", systemImage: "lock")
                PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { onOpen(.account) }
                publicContact
            } else if let item = authorizedItem {
                dossier(item)
            } else if isLoading {
                ProgressView("Loading authorized case…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                PhysiqueStatusView(title: "Case unavailable", detail: loadError ?? "This case has not been confirmed for the current account.", retry: requestRefresh)
                publicContact
            }
        }
        .navigationTitle("Case status")
        .toolbar { caseToolbar }
        .task(id: loadContext) { await loadCase(context: loadContext) }
        .task {
            if store.policy == nil { await store.loadPolicy() }
        }
        .task(id: draftStartedAt) { await expireDraft() }
        .task(id: copyFeedbackID) { await clearCopyFeedback() }
        .onDisappear { clearPrivateState() }
        .onChange(of: accountStore.accountID) { _ in clearPrivateState() }
        .onChange(of: accountStore.busy) { busy in
            if busy { clearPrivateState() }
        }
        .onChange(of: caseID) { _ in clearPrivateState() }
        .onChange(of: presentationIsActive) { active in
            if !active {
                item = nil
                savedMatch = nil
                accountSnapshot = nil
                loadedAccountID = nil
                loadedCaseID = nil
                responseFocused = false
                confirmsWithdrawal = false
                confirmsDraftCancellation = false
            }
        }
        .onChange(of: draft) { text in
            if !text.isEmpty, draftStartedAt == nil { draftStartedAt = Date() }
            responseError = nil
        }
        .onChange(of: actionMessage) { message in
            if let message { announce(message) }
        }
        .onChange(of: supportError) { message in
            if let message { announce(message) }
        }
        .onChange(of: responseState) { state in
            if state == .sending { announce("Sending response.") }
            if state == .unconfirmed { announce("Response not confirmed. Check status or retry the same response.") }
        }
        .confirmationDialog("Keep this unsent response?", isPresented: $confirmsDraftCancellation, titleVisibility: .visible) {
            Button("Keep draft in this case") {
                responseState = .closed
                responseFocused = false
            }
            Button("Discard response", role: .destructive) { discardResponse() }
            Button("Keep editing", role: .cancel) { responseFocused = true }
        } message: {
            Text("A draft is not a received response. It stays only in this open case on this device, for at most 24 hours, and clears on sign-out or account change.")
        }
    }

    @ViewBuilder
    private func dossier(_ item: PhysiqueCase) -> some View {
        statusCard(item)
        if copyFeedbackID != nil {
            Text("Copied case reference.")
                .font(TimeMasterFont.secondary())
        }
        if isLoading {
            ProgressView("Checking current status…")
                .font(TimeMasterFont.secondary())
        }
        responseSection(item)
        if !item.needsReply, item.canAppeal {
            PhysiqueAction(title: "Appeal decision", systemImage: "arrow.uturn.backward.circle") {
                responseFocused = false
                onOpen(.review(PhysiqueReviewTarget(kind: "appeal", id: item.id, matchID: item.matchID)))
            }
            Text("Review this account's decision. An appeal does not restore images or change a rating by itself.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
        if let decision = nonempty(item.decision) {
            PhysiqueSection(title: "Latest decision") {
                Text(decision)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if item.kind == "appeal" || item.kind == "dispute" {
                    Text("A review request does not suspend the existing decision, restriction, or result unless the service confirms a change.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
        }
        if item.kind == "dispute" || savedMatch?.result?.corrected == true || savedMatch?.result?.correction != nil {
            ratingSection(item)
        }
        updatesSection(item)
        caseFacts(item)
        if let match = savedMatch {
            Button {
                responseFocused = false
                onOpen(.result(match.id))
            } label: {
                Label("Match details", systemImage: "doc.text.magnifyingglass")
                    .frame(minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(.bordered)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            Text("Opens the authorized result, not pose images.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
        }
        if let actionMessage {
            Text(actionMessage)
                .font(TimeMasterFont.secondary())
        }
        if let receipt = withdrawalReceipt {
            receiptView(title: "Withdrawal acknowledged", reference: receipt, date: nil, focus: .withdrawalReceipt)
        }
        if withdrawalUnconfirmed {
            PhysiqueStatusView(title: "Withdrawal not confirmed", detail: "The service may have received the request. The last confirmed case state remains above. Check status before taking another action.", retry: requestRefresh)
        }
        publicContact
    }

    private func statusCard(_ item: PhysiqueCase) -> some View {
        PhysiqueCard {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                Label(kindTitle(item.kind), systemImage: kindSymbol(item.kind))
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.toolbarOrange)
                Text(statusTitle(item.status))
                    .font(TimeMasterFont.display())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocus, equals: .status)
                Text(nextStep(item))
                    .fixedSize(horizontal: false, vertical: true)
                if !item.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.summary)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .textSelection(.enabled)
                }
                datedFact("Last confirmed update", timestamp: item.updatedAt)
                Text("Case \(item.id)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.toolbarOrange)
                .frame(width: 3)
                .padding(.vertical, ProfileStyle.inset)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func responseSection(_ item: PhysiqueCase) -> some View {
        if responseState == .received, let receipt = responseReceipt {
            receiptView(title: "Response received", reference: receipt, date: responseReceivedAt, focus: .responseReceipt)
        }
        if item.needsReply || !draft.isEmpty || pendingResponse != nil {
            PhysiqueSection(title: "Additional information") {
                if let question = item.messages.last(where: \.fromStaff) {
                    Text(question.text)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    datedFact(item.needsReply ? "Request update" : "Case update", timestamp: question.createdAt)
                } else if item.needsReply {
                    Text("The service requests a safe text response. No separate question or response deadline was supplied.")
                        .foregroundStyle(ProfileStyle.secondary)
                }
                if responseState == .changed {
                    Text(pendingResponse == nil
                         ? "This request changed. Your unsent text has not been submitted to the updated request. Read the current information before reusing it."
                         : "This request changed while receipt was unconfirmed. The earlier response may have been received. Read the received updates or contact support before sending a new response.")
                        .accessibilityFocused($accessibilityFocus, equals: .changed)
                    unsentText
                    if item.needsReply {
                        Button("Use draft for this request") {
                            pendingResponse = nil
                            responseRequest = RequestRevision(item)
                            responseState = .editing
                            responseFocused = true
                        }
                        .buttonStyle(.bordered)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                    }
                    Button("Discard response", role: .destructive) { discardResponse() }
                        .buttonStyle(.bordered)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                } else if responseState == .unconfirmed || responseState == .sending {
                    Text(responseState == .sending ? "Sending response…" : "Response not confirmed")
                        .font(TimeMasterFont.rowTitle())
                    unsentText
                    if responseState == .sending {
                        ProgressView("Waiting for acknowledgement…")
                    } else {
                        Text("The service may have received this exact response. Check status or retry it without creating a new response locally.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                        Button("Check status", action: requestRefresh)
                            .buttonStyle(.bordered)
                            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                        if let pendingResponse, RequestRevision(item) == pendingResponse.revision, item.needsReply {
                            PhysiqueAction(title: "Retry same response", systemImage: "arrow.clockwise", disabled: isMutating || store.busy || isLoading) {
                                Task { await sendResponse(retrying: true) }
                            }
                        }
                    }
                } else if responseState == .editing {
                    responseEditor(item)
                } else if item.needsReply {
                    PhysiqueAction(title: draft.isEmpty ? "Respond" : "Continue response", systemImage: "text.bubble", disabled: isMutating) {
                        responseRequest = RequestRevision(item)
                        responseState = .editing
                        accessibilityFocus = .response
                        responseFocused = true
                    }
                } else if !draft.isEmpty {
                    Text("A response is no longer requested. Your unsent text remains below; it has not been submitted.")
                        .foregroundStyle(ProfileStyle.secondary)
                    unsentText
                    Button("Discard response", role: .destructive) { discardResponse() }
                        .buttonStyle(.bordered)
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                }
                if let responseError {
                    Text(responseError)
                        .foregroundStyle(Theme.toolbarOrange)
                        .accessibilityFocused($accessibilityFocus, equals: .responseError)
                }
            }
        }
    }

    private func responseEditor(_ item: PhysiqueCase) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Your response")
                .font(TimeMasterFont.rowTitle())
                .accessibilityFocused($accessibilityFocus, equals: .response)
            Text("Sent to the operator's authorized case-review team, not the opponent. Use safe text only; do not include private declarations or describe intimate imagery. No attachments are accepted here.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            TextEditor(text: $draft)
                .font(TimeMasterFont.body())
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(8)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: ProfileStyle.spacing))
                .focused($responseFocused)
                .accessibilityLabel("Your response")
                .accessibilityHint("Safe text, maximum 4,000 characters. Return inserts a new line.")
            Text("\(draft.unicodeScalars.count.formatted()) / 4,000 characters")
                .font(TimeMasterFont.caption())
                .foregroundStyle(draft.unicodeScalars.count > 4_000 ? Theme.toolbarOrange : ProfileStyle.secondary)
                .monospacedDigit()
            Text("Unsent text stays only in this open case on this device, for up to 24 hours. It is not synchronized, a receipt, or an evidence hold. Leaving this case can discard it.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ProfileStyle.spacing) {
                    cancelResponseButton
                    sendResponseButton(item)
                }
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    cancelResponseButton
                    sendResponseButton(item)
                }
            }
        }
    }

    private var cancelResponseButton: some View {
        Button("Cancel response") {
            mutationID = nil
            isMutating = false
            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discardResponse()
            } else {
                confirmsDraftCancellation = true
            }
        }
        .buttonStyle(.bordered)
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .frame(minHeight: ProfileStyle.touchTarget)
    }

    private func sendResponseButton(_ item: PhysiqueCase) -> some View {
        PhysiqueAction(title: "Send response", systemImage: "paperplane", disabled: isMutating || store.busy || isLoading || !item.needsReply) {
            Task { await sendResponse(retrying: false) }
        }
    }

    private var unsentText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pendingResponse == nil ? "Your unsent response" : "Your response text").font(TimeMasterFont.rowTitle())
            Text(pendingResponse?.text ?? draft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ratingSection(_ item: PhysiqueCase) -> some View {
        PhysiqueSection(title: "Your rating") {
            if let match = savedMatch, let result = match.result {
                Text(result.corrected || result.correction != nil ? "Reviewed match record" : "Saved match record")
                    .font(TimeMasterFont.rowTitle())
                Text(result.title)
                datedFact("Match date", timestamp: match.createdAt)
                if let judgeVersion = nonempty(result.judgeVersion) {
                    fact("Judging version", value: judgeVersion)
                }
                if let correction = result.correction {
                    correctionFacts(correction, match: match, result: result)
                } else if result.corrected {
                    Text("The service marks this match as corrected. Separate original-settlement and later-adjustment values are not included in this case record; no replacement values are calculated here.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                } else if let receipt = result.rating {
                    if let before = receipt.before {
                        fact("Match rating before", value: "\(before.formatted()) Physique Elo")
                    } else {
                        fact("Match rating before", value: "Not supplied")
                    }
                    fact("Signed match change", value: "\(signed(receipt.change)) Physique Elo")
                    fact("Match rating after", value: "\(receipt.after.formatted()) Physique Elo")
                    if let finalizedAt = match.finalizedAt { datedFact("Match finalized", timestamp: finalizedAt) }
                } else {
                    Text("No match rating receipt was supplied. This does not establish a zero-point change.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            } else {
                Text(matchError ?? "No confirmed competitive result is available for this case.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if item.status == "revised", savedMatch?.result?.correction == nil {
                Text("A revised review decision is not by itself confirmation that a rating adjustment has settled. The decision above describes only the change the service has reported.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            if let snapshot = accountSnapshot {
                Divider()
                Text("Last confirmed account record")
                    .font(TimeMasterFont.rowTitle())
                fact("Account rating", value: snapshot.account.record.rating.map { "\($0.formatted()) Physique Elo" } ?? "Unplaced")
                fact("Rated games", value: snapshot.account.record.games.formatted())
                if let tier = nonempty(snapshot.account.identity.tier) { fact("Service-reported tier", value: tier) }
                fact("Record", value: "\(snapshot.account.record.wins.formatted()) wins · \(snapshot.account.record.losses.formatted()) losses · \(snapshot.account.record.draws.formatted()) draws")
                datedFact("Account snapshot", timestamp: snapshot.serverTime)
                Text("This account snapshot can include later matches. It is not the original match's After value or a separate correction receipt.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            } else {
                Text("A current account snapshot could not be confirmed. No rating adjustment is inferred.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
    }

    private func correctionFacts(_ correction: PhysiqueCorrection, match: PhysiqueMatch, result: PhysiqueResult) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text("Original match settlement")
                .font(TimeMasterFont.rowTitle())
            fact("Original outcome", value: outcomeTitle(correction.originalOutcome))
            if let before = result.rating?.before {
                fact("Original match rating before", value: "\(before.formatted()) Physique Elo")
            }
            fact("Original signed match effect", value: "\(signed(correction.originalChange)) Physique Elo")
            if let finalizedAt = match.finalizedAt { datedFact("Original match finalized", timestamp: finalizedAt) }
            Divider()
            Text("Review decision")
                .font(TimeMasterFont.rowTitle())
            fact("Reviewed outcome", value: outcomeTitle(correction.correctedOutcome))
            fact("Correction reference", value: correction.id)
            Text(correction.reason)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            datedFact("Correction applied", timestamp: correction.createdAt)
            Divider()
            Text("Adjustment applied")
                .font(TimeMasterFont.rowTitle())
            fact("Signed review adjustment", value: "\(signed(correction.adjustment)) Physique Elo")
            fact("Account rating after review", value: "\(correction.after.formatted()) Physique Elo")
            Text("This is the confirmed account rating immediately after the review adjustment, not today's rating. It is separate from the original match effect; later valid matches keep their recorded outcomes and effects.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func updatesSection(_ item: PhysiqueCase) -> some View {
        PhysiqueSection(title: "Updates") {
            if let latest = item.messages.last {
                messageRow(latest)
                if item.messages.count > 1 {
                    DisclosureGroup("Earlier updates", isExpanded: $earlierUpdatesExpanded) {
                        ForEach(item.messages.dropLast()) { message in
                            messageRow(message)
                                .padding(.top, ProfileStyle.spacing)
                        }
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { earlierUpdatesExpanded.toggle() })
                    .padding(.top, 6)
                }
            } else {
                Text("No correspondence updates were supplied. The confirmed status and decision above remain the available record.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            Text("No response estimate available. A receipt is not confirmation of human attention or continuous monitoring.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func messageRow(_ message: PhysiqueCaseMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.fromStaff ? "Case update" : "Your received text")
                .font(TimeMasterFont.rowTitle())
            Text(message.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            datedFact("Received", timestamp: message.createdAt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caseFacts(_ item: PhysiqueCase) -> some View {
        DisclosureGroup("Case facts and evidence", isExpanded: $factsExpanded) {
            VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                fact("Case type", value: kindTitle(item.kind))
                fact("Case reference", value: item.id)
                datedFact("Case received", timestamp: item.createdAt)
                datedFact("Last confirmed update", timestamp: item.updatedAt)
                if let matchID = item.matchID {
                    fact("Originating match reference", value: matchID)
                }
                if let match = savedMatch { datedFact("Match date", timestamp: match.createdAt) }
                fact("Evidence availability", value: "Item-level retention and authorized-reviewer availability were not supplied by the case service.")
                Text("Receiving a case reference does not confirm that pose images were retained. A response, appeal, or reopened case does not extend retention or restore expired images.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                if let retention = nonempty((store.policy ?? store.snapshot?.policy)?.retention) {
                    fact("Published retention policy", value: retention)
                } else {
                    fact("Retention information", value: "Not published by the service. Use the available operator contact for clarification.")
                }
                if !item.canAppeal {
                    fact("Appeal access", value: "The service does not currently authorize an appeal from this case. No eligibility deadline or reason was supplied.")
                }
            }
            .padding(.top, ProfileStyle.spacing)
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { factsExpanded.toggle() })
        .font(TimeMasterFont.body())
    }

    @ViewBuilder
    private var publicContact: some View {
        if let url = supportURL {
            Button {
                openURL(url) { accepted in
                    supportError = accepted ? nil : "The published support channel could not be opened."
                }
            } label: {
                Label("Contact support", systemImage: "arrow.up.right.square")
                    .frame(minHeight: ProfileStyle.touchTarget)
            }
            .buttonStyle(.bordered)
            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
            .accessibilityHint("Opens the service's published support channel in another app. No case text is added.")
            Text("Opens another app. Only copy your case reference if you choose; do not send or attach intimate imagery.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
        } else {
            Text("No support contact is published by the service.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
        if let supportError {
            Text(supportError)
                .font(TimeMasterFont.secondary())
        }
        Text("Tmax is not an emergency service. For immediate danger, contact appropriate local emergency or specialist help.")
            .font(TimeMasterFont.caption())
            .foregroundStyle(ProfileStyle.secondary)
    }

    @ToolbarContentBuilder
    private var caseToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(action: requestRefresh) {
                Label("Refresh case", systemImage: "arrow.clockwise")
            }
            .physiqueToolbarTarget()
            .disabled(isLoading || isMutating || activeAccountID == nil || !presentationIsActive)
        }
        ToolbarItem(placement: .automatic) {
            if authorizedItem != nil || supportURL != nil {
            Menu {
                if let item = authorizedItem {
                    Button("Copy case reference", action: copyCaseReference)
                    if item.canWithdraw {
                        Button("Withdraw request", role: .destructive) {
                            withdrawalRevision = RequestRevision(item)
                            confirmsWithdrawal = true
                        }
                        .disabled(isMutating || store.busy || isLoading || pendingResponse != nil)
                    }
                }
                if let url = supportURL {
                    Link("Contact support (opens another app)", destination: url)
                }
            } label: {
                Label("Case actions", systemImage: "ellipsis.circle")
            }
            .physiqueToolbarTarget()
            .confirmationDialog("Withdraw this request?", isPresented: $confirmsWithdrawal, titleVisibility: .visible) {
                Button("Withdraw request", role: .destructive) { Task { await withdrawRequest() } }
                Button("Keep request", role: .cancel) {}
            } message: {
                Text("You will no longer pursue this request. Received safety information or a lawful hold may still need handling. Withdrawal does not erase the case, undo a block, restore images, or cancel a restriction.")
            }
            }
        }
    }

    private func fact(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func datedFact(_ label: String, timestamp: Double) -> some View {
        fact(label, value: timestamp.isFinite && timestamp > 0
             ? Date(timeIntervalSince1970: timestamp).formatted(.dateTime.year().month(.abbreviated).day().hour().minute().timeZone())
             : "Date unavailable")
    }

    private func receiptView(title: String, reference: String, date: Double?, focus: AccessibilityTarget) -> some View {
        PhysiqueCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "checkmark.circle")
                    .font(TimeMasterFont.rowTitle())
                    .accessibilityFocused($accessibilityFocus, equals: focus)
                fact("Confirmed case reference", value: reference)
                if let date { datedFact("Response received", timestamp: date) }
                Text("This acknowledges receipt, not completed or human review.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
    }

    private func requestRefresh() {
        guard !isLoading, !isMutating else { return }
        refreshID = UUID()
    }

    private func loadCase(context: LoadContext) async {
        guard context.active, let accountID = context.accountID else {
            if context.accountID == nil { clearPrivateState() }
            return
        }
        if loadedAccountID != accountID || loadedCaseID != context.caseID {
            item = nil
            savedMatch = nil
            accountSnapshot = nil
        }
        isLoading = true
        loadError = nil
        let wasAuthorized = authorizedItem != nil
        do {
            let value = try await store.caseDetail(context.caseID)
            guard !Task.isCancelled, loadContext == context, activeAccountID == accountID else { return }
            guard value.id == context.caseID else {
                clearPrivateState()
                loadError = "This case could not be confirmed for the current account."
                isLoading = false
                return
            }
            loadedAccountID = accountID
            loadedCaseID = context.caseID
            let previous = item
            item = value
            reconcileResponse(with: value)
            if wasAuthorized, previous?.updatedAt != value.updatedAt,
               previous?.status != value.status || previous?.decision != value.decision {
                announce("Case updated. \(statusTitle(value.status)).")
            }
            if withdrawalUnconfirmed, value.status == "withdrawn" {
                withdrawalUnconfirmed = false
                withdrawalReceipt = value.id
                actionMessage = "The service confirms that your request was withdrawn."
            }
            if !wasAuthorized { accessibilityFocus = .status }
            savedMatch = nil
            matchError = nil
            if let matchID = value.matchID {
                do {
                    let match = try await store.getMatch(matchID)
                    guard !Task.isCancelled, loadContext == context, activeAccountID == accountID else { return }
                    savedMatch = match
                } catch {
                    guard !Task.isCancelled, loadContext == context, activeAccountID == accountID else { return }
                    matchError = "The associated match record could not be confirmed. Case information remains available."
                }
            }
            if value.kind == "dispute" || savedMatch?.result?.corrected == true || savedMatch?.result?.correction != nil {
                await store.refresh()
                guard !Task.isCancelled, loadContext == context, activeAccountID == accountID else { return }
                accountSnapshot = store.error == nil ? store.snapshot : nil
            }
            isLoading = false
        } catch {
            guard !Task.isCancelled, loadContext == context, activeAccountID == accountID else { return }
            item = nil
            savedMatch = nil
            accountSnapshot = nil
            loadedAccountID = nil
            loadedCaseID = nil
            if error is URLError {
                loadError = "The connection could not confirm this case. Private case content is hidden until access and current status can be checked again."
            } else {
                discardResponse()
                withdrawalUnconfirmed = false
                withdrawalReceipt = nil
                actionMessage = nil
                loadError = "This case could not be loaded for the current account. It may be unavailable or access may have changed."
            }
            isLoading = false
        }
    }

    private func sendResponse(retrying: Bool) async {
        guard !isMutating, !store.busy, !isLoading, let accountID = activeAccountID,
              let item = authorizedItem, item.needsReply else { return }
        let text: String
        let expectedRevision: RequestRevision
        if retrying, let pendingResponse {
            expectedRevision = pendingResponse.revision
            text = pendingResponse.text
        } else {
            text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                responseError = "Enter a safe text response before sending. Nothing was sent."
                accessibilityFocus = .responseError
                return
            }
            guard draft.unicodeScalars.count <= 4_000 else {
                responseError = "Your response exceeds the 4,000-character limit. Shorten it before sending; your text has been kept."
                accessibilityFocus = .responseError
                return
            }
            guard !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0.value != 9 && $0.value != 10 }) else {
                responseError = "Remove unsupported control characters from your response before sending. Your text has been kept."
                accessibilityFocus = .responseError
                return
            }
            guard let responseRequest else { return }
            expectedRevision = responseRequest
        }
        guard expectedRevision == RequestRevision(item) else {
            responseState = .changed
            accessibilityFocus = .changed
            return
        }
        let operationID = UUID()
        mutationID = operationID
        isMutating = true
        responseFocused = false
        responseError = nil
        defer {
            if mutationID == operationID {
                isMutating = false
                mutationID = nil
            }
        }
        do {
            let current = try await store.caseDetail(item.id)
            guard activeAccountID == accountID, caseID == item.id, mutationID == operationID,
                  presentationIsActive else { return }
            guard current.id == item.id else {
                clearPrivateState()
                loadError = "This case could not be confirmed for the current account."
                return
            }
            self.item = current
            reconcileResponse(with: current)
            if responseState == .received { return }
            guard current.needsReply, expectedRevision == RequestRevision(current) else {
                responseState = .changed
                accessibilityFocus = .changed
                return
            }
            guard retrying || (responseState == .editing && draft.trimmingCharacters(in: .whitespacesAndNewlines) == text) else {
                responseError = "Your response changed while its request was being checked. Review the text and send again; nothing was sent."
                accessibilityFocus = .responseError
                return
            }
            if pendingResponse == nil {
                pendingResponse = PendingResponse(text: text, revision: expectedRevision, existingMessageIDs: Set(current.messages.map(\.id)))
            }
            responseState = .sending
            let confirmed = await store.perform("reply", targetID: current.id, text: text, expectedRevision: current.updatedAt)
            guard activeAccountID == accountID, caseID == current.id, mutationID == operationID else { return }
            if confirmed {
                responseReceipt = store.lastReceiptID ?? current.id
                responseState = .received
                responseReceivedAt = nil
                draft = ""
                draftStartedAt = nil
                accessibilityFocus = .responseReceipt
            } else {
                responseState = .unconfirmed
                responseError = store.error ?? "The service did not confirm receipt. Your response has been kept."
            }
            await loadCase(context: loadContext)
        } catch {
            guard activeAccountID == accountID, caseID == item.id, mutationID == operationID else { return }
            responseError = "Response not sent: the current information request could not be checked. Your text has been kept."
            accessibilityFocus = .responseError
            await loadCase(context: loadContext)
        }
    }

    private func reconcileResponse(with value: PhysiqueCase) {
        guard let pendingResponse else {
            if !draft.isEmpty, let responseRequest, responseRequest != RequestRevision(value) {
                if responseState != .changed {
                    responseState = .changed
                    accessibilityFocus = .changed
                }
            }
            return
        }
        if let received = value.messages.last(where: {
            !$0.fromStaff && $0.text == pendingResponse.text && !pendingResponse.existingMessageIDs.contains($0.id)
        }) {
            responseReceivedAt = received.createdAt
            responseReceipt = value.id
            responseState = .received
            self.pendingResponse = nil
            draft = ""
            draftStartedAt = nil
            responseError = nil
            accessibilityFocus = .responseReceipt
        } else if responseState == .received {
            self.pendingResponse = nil
        } else if pendingResponse.revision != RequestRevision(value) {
            if responseState != .changed {
                responseState = .changed
                accessibilityFocus = .changed
            }
        }
    }

    private func withdrawRequest() async {
        guard !isMutating, !store.busy, !isLoading, let accountID = activeAccountID,
              let item = authorizedItem, let withdrawalRevision else { return }
        let operationID = UUID()
        mutationID = operationID
        isMutating = true
        actionMessage = nil
        defer {
            if mutationID == operationID {
                isMutating = false
                mutationID = nil
            }
        }
        do {
            let current = try await store.caseDetail(item.id)
            guard activeAccountID == accountID, caseID == item.id, mutationID == operationID,
                  presentationIsActive else { return }
            guard current.id == item.id else {
                clearPrivateState()
                loadError = "This case could not be confirmed for the current account."
                return
            }
            self.item = current
            reconcileResponse(with: current)
            guard current.canWithdraw, RequestRevision(current) == withdrawalRevision else {
                actionMessage = "This case changed. Read its current status and permissions before requesting withdrawal again."
                return
            }
            let confirmed = await store.perform("withdrawCase", targetID: current.id, expectedRevision: current.updatedAt)
            guard activeAccountID == accountID, caseID == current.id, mutationID == operationID else { return }
            if confirmed {
                withdrawalReceipt = store.lastReceiptID ?? current.id
                withdrawalUnconfirmed = false
                actionMessage = "The service acknowledged your withdrawal request. The confirmed case status is shown above."
                accessibilityFocus = .withdrawalReceipt
            } else {
                withdrawalUnconfirmed = true
                actionMessage = nil
            }
            await loadCase(context: loadContext)
        } catch {
            guard activeAccountID == accountID, caseID == item.id, mutationID == operationID else { return }
            actionMessage = "Withdrawal was not sent because current permission could not be checked. Refresh the case and try again."
            await loadCase(context: loadContext)
        }
    }

    private func discardResponse() {
        draft = ""
        draftStartedAt = nil
        responseRequest = nil
        pendingResponse = nil
        responseState = .closed
        responseError = nil
        responseReceivedAt = nil
        responseReceipt = nil
        responseFocused = false
    }

    private func clearPrivateState() {
        item = nil
        savedMatch = nil
        accountSnapshot = nil
        loadedAccountID = nil
        loadedCaseID = nil
        isLoading = false
        loadError = nil
        matchError = nil
        discardResponse()
        isMutating = false
        mutationID = nil
        withdrawalRevision = nil
        withdrawalUnconfirmed = false
        withdrawalReceipt = nil
        actionMessage = nil
        confirmsWithdrawal = false
        confirmsDraftCancellation = false
        copyFeedbackID = nil
        supportError = nil
        factsExpanded = false
        earlierUpdatesExpanded = false
    }

    private func expireDraft() async {
        guard let startedAt = draftStartedAt else { return }
        let remaining = startedAt.addingTimeInterval(24 * 60 * 60).timeIntervalSinceNow
        if remaining > 0 {
            do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            catch { return }
        }
        guard draftStartedAt == startedAt else { return }
        discardResponse()
        actionMessage = "The unsent response expired after 24 hours. No response receipt was created locally."
    }

    private func copyCaseReference() {
        guard let item = authorizedItem else { return }
#if os(iOS)
        UIPasteboard.general.setItems([["public.utf8-plain-text": item.id]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.id, forType: .string)
#endif
        copyFeedbackID = UUID()
        announce("Copied case reference.")
    }

    private func clearCopyFeedback() async {
        guard let feedbackID = copyFeedbackID else { return }
        do { try await Task.sleep(nanoseconds: 2_500_000_000) }
        catch { return }
        guard copyFeedbackID == feedbackID else { return }
        copyFeedbackID = nil
    }

    private func announce(_ message: String) {
        guard presentationIsActive else { return }
#if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
#elseif os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
#endif
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value.formatted())" : value.formatted()
    }

    private func outcomeTitle(_ outcome: String) -> String {
        switch outcome {
        case "win": return "Win"
        case "loss": return "Loss"
        case "draw": return "Draw"
        case "forfeitWin": return "Forfeit win"
        case "forfeitLoss": return "Forfeit loss"
        case "noContest": return "No contest"
        default: return nonempty(outcome) ?? "Outcome unavailable"
        }
    }

    private func kindTitle(_ kind: String) -> String {
        switch kind {
        case "report": return "Private report"
        case "appeal": return "Safety appeal"
        case "dispute": return "Scoring review"
        case "restriction": return "Your account decision"
        default: return "Private case"
        }
    }

    private func kindSymbol(_ kind: String) -> String {
        switch kind {
        case "appeal": return "arrow.uturn.backward.circle"
        case "dispute": return "checkmark.seal"
        case "restriction": return "lock.shield"
        default: return "doc.text"
        }
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "received": return "Received"
        case "queued": return "Queued"
        case "inReview": return "In review"
        case "needsReply": return "More safe information requested"
        case "actionTaken": return "Action taken"
        case "noViolation": return "No violation found"
        case "inconclusive": return "Inconclusive"
        case "withdrawn": return "Withdrawn"
        case "closed": return "Closed"
        case "upheld": return "Original decision upheld"
        case "revised": return "Decision revised"
        default: return nonempty(status) ?? "Status unavailable"
        }
    }

    private func nextStep(_ item: PhysiqueCase) -> String {
        if item.needsReply { return "A safe text response is needed." }
        if item.canAppeal { return "You can request review of this account's decision." }
        switch item.status {
        case "received": return "Your request was received. This is not confirmation of human review."
        case "inconclusive": return "Review could not reach a conclusion. Read the service's confirmed explanation."
        case "withdrawn": return "Your request was withdrawn. Safety handling or required retention may continue."
        case "upheld": return "The original decision remains effective unless the service confirms a change."
        case "revised": return "Read what changed. A revised decision alone does not confirm a rating adjustment."
        case "noViolation": return "Read the finding for this concern. Media permissions have not been expanded by this screen."
        case "actionTaken": return "Read the participant-safe decision. Another person's private sanctions are not disclosed."
        case "queued", "inReview", "closed": return "No action needed now. Check the latest confirmed information below."
        default: return "Read the current service update and available actions below."
        }
    }
}
