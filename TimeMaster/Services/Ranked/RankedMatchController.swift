import Foundation
import Combine

@MainActor
final class RankedMatchController: ObservableObject {
    enum Stage { case camera, searching, ready, countdown, live, verifying, result, noOpponent }
    let variation: RankedVariation
    let mode: RankedMode
    let camera: RankedCamera
    let account: RankedAccountStore
    @Published private(set) var stage: Stage = .camera
    @Published private(set) var match: RankedMatch?
    @Published private(set) var frame = RankedDuelFrame()
    @Published private(set) var countdown = 3
    @Published private(set) var busy = false
    @Published private(set) var connected = true
    @Published var error: String?
    private var startHost: Double?
    private var endHost: Double?
    private var clockServer: Double = 0
    private var clockHost: Double = 0
    private var bestRTT = Double.infinity
    private var calibration: [RankedPose] = []
    private var pending: [RankedPose] = []
    private var nextSequence = 0
    private var inFlight: (count: Int, sequence: Int, body: Data)?
    private var localBase: Double = 0
    private var polling: Task<Void, Never>?
    private var ticker: Task<Void, Never>?
    private var requestID = UUID().uuidString
    private var stopped = false
    private var submitted = false
    private var lostReadiness = false

    init(variation: RankedVariation, mode: RankedMode, account: RankedAccountStore? = nil) {
        self.variation = variation
        self.mode = mode
        self.account = account ?? .shared
        camera = RankedCamera(variation: variation)
        camera.onPose = { [weak self] pose in self?.receive(pose) }
    }

    var postGo: Bool { startHost.map { RankedCamera.monotonicTime >= $0 } ?? false }
    var estimatedServerTime: Double { clockServer + RankedCamera.monotonicTime - clockHost }

    func run() async {
        stopped = false
        await camera.start()
        guard !stopped else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateClock()
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
        }
        if mode == .duel {
            do {
                if let recovery = account.recoveryMatch, recovery.variation == variation {
                    let sent = RankedCamera.monotonicTime
                    let response: RankedMatchResponse = try await account.api.request("v1/matches/\(recovery.id)")
                    try await accept(response, sent: sent)
                    startPolling()
                }
            } catch { self.error = error.localizedDescription }
        }
    }

    func prepare() async {
        guard camera.tracking.calibrated, camera.status == .running, !busy else { return }
        error = nil
        if mode == .practice {
            startHost = RankedCamera.monotonicTime + 3
            endHost = startHost! + 60
            camera.begin(start: startHost!, end: endHost!)
            stage = .countdown
            return
        }
        struct Queue: Encodable { let variation: String; let ruleVersion: String; let requestID: String }
        busy = true
        defer { busy = false }
        do {
            let sent = RankedCamera.monotonicTime
            let response: RankedServiceState = try await account.api.request("v1/queue", method: "POST", body: JSONEncoder().encode(Queue(variation: variation.rawValue, ruleVersion: RankedMovementRules.version, requestID: requestID)))
            synchronize(server: response.serverTime, sent: sent)
            if let match = response.match { try await apply(match) }
            else { stage = response.queue == nil ? .noOpponent : .searching }
            startPolling()
        } catch { self.error = error.localizedDescription }
    }

    func ready() async {
        guard let match, camera.tracking.calibrated, !busy else { return }
        struct Ready: Encodable { let ready: Bool; let calibration: [RankedPose] }
        busy = true
        defer { busy = false }
        do {
            let sent = RankedCamera.monotonicTime
            let response: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)/ready", method: "POST", body: JSONEncoder().encode(Ready(ready: true, calibration: calibration)))
            try await accept(response, sent: sent)
        } catch { self.error = error.localizedDescription }
    }

    func retry() async {
        error = nil
        if match != nil { await poll() }
        else if stage == .noOpponent { requestID = UUID().uuidString; stage = .camera }
        else { await camera.start() }
    }

    func restart() async {
        stop()
        match = nil
        startHost = nil
        endHost = nil
        frame = RankedDuelFrame()
        localBase = 0
        nextSequence = 0
        bestRTT = .infinity
        clockServer = 0
        clockHost = 0
        submitted = false
        lostReadiness = false
        error = nil
        connected = true
        requestID = UUID().uuidString
        stage = .camera
        do { try await account.api.rememberMatch(nil) }
        catch { self.error = error.localizedDescription }
        camera.onPose = { [weak self] pose in self?.receive(pose) }
        await run()
    }

    func leave() async -> Bool {
        if mode == .practice { stop(); return true }
        busy = true
        defer { busy = false }
        do {
            if let match, !match.terminal {
                let response: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)/leave", method: "POST")
                self.match = response.match
            } else if stage == .searching {
                let _: RankedServiceState = try await account.api.request("v1/queue/cancel", method: "POST")
            }
            stop()
            await account.refresh()
            return true
        } catch {
            self.error = error.localizedDescription + " The shared clock continues; reconnection grace is 8 seconds."
            return false
        }
    }

    func background() async {
        camera.stop()
        if mode == .practice {
            if stage == .live || stage == .countdown { stage = .result }
            return
        }
        guard let match, !match.terminal else { return }
        struct Presence: Encodable { let active: Bool; let calibrated: Bool }
        do {
            let sent = RankedCamera.monotonicTime
            let response: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)/presence", method: "POST", body: JSONEncoder().encode(Presence(active: false, calibrated: false)))
            try await accept(response, sent: sent)
        } catch { self.error = error.localizedDescription }
    }

    func foreground() async {
        guard stage != .result, !stopped else { return }
        if mode == .duel { await poll() }
        guard !stopped else { return }
        if stage != .verifying && stage != .result { await camera.start() }
    }

    func stop() {
        stopped = true
        polling?.cancel()
        polling = nil
        ticker?.cancel()
        ticker = nil
        camera.onPose = nil
        camera.stop()
        pending.removeAll()
        inFlight = nil
        calibration.removeAll()
    }

    private func receive(_ pose: RankedPose) {
        guard !stopped else { return }
        let assessment = RankedMovementRules.assess(pose, variation: variation)
        if let last = calibration.last, pose.time - last.time > RankedMovementRules.maximumGap {
            calibration.removeAll(keepingCapacity: true)
        }
        if assessment.valid && assessment.top {
            calibration.append(pose)
            if calibration.count > 24 { calibration.removeFirst(calibration.count - 24) }
        } else { calibration.removeAll(keepingCapacity: true) }
        frame.feedback = camera.tracking.reason
        frame.phase = camera.tracking.phase
        if let startHost, let endHost, pose.time >= startHost - 4, pose.time <= endHost {
            if mode == .duel {
                var relative = pose
                relative.time -= startHost
                if pending.count < 90 { pending.append(relative) }
                else { error = "Evidence connection was lost for too long. This attempt may not be verified." }
            }
            let score = variation.isTimedHold ? max(localBase, camera.tracking.score) : localBase + camera.tracking.score
            frame.yourScore = max(frame.yourScore, score)
        }
    }

    private func updateClock() {
        guard !stopped else { return }
        camera.expireStalePose()
        let now = RankedCamera.monotonicTime
        if let pose = camera.pose, now - pose.time > 0.35, stage == .live {
            frame.feedback = "Tracking interrupted · No movement scored"
        }
        guard let startHost, let endHost else { return }
        if stage == .countdown {
            countdown = max(0, min(3, Int(ceil(startHost - now))))
            if now >= startHost { stage = .live }
        }
        if stage == .live {
            frame.remaining = max(0, min(60, Int(ceil(endHost - now))))
            if now >= endHost {
                stage = mode == .practice ? .result : .verifying
                camera.stop()
            }
        }
    }

    private func startPolling() {
        guard polling == nil else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.stopped else { return }
                await self.poll()
                if self.stage == .result { return }
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
            }
        }
    }

    private func poll() async {
        guard mode == .duel, !stopped else { return }
        do {
            if let match {
                let sent = RankedCamera.monotonicTime
                let current: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)")
                try await accept(current, sent: sent)
                if !current.match.terminal {
                    if current.match.you?.ready == true && !camera.tracking.calibrated && !postGo && !lostReadiness {
                        lostReadiness = true
                        struct Presence: Encodable { let active = true; let calibrated = false }
                        let _: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)/presence", method: "POST", body: JSONEncoder().encode(Presence()))
                    }
                    do { try await flush() }
                    catch { self.error = error.localizedDescription }
                    if stage == .verifying && !submitted && pending.isEmpty {
                        let sent = RankedCamera.monotonicTime
                        let response: RankedMatchResponse = try await account.api.request("v1/matches/\(match.id)/submit", method: "POST")
                        submitted = true
                        try await accept(response, sent: sent)
                    }
                }
            } else {
                let sent = RankedCamera.monotonicTime
                let response: RankedServiceState = try await account.api.request("v1/state")
                synchronize(server: response.serverTime, sent: sent)
                if let match = response.match { try await apply(match) }
                else if stage == .searching && response.queue == nil { stage = .noOpponent }
            }
            connected = true
            frame.connected = connected && (match?.opponent.map { estimatedServerTime - $0.lastSeen <= 3 } ?? true)
        } catch {
            guard !stopped else { return }
            connected = false
            frame.connected = false
            self.error = error.localizedDescription
            if case RankedServiceError.signedOut = error { await account.signOut() }
        }
    }

    private func flush() async throws {
        guard let match, let you = match.you, let nonce = you.nonce, !pending.isEmpty,
              match.state == "countdown" || match.state == "live" || match.state == "verifying" else { return }
        struct Evidence: Encodable {
            let nonce: String
            let ruleVersion: String
            let sequence: Int
            let frames: [RankedPose]
        }
        if inFlight == nil {
            let batch = Array(pending.prefix(20))
            inFlight = (batch.count, nextSequence, try JSONEncoder().encode(Evidence(nonce: nonce, ruleVersion: match.ruleVersion, sequence: nextSequence, frames: batch)))
        }
        guard let sending = inFlight else { return }
        let receipt: RankedEvidenceReceipt = try await account.api.request("v1/matches/\(match.id)/evidence", method: "POST", body: sending.body)
        nextSequence = receipt.nextSequence
        pending.removeFirst(min(sending.count, pending.count))
        inFlight = nil
    }

    private func accept(_ response: RankedMatchResponse, sent: Double) async throws {
        synchronize(server: response.serverTime, sent: sent)
        try await apply(response.match)
    }

    private func synchronize(server: Double, sent: Double) {
        let received = RankedCamera.monotonicTime
        let rtt = received - sent
        if rtt < bestRTT || clockHost == 0 {
            bestRTT = rtt
            clockServer = server
            clockHost = (received + sent) / 2
        }
    }

    private func apply(_ value: RankedMatch) async throws {
        guard !stopped, value.you?.publicID == account.identity?.publicID else { return }
        guard value.variation == variation else { throw RankedServiceError.message("An active \(value.variation.fullTitle) round must be resumed from the lobby.") }
        if let match, value.revision < match.revision { return }
        let initial = match == nil
        match = value
        try await account.remember(value)
        if initial {
            nextSequence = value.you?.nextSequence ?? 0
            localBase = value.you?.score ?? 0
        }
        else if let sequence = value.you?.nextSequence, let sending = inFlight, sequence > sending.sequence {
            pending.removeFirst(min(sending.count, pending.count))
            nextSequence = sequence
            inFlight = nil
        }
        frame.opponentName = value.opponent?.displayName ?? "Opponent"
        frame.opponentScore = max(frame.opponentScore, value.opponent?.score ?? 0)
        frame.yourScore = max(frame.yourScore, value.you?.score ?? 0)
        if value.terminal {
            frame.yourScore = value.you?.score ?? 0
            frame.opponentScore = value.opponent?.score ?? 0
            stage = .result
            camera.stop()
            pending.removeAll()
            await account.refresh()
            return
        }
        if startHost == nil, let start = value.startAt, let end = value.endAt {
            startHost = clockHost + start - clockServer
            endHost = startHost! + end - start
            camera.begin(start: startHost!, end: endHost!)
        }
        switch value.state {
        case "matched": stage = .ready
        case "countdown": stage = postGo ? .live : .countdown
        case "live": stage = .live
        case "verifying": stage = .verifying
        default: break
        }
        if let last = value.opponent?.lastSeen, estimatedServerTime - last > 3 {
            frame.connected = false
        }
    }
}
