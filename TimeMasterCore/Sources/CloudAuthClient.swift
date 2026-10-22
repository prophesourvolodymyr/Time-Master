import Foundation
import CryptoKit
import Security
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor CloudAuthClient {
    public nonisolated let configuration: CloudAuthConfiguration
    private let transport: URLSession
    private let vault: CloudCredentialVault
    private var session: CloudSession?
    private var loaded = false
    private var generation: UInt64 = 0
    private var refreshTask: Task<CloudSession, Error>?
    private var refreshID: UUID?

    public init(configuration: CloudAuthConfiguration) {
        self.configuration = configuration
        vault = CloudCredentialVault(service: configuration.keychainService)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        transport = URLSession(configuration: config, delegate: CloudAuthTransportDelegate(), delegateQueue: nil)
    }

    public func restore() async throws -> CloudSession? {
        try loadIfNeeded()
        return session
    }

    public func validSession() async throws -> CloudSession {
        try loadIfNeeded()
        guard let session else { throw CloudAuthError.signedOut }
        if session.expiresAt.timeIntervalSinceNow > 60 { return session }
        return try await refreshSession()
    }

    public func refreshSession() async throws -> CloudSession {
        try loadIfNeeded()
        if let refreshTask {
            let version = generation
            let value = try await refreshTask.value
            guard version == generation else { throw CloudAuthError.superseded }
            try Task.checkCancellation()
            return value
        }
        guard let previous = session else { throw CloudAuthError.signedOut }
        let version = generation
        let id = UUID()
        let task = Task { () throws -> CloudSession in
            struct Body: Encodable { let refresh_token: String }
            let response: TokenResponse
            do {
                response = try await self.send("token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")], method: "POST", body: JSONEncoder().encode(Body(refresh_token: previous.refreshToken)))
            } catch CloudAuthError.service(let status, _) where status == 400 || status == 401 || status == 403 {
                throw CloudAuthError.sessionExpired
            }
            guard version == self.generation else { throw CloudAuthError.superseded }
            let value = try await self.verifiedSession(response)
            guard version == self.generation, value.userID == previous.userID else { throw CloudAuthError.superseded }
            try Task.checkCancellation()
            try self.vault.save(value, account: "session")
            self.session = value
            return value
        }
        refreshTask = task
        refreshID = id
        defer {
            if refreshID == id { refreshTask = nil; refreshID = nil }
        }
        let value = try await task.value
        guard version == generation else { throw CloudAuthError.superseded }
        try Task.checkCancellation()
        return value
    }

    public func signIn(email: String, password: String) async throws -> CloudSession {
        let version = beginAuthentication()
        struct Body: Encodable { let email: String; let password: String }
        let response: TokenResponse = try await send("token", query: [URLQueryItem(name: "grant_type", value: "password")], method: "POST", body: JSONEncoder().encode(Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)))
        return try await install(response, generation: version)
    }

    public func signUp(email: String, password: String, displayName: String) async throws -> CloudSession? {
        let version = beginAuthentication()
        let flow = try makeFlow(kind: .confirmation, email: email)
        struct Metadata: Encodable { let display_name: String }
        struct Body: Encodable {
            let email: String; let password: String; let data: Metadata
            let code_challenge: String; let code_challenge_method: String
        }
        let body = Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, data: Metadata(display_name: displayName), code_challenge: challenge(flow.verifier), code_challenge_method: "s256")
        let response: TokenResponse = try await sendEmail("signup", flow: flow, body: JSONEncoder().encode(body))
        guard version == generation else { throw CloudAuthError.superseded }
        guard response.accessToken != nil else { return nil }
        return try await install(response, generation: version)
    }

    public func signOut() async throws {
        try loadIfNeeded()
        let previous = session
        _ = beginAuthentication()
        try vault.clear(account: "session")
        session = nil
        loaded = true
        try clearPendingFlows()
        if let previous {
            do {
                let _: EmptyResponse = try await send("logout", query: [URLQueryItem(name: "scope", value: "local")], method: "POST", token: previous.accessToken)
            } catch {
                throw CloudAuthError.revocationUnconfirmed(error.localizedDescription)
            }
        }
    }

    public func clearLocalSession() throws {
        _ = beginAuthentication()
        try vault.clear(account: "session")
        session = nil
        loaded = true
        try clearPendingFlows()
    }

    public func requestPasswordReset(email: String) async throws {
        let flow = try makeFlow(kind: .recovery, email: email)
        struct Body: Encodable { let email: String; let code_challenge: String; let code_challenge_method: String }
        let _: EmptyResponse = try await sendEmail("recover", flow: flow, body: JSONEncoder().encode(Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines), code_challenge: challenge(flow.verifier), code_challenge_method: "s256")))
    }

    public func updatePassword(_ password: String) async throws {
        let version = generation
        let value = try await validSession()
        guard generation == version else { throw CloudAuthError.superseded }
        struct Body: Encodable { let password: String }
        let _: User = try await send("user", method: "PUT", body: JSONEncoder().encode(Body(password: password)), token: value.accessToken)
        guard generation == version else { throw CloudAuthError.superseded }
    }

    public func resendConfirmation(email: String) async throws {
        let flow = try makeFlow(kind: .confirmation, email: email)
        struct Body: Encodable { let email: String; let type: String; let code_challenge: String; let code_challenge_method: String }
        let body = Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines), type: "signup", code_challenge: challenge(flow.verifier), code_challenge_method: "s256")
        let _: EmptyResponse = try await sendEmail("resend", flow: flow, body: JSONEncoder().encode(body))
    }

    public func settings() async throws -> CloudAuthSettings {
        try await send("settings", method: "GET")
    }

    public func oauthURL(provider: String) async throws -> URL {
        guard ["google", "apple"].contains(provider) else { throw CloudAuthError.providerUnavailable(provider) }
        let version = beginAuthentication()
        let available = try await settings()
        guard version == generation else { throw CloudAuthError.superseded }
        guard available.external[provider] == true else { throw CloudAuthError.providerUnavailable(provider) }
        let flow = try makeFlow(kind: .oauth)
        var url = URLComponents(url: configuration.supabaseURL.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "provider", value: provider),
                          URLQueryItem(name: "redirect_to", value: callbackURL(flow).absoluteString),
                          URLQueryItem(name: "code_challenge", value: challenge(flow.verifier)),
                          URLQueryItem(name: "code_challenge_method", value: "s256")]
        guard let result = url.url else { throw CloudAuthError.invalidResponse }
        return result
    }

    public func cancelOAuth() throws {
        guard try vault.load(PendingFlows.self, account: flowKey(.oauth)) != nil else { return }
        _ = beginAuthentication()
        try vault.clear(account: flowKey(.oauth))
    }

    public func callbackIsRecovery(_ url: URL) throws -> Bool {
        guard acceptsCallback(url) else { return false }
        return try pendingFlow(for: url).kind == .recovery
    }

    public nonisolated func acceptsCallback(_ url: URL) -> Bool {
        let expected = configuration.redirectURL
        return url.scheme?.lowercased() == expected.scheme?.lowercased()
            && url.host?.lowercased() == expected.host?.lowercased()
            && url.port == expected.port && url.path == expected.path
            && url.user == nil && url.password == nil
    }

    public func handleCallback(_ url: URL) async throws -> CloudSession {
        guard acceptsCallback(url), url.fragment == nil,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw CloudAuthError.invalidCallback }
        let flow = try pendingFlow(for: url)
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            let values = items.filter { $0.name == name }
            return values.count == 1 ? values[0].value : nil
        }
        guard value("tm_state") == flow.state else { throw CloudAuthError.invalidCallback }
        guard Date().timeIntervalSince(flow.createdAt) < (flow.kind == .oauth ? 900 : 86_400) else { throw CloudAuthError.expiredCallback }
        if let failure = value("error_description") ?? value("error") {
            try removeFlow(flow)
            throw CloudAuthError.service(status: 400, message: failure)
        }
        let version = beginAuthentication()
        let response: TokenResponse
        if let code = value("code"), !code.isEmpty {
            struct Body: Encodable { let auth_code: String; let code_verifier: String }
            response = try await send("token", query: [URLQueryItem(name: "grant_type", value: "pkce")], method: "POST", body: JSONEncoder().encode(Body(auth_code: code, code_verifier: flow.verifier)))
        } else if let hash = value("token_hash"), let type = value("type"),
                  (flow.kind == .recovery && type == "recovery") || (flow.kind == .confirmation && ["signup", "email"].contains(type)) {
            struct Body: Encodable { let token_hash: String; let type: String }
            response = try await send("verify", method: "POST", body: JSONEncoder().encode(Body(token_hash: hash, type: type)))
        } else { throw CloudAuthError.invalidCallback }
        return try await install(response, generation: version, expectedEmail: flow.email)
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        let stored = try vault.load(CloudSession.self, account: "session")
        if let stored, UUID(uuidString: stored.userID) == nil { throw CloudAuthError.invalidResponse }
        session = stored
        loaded = true
    }

    private func beginAuthentication() -> UInt64 {
        generation &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
        return generation
    }

    private func install(_ response: TokenResponse, generation version: UInt64, expectedEmail: String? = nil) async throws -> CloudSession {
        let value = try await verifiedSession(response)
        if let expectedEmail, value.email?.lowercased() != expectedEmail { throw CloudAuthError.invalidCallback }
        guard version == generation else { throw CloudAuthError.superseded }
        try Task.checkCancellation()
        try clearPendingFlows()
        try vault.save(value, account: "session")
        session = value
        loaded = true
        return value
    }

    private func verifiedSession(_ response: TokenResponse) async throws -> CloudSession {
        guard let token = response.accessToken, !token.isEmpty,
              let refresh = response.refreshToken, !refresh.isEmpty else { throw CloudAuthError.invalidResponse }
        let user: User = try await send("user", method: "GET", token: token)
        guard let id = UUID(uuidString: user.id) else { throw CloudAuthError.invalidResponse }
        guard response.expiresAt != nil || response.expiresIn != nil else { throw CloudAuthError.invalidResponse }
        let expires = response.expiresAt.map { Date(timeIntervalSince1970: $0) }
            ?? Date().addingTimeInterval(response.expiresIn ?? 0)
        guard expires > Date() else { throw CloudAuthError.sessionExpired }
        return CloudSession(accessToken: token, refreshToken: refresh, expiresAt: expires, userID: id.uuidString.lowercased(), email: user.email)
    }

    private enum FlowKind: String, Codable, CaseIterable { case oauth, confirmation, recovery }
    private struct PendingFlow: Codable {
        let kind: FlowKind
        let verifier: String
        let state: String
        let createdAt: Date
        let email: String?
    }
    private struct PendingFlows: Codable { var attempts: [PendingFlow] }

    private func flowKey(_ kind: FlowKind) -> String { "pending-flow-\(kind.rawValue)" }

    private func clearPendingFlows() throws {
        for kind in FlowKind.allCases { try vault.clear(account: flowKey(kind)) }
    }

    private func pendingFlow(for url: URL) throws -> PendingFlow {
        guard acceptsCallback(url), url.fragment == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { throw CloudAuthError.invalidCallback }
        let states = items.filter { $0.name == "tm_state" }
        guard states.count == 1, let state = states.first?.value else { throw CloudAuthError.invalidCallback }
        for kind in FlowKind.allCases {
            if let flows = try vault.load(PendingFlows.self, account: flowKey(kind)),
               let flow = flows.attempts.first(where: { $0.state == state }) { return flow }
        }
        throw CloudAuthError.invalidCallback
    }

    private func makeFlow(kind: FlowKind, email: String? = nil) throws -> PendingFlow {
        let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let flow = PendingFlow(kind: kind, verifier: try random(), state: try random(), createdAt: Date(), email: email)
        var attempts = try vault.load(PendingFlows.self, account: flowKey(kind))?.attempts ?? []
        attempts.removeAll { Date().timeIntervalSince($0.createdAt) >= ($0.kind == .oauth ? 900 : 86_400) }
        attempts.append(flow)
        if attempts.count > 8 { attempts.removeFirst(attempts.count - 8) }
        try vault.save(PendingFlows(attempts: attempts), account: flowKey(kind))
        return flow
    }

    private func removeFlow(_ flow: PendingFlow) throws {
        guard var flows = try vault.load(PendingFlows.self, account: flowKey(flow.kind)) else { return }
        flows.attempts.removeAll { $0.state == flow.state }
        if flows.attempts.isEmpty { try vault.clear(account: flowKey(flow.kind)) }
        else { try vault.save(flows, account: flowKey(flow.kind)) }
    }

    private func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw CloudAuthError.keychain(status) }
        return base64URL(Data(bytes))
    }

    private func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func callbackURL(_ flow: PendingFlow) -> URL {
        var components = URLComponents(url: configuration.redirectURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "tm_state", value: flow.state)]
        return components.url!
    }

    private struct User: Decodable { let id: String; let email: String? }
    private struct TokenResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: TimeInterval?
        let expiresAt: TimeInterval?
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", expiresAt = "expires_at"
        }
    }
    private struct EmptyResponse: Decodable {}
    private struct Problem: Decodable {
        let msg: String?
        let message: String?
        let errorDescription: String?
        let error: String?
        enum CodingKeys: String, CodingKey { case msg, message, errorDescription = "error_description", error }
        var detail: String? { msg ?? message ?? errorDescription ?? error }
    }

    private func sendEmail<T: Decodable>(_ path: String, flow: PendingFlow, body: Data) async throws -> T {
        do {
            return try await send(path, query: [URLQueryItem(name: "redirect_to", value: callbackURL(flow).absoluteString)], method: "POST", body: body)
        } catch CloudAuthError.service(let status, let message) where (400..<500).contains(status) {
            try removeFlow(flow)
            throw CloudAuthError.service(status: status, message: message)
        }
    }

    private func send<T: Decodable>(_ path: String, query: [URLQueryItem] = [], method: String, body: Data? = nil, token: String? = nil) async throws -> T {
        try Task.checkCancellation()
        var components = URLComponents(url: configuration.supabaseURL.appendingPathComponent("auth/v1/\(path)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw CloudAuthError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw CloudAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode(Problem.self, from: data)
            throw CloudAuthError.service(status: http.statusCode, message: problem?.detail ?? "The account service rejected this request (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
    }
}

private final class CloudAuthTransportDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
