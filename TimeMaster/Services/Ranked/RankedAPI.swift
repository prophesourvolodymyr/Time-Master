import Foundation
import Security

struct RankedCredentials: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var endpoint: String?
    var activeMatchID: String?
}

enum RankedServiceError: LocalizedError {
    case unconfigured, insecureEndpoint, signedOut, message(String), keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .unconfigured: return "Ranked service is not configured. Camera-tracked Practice is available."
        case .insecureEndpoint: return "Ranked requires a secure HTTPS service address."
        case .signedOut: return "Sign in to Ranked to compete."
        case .message(let value): return value
        case .keychain(let status): return "Secure session storage failed (\(status)). No token was saved in preferences."
        }
    }
}

private enum RankedCredentialVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "com.timemaster") + ".ranked",
         kSecAttrAccount as String: "session"]
    }
    static func load() throws -> RankedCredentials? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw RankedServiceError.keychain(status) }
        return try JSONDecoder().decode(RankedCredentials.self, from: data)
    }
    static func save(_ value: RankedCredentials) throws {
        let data = try JSONEncoder().encode(value)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw RankedServiceError.keychain(status) }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let inserted = SecItemAdd(add as CFDictionary, nil)
        guard inserted == errSecSuccess else { throw RankedServiceError.keychain(inserted) }
    }
    static func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw RankedServiceError.keychain(status) }
    }
}

actor RankedAPI {
    static let shared = RankedAPI()
    private var credentials: RankedCredentials?
    private var loaded = false
    private var refreshTask: Task<RankedCredentials, Error>?
    private var generation = 0
    private struct Problem: Decodable { let detail: String }
    private let session: URLSession
    let baseURL: URL?

    init() {
        var raw = Bundle.main.object(forInfoDictionaryKey: "TMRankedServiceURL") as? String ?? ""
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["TM_RANKED_URL"] { raw = override }
#endif
        let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        if let url, url.host != nil, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil {
            baseURL = url
        } else { baseURL = nil }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: RankedTransportDelegate(), delegateQueue: nil)
    }

    var configured: Bool { baseURL != nil }

    func restore() throws -> String? {
        if !loaded {
            credentials = try RankedCredentialVault.load()
            loaded = true
            if let stored = credentials, stored.endpoint != baseURL?.absoluteString {
                credentials = nil
            }
        }
        return credentials?.activeMatchID
    }

    func hasSession() throws -> Bool { _ = try restore(); return credentials != nil }

    func authenticate(login: String, password: String, displayName: String?, listed: Bool) async throws {
        generation += 1
        let version = generation
        refreshTask?.cancel()
        refreshTask = nil
        struct Login: Encodable { let login: String; let password: String }
        struct Registration: Encodable { let login: String; let password: String; let displayName: String; let listed: Bool }
        let body: Data
        if let displayName {
            body = try JSONEncoder().encode(Registration(login: login, password: password, displayName: displayName, listed: listed))
        } else { body = try JSONEncoder().encode(Login(login: login, password: password)) }
        var grant: RankedCredentials = try await send(path: "v1/auth/" + (displayName == nil ? "login" : "register"), method: "POST", body: body, token: nil)
        guard version == generation else { throw RankedServiceError.signedOut }
        grant.endpoint = baseURL?.absoluteString
        do { try RankedCredentialVault.save(grant) }
        catch {
            let _: RankedOK? = try? await send(path: "v1/auth/logout", method: "POST", body: nil, token: grant.accessToken)
            throw error
        }
        credentials = grant
        loaded = true
    }

    func rememberMatch(_ id: String?) throws {
        guard var stored = credentials else { return }
        if stored.activeMatchID == id { return }
        stored.activeMatchID = id
        try RankedCredentialVault.save(stored)
        credentials = stored
    }

    func logout() async throws {
        let previous = credentials
        generation += 1
        credentials = nil
        loaded = true
        refreshTask?.cancel()
        refreshTask = nil
        try RankedCredentialVault.clear()
        if let previous {
            do {
                let _: RankedOK = try await send(path: "v1/auth/logout", method: "POST", body: nil, token: previous.accessToken)
            } catch {
                throw RankedServiceError.message("Signed out on this device. Remote revocation could not be confirmed; the server session will expire.")
            }
        }
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        _ = try restore()
        guard let credentials else { throw RankedServiceError.signedOut }
        let version = generation
        let token = credentials.expiresAt <= Date().timeIntervalSince1970 + 30 ? try await refresh().accessToken : credentials.accessToken
        let result: T
        do { result = try await send(path: path, method: method, body: body, token: token) }
        catch RankedHTTPError.unauthorized {
            guard version == generation else { throw RankedServiceError.signedOut }
            let refreshed = try await refresh()
            result = try await send(path: path, method: method, body: body, token: refreshed.accessToken)
        }
        guard version == generation else { throw RankedServiceError.signedOut }
        try Task.checkCancellation()
        return result
    }

    private func refresh() async throws -> RankedCredentials {
        if let refreshTask { return try await refreshTask.value }
        guard let previous = credentials else { throw RankedServiceError.signedOut }
        let version = generation
        struct Refresh: Encodable { let refreshToken: String }
        let task = Task { () throws -> RankedCredentials in
            var grant: RankedCredentials = try await self.send(path: "v1/auth/refresh", method: "POST", body: JSONEncoder().encode(Refresh(refreshToken: previous.refreshToken)), token: nil)
            grant.endpoint = previous.endpoint
            grant.activeMatchID = previous.activeMatchID
            guard version == self.generation, !Task.isCancelled else { throw RankedServiceError.signedOut }
            try RankedCredentialVault.save(grant)
            return grant
        }
        refreshTask = task
        defer { if version == generation { refreshTask = nil } }
        do {
            let result = try await task.value
            guard version == generation else { throw RankedServiceError.signedOut }
            credentials = result
            return result
        } catch RankedHTTPError.unauthorized {
            guard version == generation else { throw RankedServiceError.signedOut }
            credentials = nil
            try RankedCredentialVault.clear()
            throw RankedServiceError.signedOut
        }
    }

    private func send<T: Decodable>(path: String, method: String, body: Data?, token: String?) async throws -> T {
        guard let baseURL else { throw RankedServiceError.unconfigured }
        var secure = baseURL.scheme?.lowercased() == "https"
#if DEBUG
        if baseURL.scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(baseURL.host ?? "") { secure = true }
#endif
        guard secure else { throw RankedServiceError.insecureEndpoint }
        guard let url = URL(string: path, relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL,
              url.host == baseURL.host, url.scheme == baseURL.scheme else { throw RankedServiceError.insecureEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RankedServiceError.message("Invalid service response") }
        if http.statusCode == 401 { throw RankedHTTPError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(Problem.self, from: data).detail) ?? "Ranked service rejected this request (\(http.statusCode))."
            throw RankedServiceError.message(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private enum RankedHTTPError: LocalizedError {
    case unauthorized
    var errorDescription: String? { "Session expired or login was not accepted. Sign in again." }
}

struct RankedOK: Decodable { let ok: Bool }

private final class RankedTransportDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
