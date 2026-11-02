import Foundation

public enum OnDeviceAvailability: Equatable, Sendable {
    case ready
    case unavailable(String)

    public var isReady: Bool {
        self == .ready
    }

    public var reason: String? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

public enum OnDeviceSupport {
    public static func availability() -> OnDeviceAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return OnDeviceCoach.availability()
        }
        #endif
        return .unavailable("The on-device helper needs iOS 26 or macOS 26 with Apple Intelligence.")
    }
}
