import Foundation

public struct EverAgentPairingInvitation: Sendable, Equatable {
    public let serverURL: URL
    public let serverId: String
    public let certificateSHA256: String
    public let code: String
    public let expiresAt: Date
    public let hostLabel: String

    static let maximumPayloadBytes = 16 * 1024

    private struct Payload: Decodable {
        let version: Int
        let url: String
        let code: String
        let certificateSHA256: String
        let serverId: String
        let expiresAt: String
    }

    public init(string: String, now: Date = Date()) throws {
        let payload = try Self.payload(in: string)
        guard payload.version == 1 else {
            throw EverAgentError.invalidInvitation("This pairing code uses a format this version of Tmax does not support.")
        }
        guard !payload.serverId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EverAgentError.invalidInvitation("This pairing code does not say which EverAhent it belongs to.")
        }
        guard !payload.code.isEmpty else {
            throw EverAgentError.invalidInvitation("This pairing code is missing its one-time code.")
        }
        guard payload.certificateSHA256.utf8.count == 64, payload.certificateSHA256.utf8.allSatisfy(Self.isHexDigit) else {
            throw EverAgentError.invalidInvitation("This pairing code is missing a valid server fingerprint.")
        }
        guard let components = URLComponents(string: payload.url),
              components.scheme?.lowercased() == "https",
              components.user == nil, components.password == nil, components.fragment == nil,
              let serverURL = components.url,
              let host = serverURL.host, !host.isEmpty
        else {
            throw EverAgentError.invalidInvitation("The server address in this pairing code must use HTTPS.")
        }
        guard let expiry = Self.date(from: payload.expiresAt) else {
            throw EverAgentError.invalidInvitation("This pairing code has an invalid expiry date.")
        }
        guard expiry > now else { throw EverAgentError.invitationExpired }
        self.serverURL = serverURL
        serverId = payload.serverId
        certificateSHA256 = payload.certificateSHA256
        code = payload.code
        expiresAt = expiry
        let displayHost = host.contains(":") ? "[\(host)]" : host
        hostLabel = serverURL.port.map { "\(displayHost):\($0)" } ?? displayHost
    }

    private static func payload(in string: String) throws -> Payload {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "ompp",
              url.host?.lowercased() == "pair",
              url.path.isEmpty || url.path == "/",
              url.user == nil, url.password == nil, url.fragment == nil
        else {
            throw EverAgentError.invalidInvitation("This is not an EverAhent pairing code.")
        }
        guard let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery else {
            throw EverAgentError.invalidInvitation("This pairing code is missing its payload.")
        }
        var encoded: String?
        for item in query.split(separator: "&", omittingEmptySubsequences: false) {
            let pieces = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2, let key = String(pieces[0]).removingPercentEncoding else {
                throw EverAgentError.invalidInvitation("This pairing code is damaged.")
            }
            guard key == "payload" else {
                throw EverAgentError.invalidInvitation("This pairing code has an unexpected parameter.")
            }
            guard encoded == nil else {
                throw EverAgentError.invalidInvitation("This pairing code contains more than one payload.")
            }
            encoded = String(pieces[1])
        }
        guard let encoded,
              encoded.utf8.count <= maximumPayloadBytes,
              let text = encoded.removingPercentEncoding,
              let data = base64URLData(text),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            throw EverAgentError.invalidInvitation("This pairing code is damaged.")
        }
        return payload
    }

    private static func base64URLData(_ text: String) -> Data? {
        let bytes = Array(text.utf8)
        let body = bytes.prefix { $0 != 0x3D }
        guard !body.isEmpty, bytes.count - body.count <= 2, bytes[body.count...].allSatisfy({ $0 == 0x3D }), body.allSatisfy(isBase64URLCharacter) else {
            return nil
        }
        var standard = String(decoding: body, as: UTF8.self).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        standard += String(repeating: "=", count: (4 - standard.utf8.count % 4) % 4)
        return Data(base64Encoded: standard)
    }

    private static func isBase64URLCharacter(_ byte: UInt8) -> Bool {
        (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) || byte == 0x2D || byte == 0x5F
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        (0x30...0x39).contains(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte)
    }

    private static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}

public struct EverAgentRemoteProfile: Codable, Equatable, Sendable {
    public var serverId: String
    public var name: String
    public var url: String
    public var certificateSHA256: String
    public var deviceId: String
    public var keyTag: String
    public var development: Bool

    public init(serverId: String, name: String, url: String, certificateSHA256: String, deviceId: String, keyTag: String, development: Bool) {
        self.serverId = serverId
        self.name = name
        self.url = url
        self.certificateSHA256 = certificateSHA256
        self.deviceId = deviceId
        self.keyTag = keyTag
        self.development = development
    }
}

public enum EverAgentPairing {
    static let requestSeconds: TimeInterval = 20

    public static func pair(
        _ invitation: EverAgentPairingInvitation,
        deviceName: String,
        development: Bool,
        identity: EverAgentDeviceIdentity = EverAgentKeychainIdentity()
    ) async throws -> EverAgentRemoteProfile {
        try await enroll(invitation, deviceName: deviceName, development: development, identity: identity) { request in
            let (session, trust) = EverAgentPinnedTrust.makeSession(fingerprint: invitation.certificateSHA256, timeout: requestSeconds)
            defer { session.finishTasksAndInvalidate() }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw EverAgentError.protocol("EverAgent answered the pairing request with something that is not HTTP.")
                }
                return (data, http)
            } catch {
                throw EverAgentNetworkFailure.classify(error, address: invitation.serverURL.absoluteString, certificateRejected: trust.certificateRejected)
            }
        }
    }

    static func enroll(
        _ invitation: EverAgentPairingInvitation,
        deviceName: String,
        development: Bool,
        identity: EverAgentDeviceIdentity,
        exchange: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> EverAgentRemoteProfile {
        let address = invitation.serverURL.absoluteString
        let tag = "device.\(invitation.serverId).\(UUID().uuidString)"
        let publicKey = try identity.createKey(tag: tag, development: development)
        do {
            var request = URLRequest(url: try EverAgentGatewayAddress.endpoint(address, scheme: "https", path: "/v1/pair"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = JSONValue.object([
                "code": .string(invitation.code),
                "deviceName": .string(deviceName),
                "publicKey": .string(publicKey),
                "development": .bool(development),
            ]).serialized()
            let (data, response) = try await exchange(request)
            let body = (try? JSONValue(parsing: data)) ?? .null
            guard (200..<300).contains(response.statusCode) else {
                let failure = body["error"]
                guard !failure.isNull else {
                    throw EverAgentError.protocol("EverAgent answered the pairing request with HTTP \(response.statusCode).")
                }
                throw EverAgentError.remote(code: failure["code"].stringValue ?? "unknown", message: failure["message"].text, details: nil)
            }
            guard let deviceId = body["deviceId"].stringValue, !deviceId.isEmpty else {
                throw EverAgentError.protocol("EverAgent accepted the pairing but did not return a device id.")
            }
            if let serverId = body["serverId"].stringValue, serverId != invitation.serverId { throw EverAgentError.untrustedServer }
            return EverAgentRemoteProfile(
                serverId: invitation.serverId,
                name: invitation.hostLabel,
                url: address,
                certificateSHA256: invitation.certificateSHA256,
                deviceId: deviceId,
                keyTag: tag,
                development: development
            )
        } catch {
            identity.removeKey(tag: tag)
            throw error
        }
    }
}
