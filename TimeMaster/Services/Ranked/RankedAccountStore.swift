import Foundation
import Combine

@MainActor
final class RankedAccountStore: ObservableObject {
    static let shared = RankedAccountStore()
    @Published private(set) var identity: RankedIdentity?
    @Published private(set) var ratings: [RankedRating] = []
    @Published private(set) var allowances: [RankedAllowance] = []
    @Published private(set) var recoveryMatch: RankedMatch?
    @Published private(set) var loading = false
    @Published private(set) var stale = false
    @Published var error: String?
    @Published private(set) var configured = false
    private var restored = false
    private var generation = 0
    let api = RankedAPI.shared

    var placedCount: Int { ratings.filter { $0.games > 0 }.count }
    func rating(for variation: RankedVariation) -> RankedRating? { ratings.first { $0.variation == variation && $0.games > 0 } }
    func allowance(for family: RankedFamily) -> RankedAllowance? { allowances.first { $0.family == family.rawValue } }

    func restore() async {
        configured = await api.configured
        guard !restored else { return }
        restored = true
        do {
            if try await api.hasSession() { await refresh() }
        } catch { self.error = error.localizedDescription }
    }

    func authenticate(login: String, password: String, displayName: String?, listed: Bool) async throws {
        generation += 1
        let version = generation
        try await api.authenticate(login: login, password: password, displayName: displayName, listed: listed)
        guard version == generation else { throw RankedServiceError.signedOut }
        identity = nil
        ratings = []
        allowances = []
        recoveryMatch = nil
        stale = false
        await refresh()
        guard version == generation else { throw RankedServiceError.signedOut }
        if identity == nil { throw RankedServiceError.message(error ?? "Could not load your account") }
    }

    func refresh() async {
        let version = generation
        loading = true
        defer { loading = false }
        do {
            let snapshot: RankedAccountSnapshot = try await api.request("v1/me")
            let remembered = try await api.restore()
            let state: RankedServiceState = try await api.request("v1/state")
            var match = state.match
            if match == nil, let remembered {
                let response: RankedMatchResponse = try await api.request("v1/matches/\(remembered)")
                if !response.match.terminal { match = response.match }
            }
            guard version == generation else { return }
            identity = snapshot.identity
            ratings = snapshot.ratings
            allowances = snapshot.allowances
            recoveryMatch = match
            error = nil
            stale = false
        } catch {
            guard version == generation else { return }
            let hasSession = try? await api.hasSession()
            guard version == generation else { return }
            if hasSession == false {
                identity = nil
                ratings = []
                allowances = []
                recoveryMatch = nil
            }
            stale = identity != nil
            self.error = error.localizedDescription
        }
    }

    func remember(_ match: RankedMatch) async throws {
        recoveryMatch = match.terminal ? nil : match
        try await api.rememberMatch(match.id)
    }

    func signOut() async {
        generation += 1
        identity = nil
        ratings = []
        allowances = []
        recoveryMatch = nil
        stale = false
        error = nil
        do { try await api.logout() }
        catch { self.error = error.localizedDescription }
    }

    func updatePublicIdentity(name: String, listed: Bool) async throws {
        struct Privacy: Encodable { let displayName: String; let listed: Bool }
        let identity: RankedIdentity = try await api.request("v1/me/privacy", method: "POST", body: JSONEncoder().encode(Privacy(displayName: name, listed: listed)))
        self.identity = identity
    }

    func leaderboard(_ variation: RankedVariation, cursor: String? = nil, aroundMe: Bool = false) async throws -> RankedLeaderboardPage {
        var path = "v1/leaderboard/\(variation.rawValue)?aroundMe=\(aroundMe ? "true" : "false")"
        if let cursor { path += "&cursor=" + cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! }
        return try await api.request(path)
    }

    func history(cursor: String? = nil) async throws -> RankedHistoryPage {
        let path = "v1/history" + (cursor.map { "?cursor=" + $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)! } ?? "")
        return try await api.request(path)
    }
}
