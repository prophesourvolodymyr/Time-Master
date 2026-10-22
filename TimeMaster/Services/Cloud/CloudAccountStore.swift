import Foundation
import Combine
import TimeMasterCore

@MainActor
final class CloudAccountStore: ObservableObject {
    static let shared = CloudAccountStore()

    @Published private(set) var session: CloudSession?
    @Published private(set) var busy = false
    @Published private(set) var restored = false
    @Published private(set) var providerSettings: CloudAuthSettings?
    @Published private(set) var providerError: String?
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    @Published private(set) var passwordRecovery = false
    @Published var presentsRecovery = false

    private let oauth = CloudOAuthPresenter()
    private var started = false
    private var deferredCallback: URL?
    private var processingCallback: URL?
    private var completedCallback: URL?

    var configured: Bool { if case .success = CloudServices.auth { return true }; return false }
    var configurationError: String? { if case .failure(let error) = CloudServices.auth { return error.localizedDescription }; return nil }
    var accountID: String? { session?.userID }
    var email: String? { session?.email }

    func start() async {
        guard !started else { return }
        started = true
        await DatabaseSyncStore.shared.start()
        do {
            let current = try await CloudServices.auth.get().restore()
            try await applyIdentity(current)
        } catch { self.error = error.localizedDescription }
        restored = true
        Task { await self.loadProviderSettings() }
        if let deferredCallback {
            self.deferredCallback = nil
            await handleCallback(deferredCallback)
        }
    }

    func loadProviderSettings() async {
        guard started, restored else { return }
        do {
            providerSettings = try await CloudServices.auth.get().settings()
            providerError = nil
        } catch {
            providerSettings = nil
            providerError = "Provider availability could not be checked: \(error.localizedDescription)"
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await $0.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String, displayName: String) async {
        await authenticate { client in
            let value = try await client.signUp(email: email, password: password, displayName: displayName)
            if value == nil {
                self.notice = "Account request submitted. If confirmation is needed, open the latest email link on this device to finish sign-in. Your library remains available locally."
            }
            return value
        }
    }

    func signIn(provider: String) async {
        guard !busy, started, restored else { return }
        busy = true
        error = nil
        notice = nil
        await prepareIdentityChange()
        do {
            let client = try CloudServices.auth.get()
            let url = try await client.oauthURL(provider: provider)
            let callback = try await oauth.authenticate(url: url, callbackScheme: CloudServices.callbackURL.scheme!)
            let value = try await client.handleCallback(callback)
            completedCallback = callback
            try await applyIdentity(value)
        } catch {
            if let client = try? CloudServices.auth.get() { try? await client.cancelOAuth() }
            self.error = error.localizedDescription
            await recoverUnchangedIdentity()
        }
        await finishOperation()
    }


    func resendConfirmation(email: String) async {
        await performAccountAction {
            try await CloudServices.auth.get().resendConfirmation(email: email)
            notice = "Confirmation email requested. Delivery depends on the project's email configuration; check your inbox and spam folder."
        }
    }

    func requestPasswordReset(email: String) async {
        await performAccountAction {
            try await CloudServices.auth.get().requestPasswordReset(email: email)
            notice = "If an account exists for this email, a password-reset link has been requested. Open the latest link on this device."
        }
    }

    func updatePassword(_ password: String) async {
        await performAccountAction {
            try await CloudServices.auth.get().updatePassword(password)
            passwordRecovery = false
            notice = "Your password was updated."
        }
    }

    func handleCallback(_ url: URL) async {
        guard let client = try? CloudServices.auth.get(), client.acceptsCallback(url) else { return }
        guard started, restored else { deferredCallback = url; return }
        guard processingCallback != url, completedCallback != url else { return }
        guard !busy else { deferredCallback = url; return }
        processingCallback = url
        busy = true
        error = nil
        notice = nil
        await prepareIdentityChange()
        do {
            let recovery = try await client.callbackIsRecovery(url)
            let value = try await client.handleCallback(url)
            try await applyIdentity(value)
            completedCallback = url
            if recovery {
                passwordRecovery = true
                presentsRecovery = true
                notice = "Your reset link was verified. Choose a new password."
            } else { notice = "Your account link was verified. You are signed in." }
        } catch {
            self.error = error.localizedDescription
            await recoverUnchangedIdentity()
        }
        processingCallback = nil
        await finishOperation()
    }

    func signOut() async {
        guard !busy, restored else { return }
        busy = true
        error = nil
        notice = nil
        await prepareIdentityChange(keepRankedConnection: true)
        var rankedLogoutError: String?
        do {
            let client = try CloudServices.auth.get()
            var revoked = false
            do {
                let result: RankedOK = try await RankedAPI.shared.request("v1/auth/logout", method: "POST")
                guard result.ok else { throw RankedServiceError.message("The service did not confirm remote sign-out.") }
                revoked = true
            } catch { rankedLogoutError = error.localizedDescription }
            if revoked { try await client.clearLocalSession() }
            else { try await client.signOut() }
        } catch { self.error = error.localizedDescription }
        if let rankedLogoutError {
            self.error = [self.error, "Remote Ranked activity cleanup could not be confirmed: \(rankedLogoutError)"].compactMap { $0 }.joined(separator: " ")
        }
        do {
            let remaining = try await CloudServices.auth.get().restore()
            try await applyIdentity(remaining)
            if remaining == nil {
                passwordRecovery = false
                notice = "Signed out on this device. Your local library and ZIP export remain available."
            }
        } catch { self.error = error.localizedDescription }
        await finishOperation()
    }

    func deleteAccount() async {
        guard !busy, session != nil else { return }
        PhysiqueStore.shared.suspendCapture()
        busy = true
        error = nil
        notice = nil
        var confirmedDeleted = false
        await DatabaseSyncStore.shared.prepareForIdentityChange()
        do {
            let result: RankedOK = try await RankedAPI.shared.request("v1/account", method: "DELETE")
            guard result.ok else { throw RankedServiceError.message("The service did not confirm account deletion.") }
            confirmedDeleted = true
            RankedAccountStore.shared.accountWillChange()
            await RankedAPI.shared.activateAccount(nil)
            try await CloudServices.auth.get().clearLocalSession()
            try await applyIdentity(nil)
            passwordRecovery = false
            notice = "Your cloud account was deleted. The local library was kept on this device."
        } catch {
            if confirmedDeleted {
                self.error = "The cloud account was deleted, but secure local session cleanup failed: \(error.localizedDescription) Sign out on this device to retry removing credentials. Database sync is now local-only."
            } else {
                self.error = "Account deletion could not be confirmed and may still be pending: \(error.localizedDescription) Database sync is now local-only. Retry Delete cloud account to finish cleanup."
            }
            await DatabaseSyncStore.shared.setSyncEnabled(false)
            DatabaseSyncStore.shared.resumeAfterUnchangedIdentity()
        }
        await finishOperation()
    }

    func linkRanked(login: String, password: String) async {
        await performAccountAction {
            struct Link: Encodable { let login: String; let password: String }
            let _: RankedAccountSnapshot = try await RankedAPI.shared.request("v1/account/link-ranked", method: "POST", body: JSONEncoder().encode(Link(login: login, password: password)))
            RankedAccountStore.shared.accountWillChange()
            await RankedAccountStore.shared.refresh()
            notice = "Existing Ranked account linked. Your aliases, ratings and match history have been preserved."
        }
    }

    func clearMessages() { error = nil; notice = nil }

    private func authenticate(_ action: (CloudAuthClient) async throws -> CloudSession?) async {
        guard !busy, started, restored else { return }
        busy = true
        error = nil
        notice = nil
        await prepareIdentityChange()
        do {
            let value = try await action(CloudServices.auth.get())
            try await applyIdentity(value)
            if value != nil { passwordRecovery = false }
        } catch {
            self.error = error.localizedDescription
            await recoverUnchangedIdentity()
        }
        await finishOperation()
    }

    private func performAccountAction(_ action: () async throws -> Void) async {
        guard !busy, started, restored else { return }
        busy = true
        error = nil
        notice = nil
        do { try await action() }
        catch { self.error = error.localizedDescription }
        await finishOperation()
    }

    private func finishOperation() async {
        busy = false
        if let callback = deferredCallback {
            deferredCallback = nil
            await handleCallback(callback)
        }
    }

    private func prepareIdentityChange(keepRankedConnection: Bool = false) async {
        PhysiqueStore.shared.suspendCapture()
        RankedAccountStore.shared.accountWillChange()
        if !keepRankedConnection { await RankedAPI.shared.activateAccount(nil) }
        await DatabaseSyncStore.shared.prepareForIdentityChange()
    }

    private func applyIdentity(_ value: CloudSession?) async throws {
        session = nil
        try await DatabaseSyncStore.shared.activateAccount(value?.userID)
        await RankedAPI.shared.activateAccount(value?.userID)
        session = value
        if value != nil { Task { await RankedAccountStore.shared.refresh() } }
    }

    private func recoverUnchangedIdentity() async {
        do {
            let current = try await CloudServices.auth.get().restore()
            try await applyIdentity(current)
        } catch {
            session = nil
            self.error = "\(self.error.map { "\($0) " } ?? "")\(error.localizedDescription)"
        }
    }
}
