import CryptoKit
import Foundation
import Security

final class EverAgentPinnedTrust: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let fingerprint: String
    private let lock = NSLock()
    private var rejected = false

    init(fingerprint: String) {
        self.fingerprint = fingerprint
    }

    var certificateRejected: Bool {
        lock.withLock { rejected }
    }

    static func accepts(_ certificate: Data, fingerprint: String) -> Bool {
        SHA256.hash(data: certificate).map { String(format: "%02x", $0) }.joined() == fingerprint.lowercased()
    }

    static func makeSession(fingerprint: String, timeout: TimeInterval) -> (session: URLSession, trust: EverAgentPinnedTrust) {
        let trust = EverAgentPinnedTrust(fingerprint: fingerprint)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.waitsForConnectivity = false
        return (URLSession(configuration: configuration, delegate: trust, delegateQueue: nil), trust)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        guard let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first,
              Self.accepts(SecCertificateCopyData(leaf) as Data, fingerprint: fingerprint),
              Self.trusts(trust, anchoredAt: leaf)
        else {
            lock.withLock { rejected = true }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private static func trusts(_ trust: SecTrust, anchoredAt leaf: SecCertificate) -> Bool {
        SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, nil))
        SecTrustSetAnchorCertificates(trust, [leaf] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
        return SecTrustEvaluateWithError(trust, nil)
    }
}

enum EverAgentGatewayAddress {
    static func endpoint(_ address: String, scheme: String, path: String) throws -> URL {
        guard var components = URLComponents(string: address),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false
        else { throw EverAgentError.gatewayNotRunning(path: address) }
        components.scheme = scheme
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw EverAgentError.gatewayNotRunning(path: address) }
        return url
    }
}

enum EverAgentNetworkFailure {
    static func classify(_ error: Error, address: String, certificateRejected: Bool) -> EverAgentError {
        if certificateRejected { return .untrustedServer }
        if let known = error as? EverAgentError { return known }
        if error is CancellationError { return .cancelled }
        let failure = error as NSError
        switch (failure.domain, failure.code) {
        case (NSURLErrorDomain, NSURLErrorCancelled):
            return .cancelled
        case (NSURLErrorDomain, NSURLErrorNetworkConnectionLost),
             (NSPOSIXErrorDomain, Int(ENOTCONN)),
             (NSPOSIXErrorDomain, Int(ECONNRESET)),
             (NSPOSIXErrorDomain, Int(ECONNABORTED)),
             (NSPOSIXErrorDomain, Int(EPIPE)):
            return .connectionClosed
        default:
            return .gatewayNotRunning(path: address)
        }
    }
}
