import Foundation

protocol EverAgentLink: AnyObject, Sendable {
    func startReading(
        onLine: @escaping @Sendable (UnsafeBufferPointer<UInt8>) throws -> Void,
        onClose: @escaping @Sendable (EverAgentError) -> Void
    )
    func send(_ bytes: [UInt8], completion: @escaping @Sendable (EverAgentError?) -> Void)
    func shutdown()
}
