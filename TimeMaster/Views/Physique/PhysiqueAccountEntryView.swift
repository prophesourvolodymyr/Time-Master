import SwiftUI

struct PhysiqueAccountEntryView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var cloudAccount = CloudAccountStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var contextFocused: Bool
    @State private var accessState = AccessState.idle
    @State private var retryRevision = 0
    @State private var originalAccountID: String?
    @State private var accountChanged = false
    @State private var focusedInitialContext = false
    @State private var leaving = false

    private enum AccessState {
        case idle
        case checking(ownerID: String, startedAt: Date)
        case verified(ownerID: String)
        case failed(ownerID: String, message: String)
    }

    private struct AccessRequest: Hashable {
        let ownerID: String?
        let restored: Bool
        let busy: Bool
        let recovering: Bool
        let accountError: String?
        let active: Bool
        let retryRevision: Int
    }

    private var accessRequest: AccessRequest {
        AccessRequest(
            ownerID: cloudAccount.accountID,
            restored: cloudAccount.restored,
            busy: cloudAccount.busy,
            recovering: cloudAccount.passwordRecovery,
            accountError: cloudAccount.error,
            active: scenePhase == .active,
            retryRevision: retryRevision
        )
    }

    private var accountIsUsable: Bool {
        !leaving && scenePhase == .active && cloudAccount.restored
            && !cloudAccount.busy && !cloudAccount.passwordRecovery
            && cloudAccount.accountID != nil && cloudAccount.error == nil
    }

    private var verifiedAccount: PhysiqueAccount? {
        guard accountIsUsable, !store.loading, !store.isStale, store.error == nil,
              case .verified(let ownerID) = accessState,
              ownerID == cloudAccount.accountID else { return nil }
        return store.account
    }

    private var checkingAccess: Bool {
        guard accountIsUsable, case .checking(let ownerID, _) = accessState else { return false }
        return ownerID == cloudAccount.accountID
    }

    private var accessFailure: String? {
        guard accountIsUsable else { return nil }
        switch accessState {
        case .failed(let ownerID, let message) where ownerID == cloudAccount.accountID:
            return message
        case .verified(let ownerID) where ownerID == cloudAccount.accountID:
            return store.error
        default:
            return nil
        }
    }

    private var canContinue: Bool {
        verifiedAccount != nil && !store.busy
    }

    private var contextTitle: String {
        if !cloudAccount.restored { return "Restoring account…" }
        if cloudAccount.passwordRecovery { return "Reset password" }
        if cloudAccount.busy { return "Account operation in progress" }
        if cloudAccount.error != nil { return "Tmax account needs attention" }
        if cloudAccount.accountID == nil { return "Sign in to compete" }
        if checkingAccess { return "Checking Physique access…" }
        if accessFailure != nil { return "Can’t check Physique access" }
        if let account = verifiedAccount {
            if account.restrictedReason != nil || store.policy?.ready != true { return "Physique unavailable" }
            return accountChanged ? "Account changed" : "Ready for Physique"
        }
        return "Check Physique access"
    }

    private var contextDetail: String {
        if !cloudAccount.restored { return "No previous-account content is shown while the shared account is restored." }
        if cloudAccount.passwordRecovery { return "Choose and save a new password in Tmax Account before returning to Physique." }
        if cloudAccount.busy { return "The shared Tmax account is completing a request. No Physique action will start automatically." }
        if let error = cloudAccount.error { return error }
        if cloudAccount.accountID == nil { return "Your Tmax account. Separate Physique Elo." }
        if checkingAccess { return "Confirming current access with the Physique service. Local account restoration alone does not grant access." }
        if let accessFailure { return accessFailure }
        if let account = verifiedAccount {
            if let reason = account.restrictedReason { return reason }
            if store.policy?.ready != true {
                return store.policy?.unavailableReason ?? "The service has not confirmed that rated Physique matches are available. You can return to the lobby."
            }
            if accountChanged { return "Continue with this account from the lobby. Previous-account private destinations are not restored." }
            if let match = store.match, !match.stage.terminal {
                return "Continue to the lobby to review your existing match. Its original timing still applies; camera capture remains stopped."
            }
            return "Continue to the Physique lobby. Matchmaking, consent and camera access remain separate, deliberate actions."
        }
        return "Current service access must be confirmed before continuing. Open Tmax Account to manage sign-in or retry the access check."
    }

    private var contextSymbol: String {
        if cloudAccount.passwordRecovery { return "key" }
        if !cloudAccount.restored || cloudAccount.busy || checkingAccess { return "hourglass" }
        if cloudAccount.error != nil || accessFailure != nil || verifiedAccount?.restrictedReason != nil { return "exclamationmark.circle" }
        if verifiedAccount != nil && store.policy?.ready == true { return "checkmark.circle" }
        return "person.crop.circle"
    }

    var body: some View {
        PhysiqueScreen(title: "Physique account") {
            PhysiqueCard {
                HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.toolbarOrange)
                        .frame(width: 3)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Label("Physique", systemImage: contextSymbol)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(ProfileStyle.secondary)
                        Text(contextTitle)
                            .font(TimeMasterFont.sectionTitle())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($contextFocused)
                        Text(contextDetail)
                            .font(TimeMasterFont.body())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                CloudAccountSettingsView()
            } label: {
                HStack(spacing: ProfileStyle.spacing) {
                    Image(systemName: "person.crop.circle").accessibilityHidden(true)
                    Text(cloudAccount.passwordRecovery ? "Reset password in Tmax Account" : "Open Tmax Account")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .font(TimeMasterFont.label())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: verifiedAccount == nil, fillsWidth: true))
            .disabled(!cloudAccount.restored || cloudAccount.busy || leaving)
            .accessibilityHint("Uses the existing shared sign-in, account creation, recovery and account security controls.")

            if accountIsUsable && !checkingAccess && verifiedAccount == nil {
                PhysiqueAction(
                    title: "Retry access check",
                    systemImage: "arrow.clockwise",
                    disabled: store.loading || store.busy
                ) {
                    retryRevision &+= 1
                }
            }

            if verifiedAccount?.restrictedReason != nil {
                PhysiqueAction(title: "View safety and cases", systemImage: "checkmark.shield") {
                    guard verifiedAccount != nil else { return }
                    leave(for: .safety)
                }
            }

            Text("Signing in alone sends no physique photos and does not grant Physique sharing consent. Account switching and sign-out affect your shared Tmax account, not only Physique.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { leave(for: .lobby) }
                    .disabled(cloudAccount.busy || leaving)
            }
#if os(macOS)
            ToolbarItem(placement: .confirmationAction) {
                if canContinue {
                    Button("Continue to lobby") { continueToLobby() }
                        .buttonStyle(.borderedProminent)
                }
            }
#endif
        }
#if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if canContinue {
                PhysiqueAction(title: "Continue to lobby", systemImage: "arrow.right") {
                    continueToLobby()
                }
                .frame(maxWidth: ProfileStyle.readableWidth)
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity)
                .background(Theme.surface)
            }
        }
#endif
        .interactiveDismissDisabled(cloudAccount.busy)
        .navigationBarBackButtonHidden(cloudAccount.busy)
        .task(id: accessRequest) { await checkAccess() }
        .onAppear {
            store.suspendCapture()
            if originalAccountID == nil { originalAccountID = cloudAccount.accountID }
            if !focusedInitialContext {
                focusedInitialContext = true
                contextFocused = true
            }
        }
        .onChange(of: cloudAccount.accountID) { ownerID in
            accessState = .idle
            store.suspendCapture()
            if let ownerID {
                if let originalAccountID {
                    if ownerID != originalAccountID { accountChanged = true }
                } else {
                    originalAccountID = ownerID
                }
            }
        }
        .onChange(of: cloudAccount.busy) { busy in
            if busy {
                accessState = .idle
                store.suspendCapture()
            }
        }
        .onChange(of: store.loading) { loading in
            if !loading { resolveAccess() }
        }
        .onDisappear {
            accessState = .idle
            store.suspendCapture()
        }
        .accessibilityIdentifier("physique-account-entry")
    }

    @MainActor private func checkAccess() async {
        accessState = .idle
        guard accountIsUsable, let ownerID = cloudAccount.accountID else { return }
        accessState = .checking(ownerID: ownerID, startedAt: Date())
        await store.refresh()
        guard !Task.isCancelled, accountIsUsable, cloudAccount.accountID == ownerID else { return }
        resolveAccess()
    }

    private func resolveAccess() {
        guard accountIsUsable, !store.loading,
              case .checking(let ownerID, let startedAt) = accessState,
              ownerID == cloudAccount.accountID else { return }
        if let error = store.error {
            accessState = .failed(ownerID: ownerID, message: error)
        } else if store.account != nil, !store.isStale,
                  let refreshedAt = store.lastRefreshedAt, refreshedAt >= startedAt {
            accessState = .verified(ownerID: ownerID)
        } else {
            accessState = .failed(ownerID: ownerID, message: "Current Physique access was not confirmed. Retry the access check or open Tmax Account.")
        }
    }

    private func continueToLobby() {
        guard canContinue else { return }
        leave(for: .lobby)
    }

    private func leave(for route: PhysiqueRoute) {
        guard !cloudAccount.busy, !leaving else { return }
        leaving = true
        accessState = .idle
        store.suspendCapture()
        onOpen(route)
    }
}
