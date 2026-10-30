import SwiftUI

@MainActor
struct PhysiqueDeletionStatusView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var receipts: [PhysiquePrivacyReceipt] = []
    @State private var receiptAccountID: String?
    @State private var currentRequest: UUID?
    @State private var loadingReceipts = false
    @State private var loadedReceipts = false
    @State private var receiptError: String?

    private var accessScope: String? {
        scenePhase == .active ? cloudAccount.accountID : nil
    }

    private var hasReceiptAccess: Bool {
        guard let accountID = cloudAccount.accountID else { return false }
        return scenePhase == .active && receiptAccountID == accountID
    }

    private var policy: PhysiquePolicy? {
        store.policy ?? store.snapshot?.policy
    }

    private var supportURL: URL? {
        guard let value = policy?.supportURL, let url = URL(string: value),
              let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "https", url.host?.isEmpty == false { return url }
        if scheme == "mailto", !url.path.isEmpty { return url }
        return nil
    }

    var body: some View {
        PhysiqueScreen(title: "Account deletion", subtitle: "Deletes this account, not just Physique.") {
            if scenePhase == .active {
                if cloudAccount.session != nil {
                    requestStatus
                } else {
                    statusRecovery
                }
                accountScope
                retentionPolicy
                privacyControls
            } else {
                PhysiqueStatusView(
                    title: "Private account information hidden",
                    detail: "Return to this window to check the authorized account status.",
                    systemImage: "lock.shield"
                )
            }
        }
        .privacySensitive()
        .task(id: accessScope) {
            clearReceipts()
            guard scenePhase == .active else { return }
            if cloudAccount.accountID != nil {
                await checkStatus()
            } else if store.policy == nil {
                await store.loadPolicy()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { clearReceipts() }
        }
        .onDisappear { clearReceipts() }
        .accessibilityIdentifier("physique-deletion-status")
    }

    @ViewBuilder
    private var requestStatus: some View {
        if hasReceiptAccess, loadingReceipts {
            ProgressView("Checking deletion status…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if hasReceiptAccess, let receiptError {
            PhysiqueStatusView(
                title: "Unable to refresh deletion status",
                detail: "\(receiptError) A connection, authorization, or missing-record error does not confirm deletion. Any receipt below is the last confirmed state.",
                systemImage: "exclamationmark.circle"
            )
        }
        if hasReceiptAccess, !receipts.isEmpty {
            ForEach(receipts) { receipt in
                receiptCard(receipt)
            }
        } else if hasReceiptAccess, loadedReceipts {
            PhysiqueStatusView(
                title: "No deletion receipt available",
                detail: "The service returned no account-deletion receipt for this account. This does not prove that a request was never sent or that deletion is complete. Check the shared Tmax account controls before retrying a request.",
                systemImage: "doc.text.magnifyingglass"
            )
        }
        PhysiqueAction(
            title: "Check status",
            systemImage: "arrow.clockwise",
            disabled: loadingReceipts
        ) {
            Task { await checkStatus() }
        }
    }

    private var statusRecovery: some View {
        PhysiqueCard {
            Label("Deletion status not confirmed", systemImage: "lock.doc")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            Text("Signing out is not proof of account deletion. Private receipts cannot be retrieved here after normal account access has been revoked.")
            Text("A secure post-deletion status-recovery route is not supplied by this service. Do not create a new account to check an old deletion request. Use the published operator contact for help verifying access; a receipt reference alone is not authorization.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            operatorContact
        }
    }

    private var accountScope: some View {
        PhysiqueCard {
            Text("One Tmax account")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            if let email = cloudAccount.email {
                Text(email).textSelection(.enabled)
            }
            Text("Global account deletion includes the cloud exercise database, Ranked account data, and Physique account records and pose media, except information lawfully required to remain.")
            Label("Your local library stays on this device.", systemImage: "internaldrive")
                .font(TimeMasterFont.label())
            matchConsequences
            Text("Opening account settings does not submit deletion or leave a match. The shared Tmax account controls own the final confirmation and supported account verification.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            PhysiqueAction(
                title: hasReceiptAccess && !receipts.isEmpty ? "Open Tmax account settings" : cloudAccount.session == nil ? "Open Tmax account controls" : "Delete Tmax account…",
                systemImage: "person.crop.circle.badge.minus"
            ) {
                onOpen(.account)
            }
        }
    }

    @ViewBuilder
    private var matchConsequences: some View {
        if cloudAccount.session != nil {
            Divider()
            Text("Match consequences")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            if store.snapshot == nil || store.isStale {
                Text("Current match effect is not confirmed. The shared account flow must reconcile the service state before confirming any rated departure; privacy protection does not require continued capture.")
            } else {
                Text("Last confirmed stage: \(store.stage.title)")
                    .font(TimeMasterFont.label())
                Text(matchExplanation)
                if let confirmedAt = store.lastRefreshedAt {
                    Text("Match state checked: \(confirmedAt.formatted(date: .complete, time: .complete))")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                }
            }
        }
    }

    private var matchExplanation: String {
        switch store.stage {
        case .idle, .noOpponent, .cancelled:
            return "The last confirmed state has no started match to leave. Opening account review creates no match, rating change, or allowance charge."
        case .searching, .ready, .countdown:
            return "Before the service confirms Go, an acknowledged deletion cancels pairing without a rating change and releases the reserved slot. A countdown reaching zero locally is not proof of Go. A late pre-Go decision cannot silently authorize a rated forfeit."
        case .capture, .submitting:
            return "Go has occurred. An explicit, informed departure from an otherwise eligible match can be a forfeit loss, and the allowance stays used. A service-established safety, invalid-evidence, or service abort is a no-contest instead. Opening account review alone is not a departure."
        case .judging:
            return "Accepted processing may not be retractable, and a final result may settle first. An explicit departure from an eligible open match can be a forfeit loss with the allowance used; a service-established safety, invalid-evidence, or service abort is a no-contest instead. The service determines the actual result and ordering."
        case .completed, .forfeited, .noContest:
            return "Deleting the account or removing images does not reroll an already-finalized result. It does not create a second forfeit or allowance charge. Any authorized scoring correction belongs to the separate review process."
        }
    }

    private var retentionPolicy: some View {
        PhysiqueCard {
            Text("Retention and media access")
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            if let retention = policy?.retention, !retention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(retention).textSelection(.enabled)
            } else {
                Text("Current operator retention terms are unavailable. No account-deletion completion deadline can be confirmed here.")
            }
            Text("Account cleanup does not extend an earlier pose-media expiry. A lawful evidence hold does not keep an ordinary pose gallery available. Deletion cannot recall copies already made outside Tmax.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            if cloudAccount.session != nil { operatorContact }
        }
    }

    private var privacyControls: some View {
        PhysiqueCard {
            Text("Only want to remove photos?")
                .font(TimeMasterFont.sectionTitle())
                .accessibilityAddTraits(.isHeader)
            Text("Photo removal, withdrawing sharing, unlisting, signing out, and removing Physique from navigation are not whole-account deletion or a rating reset.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            Button("Open privacy and sharing") { onOpen(.privacy) }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: false, fillsWidth: true))
        }
    }

    @ViewBuilder
    private var operatorContact: some View {
        if let supportURL {
            Link(destination: supportURL) {
                Label("Contact operator", systemImage: "arrow.up.right.square")
                    .font(TimeMasterFont.label())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: false, fillsWidth: true))
            Text("Contacting support does not itself submit an account-deletion request. Do not send pose photos, passwords, or status-access secrets.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
        } else {
            Text("The service has not supplied a usable operator contact. Use the shared Tmax account controls for available account recovery; no deletion-status recovery is confirmed here.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
        }
    }

    private func receiptCard(_ receipt: PhysiquePrivacyReceipt) -> some View {
        PhysiqueCard {
            Label(receiptTitle(receipt), systemImage: receiptSymbol(receipt))
                .font(TimeMasterFont.heading())
                .accessibilityAddTraits(.isHeader)
            Text(receipt.detail)
            if let retainedReason = receipt.retainedReason, !retainedReason.isEmpty {
                Label("Retention exception", systemImage: "lock.doc")
                    .font(TimeMasterFont.label())
                Text(retainedReason)
            }
            Text("Last confirmed: \(formattedTimestamp(receipt.updatedAt))")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            if receipt.status == "completed" {
                Text("This receipt concerns deletion in active systems. Any retention exception above and the published processor or backup terms still apply.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            } else {
                Text("Account deletion is not confirmed complete. A completion time is not supplied by this receipt.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    fact("Reference", value: receipt.id)
                    fact("Request received", value: formattedTimestamp(receipt.createdAt))
                    fact("Scope", value: "Global Tmax account deletion")
                    fact("Access", value: "Access effects are not separately reported by this receipt.")
                    fact("Account data", value: "Service status: \(receipt.status)")
                    fact("Expected completion", value: "Not supplied by the service.")
                }
                .padding(.top, ProfileStyle.spacing)
            } label: {
                Text("Details")
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TimeMasterFont.label())
            Text(value).font(TimeMasterFont.secondary()).textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func receiptTitle(_ receipt: PhysiquePrivacyReceipt) -> String {
        switch receipt.status {
        case "completed":
            return receipt.retainedReason?.isEmpty == false ? "Deleted from active systems; retention remains" : "Deleted from active systems"
        case "inProgress": return "Deletion in progress"
        case "partiallyHeld": return "Limited hold remains"
        default: return "Service status: \(receipt.status)"
        }
    }

    private func receiptSymbol(_ receipt: PhysiquePrivacyReceipt) -> String {
        switch receipt.status {
        case "completed": return receipt.retainedReason?.isEmpty == false ? "lock.doc" : "checkmark.circle"
        case "inProgress": return "doc.text"
        case "partiallyHeld": return "lock.doc"
        default: return "questionmark.circle"
        }
    }

    private func formattedTimestamp(_ timestamp: Double) -> String {
        Date(timeIntervalSince1970: timestamp).formatted(date: .complete, time: .complete)
    }

    private func clearReceipts() {
        currentRequest = nil
        receipts = []
        receiptAccountID = nil
        receiptError = nil
        loadingReceipts = false
        loadedReceipts = false
    }

    private func checkStatus() async {
        guard scenePhase == .active, let accountID = cloudAccount.accountID else { return }
        if receiptAccountID != accountID {
            clearReceipts()
            receiptAccountID = accountID
        }
        guard !loadingReceipts else { return }
        let request = UUID()
        currentRequest = request
        loadingReceipts = true
        receiptError = nil
        defer {
            if currentRequest == request {
                loadingReceipts = false
                currentRequest = nil
            }
        }
        await store.refresh()
        guard !Task.isCancelled, currentRequest == request,
              cloudAccount.accountID == accountID, scenePhase == .active else { return }
        do {
            let values = try await store.privacyReceipts()
            guard !Task.isCancelled, currentRequest == request,
                  cloudAccount.accountID == accountID, scenePhase == .active else { return }
            receipts = values.filter { $0.scope == "deleteAccount" }.sorted {
                $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
            }
            loadedReceipts = true
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, currentRequest == request,
                  cloudAccount.accountID == accountID, scenePhase == .active else { return }
            receiptError = error.localizedDescription
        }
    }
}
