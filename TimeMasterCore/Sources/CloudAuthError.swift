import Foundation

public enum CloudAuthError: LocalizedError, Sendable {
    case configuration(String)
    case signedOut
    case sessionExpired
    case superseded
    case invalidCallback
    case expiredCallback
    case cancelled
    case providerUnavailable(String)
    case keychain(Int32)
    case service(status: Int, message: String)
    case invalidResponse
    case revocationUnconfirmed(String)

    public var errorDescription: String? {
        switch self {
        case .configuration(let message): return message
        case .signedOut: return "Sign in to your TimeMaster account to connect to the cloud. Your local library is still available."
        case .sessionExpired: return "Your session could not be renewed. Sign in again; your local library and offline identity have been kept."
        case .superseded: return "This account request was replaced by a newer request."
        case .invalidCallback: return "This account link could not be verified. Open the latest link on the device that requested it, or sign in with your email and password."
        case .expiredCallback: return "This account link has expired. Request a new confirmation or password-reset email."
        case .cancelled: return "Sign-in was canceled. No account was changed."
        case .providerUnavailable(let provider): return "\(provider.capitalized) sign-in is disabled in this Supabase project's Auth provider settings."
        case .keychain(let status): return "Secure account storage failed (\(status)). Credentials are never saved in preferences."
        case .service(_, let message): return message
        case .invalidResponse: return "The account service returned an invalid response."
        case .revocationUnconfirmed(let message): return "Signed out on this device. Remote session revocation could not be confirmed: \(message)"
        }
    }
}
