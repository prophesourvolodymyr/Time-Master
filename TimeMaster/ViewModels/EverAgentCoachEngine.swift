import Foundation
import TimeMasterCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum CoachEngineError: LocalizedError {
    case helperMissing
    case notConnected
    case busy
    case notPaired
    case phoneAlreadyPaired
    case pairingRefused

    var errorDescription: String? {
        switch self {
        case .helperMissing: return "The tmax helper is missing from this build of Tmax."
        case .notConnected: return "EverAgent is not connected."
        case .busy: return "EverAgent is still working on the previous message."
        case .notPaired: return "This iPhone is not paired with EverAhent yet."
        case .phoneAlreadyPaired: return "This EverAhent container already has an iPhone paired, and EverAhent allows one iPhone per container. Remove that iPhone under “Paired devices” in EverAhent on your Mac, or create another container for Tmax."
        case .pairingRefused: return "EverAhent did not accept this pairing code. Codes last five minutes and work once. Create a new one on your Mac and try again."
        }
    }
}

@MainActor
final class EverAgentCoachEngine: ObservableObject {
    static let shared = EverAgentCoachEngine()

    enum Availability: Equatable {
        case unknown
        case checking
        case starting
        case ready
        case unavailable(String)
    }

    @Published private(set) var availability: Availability = .unknown {
        didSet { publishEngineName() }
    }
    @Published private(set) var request: EverAgentUIRequest?
    @Published private(set) var models: [EverAgentModelInfo] = []
    @Published private(set) var gatewayName: String?
    @Published var modelChoice: String? {
        didSet { UserDefaults.standard.set(modelChoice, forKey: Self.modelDefault) }
    }

    private static let modelDefault = "coach_model_v1"
    private static let toolWait: TimeInterval = 8
    private static let promptRetries = 8
    private static let retryAfterFailure: TimeInterval = 60

    private var client: EverAgentClient?
    private var project: EverAgentProject?
    private var activeSession: (project: String, session: String)?
    private var answered: Set<String> = []
    private(set) var wasStopped = false
    private var lastUnreachable: Date?

    #if os(macOS)
    private let socketPaths: () -> [String]
    private let workspaceDirectory: URL
    private let helperPath: String

    init(
        socketPaths: @escaping () -> [String] = { EverAgentSocketDiscovery.candidates() },
        workspaceDirectory: URL = CoachWorkspace.defaultDirectory(),
        helperPath: String = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/tmax").path
    ) {
        self.socketPaths = socketPaths
        self.workspaceDirectory = workspaceDirectory
        self.helperPath = helperPath
        modelChoice = UserDefaults.standard.string(forKey: Self.modelDefault)
    }
    #else
    @Published private(set) var pairedProfile: EverAgentRemoteProfile?
    private let profileStore: CoachRemoteProfileStore
    private let identity: EverAgentDeviceIdentity

    init(profileStore: CoachRemoteProfileStore = CoachRemoteProfileStore(), identity: EverAgentDeviceIdentity = EverAgentKeychainIdentity()) {
        self.profileStore = profileStore
        self.identity = identity
        pairedProfile = profileStore.load()
        modelChoice = UserDefaults.standard.string(forKey: Self.modelDefault)
    }
    #endif

    var isActive: Bool {
        availability == .ready && !AIStore.shared.usesOwnKey
    }

    var isRunning: Bool {
        activeSession != nil
    }

    private func publishEngineName() {
        AIStore.shared.refreshEngineName()
    }

    func isReadyToSend() async -> Bool {
        let settled = availability == .ready || availability == .checking || availability == .starting
        if !AIStore.shared.usesOwnKey, !settled, isDueForRetry { await refresh(quiet: true) }
        return isActive
    }

    private var isDueForRetry: Bool {
        guard let lastUnreachable else { return true }
        return Date().timeIntervalSince(lastUnreachable) >= Self.retryAfterFailure
    }

    func loadModels() async {
        guard let client, let project else { return }
        let connected = Set(((try? await client.providerCatalog(projectId: project.id)) ?? []).filter { !$0.accounts.isEmpty }.map(\.id))
        let everything = (try? await client.models(projectId: project.id)) ?? []
        models = everything.filter { connected.contains($0.provider) }
    }

    func run(sessionID: UUID, title: String, text: String, update: @escaping @MainActor (CoachTurn) -> Void) async -> CoachTurn {
        var turn = CoachTurn()
        guard let client, let project else {
            return Self.failed(turn, CoachEngineError.notConnected)
        }
        guard activeSession == nil else {
            return Self.failed(turn, CoachEngineError.busy)
        }
        let sessionId = sessionID.uuidString.lowercased()
        activeSession = (project.id, sessionId)
        answered = []
        wasStopped = false
        defer {
            activeSession = nil
            request = nil
        }
        do {
            try prepareForTurn()
            try await client.ensureSession(sessionId: sessionId, projectId: project.id, title: title)
            if let choice = modelChoice, let ref = Self.modelRef(choice) {
                try await client.setModel(sessionId: sessionId, projectId: project.id, model: ref)
            }
            let events = try await client.subscribe(
                sessionId: sessionId,
                topics: [EverAgentTopic.agent, EverAgentTopic.agentError, EverAgentTopic.uiRequest, EverAgentTopic.uiRequestClosed]
            )
            var toolsReady = false
            for _ in 0..<Int(Self.toolWait) where !toolsReady && !wasStopped {
                toolsReady = (try? await client.waitForTools(sessionId: sessionId, projectId: project.id, prefix: CoachConstants.toolPrefix, timeout: 1)) != nil
            }
            if wasStopped { throw CancellationError() }
            if !toolsReady {
                turn.addActivity(CoachActivity(id: "tmax-tools", title: "The Tmax tools did not connect", detail: Self.toolsHint, status: .failed))
            }
            var accepted = try await client.prompt(sessionId: sessionId, projectId: project.id, text: text)
            var retries = 0
            while !accepted.accepted, retries < Self.promptRetries, !wasStopped {
                retries += 1
                try await Task.sleep(nanoseconds: 250_000_000)
                accepted = try await client.prompt(sessionId: sessionId, projectId: project.id, text: text)
            }
            if wasStopped { throw CancellationError() }
            guard accepted.accepted else { throw CoachEngineError.busy }
            var lastEmit = Date.distantPast
            for await event in events {
                turn.apply(event)
                if let pending = turn.request, answered.contains(pending.requestId) { turn.resolveRequest() }
                request = turn.request
                let now = Date()
                if turn.isFinished || now.timeIntervalSince(lastEmit) > 0.04 {
                    lastEmit = now
                    update(turn)
                }
                if turn.isFinished { break }
            }
            if turn.needsReload || !turn.isFinished {
                turn.reconcile(with: try await client.getSession(sessionId: sessionId))
            }
            if !turn.isFinished { turn = Self.failed(turn, EverAgentError.connectionClosed) }
        } catch is CancellationError {
            turn.stop()
            try? await client.abort(sessionId: sessionId, projectId: project.id)
        } catch {
            turn = Self.failed(turn, error)
        }
        if case .failed = turn.phase { await dropIfUnreachable(client) }
        update(turn)
        return turn
    }

    func answer(_ result: JSONValue, cancelled: Bool = false) async {
        guard let client, let active = activeSession, let pending = request else { return }
        answered.insert(pending.requestId)
        request = nil
        try? await client.respondUI(projectId: active.project, sessionId: active.session, requestId: pending.requestId, result: result, cancelled: cancelled)
    }

    func stop() async {
        guard let client, let active = activeSession else { return }
        wasStopped = true
        try? await client.abort(sessionId: active.session, projectId: active.project)
    }

    private func dropIfUnreachable(_ client: EverAgentClient) async {
        if (try? await client.serverInfo()) != nil { return }
        await client.close()
        self.client = nil
        project = nil
        #if os(iOS)
        lastUnreachable = Date()
        #endif
        availability = .unavailable(Self.unreachable)
    }

    private static func failed(_ turn: CoachTurn, _ error: Error) -> CoachTurn {
        var turn = turn
        turn.fail(explain(error))
        return turn
    }

    static func modelKey(_ model: EverAgentModelInfo) -> String {
        "\(model.provider)/\(model.id)"
    }

    private static func modelRef(_ choice: String) -> EverAgentModelRef? {
        guard let slash = choice.firstIndex(of: "/") else { return nil }
        return EverAgentModelRef(provider: String(choice[..<slash]), id: String(choice[choice.index(after: slash)...]))
    }
}

#if os(macOS)
extension EverAgentCoachEngine {
    static let unreachable = "EverAgent isn't running."
    static let toolsHint = "Open Tmax's Agent Access settings and check that agent access is on."
    private static let everAgentBundleIdentifier = "com.everthink.ompp.connect"
    private static let startupAttempts = 30

    func refresh(quiet: Bool = false) async {
        guard availability != .checking else { return }
        if !quiet { availability = .checking }
        if let client, project != nil, (try? await client.serverInfo()) != nil {
            availability = .ready
            return
        }
        await client?.close()
        client = nil
        project = nil
        gatewayName = nil
        var tooOld = false
        for path in socketPaths() {
            let candidate = EverAgentClient(socketPath: path)
            do {
                try await candidate.connect()
                let info = try await candidate.serverInfo()
                guard info.supportsEventSubscription else {
                    tooOld = true
                    await candidate.close()
                    continue
                }
                do {
                    try provisionWorkspace()
                } catch {
                    await candidate.close()
                    availability = .unavailable(Self.explain(error))
                    return
                }
                project = try await candidate.attachProject(root: workspaceDirectory.path)
                client = candidate
                gatewayName = info.name
                availability = .ready
                return
            } catch {
                await candidate.close()
            }
        }
        availability = .unavailable(tooOld ? Self.explain(EverAgentError.gatewayTooOld) : Self.unreachable)
    }

    func startEverAgent() async {
        guard let url = everAgentURL() else {
            availability = .unavailable("EverAgent is not installed on this Mac.")
            return
        }
        availability = .starting
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            availability = .unavailable(error.localizedDescription)
            return
        }
        for _ in 0..<Self.startupAttempts {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refresh(quiet: true)
            if availability == .ready { return }
            if case .unavailable(let message) = availability, message != Self.unreachable { return }
        }
        availability = .unavailable("EverAgent opened, but its gateway did not start. Open a folder in EverAgent and check again.")
    }

    func prepareForTurn() throws {
        try provisionWorkspace()
    }

    private func provisionWorkspace() throws {
        guard FileManager.default.isExecutableFile(atPath: helperPath) else { throw CoachEngineError.helperMissing }
        try CoachWorkspace.provision(
            at: workspaceDirectory,
            helperPath: helperPath,
            persona: AIStore.shared.soulPrompt,
            guidance: AgentToolRegistry.coachGuidance,
            knowledgePath: AIStore.shared.knowledgeDirectoryPath
        )
    }

    private func everAgentURL() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.everAgentBundleIdentifier) { return url }
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/EverAhent.app")
        return FileManager.default.fileExists(atPath: home.path) ? home : nil
    }

    static func explain(_ error: Error) -> String {
        switch error {
        case EverAgentError.gatewayNotRunning:
            return unreachable
        case EverAgentError.gatewayTooOld:
            return "This version of EverAgent is too old for the coach. Update EverAgent and restart it."
        default:
            return error.localizedDescription
        }
    }
}
#else
extension EverAgentCoachEngine {
    static let unreachable = "Can't reach your Mac. Check that EverAhent is running on it and that both are on the same Wi-Fi."
    static let toolsHint = "Open Tmax on your Mac and check that agent access is on in its settings."

    func refresh(quiet: Bool = false) async {
        guard availability != .checking else { return }
        guard let profile = pairedProfile else {
            availability = .unavailable(CoachEngineError.notPaired.localizedDescription)
            return
        }
        if !quiet { availability = .checking }
        if let client, project != nil, (try? await client.serverInfo()) != nil {
            availability = .ready
            return
        }
        await client?.close()
        client = nil
        project = nil
        let candidate = EverAgentClient(remote: profile, identity: identity)
        do {
            try await candidate.connect()
            let found = try await candidate.projects()
            guard let coach = found.first(where: { $0.name == CoachConstants.projectName }) else {
                await candidate.close()
                lastUnreachable = Date()
                availability = .unavailable("Tmax on your Mac has not added its coach folder to this EverAhent container yet. Open Tmax on your Mac while EverAhent is running, then check again.")
                return
            }
            client = candidate
            project = coach
            gatewayName = profile.name
            lastUnreachable = nil
            availability = .ready
        } catch {
            await candidate.close()
            lastUnreachable = Date()
            availability = .unavailable(Self.explain(error))
        }
    }

    func prepareForTurn() throws {}

    func pair(invitation text: String) async throws {
        let invitation = try EverAgentPairingInvitation(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        let paired: EverAgentRemoteProfile
        do {
            paired = try await EverAgentPairing.pair(invitation, deviceName: UIDevice.current.name, development: Self.isSimulator, identity: identity)
        } catch EverAgentError.remote(let code, _, _) where code == EverAgentErrorCode.busy {
            throw CoachEngineError.phoneAlreadyPaired
        } catch EverAgentError.remote(let code, _, _) where code == EverAgentErrorCode.unauthorized {
            throw CoachEngineError.pairingRefused
        }
        if let previous = pairedProfile { identity.removeKey(tag: previous.keyTag) }
        await client?.close()
        client = nil
        project = nil
        profileStore.save(paired)
        pairedProfile = paired
        availability = .unknown
        await refresh()
    }

    func forgetPairing() async {
        await client?.close()
        client = nil
        project = nil
        models = []
        gatewayName = nil
        if let profile = pairedProfile { identity.removeKey(tag: profile.keyTag) }
        profileStore.clear()
        pairedProfile = nil
        availability = .unavailable(CoachEngineError.notPaired.localizedDescription)
    }

    static func explain(_ error: Error) -> String {
        switch error {
        case EverAgentError.gatewayNotRunning:
            return unreachable
        default:
            return error.localizedDescription
        }
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
#endif
