import SwiftUI
import Combine
import TimeMasterCore

@MainActor
final class DeviceSyncCoordinator: ObservableObject {
    static let shared = DeviceSyncCoordinator()

    enum Status: Equatable {
        case notNearby
        case connecting
        case connected
        case syncing(String)
        case upToDate(Date)
        case problem(String)
    }

    struct Device: Identifiable, Equatable {
        let id: String
        var name: String
        var platform: DeviceSyncPlatform
        var status: Status
        var lastSynced: Date?
    }

    enum Pairing: Equatable {
        case idle
        case waiting
        case connecting(String)
        case comparing(name: String, platform: DeviceSyncPlatform, code: String)
        case waitingForOther(String)
        case paired(String)
        case failed(String)
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var nearby: [DeviceSyncNearby] = []
    @Published private(set) var pairing: Pairing = .idle
    @Published private(set) var problem: String?
    @Published private(set) var notice: String?
    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: DeviceSyncCoordinator.enabledKey)
            if !isEnabled { endPairing() }
            refreshNetwork()
        }
    }

    let deviceName = DeviceSyncIdentity.name
    let platform = DeviceSyncIdentity.platform

    private struct LiveSession {
        let token: UUID
        let session: SyncPeerSession
        var state: SyncPeerSession.State
    }

    private var engine: SyncEngine?
    private var deviceID = ""
    private var network: DeviceSyncNetwork?
    private var peers: [SyncPeerRecord] = []
    private var sessions: [String: LiveSession] = [:]
    private var dialing: Set<String> = []
    private var failures: [String: Int] = [:]
    private var nextAttempt: [String: Date] = [:]
    private var firstSeen: [String: Date] = [:]
    private var peerProblems: [String: String] = [:]
    private var announceFirstSync: Set<String> = []
    private var libraryReady = false
    private var isForeground = true
    private var inbound = 0
    private var redial: Task<Void, Never>?
    private var storedReload: Task<Void, Never>?
    private var pendingChanges: SyncChangeSet = []
    private var pairingWork: Task<Void, Never>?
    private var pairingSocket: DeviceSyncSocket?
    private var activePairing: SyncPairing?
    private var codeShownAt = Date.distantPast

    private static let dialGrace: TimeInterval = 8
    private static let probeInterval: TimeInterval = 0.7
    static let enabledKey = "tm.deviceSync.enabled"

    private var cloudBusy = false
    private var cloudObservers: Set<AnyCancellable> = []
    private var probe: Task<Void, Never>?

    static func extraFolders() -> SyncExtraFolders {
        if ProcessInfo.processInfo.environment["TIMEMASTER_DATA_ROOT"] != nil { return .none }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return SyncExtraFolders(
            photos: documents.appendingPathComponent("Photos", isDirectory: true),
            music: documents.appendingPathComponent("Music", isDirectory: true)
        )
    }

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: DeviceSyncCoordinator.enabledKey) as? Bool ?? true
    }



    func libraryDidLoad() {
        guard !libraryReady else { return }
        libraryReady = true
        let cloud = DatabaseSyncStore.shared
        Publishers.CombineLatest(cloud.$changingAccount, cloud.$changingMode)
            .map { $0 || $1 }
            .removeDuplicates()
            .sink { [weak self] busy in
                self?.cloudBusy = busy
                self?.refreshNetwork()
            }
            .store(in: &cloudObservers)
        refreshNetwork()
        #if DEBUG && os(macOS)
        DeviceSyncQAControl.shared.startIfRequested()
        #endif
    }

    func setForeground(_ active: Bool) {
        #if os(iOS)
        guard active != isForeground else { return }
        isForeground = active
        if !active { endPairing() }
        refreshNetwork()
        #endif
    }

    func libraryChanged() {
        for live in sessions.values { live.session.localChanged() }
    }


    private func makeEngine() -> SyncEngine? {
        if let engine { return engine }
        let engine = SyncEngine(database: DatabaseManager.shared, deviceName: deviceName, extra: Self.extraFolders())
        self.engine = engine
        return engine
    }

    private func reloadPeers() {
        peers = makeEngine()?.peers() ?? []
    }

    private func refreshNetwork() {
        reloadPeers()
        let wanted = libraryReady && isEnabled && isForeground && !cloudBusy && (!peers.isEmpty || pairing != .idle)
        if wanted { startNetwork() } else { stopNetwork() }
        rebuildDevices()
    }

    private func startNetwork() {
        guard network == nil, let engine = makeEngine() else { return }
        do {
            deviceID = try engine.deviceID()
        } catch {
            problem = "Sync couldn't set up this device. \(error.localizedDescription)"
            return
        }
        let network = DeviceSyncNetwork(
            identity: DeviceSyncNetwork.Identity(id: deviceID, name: deviceName, platform: platform),
            onNearby: { [weak self] list in Task { @MainActor in self?.nearbyChanged(list) } },
            onIncoming: { [weak self] socket in Task { @MainActor in self?.handleIncoming(socket) } },
            onProblem: { [weak self] text in Task { @MainActor in self?.problem = text } }
        )
        self.network = network
        network.setPairing(pairing == .waiting)
        network.start()
    }

    private func stopNetwork() {
        guard network != nil else { return }
        network?.stop()
        network = nil
        let live = sessions
        sessions = [:]
        for item in live.values { item.session.stop() }
        dialing = []
        nearby = []
        firstSeen = [:]
        redial?.cancel()
        stopProbe()
        problem = nil
    }

    private func startProbe() {
        guard probe == nil, let engine else { return }
        let interval = UInt64(Self.probeInterval * 1_000_000_000)
        probe = Task.detached(priority: .utility) { [weak self] in
            var last = engine.changeSignature()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: interval) } catch { return }
                let current = engine.changeSignature()
                guard current != last else { continue }
                last = current
                guard let target = self else { return }
                await MainActor.run { target.libraryChanged() }
            }
        }
    }

    private func stopProbe() {
        probe?.cancel()
        probe = nil
    }


    private func nearbyChanged(_ list: [DeviceSyncNearby]) {
        nearby = list
        let visible = Set(list.map(\.id))
        for id in firstSeen.keys where !visible.contains(id) { firstSeen[id] = nil }
        for id in visible where firstSeen[id] == nil { firstSeen[id] = Date() }
        dialMissing()
        rebuildDevices()
    }

    private func lastSynced(_ id: String) -> Date? {
        engine?.lastSynced(with: id)
    }

    private func rebuildDevices() {
        devices = peers.map { peer in
            let status: Status
            if let live = sessions[peer.id] {
                switch live.state {
                case .connected: status = .connected
                case .syncing(let text): status = .syncing(text)
                case .upToDate(let date): status = .upToDate(date)
                case .failed(let text): status = .problem(text)
                }
            } else if let text = peerProblems[peer.id] {
                status = .problem(text)
            } else if nearby.contains(where: { $0.id == peer.id }) {
                status = .connecting
            } else {
                status = .notNearby
            }
            return Device(id: peer.id, name: peer.name, platform: DeviceSyncPlatform(wire: peer.platform), status: status, lastSynced: lastSynced(peer.id))
        }
    }

    func syncNow(_ id: String) {
        if let live = sessions[id] {
            live.session.syncSoon()
            return
        }
        failures[id] = 0
        nextAttempt[id] = nil
        peerProblems[id] = nil
        firstSeen[id] = .distantPast
        dialMissing()
        rebuildDevices()
    }

    func remove(_ id: String) {
        let live = sessions.removeValue(forKey: id)
        live?.session.stop()
        try? makeEngine()?.removePeer(id: id)
        peerProblems[id] = nil
        refreshNetwork()
    }


    private static func watchdog(_ socket: DeviceSyncSocket, after seconds: TimeInterval, if condition: @escaping @MainActor () -> Bool = { true }) -> Task<Void, Never> {
        Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) } catch { return }
            if condition() { socket.close() }
        }
    }

    private func scheduleRedial(after delay: TimeInterval) {
        redial?.cancel()
        redial = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dialMissing()
        }
    }

    private func dialMissing() {
        guard let network, !deviceID.isEmpty else { return }
        var wait: TimeInterval?
        let now = Date()
        for peer in peers where sessions[peer.id] == nil && !dialing.contains(peer.id) {
            guard let found = nearby.first(where: { $0.id == peer.id }) else { continue }
            var delay: TimeInterval = 0
            if let next = nextAttempt[peer.id] { delay = max(delay, next.timeIntervalSince(now)) }
            if deviceID > peer.id { delay = max(delay, Self.dialGrace - now.timeIntervalSince(firstSeen[peer.id] ?? now)) }
            if delay > 0.05 {
                wait = min(wait ?? delay, delay)
                continue
            }
            dial(peer, found, network: network)
        }
        if let wait { scheduleRedial(after: wait + 0.05) }
    }

    private func dial(_ peer: SyncPeerRecord, _ found: DeviceSyncNearby, network: DeviceSyncNetwork) {
        dialing.insert(peer.id)
        let socket = network.open(found)
        let myID = deviceID
        Task { [weak self] in
            let watchdog = Self.watchdog(socket, after: 12)
            var channel: SyncSecureChannel?
            var failure: Error?
            do {
                try await socket.start(timeout: 8)
                try await SyncIntent.sync.announce(on: socket)
                channel = try await SyncSecureChannel.connect(transport: socket, myID: myID, peer: peer)
            } catch {
                DeviceSyncLog.logger.error("dialing \(peer.name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                failure = error
            }
            watchdog.cancel()
            self?.dialFinished(peer, socket: socket, channel: channel, failure: failure)
        }
    }

    private func dialFinished(_ peer: SyncPeerRecord, socket: DeviceSyncSocket, channel: SyncSecureChannel?, failure: Error?) {
        dialing.remove(peer.id)
        if let channel {
            socket.raiseLimit()
            if sessions[peer.id] != nil || network == nil { channel.close() } else { install(channel, role: .dialer) }
            failures[peer.id] = 0
        } else {
            socket.close()
            let count = (failures[peer.id] ?? 0) + 1
            failures[peer.id] = count
            nextAttempt[peer.id] = Date().addingTimeInterval(min(pow(2, Double(count)), 30))
            if (failure as? SyncFailure) == .notPaired {
                peerProblems[peer.id] = "\(peer.name) no longer knows this device. Remove it here and pair again."
            }
            rebuildDevices()
        }
        dialMissing()
    }


    private func install(_ channel: SyncSecureChannel, role: SyncPeerSession.Role) {
        guard let engine else {
            channel.close()
            return
        }
        let peerID = channel.peer.id
        sessions[peerID]?.session.stop()
        let token = UUID()
        let session = SyncPeerSession(
            engine: engine, channel: channel, role: role,
            onState: { [weak self] state in Task { @MainActor in self?.sessionState(peerID, token, state) } },
            onStored: { [weak self] changes in Task { @MainActor in self?.storedFromPeer(changes) } },
            onReport: { [weak self] report in Task { @MainActor in self?.sessionReported(peerID, token, report) } },
            onClosed: { [weak self] in Task { @MainActor in self?.sessionClosed(peerID, token) } }
        )
        sessions[peerID] = LiveSession(token: token, session: session, state: .connected)
        peerProblems[peerID] = nil
        rebuildDevices()
        startProbe()
        session.start()
    }

    private func sessionState(_ peerID: String, _ token: UUID, _ state: SyncPeerSession.State) {
        guard var live = sessions[peerID], live.token == token else { return }
        live.state = state
        sessions[peerID] = live
        rebuildDevices()
    }

    private func sessionReported(_ peerID: String, _ token: UUID, _ report: SyncReport) {
        guard sessions[peerID]?.token == token else { return }
        let name = peers.first { $0.id == peerID }?.name ?? "your other device"
        if announceFirstSync.remove(peerID) != nil, report.changedHere || report.changedThere {
            notice = "Synced with \(name). \(Self.summary(report))"
        }
        if !report.conflicts.isEmpty {
            let titles = report.conflicts.prefix(3).map { "“\($0)”" }.joined(separator: ", ")
            notice = "Edited on both devices: \(titles). Both versions of the same lines are kept in the note, so you can pick."
        }
    }

    private static func summary(_ report: SyncReport) -> String {
        var parts: [String] = []
        if report.itemsHere > 0 { parts.append("\(report.itemsHere) \(report.itemsHere == 1 ? "item" : "items") came here") }
        if report.itemsThere > 0 { parts.append("\(report.itemsThere) went over there") }
        if report.historyHere + report.historyThere > 0 { parts.append("history matched up") }
        guard !parts.isEmpty else { return "Everything matches." }
        let text = parts.joined(separator: ", ")
        return String(text.prefix(1)).uppercased() + String(text.dropFirst()) + "."
    }

    private func sessionClosed(_ peerID: String, _ token: UUID) {
        guard sessions[peerID]?.token == token else { return }
        sessions[peerID] = nil
        if sessions.isEmpty { stopProbe() }
        firstSeen[peerID] = Date()
        nextAttempt[peerID] = Date().addingTimeInterval(1)
        rebuildDevices()
        dialMissing()
    }

    private func storedFromPeer(_ changes: SyncChangeSet) {
        pendingChanges.formUnion(changes)
        guard storedReload == nil else { return }
        storedReload = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self else { return }
            self.storedReload = nil
            let changes = self.pendingChanges
            self.pendingChanges = []
            NotificationCenter.default.post(name: .deviceSyncDidStoreChanges, object: nil, userInfo: ["changes": changes.rawValue])
        }
    }

    private func handleIncoming(_ socket: DeviceSyncSocket) {
        guard network != nil, inbound < 6 else {
            socket.close()
            return
        }
        inbound += 1
        Task { [weak self] in
            await self?.serve(socket)
            self?.inbound -= 1
        }
    }

    private func serve(_ socket: DeviceSyncSocket) async {
        let watchdog = Self.watchdog(socket, after: 12)
        do {
            try await socket.start(timeout: 8)
            switch try await SyncIntent.read(from: socket) {
            case .sync:
                let known = Dictionary(peers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let channel = try await SyncSecureChannel.accept(transport: socket, myID: deviceID, lookup: { known[$0] })
                watchdog.cancel()
                socket.raiseLimit()
                if network != nil { install(channel, role: .listener) } else { channel.close() }
            case .pair:
                watchdog.cancel()
                await answerPairing(socket)
            }
        } catch {
            DeviceSyncLog.logger.error("an incoming connection ended: \(String(describing: error), privacy: .public)")
            watchdog.cancel()
            socket.close()
        }
    }


    func beginPairing() {
        guard isEnabled, pairing == .idle || isFinished(pairing) else { return }
        pairing = .waiting
        refreshNetwork()
        network?.setPairing(true)
    }

    private func isFinished(_ value: Pairing) -> Bool {
        switch value {
        case .paired, .failed: return true
        default: return false
        }
    }

    func endPairing() {
        pairingWork?.cancel()
        pairingWork = nil
        activePairing?.decline()
        activePairing = nil
        pairingSocket?.close()
        pairingSocket = nil
        guard pairing != .idle else { return }
        pairing = .idle
        network?.setPairing(false)
        refreshNetwork()
    }

    func retryPairing() {
        endPairing()
        beginPairing()
    }

    func pair(with device: DeviceSyncNearby) {
        guard case .waiting = pairing, let network else { return }
        pairing = .connecting(device.name)
        let socket = network.open(device)
        pairingWork = Task { [weak self] in
            await self?.runPairing(role: .initiator, socket: socket)
        }
    }

    private func answerPairing(_ socket: DeviceSyncSocket) async {
        guard case .waiting = pairing else {
            await SyncPairing.refuse(on: socket, reason: "Open “Add a device” on this device too, then try again.")
            try? await Task.sleep(nanoseconds: 300_000_000)
            socket.close()
            return
        }
        pairing = .connecting("another device")
        await runPairing(role: .responder, socket: socket)
    }

    private func runPairing(role: SyncPairing.Role, socket: DeviceSyncSocket) async {
        pairingSocket = socket
        let watchdog = Self.watchdog(socket, after: 20) { [weak self] in
            if case .connecting = self?.pairing { return true }
            return false
        }
        do {
            if role == .initiator {
                try await socket.start(timeout: 8)
                try await SyncIntent.pair.announce(on: socket)
            }
            let exchange = SyncPairing(
                role: role, me: SyncPairing.Identity(id: deviceID, name: deviceName, platform: platform.rawValue), transport: socket
            )
            activePairing = exchange
            let record = try await exchange.run { [weak self] code, other in
                Task { @MainActor in self?.showCode(code, other) }
            }
            watchdog.cancel()
            try finishPairing(record)
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                socket.close()
            }
        } catch {
            DeviceSyncLog.logger.error("pairing ended: \(String(describing: error), privacy: .public)")
            watchdog.cancel()
            socket.close()
            failPairing(error)
        }
        activePairing = nil
    }

    private func showCode(_ code: String, _ other: SyncPairing.Identity) {
        guard activePairing != nil, case .connecting = pairing else { return }
        codeShownAt = Date()
        pairing = .comparing(name: other.name, platform: DeviceSyncPlatform(wire: other.platform), code: code)
    }

    func confirmPairing(matches: Bool) {
        guard case let .comparing(name, _, _) = pairing else { return }
        if matches, Date().timeIntervalSince(codeShownAt) < 1 { return }
        if matches {
            pairing = .waitingForOther(name)
            activePairing?.approve()
        } else {
            activePairing?.decline()
            pairing = .failed("Those codes didn't match, so nothing was paired. If you didn't expect this, check who is on your Wi-Fi.")
        }
    }

    private func finishPairing(_ record: SyncPeerRecord) throws {
        guard let engine = makeEngine() else { throw SyncFailure.connectionLost }
        try engine.addPeer(record)
        failures[record.id] = 0
        nextAttempt[record.id] = nil
        peerProblems[record.id] = nil
        announceFirstSync.insert(record.id)
        pairing = .paired(record.name)
        network?.setPairing(false)
        refreshNetwork()
        dialMissing()
    }

    private func failPairing(_ error: Error) {
        switch pairing {
        case .idle, .failed: return
        default: break
        }
        switch error as? SyncFailure {
        case .cancelled?:
            pairing = .failed("The other device said the codes didn't match, or it stopped. Nothing was paired.")
        case .remote(let text)?:
            pairing = .failed(text)
        default:
            pairing = .failed("Couldn't pair. Make sure both devices are on the same Wi-Fi and both have “Add a device” open, then try again.")
        }
    }
}

extension Notification.Name {
    static let deviceSyncDidStoreChanges = Notification.Name("TimeMaster.deviceSyncDidStoreChanges")
}

extension Notification {
    var deviceSyncChanges: SyncChangeSet {
        SyncChangeSet(rawValue: userInfo?["changes"] as? Int ?? 0)
    }
}
