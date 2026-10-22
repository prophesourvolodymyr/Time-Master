import Foundation
import CryptoKit

public struct CloudAuthConfiguration: Sendable {
    public let supabaseURL: URL
    public let anonKey: String
    public let redirectURL: URL
    public let keychainService: String

    public init(supabaseURL: URL, anonKey: String, redirectURL: URL) throws {
        guard supabaseURL.scheme?.lowercased() == "https", supabaseURL.host != nil,
              supabaseURL.user == nil, supabaseURL.password == nil,
              supabaseURL.query == nil, supabaseURL.fragment == nil,
              supabaseURL.path.isEmpty || supabaseURL.path == "/" else {
            throw CloudAuthError.configuration("TMSupabaseURL must be the project's HTTPS origin, without a path, query or credentials.")
        }
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("$("), !key.hasPrefix("sb_secret_") else {
            throw CloudAuthError.configuration("TMSupabaseAnonKey must contain the public Supabase publishable/anon key, never a secret key.")
        }
        if let payload = key.split(separator: ".").dropFirst().first,
           let data = Data(base64Encoded: Self.paddedBase64(String(payload))),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["role"] as? String == "service_role" {
            throw CloudAuthError.configuration("A Supabase service-role key must never be included in an app.")
        }
        guard let scheme = redirectURL.scheme?.lowercased(), !["http", "https"].contains(scheme),
              redirectURL.host != nil, redirectURL.user == nil, redirectURL.password == nil,
              redirectURL.query == nil, redirectURL.fragment == nil else {
            throw CloudAuthError.configuration("The account callback must be a registered app URL without query parameters.")
        }
        var origin = URLComponents(url: supabaseURL, resolvingAgainstBaseURL: false)!
        origin.scheme = "https"
        origin.host = origin.host?.lowercased()
        origin.path = ""
        if origin.port == 443 { origin.port = nil }
        guard let endpoint = origin.url else { throw CloudAuthError.configuration("Invalid Supabase origin.") }
        self.supabaseURL = endpoint
        self.anonKey = key
        self.redirectURL = redirectURL
        let digest = SHA256.hash(data: Data(endpoint.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        keychainService = "com.timemaster.cloud-auth.\(digest)"
    }

    private static func paddedBase64(_ value: String) -> String {
        let value = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return value + String(repeating: "=", count: (4 - value.count % 4) % 4)
    }
}
