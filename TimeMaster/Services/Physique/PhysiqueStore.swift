import Foundation
import Combine
import CryptoKit
import TimeMasterCore

@MainActor
final class PhysiqueStore: ObservableObject {
    static let shared = PhysiqueStore()
    @Published private(set) var snapshot: PhysiqueSnapshot?
    @Published private(set) var policy: PhysiquePolicy?
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    @Published private(set) var lastReceiptID: String?
    @Published private(set) var serverOffset: Double = 0
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var isStale = false
    @Published private(set) var cancellationPending = false
    @Published private(set) var controllingWindowID: UUID?
    @Published private(set) var hiddenMediaIDs: Set<String> = []
    @Published private(set) var locallyBlockedIDs: Set<String> = []
    @Published private(set) var privacyRevision: UInt64 = 0
    @Published private(set) var localOwnMediaHidden = false
    @Published private(set) var localProcessingStopped = false
    @Published private(set) var hiddenExplanationIDs: Set<String> = []
    @Published private(set) var requestedPose: PhysiquePose?
    private var pendingBlockIDs: Set<String> = []
    let camera = PhysiqueCamera.shared
    private var identitySubscription: AnyCancellable?
    private var generation: UInt64 = 0
    private var ownerID: String?
    private var pendingRequests: [String: String] = [:]
    private var freshResults: Set<String> = []
    private var revealedResults: Set<String> = []
    private var armedRevealID: String?
    private var earnedBadgeIDs: [String: Set<String>] = [:]
    private var activeMutation: Task<PhysiqueCommandResponse, Error>?
    private var mutationID: UUID?
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let policyTransport = PhysiquePolicyTransport()

    var account: PhysiqueAccount? { snapshot?.account }
    var match: PhysiqueMatch? { snapshot?.match }
    var stage: PhysiqueStage {
        if let match { return match.stage }
        if snapshot?.queueDeadline != nil { return .searching }
        if snapshot?.queueOutcome == "noOpponent" { return .noOpponent }
        if snapshot?.queueOutcome == "cancelled" { return .cancelled }
        return .idle
    }
    var signedIn: Bool { CloudAccountStore.shared.session != nil }

    private init() {
        identitySubscription = CloudAccountStore.shared.$session.map { $0?.userID }.removeDuplicates()
            .sink { [weak self] owner in self?.identityChanged(owner) }
    }

    private func identityChanged(_ owner: String?) {
        guard ownerID != owner else { return }
        generation &+= 1
        activeMutation?.cancel()
        activeMutation = nil
        mutationID = nil
        ownerID = owner
        camera.clear()
        snapshot = nil
        policy = nil
        lastRefreshedAt = nil
        isStale = false
        serverOffset = 0
        error = nil
        notice = nil
        lastReceiptID = nil
        loading = false
        busy = false
        cancellationPending = false
        controllingWindowID = nil
        hiddenMediaIDs.removeAll()
        locallyBlockedIDs.removeAll()
        hiddenExplanationIDs.removeAll()
        pendingBlockIDs.removeAll()
        privacyRevision &+= 1
        localOwnMediaHidden = protectionKey.map { UserDefaults.standard.bool(forKey: $0 + ".media") } ?? false
        localProcessingStopped = protectionKey.map { UserDefaults.standard.bool(forKey: $0 + ".processing") } ?? false
        if let key = protectionKey {
            pendingRequests = UserDefaults.standard.dictionary(forKey: key + ".requests") as? [String: String] ?? [:]
        } else {
            pendingRequests.removeAll()
        }
        requestedPose = nil
        freshResults.removeAll()
        revealedResults.removeAll()
        armedRevealID = nil
        earnedBadgeIDs.removeAll()
    }

    func clearError() { error = nil }
    func suspendCapture() { camera.stop() }
    func hideMedia(_ id: String) { hiddenMediaIDs.insert(id); privacyRevision &+= 1 }
    func revealMedia(_ id: String) { hiddenMediaIDs.remove(id); privacyRevision &+= 1 }
    func isMediaHidden(_ id: String) -> Bool { hiddenMediaIDs.contains(id) }
    func hideExplanation(_ id: String) { hiddenExplanationIDs.insert(id); privacyRevision &+= 1 }
    func isExplanationHidden(_ id: String) -> Bool { hiddenExplanationIDs.contains(id) }
    func requestPose(_ pose: PhysiquePose) { requestedPose = pose }
    func consumeRequestedPose() -> PhysiquePose? {
        let pose = requestedPose
        requestedPose = nil
        return pose
    }
    func canControl(from id: UUID) -> Bool { controllingWindowID == nil || controllingWindowID == id }
    @discardableResult func claimControl(for id: UUID) -> Bool {
        guard canControl(from: id) else { return false }
        controllingWindowID = id
        return true
    }
    func transferControl(to id: UUID) {
        camera.stop()
        controllingWindowID = id
    }
    func releaseControl(for id: UUID) {
        guard controllingWindowID == id else { return }
        camera.stop(owner: id)
        controllingWindowID = nil
    }
    func armResultReveal(matchID: String) {
        earnedBadgeIDs = earnedBadgeIDs.filter { $0.key == matchID }
        armedRevealID = freshResults.contains(matchID) ? matchID : nil
    }
    func cancelReveals() {
        armedRevealID = nil
        freshResults.removeAll()
        earnedBadgeIDs.removeAll()
    }
    func claimReveal(matchID: String) -> Bool {
        guard armedRevealID == matchID, freshResults.remove(matchID) != nil, !revealedResults.contains(matchID) else { return false }
        armedRevealID = nil
        revealedResults.insert(matchID)
        return true
    }
    func newlyEarnedBadgeIDs(matchID: String) -> Set<String> { earnedBadgeIDs[matchID] ?? [] }

    func loadPolicy() async {
        let version = generation
        do {
            let value = try await policyTransport.load()
            guard version == generation else { return }
            policy = value
            error = nil
        } catch is CancellationError {
        } catch {
            guard version == generation else { return }
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        guard !loading else { return }
        guard signedIn else { await loadPolicy(); return }
        let version = generation
        loading = true
        defer { if version == generation { loading = false } }
        let started = Date().timeIntervalSince1970
        do {
            let value: PhysiqueSnapshot = try await request("state")
            guard version == generation else { return }
            accept(value, requestStartedAt: started)
            error = nil
        } catch is CancellationError {
        } catch {
            guard version == generation else { return }
            isStale = snapshot != nil
            self.error = error.localizedDescription
        }
    }

    func perform(_ operation: String, matchID: String? = nil, targetID: String? = nil, pose: PhysiquePose? = nil, imageBase64: String? = nil, text: String? = nil, reason: String? = nil, value: Bool? = nil, countryCode: String? = nil, consent: PhysiqueConsent? = nil, expectedRevision: Double? = nil) async -> Bool {
        let protects = ["withdrawAI", "withdrawSharing", "removeImages", "deleteAccount", "block", "leave", "cancel"].contains(operation)
        if protects {
            camera.stop()
            privacyRevision &+= 1
            activeMutation?.cancel()
            if operation == "withdrawAI" || operation == "deleteAccount" {
                localProcessingStopped = true
                if let protectionKey { UserDefaults.standard.set(true, forKey: protectionKey + ".processing") }
            }
            if operation == "withdrawSharing" || operation == "removeImages" || operation == "deleteAccount" {
                localOwnMediaHidden = true
                if let protectionKey { UserDefaults.standard.set(true, forKey: protectionKey + ".media") }
            }
        }
        if operation == "cancel" { cancellationPending = true }
        if operation == "block", let targetID { locallyBlockedIDs.insert(targetID); pendingBlockIDs.insert(targetID) }
        guard !busy || protects else { error = "A request is still being confirmed."; return false }
        guard signedIn else { error = "Sign in to your Tmax account to continue."; return false }
        if operation == "candidate", localProcessingStopped {
            error = "Processing is stopped on this device. Review sharing choices before sending another capture."
            return false
        }
        if operation == "deleteAccount" {
            camera.clear()
            await CloudAccountStore.shared.deleteAccount()
            error = CloudAccountStore.shared.error
            return CloudAccountStore.shared.session == nil && error == nil
        }
        if operation == "enqueue", cancellationPending || !pendingBlockIDs.isEmpty {
            error = "Confirm pending cancellation or blocking before finding another opponent."
            return false
        }
        let version = generation
        let ticket = UUID()
        mutationID = ticket
        busy = true
        let heartbeat = operation == "presence"
        let recoveringConnection = isStale
        if !heartbeat { error = nil; notice = nil; lastReceiptID = nil }
        defer {
            if version == generation, mutationID == ticket {
                busy = false
                activeMutation = nil
                mutationID = nil
            }
        }
        do {
            let revision = expectedRevision ?? (operation == "consent" ? account?.consentRevision : nil)
            let unsigned = PhysiqueCommand(operation: operation, requestID: "", matchID: matchID, targetID: targetID, pose: pose, imageBase64: imageBase64, text: text, reason: reason, value: value, countryCode: countryCode, consent: consent, expectedRevision: revision)
            let digest = SHA256.hash(data: try encoder.encode(unsigned)).map { String(format: "%02x", $0) }.joined()
            let requestID = pendingRequests[digest] ?? UUID().uuidString.lowercased()
            pendingRequests[digest] = requestID
            if let protectionKey { UserDefaults.standard.set(pendingRequests, forKey: protectionKey + ".requests") }
            let command = PhysiqueCommand(operation: operation, requestID: requestID, matchID: matchID, targetID: targetID, pose: pose, imageBase64: imageBase64, text: text, reason: reason, value: value, countryCode: countryCode, consent: consent, expectedRevision: revision)
            let body = try encoder.encode(command)
            let started = Date().timeIntervalSince1970
            let work = Task { try await self.request("command", method: "POST", body: body) as PhysiqueCommandResponse }
            activeMutation = work
            let response = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
            guard version == generation, mutationID == ticket else { return false }
            accept(response.snapshot, requestStartedAt: started, allowReward: !recoveringConnection && !isStale && !Task.isCancelled && (operation == "presence" || operation == "submit"))
            if !heartbeat {
                lastReceiptID = response.receiptID
                notice = response.message
            } else if recoveringConnection { error = nil }
            pendingRequests.removeValue(forKey: digest)
            if let protectionKey { UserDefaults.standard.set(pendingRequests, forKey: protectionKey + ".requests") }
            if operation == "cancel" { cancellationPending = false }
            if operation == "block", let targetID { pendingBlockIDs.remove(targetID) }
            if operation == "unblock", let targetID { locallyBlockedIDs.remove(targetID); pendingBlockIDs.remove(targetID) }
            if operation == "consent", response.snapshot.account.consent.accepted {
                localProcessingStopped = false
                localOwnMediaHidden = false
                if let protectionKey {
                    UserDefaults.standard.removeObject(forKey: protectionKey + ".processing")
                    UserDefaults.standard.removeObject(forKey: protectionKey + ".media")
                }
            }
            return true
        } catch is CancellationError {
            if version == generation, mutationID == ticket { error = "Request not confirmed. Check the current state before retrying." }
            return false
        } catch {
            guard version == generation, mutationID == ticket else { return false }
            isStale = snapshot != nil
            self.error = error.localizedDescription
            return false
        }
    }

    func getMatch(_ id: String) async throws -> PhysiqueMatch { try await request("matches/\(segment(id))") }
    func history(cursor: String? = nil) async throws -> PhysiquePageResponse<PhysiqueMatch> { try await request(paged("history", cursor: cursor)) }
    func standings(cursor: String? = nil) async throws -> PhysiquePageResponse<PhysiqueStanding> { try await request(paged("standings", cursor: cursor)) }
    func player(_ id: String) async throws -> PhysiqueStanding { try await request("players/\(segment(id))") }
    func cases() async throws -> [PhysiqueCase] {
        let response: PhysiqueItems<PhysiqueCase> = try await request("cases")
        return response.items
    }
    func caseDetail(_ id: String) async throws -> PhysiqueCase { try await request("cases/\(segment(id))") }
    func gallery(_ id: String, revealing mediaID: String? = nil) async throws -> [PhysiqueMedia] {
        let revision = privacyRevision
        let response: PhysiqueItems<PhysiqueMedia> = try await request("matches/\(segment(id))/gallery")
        guard revision == privacyRevision else { throw CancellationError() }
        let ownID = account?.identity.id
        return response.items.map { item in
            if (hiddenMediaIDs.contains(item.id) && item.id != mediaID) || locallyBlockedIDs.contains(item.ownerID) || (localOwnMediaHidden && (ownID == nil || item.ownerID == ownID)) {
                return PhysiqueMedia(id: item.id, ownerID: item.ownerID, pose: item.pose, status: "locallyHidden", imageBase64: nil, expiresAt: item.expiresAt)
            }
            return item
        }
    }
    func privacyReceipts() async throws -> [PhysiquePrivacyReceipt] {
        let response: PhysiqueItems<PhysiquePrivacyReceipt> = try await request("privacy")
        return response.items
    }
    func blocks() async throws -> [PhysiqueBlockedPlayer] {
        let response: PhysiqueItems<PhysiqueBlockedPlayer> = try await request("blocks")
        return response.items
    }
    private func request<Value: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Value {
        let version = generation
        guard let ownerID, ownerID == CloudAccountStore.shared.accountID else { throw RankedServiceError.signedOut }
        let result: Value = try await RankedAPI.shared.request("v1/physique/" + path, method: method, body: body)
        guard version == generation, ownerID == CloudAccountStore.shared.accountID else { throw CloudAuthError.superseded }
        return result
    }
    private func accept(_ value: PhysiqueSnapshot, requestStartedAt: Double, allowReward: Bool = false) {
        let received = Date().timeIntervalSince1970
        serverOffset = value.serverTime - (requestStartedAt + received) / 2
        if allowReward, let previous = snapshot?.match, let current = value.match, previous.id == current.id, !previous.stage.terminal, current.stage.terminal, current.result?.corrected == false {
            freshResults.insert(current.id)
            let previousBadges = Set(snapshot?.account.identity.badges.map(\.id) ?? [])
            let additions = Set(value.account.identity.badges.map(\.id)).subtracting(previousBadges)
            if !additions.isEmpty { earnedBadgeIDs[current.id] = additions }
        }
        snapshot = value
        policy = value.policy
        lastRefreshedAt = Date()
        isStale = false
        if value.match == nil, value.queueDeadline == nil, value.queueOutcome == "cancelled" || value.queueOutcome == "noOpponent" { cancellationPending = false }
        if value.match?.stage.terminal == true { camera.clear() }
    }
    private func segment(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    private func paged(_ path: String, cursor: String?) -> String { cursor.map { path + "?cursor=" + segment($0) } ?? path }
    private var protectionKey: String? {
        guard let ownerID else { return nil }
        let endpoint = CloudServices.serviceURL(key: "TMRankedServiceURL", fallback: "TMSyncServiceURL")?.absoluteString ?? ""
        let digest = SHA256.hash(data: Data((endpoint + "|" + ownerID).utf8)).map { String(format: "%02x", $0) }.joined()
        return "tm.physique.protection." + digest
    }
}
