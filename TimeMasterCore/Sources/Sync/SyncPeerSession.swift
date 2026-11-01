import Foundation

public final class SyncPeerSession: @unchecked Sendable {
    public enum Role: Sendable {
        case dialer
        case listener
    }

    public enum State: Equatable, Sendable {
        case connected
        case syncing(String)
        case upToDate(Date)
        case failed(String)
    }

    public let peer: SyncPeerRecord
    public let role: Role
    private let engine: SyncEngine
    private let service: SyncService
    private let onState: @Sendable (State) -> Void
    private let onStored: @Sendable (SyncChangeSet) -> Void
    private let onReport: @Sendable (SyncReport) -> Void
    private let onClosed: @Sendable () -> Void
    private let lock = NSLock()
    private var connection: SyncConnection!
    private var state: State = .connected
    private var syncing = false
    private var syncAgain = false
    private var closed = false
    private var retryDelay: TimeInterval = 30
    private var retry: Task<Void, Never>?
    private var running: Task<Void, Never>?
    private var safetyNet: Task<Void, Never>?

    public static let recheckInterval: TimeInterval = 180

    public init(
        engine: SyncEngine, channel: SyncSecureChannel, role: Role,
        onState: @escaping @Sendable (State) -> Void,
        onStored: @escaping @Sendable (SyncChangeSet) -> Void,
        onReport: @escaping @Sendable (SyncReport) -> Void = { _ in },
        onClosed: @escaping @Sendable () -> Void
    ) {
        self.engine = engine
        self.peer = channel.peer
        self.role = role
        self.onState = onState
        self.onStored = onStored
        self.onReport = onReport
        self.onClosed = onClosed
        self.service = SyncService(engine: engine, peerID: channel.peer.id)
        service.onApplied = { onStored($0.changes) }
        service.onConfigApplied = { onStored(.config) }
        service.onHistoryChanged = { onStored(.history) }
        self.connection = SyncConnection(
            channel: channel, service: service,
            onNotice: { [weak self] notice, text in self?.received(notice, text: text) },
            onClose: { [weak self] in self?.connectionClosed() }
        )
    }

    public var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func start() {
        connection.start()
        if role == .dialer {
            syncSoon()
            lock.lock()
            safetyNet = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(Self.recheckInterval * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    self?.syncSoon()
                }
            }
            lock.unlock()
        }
    }

    public func stop() {
        connection.close()
    }


    public func localChanged() {
        switch role {
        case .dialer: syncSoon()
        case .listener: Task { [connection] in await connection?.notify(.changed) }
        }
    }

    public func syncSoon() {
        guard role == .dialer else {
            Task { [connection] in await connection?.notify(.changed) }
            return
        }
        lock.lock()
        guard !closed else { lock.unlock(); return }
        retry?.cancel()
        retry = nil
        if syncing {
            syncAgain = true
            lock.unlock()
            return
        }
        syncing = true
        running = Task { [self] in await syncLoop() }
        lock.unlock()
    }

    private func received(_ notice: SyncNotice, text: String?) {
        switch notice {
        case .changed:
            if role == .dialer { syncSoon() }
        case .syncing:
            update(.syncing("\(peer.name) is syncing…"))
        case .synced:
            update(.upToDate(Date()))
        case .failed:
            update(.failed(text ?? "The other device could not sync."))
        }
    }

    private func update(_ value: State) {
        lock.lock()
        guard !closed, state != value else { lock.unlock(); return }
        state = value
        lock.unlock()
        onState(value)
    }

    private func connectionClosed() {
        lock.lock()
        closed = true
        let tasks = [retry, running, safetyNet]
        retry = nil
        running = nil
        safetyNet = nil
        lock.unlock()
        for task in tasks { task?.cancel() }
        service.cancelUploads()
        onClosed()
    }


    private func syncLoop() async {
        repeat {
            await connection.notify(.syncing)
            update(.syncing("Syncing…"))
            let driver = SyncDriver(engine: engine, peer: peer, remote: connection, progress: { [weak self] text in self?.update(.syncing(text)) })
            do {
                let report = try await driver.reconcile()
                if report.changedHere { onStored(report.changes) }
                resetRetryDelay()
                await connection.notify(.synced)
                update(.upToDate(Date()))
                onReport(report)
            } catch {
                let failure = error as? SyncFailure
                if Task.isCancelled || error is CancellationError || failure == .connectionLost || failure == .cancelled {
                    connection.close()
                    endLoop()
                    return
                }
                let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                update(.failed(text))
                await connection.notify(.failed, text: text)
                if failure != .incompatible { scheduleRetry() }
            }
        } while shouldRepeat()
    }

    private func resetRetryDelay() {
        lock.lock()
        retryDelay = 30
        lock.unlock()
    }

    private func shouldRepeat() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if syncAgain, !closed {
            syncAgain = false
            return true
        }
        syncing = false
        return false
    }

    private func endLoop() {
        lock.lock()
        syncing = false
        syncAgain = false
        lock.unlock()
    }

    private func scheduleRetry() {
        lock.lock()
        let delay = retryDelay
        retryDelay = min(retryDelay * 4, 600)
        retry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.syncSoon()
        }
        lock.unlock()
    }
}
