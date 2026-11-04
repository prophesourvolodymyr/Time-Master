import CryptoKit
import XCTest
@testable import TimeMasterCore

private let pinnedFingerprint = String(repeating: "ab", count: 32)

private func profile(url: String = "https://127.0.0.1:8443") -> EverAgentRemoteProfile {
    EverAgentRemoteProfile(
        serverId: "srv-1",
        name: "Mac",
        url: url,
        certificateSHA256: pinnedFingerprint,
        deviceId: "dev-1",
        keyTag: "device.srv-1.tag",
        development: true
    )
}

private func challenge(serverId: String = "srv-1", nonce: String = "n-123") -> String {
    JSONValue.object(["type": "challenge", "nonce": .string(nonce), "serverId": .string(serverId)]).jsonString
}

private let authenticated = JSONValue.object(["type": "authenticated", "deviceId": "dev-1", "serverId": "srv-1"]).jsonString

final class EverAgentHandshakeTests: XCTestCase {
    private let identity = MemoryIdentity()

    private func run(
        incoming: [Result<String, Error>],
        identity override: EverAgentDeviceIdentity? = nil,
        failSend: Error? = nil
    ) async -> (error: Error?, sent: [String]) {
        var queue = incoming
        var sent: [String] = []
        do {
            try await EverAgentHandshake.authenticate(
                profile: profile(),
                identity: override ?? identity,
                receive: {
                    guard !queue.isEmpty else { throw EverAgentError.connectionClosed }
                    return try queue.removeFirst().get()
                },
                send: { text in
                    sent.append(text)
                    if let failSend { throw failSend }
                }
            )
            return (nil, sent)
        } catch {
            return (error, sent)
        }
    }

    private func prepare() throws -> P256.Signing.PublicKey {
        _ = try identity.createKey(tag: "device.srv-1.tag", development: true)
        return try XCTUnwrap(identity.publicKey(tag: "device.srv-1.tag"))
    }

    func testTheHandshakeAnswersTheChallengeWithASignedAuthenticateFrame() async throws {
        let key = try prepare()
        let outcome = await run(incoming: [.success(challenge()), .success(authenticated)])
        XCTAssertNil(outcome.error)
        XCTAssertEqual(outcome.sent.count, 1)
        let frame = try JSONValue(parsing: try XCTUnwrap(outcome.sent.first))
        XCTAssertEqual(Set(frame.objectValue.keys), ["type", "deviceId", "signature"])
        XCTAssertEqual(frame["type"], "authenticate")
        XCTAssertEqual(frame["deviceId"], "dev-1")
        let expected = Data("ompp.v1\nsrv-1\nn-123".utf8)
        XCTAssertEqual(identity.signed, [expected])
        let der = try XCTUnwrap(Data(base64Encoded: frame["signature"].text))
        XCTAssertTrue(key.isValidSignature(try P256.Signing.ECDSASignature(derRepresentation: der), for: expected))
    }

    func testAChallengeFromAnotherServerIsNotAnswered() async throws {
        _ = try prepare()
        let outcome = await run(incoming: [.success(challenge(serverId: "srv-2"))])
        XCTAssertEqual(outcome.error as? EverAgentError, .untrustedServer)
        XCTAssertTrue(outcome.sent.isEmpty)
        XCTAssertTrue(identity.signed.isEmpty)
    }

    func testAnOpeningMessageThatIsNotAChallengeIsAProtocolError() async throws {
        _ = try prepare()
        let openings = [
            #"{"type":"authenticated"}"#,
            #"{"type":"event","sequence":1,"topic":"agent","data":{}}"#,
            #"{"nonce":"n","serverId":"srv-1"}"#,
            #"{"type":"challenge","serverId":"srv-1"}"#,
            #"{"type":"challenge","nonce":"","serverId":"srv-1"}"#,
            #"{"type":"challenge","nonce":5,"serverId":"srv-1"}"#,
            "[]",
            "{}",
            "not json",
            "",
        ]
        for opening in openings {
            let outcome = await run(incoming: [.success(opening)])
            guard case .protocol? = outcome.error as? EverAgentError else {
                XCTFail("\(opening) should be a protocol error but was \(String(describing: outcome.error))")
                continue
            }
            XCTAssertTrue(outcome.sent.isEmpty, opening)
        }
        XCTAssertTrue(identity.signed.isEmpty)
    }

    func testAFailureBeforeTheChallengeKeepsItsMeaning() async throws {
        _ = try prepare()
        let failures: [EverAgentError] = [.gatewayNotRunning(path: "https://127.0.0.1:8443"), .untrustedServer, .cancelled, .connectionClosed]
        for failure in failures {
            let outcome = await run(incoming: [.failure(failure)])
            XCTAssertEqual(outcome.error as? EverAgentError, failure)
            XCTAssertTrue(outcome.sent.isEmpty)
        }
    }

    func testAGatewayThatHangsUpAfterTheAuthenticateFrameHasRefusedTheDevice() async throws {
        _ = try prepare()
        let outcome = await run(incoming: [.success(challenge())])
        XCTAssertEqual(outcome.error as? EverAgentError, .unauthorizedDevice)
        XCTAssertEqual(outcome.sent.count, 1)
        let explicit = await run(incoming: [.success(challenge()), .failure(EverAgentError.connectionClosed)])
        XCTAssertEqual(explicit.error as? EverAgentError, .unauthorizedDevice)
    }

    func testAnyOtherVerdictThanAuthenticatedIsARefusal() async throws {
        _ = try prepare()
        let verdicts = [
            #"{"type":"error","error":{"code":"unauthorized","message":"nope"}}"#,
            #"{"error":{"code":"unauthorized"}}"#,
            #"{"type":"challenge","nonce":"again","serverId":"srv-1"}"#,
            "{}",
            "[]",
            #"{"type":"Authenticated"}"#,
        ]
        for verdict in verdicts {
            let outcome = await run(incoming: [.success(challenge()), .success(verdict)])
            XCTAssertEqual(outcome.error as? EverAgentError, .unauthorizedDevice, verdict)
        }
        let garbage = await run(incoming: [.success(challenge()), .success("garbage")])
        guard case .protocol? = garbage.error as? EverAgentError else { return XCTFail("Wrong error: \(String(describing: garbage.error))") }
    }

    func testFailuresThatAreNotARefusalPassThroughAfterTheAuthenticateFrame() async throws {
        _ = try prepare()
        let failures: [EverAgentError] = [.cancelled, .untrustedServer, .gatewayNotRunning(path: "https://127.0.0.1:8443"), .timeout(operation: "x", after: 1)]
        for failure in failures {
            let outcome = await run(incoming: [.success(challenge()), .failure(failure)])
            XCTAssertEqual(outcome.error as? EverAgentError, failure)
        }
    }

    func testAMissingKeyStopsTheHandshakeBeforeAnythingIsSent() async throws {
        let outcome = await run(incoming: [.success(challenge()), .success(authenticated)])
        XCTAssertEqual(outcome.error as? EverAgentError, .unauthorizedDevice)
        XCTAssertTrue(outcome.sent.isEmpty)
    }

    func testASendFailureEndsTheHandshake() async throws {
        _ = try prepare()
        let outcome = await run(incoming: [.success(challenge()), .success(authenticated)], failSend: EverAgentError.connectionClosed)
        XCTAssertEqual(outcome.error as? EverAgentError, .connectionClosed)
        XCTAssertEqual(outcome.sent.count, 1)
    }

    func testASigningFailureIsReportedAsIs() async throws {
        let outcome = await run(incoming: [.success(challenge())], identity: BrokenIdentity())
        XCTAssertEqual(outcome.error as? EverAgentError, .deviceIdentity("The key is locked."))
        XCTAssertTrue(outcome.sent.isEmpty)
    }

    private struct BrokenIdentity: EverAgentDeviceIdentity {
        func createKey(tag: String, development: Bool) throws -> String { "" }
        func sign(_ message: Data, tag: String) throws -> String { throw EverAgentError.deviceIdentity("The key is locked.") }
        func removeKey(tag: String) {}
    }
}

final class EverAgentPinningTests: XCTestCase {
    private let certificate = Data("abc".utf8)
    private let digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    func testTheLeafCertificateMustHashToThePinnedFingerprint() {
        XCTAssertTrue(EverAgentPinnedTrust.accepts(certificate, fingerprint: digest))
    }

    func testTheFingerprintComparisonIgnoresHexDigitCase() {
        XCTAssertTrue(EverAgentPinnedTrust.accepts(certificate, fingerprint: digest.uppercased()))
        let mixed = String(digest.prefix(20)).uppercased() + String(digest.dropFirst(20))
        XCTAssertTrue(EverAgentPinnedTrust.accepts(certificate, fingerprint: mixed))
    }

    func testAnythingElseIsRefused() {
        XCTAssertFalse(EverAgentPinnedTrust.accepts(Data("abd".utf8), fingerprint: digest))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(Data(), fingerprint: digest))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate + Data([0]), fingerprint: digest))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: ""))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: String(digest.dropLast())))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: digest + "0"))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: " " + digest))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: String(digest.dropLast()) + "e"))
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: String(repeating: "0", count: 64)))
        let colons = stride(from: 0, to: 64, by: 2).map { String(digest.dropFirst($0).prefix(2)) }.joined(separator: ":")
        XCTAssertFalse(EverAgentPinnedTrust.accepts(certificate, fingerprint: colons))
    }

    func testTheEmptyInputHasItsOwnDigest() {
        XCTAssertTrue(EverAgentPinnedTrust.accepts(Data(), fingerprint: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
    }

    func testANewTrustStartsWithoutARejection() {
        let trust = EverAgentPinnedTrust(fingerprint: digest)
        XCTAssertFalse(trust.certificateRejected)
    }
}

final class EverAgentNetworkFailureTests: XCTestCase {
    private let address = "https://192.168.1.20:8443"

    private func classify(_ error: Error, rejected: Bool = false) -> EverAgentError {
        EverAgentNetworkFailure.classify(error, address: address, certificateRejected: rejected)
    }

    func testARejectedCertificateOutranksEveryOtherFailure() {
        XCTAssertEqual(classify(URLError(.cancelled), rejected: true), .untrustedServer)
        XCTAssertEqual(classify(URLError(.cannotConnectToHost), rejected: true), .untrustedServer)
        XCTAssertEqual(classify(EverAgentError.connectionClosed, rejected: true), .untrustedServer)
        XCTAssertEqual(classify(CancellationError(), rejected: true), .untrustedServer)
    }

    func testUnreachableOrRefusingHostsMeanTheGatewayIsNotRunning() {
        let unreachable: [Error] = [
            URLError(.cannotConnectToHost),
            URLError(.cannotFindHost),
            URLError(.dnsLookupFailed),
            URLError(.timedOut),
            URLError(.notConnectedToInternet),
            URLError(.internationalRoamingOff),
            URLError(.dataNotAllowed),
            URLError(.secureConnectionFailed),
            URLError(.badServerResponse),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EHOSTUNREACH)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENETUNREACH)),
            NSError(domain: "SomethingElse", code: 1),
        ]
        for error in unreachable {
            XCTAssertEqual(classify(error), .gatewayNotRunning(path: address), "\(error)")
        }
    }

    func testDroppedConnectionsMeanTheConnectionClosed() {
        let dropped: [Error] = [
            URLError(.networkConnectionLost),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTCONN)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNRESET)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNABORTED)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EPIPE)),
        ]
        for error in dropped {
            XCTAssertEqual(classify(error), .connectionClosed, "\(error)")
        }
    }

    func testCancellationAndTypedErrorsKeepTheirMeaning() {
        XCTAssertEqual(classify(CancellationError()), .cancelled)
        XCTAssertEqual(classify(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(classify(EverAgentError.unauthorizedDevice), .unauthorizedDevice)
        XCTAssertEqual(classify(EverAgentError.timeout(operation: "x", after: 2)), .timeout(operation: "x", after: 2))
        XCTAssertEqual(classify(EverAgentError.protocol("odd")), .protocol("odd"))
    }
}

final class EverAgentGatewayAddressTests: XCTestCase {
    private func endpoint(_ address: String, _ scheme: String, _ path: String) throws -> String {
        try EverAgentGatewayAddress.endpoint(address, scheme: scheme, path: path).absoluteString
    }

    func testEndpointsKeepTheHostAndPortAndReplaceTheRest() throws {
        XCTAssertEqual(try endpoint("https://192.168.1.20:8443", "wss", "/v1/connect"), "wss://192.168.1.20:8443/v1/connect")
        XCTAssertEqual(try endpoint("https://192.168.1.20:8443", "https", "/v1/pair"), "https://192.168.1.20:8443/v1/pair")
        XCTAssertEqual(try endpoint("https://mac.local/", "https", "/v1/pair"), "https://mac.local/v1/pair")
        XCTAssertEqual(try endpoint("HTTPS://mac.local:9000/base/path?x=1#part", "wss", "/v1/connect"), "wss://mac.local:9000/v1/connect")
        XCTAssertEqual(try endpoint("https://[fe80::1]:8443", "wss", "/v1/connect"), "wss://[fe80::1]:8443/v1/connect")
    }

    func testOnlyHTTPSAddressesWithAHostAreUsable() {
        for address in ["http://192.168.1.20:8443", "wss://192.168.1.20:8443", "ftp://mac.local", "mac.local:8443", "https://", "", "not a url"] {
            XCTAssertThrowsError(try endpoint(address, "wss", "/v1/connect"), address) { error in
                XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: address))
            }
        }
    }
}
