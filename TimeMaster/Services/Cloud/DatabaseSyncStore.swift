import Foundation
import Combine
import TimeMasterCore

extension Notification.Name {
    static let exerciseLibraryDidSync = Notification.Name("TimeMaster.exerciseLibraryDidSync")
}

@MainActor
final class DatabaseSyncStore: ObservableObject {
    static let shared = DatabaseSyncStore()

    enum Status: String {
        case localOnly = "Local only"
        case signedOut = "Not signed in"
        case waiting = "Waiting to sync"
        case syncing = "Syncing exercise database"
        case switching = "Preparing account library"
        case stopping = "Stopping sync"
        case upToDate = "Last sync completed"
        case failed = "Sync needs attention"
    }

    @Published private(set) var status: Status = .signedOut
    @Published private(set) var syncEnabled: Bool
    @Published private(set) var changingMode = false
    @Published private(set) var changingAccount = false
    @Published private(set) var libraryGeneration: UInt64 = 0
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var conflicts = 0
    @Published private(set) var uploadedFiles = 0
    @Published private(set) var downloadedFiles = 0
    @Published private(set) var hasTransferReport = false
    @Published private(set) var error: String?
    @Published private(set) var activeAccountID: String?

    private var engine: DatabaseSyncEngine?
    private var started = false
    private var foreground = false
    private var handingOff = false
    private var libraryOwnerAccountID: String?
    private var stoppingWork = 0
    private var localOperations = 0
    private var sceneTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var poller: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private static let localOnlyKey = "tm.databaseSync.localOnly"
    private let successScope: String

    private init() {
        switch CloudServices.auth {
        case .success(let client): successScope = client.configuration.keychainService
        case .failure: successScope = "unconfigured"
        }
        syncEnabled = (defaults.object(forKey: Self.localOnlyKey) as? Bool) == false
    }

    var configured: Bool { CloudServices.syncServiceURL != nil }
    var isSyncing: Bool { status == .syncing }
    var canSyncNow: Bool { started && foreground && syncEnabled && activeAccountID != nil && !handingOff && !changingMode && stoppingWork == 0 && localOperations == 0 && configured }

    func start() async {
        guard !started else { return }
        started = true
#if os(macOS)
        if defaults.bool(forKey: LocalLibraryMigration.pendingKey) {
            syncEnabled = false
            defaults.set(true, forKey: Self.localOnlyKey)
        }
#endif
        if let url = CloudServices.syncServiceURL {
            engine = DatabaseSyncEngine(dataRoot: DatabaseManager.shared.dataRoot, serviceURL: url)
        }
        updateIdleStatus()
    }

    func handleScenePhase(active: Bool) {
        foreground = active
        let previous = sceneTask
        sceneTask = Task {
            await previous?.value
            guard self.foreground == active else { return }
            if active { beginPolling() }
            else { await stopWork(); updateIdleStatus() }
        }
    }

    func prepareForIdentityChange() async {
        handingOff = true
        status = .switching
        await stopWork()
    }

    func activateAccount(_ accountID: String?) async throws {
        guard !changingAccount else { throw DatabaseSyncError.busy }
        handingOff = true
        let libraryChanges = syncEnabled && accountID != nil && accountID != libraryOwnerAccountID
        if libraryChanges {
            changingAccount = true
            libraryGeneration &+= 1
            await Task.yield()
        }
        var libraryAccessClosed = false
        defer {
            if libraryAccessClosed { ExerciseLibraryAccess.shared.endAccountChange() }
            if libraryChanges { changingAccount = false }
        }
        await stopWork()
        activeAccountID = nil
        lastSuccessfulSync = nil
        conflicts = 0
        uploadedFiles = 0
        downloadedFiles = 0
        hasTransferReport = false
        error = nil
        guard syncEnabled else {
            activeAccountID = accountID
            handingOff = false
            updateIdleStatus()
            return
        }
        if let accountID {
            guard let engine else {
                let failure = CloudAuthError.configuration("TMSyncServiceURL is required to activate an account library safely. Your existing local library has not been changed.")
                error = failure.localizedDescription
                status = .failed
                throw failure
            }
            if libraryChanges {
                await ExerciseLibraryAccess.shared.beginAccountChange()
                libraryAccessClosed = true
            }
            do { try await engine.activateAccount(accountID) }
            catch {
                self.error = "Account library could not be activated: \(error.localizedDescription)"
                status = .failed
                throw error
            }
            activeAccountID = accountID
            libraryOwnerAccountID = accountID
            lastSuccessfulSync = defaults.object(forKey: successKey(accountID)) as? Date
            if libraryChanges {
                NotificationCenter.default.post(name: .exerciseLibraryDidSync, object: nil, userInfo: ["accountChanged": true])
            }
        }
        handingOff = false
        updateIdleStatus()
        beginPolling()
    }

    func resumeAfterUnchangedIdentity() {
        handingOff = false
        updateIdleStatus()
        beginPolling()
    }

    func setSyncEnabled(_ enabled: Bool) async {
        guard !changingMode, enabled != syncEnabled else { return }
#if os(macOS)
        if enabled && defaults.bool(forKey: LocalLibraryMigration.pendingKey) {
            error = "Recover the previous library's missing files in Local storage before enabling sync. This prevents missing files from being treated as cloud deletions."
            return
        }
#endif
        changingMode = true
        if !enabled {
            status = .stopping
            await stopWork()
            syncEnabled = false
            defaults.set(true, forKey: Self.localOnlyKey)
            error = nil
        } else {
            syncEnabled = true
            do {
                try await activateAccount(activeAccountID)
                defaults.set(false, forKey: Self.localOnlyKey)
            } catch {
                syncEnabled = false
                defaults.set(true, forKey: Self.localOnlyKey)
                self.error = error.localizedDescription
            }
        }
        changingMode = false
        updateIdleStatus()
        beginPolling()
    }

    func syncNow() async {
        guard canSyncNow else {
            if !syncEnabled { status = .localOnly }
            else if activeAccountID == nil { status = .signedOut }
            else if !configured { error = "TMSyncServiceURL is missing or is not a secure HTTPS service address."; status = .failed }
            return
        }
        await performSync()
    }

    func performLocalOperation<T: Sendable>(token: ExerciseLibraryAccess.Token, operation: @escaping @Sendable () throws -> T) async throws -> T {
        localOperations += 1
        await stopWork()
        defer {
            localOperations -= 1
            updateIdleStatus()
            beginPolling()
        }
        return try await Task.detached(priority: .userInitiated) {
            try ExerciseLibraryAccess.shared.perform(token: token, operation: operation)
        }.value
    }

    private func beginPolling() {
        guard poller == nil, foreground, canSyncNow else { return }
        let version = generation
        poller = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.generation == version, self.foreground, self.canSyncNow {
                await self.performSync()
                do { try await Task.sleep(nanoseconds: 15_000_000_000) }
                catch { return }
            }
            if self.generation == version { self.poller = nil }
        }
    }

    private func performSync() async {
        if let syncTask { await syncTask.value; return }
        guard canSyncNow, foreground, let engine, let accountID = activeAccountID else { return }
        let version = generation
        status = .syncing
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try CloudServices.auth.get()
                var session = try await client.validSession()
                guard session.userID == accountID else { throw CloudAuthError.superseded }
                try Task.checkCancellation()
                let report: DatabaseSyncReport
                do {
                    report = try await engine.synchronize(accountID: accountID, accessToken: session.accessToken)
                } catch DatabaseSyncError.unauthorized {
                    session = try await client.refreshSession()
                    guard session.userID == accountID else { throw CloudAuthError.superseded }
                    try Task.checkCancellation()
                    report = try await engine.synchronize(accountID: accountID, accessToken: session.accessToken)
                }
                try Task.checkCancellation()
                guard self.generation == version, self.activeAccountID == accountID, self.syncEnabled, !self.handingOff else { return }
                self.lastSuccessfulSync = report.completedAt
                self.defaults.set(report.completedAt, forKey: self.successKey(accountID))
                self.conflicts = report.conflicts
                self.uploadedFiles = report.uploadedFiles
                self.downloadedFiles = report.downloadedFiles
                self.hasTransferReport = true
                self.error = nil
                self.status = .upToDate
                if report.downloadedFiles > 0 || report.conflicts > 0 {
                    NotificationCenter.default.post(name: .exerciseLibraryDidSync, object: nil)
                }
            } catch is CancellationError {
            } catch {
                guard self.generation == version, self.activeAccountID == accountID else { return }
                self.error = "\(error.localizedDescription) Changes remain on this device and will be retried while sync is enabled."
                self.status = .failed
            }
        }
        syncTask = task
        await task.value
        if generation == version { syncTask = nil }
    }

    private func stopWork() async {
        stoppingWork += 1
        defer { stoppingWork -= 1 }
        generation &+= 1
        let previousPoller = poller
        let previousSync = syncTask
        poller = nil
        syncTask = nil
        previousPoller?.cancel()
        previousSync?.cancel()
        await engine?.cancel()
        await previousSync?.value
        await previousPoller?.value
    }

    private func successKey(_ accountID: String) -> String { "tm.databaseSync.lastSuccess.\(successScope).\(accountID)" }

    private func updateIdleStatus() {
        if !syncEnabled { status = .localOnly; return }
        guard !handingOff else { status = error == nil ? .switching : .failed; return }
        if activeAccountID == nil { status = .signedOut }
        else if !configured {
            status = .failed
            error = "TMSyncServiceURL is missing or is not a secure HTTPS service address. Your library stays local."
        } else if error != nil { status = .failed }
        else { status = lastSuccessfulSync == nil ? .waiting : .upToDate }
    }
}
