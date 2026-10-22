import Foundation
import TimeMasterCore

enum CloudServices {
    static let callbackURL = URL(string: "timemaster://auth/callback")!
    static let auth: Result<CloudAuthClient, Error> = Result {
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "TMSupabaseURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "TMSupabaseAnonKey") as? String ?? ""
        guard let url = URL(string: rawURL), !rawURL.isEmpty, !rawURL.contains("$(") else {
            throw CloudAuthError.configuration("Set TMSupabaseURL and TMSupabaseAnonKey to connect this build to Supabase. Local use and ZIP export are available without them.")
        }
        return CloudAuthClient(configuration: try CloudAuthConfiguration(supabaseURL: url, anonKey: key, redirectURL: callbackURL))
    }

    static let syncServiceURL: URL? = serviceURL(key: "TMSyncServiceURL", fallback: "TMRankedServiceURL")

    static func serviceURL(key: String, fallback: String? = nil) -> URL? {
        var raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        if raw.isEmpty || raw.contains("$("), let fallback {
            raw = Bundle.main.object(forInfoDictionaryKey: fallback) as? String ?? ""
        }
#if DEBUG
        if key == "TMRankedServiceURL", let override = ProcessInfo.processInfo.environment["TM_RANKED_URL"] { raw = override }
#endif
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        if url.scheme?.lowercased() == "https" { return url }
#if DEBUG
        if url.scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "") { return url }
#endif
        return nil
    }
}
