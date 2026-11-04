import Foundation

public enum EverAgentErrorCode {
    public static let unauthorized = "unauthorized"
    public static let invalidRequest = "invalid_request"
    public static let notFound = "not_found"
    public static let conflict = "conflict"
    public static let unavailable = "unavailable"
    public static let busy = "busy"
    public static let cancelled = "cancelled"
    public static let internalFailure = "internal"
}

public enum EverAgentError: Error, Sendable, Equatable {
    case gatewayNotRunning(path: String)
    case gatewayTooOld
    case socketPathTooLong(path: String, limit: Int)
    case io(operation: String, code: Int32)
    case `protocol`(String)
    case remote(code: String, message: String, details: JSONValue?)
    case connectionClosed
    case cancelled
    case timeout(operation: String, after: TimeInterval)
    case requestTooLarge(bytes: Int, limit: Int)
    case untrustedServer
    case unauthorizedDevice
    case invalidInvitation(String)
    case invitationExpired
    case deviceIdentity(String)
}

extension EverAgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .gatewayNotRunning(let path):
            "EverAgent is not running or cannot be reached (nothing is listening at \(path))."
        case .gatewayTooOld:
            "The running EverAgent is too old to stream live updates. Update EverAgent and restart it."
        case .socketPathTooLong(let path, let limit):
            "The EverAgent socket path is too long (\(path.utf8.count) bytes; the limit is \(limit)): \(path)"
        case .io(let operation, let code):
            "Could not \(operation) the EverAgent socket: \(String(cString: strerror(code)))."
        case .protocol(let reason):
            "EverAgent sent something unexpected: \(reason)"
        case .remote(let code, let message, _):
            message.isEmpty ? "EverAgent reported \(code)." : message
        case .connectionClosed:
            "The connection to EverAgent closed."
        case .cancelled:
            "The request to EverAgent was cancelled."
        case .timeout(let operation, let seconds):
            "EverAgent did not answer \(operation) within \(Self.describe(seconds: seconds))."
        case .requestTooLarge(let bytes, let limit):
            "The request is \(bytes) bytes; EverAgent accepts at most \(limit) bytes per request."
        case .untrustedServer:
            "The EverAgent that answered is not the one this device was paired with: its certificate does not match. Pair again from EverAhent."
        case .unauthorizedDevice:
            "EverAgent no longer accepts this device. Pair it again from EverAhent."
        case .invalidInvitation(let reason):
            reason
        case .invitationExpired:
            "This pairing code has expired. Create a new one in EverAhent and scan it again."
        case .deviceIdentity(let reason):
            reason
        }
    }

    private static func describe(seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "the allowed time" }
        let text = String(format: "%g", seconds)
        return seconds == 1 ? "\(text) second" : "\(text) seconds"
    }
}
