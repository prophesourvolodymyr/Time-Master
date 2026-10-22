import Foundation

public struct CloudAuthSettings: Decodable, Sendable {
    public let external: [String: Bool]
    public let disableSignup: Bool?

    enum CodingKeys: String, CodingKey {
        case external
        case disableSignup = "disable_signup"
    }
}
