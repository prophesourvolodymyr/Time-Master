import XCTest
@testable import TimeMasterCore

private let now = Date(timeIntervalSince1970: 1_793_620_800)
private let fingerprint = String(repeating: "ab", count: 32)
private let serverId = "5c22b39f-a2c3-44ff-9fc3-29157ec22ac7"
private let pairingCode = "DU5ab_Z4TdPV5DMSohXYK_MJ"

private func payload(_ changes: [String: JSONValue] = [:], removing: [String] = []) -> [String: JSONValue] {
    var value: [String: JSONValue] = [
        "version": 1,
        "url": "https://192.168.1.20:8443",
        "code": .string(pairingCode),
        "certificateSHA256": .string(fingerprint),
        "serverId": .string(serverId),
        "expiresAt": "2026-11-02T12:05:00.123456+00:00",
    ]
    for (key, replacement) in changes { value[key] = replacement }
    for key in removing { value[key] = nil }
    return value
}

private func encoded(_ data: Data, padded: Bool = false) -> String {
    let text = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    return padded ? text : text.replacingOccurrences(of: "=", with: "")
}

private func link(_ fields: [String: JSONValue], padded: Bool = false) -> String {
    "ompp://pair?payload=" + encoded(JSONValue.object(fields).serialized(), padded: padded)
}

private func invitation(_ changes: [String: JSONValue] = [:]) throws -> EverAgentPairingInvitation {
    try EverAgentPairingInvitation(string: link(payload(changes)), now: now)
}

final class EverAgentPairingTests: XCTestCase {
    private func rejection(_ string: String, file: StaticString = #filePath, line: UInt = #line) -> EverAgentError? {
        do {
            let accepted = try EverAgentPairingInvitation(string: string, now: now)
            XCTFail("Expected the invitation to be refused but got \(accepted)", file: file, line: line)
            return nil
        } catch let error as EverAgentError {
            return error
        } catch {
            XCTFail("Expected an EverAgentError but got \(error)", file: file, line: line)
            return nil
        }
    }

    private func assertInvalid(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .invalidInvitation(let reason)? = rejection(string, file: file, line: line) else {
            return XCTFail("Expected invalidInvitation", file: file, line: line)
        }
        XCTAssertFalse(reason.isEmpty, file: file, line: line)
    }

    func testParsesAValidInvitation() throws {
        let parsed = try EverAgentPairingInvitation(string: link(payload()), now: now)
        XCTAssertEqual(parsed.serverURL, URL(string: "https://192.168.1.20:8443"))
        XCTAssertEqual(parsed.serverId, serverId)
        XCTAssertEqual(parsed.certificateSHA256, fingerprint)
        XCTAssertEqual(parsed.code, pairingCode)
        XCTAssertEqual(parsed.expiresAt.timeIntervalSince1970, 1_793_621_100.123, accuracy: 0.001)
        XCTAssertEqual(parsed.hostLabel, "192.168.1.20:8443")
    }

    func testAcceptsTheEquivalentWaysAnInvitationCanBeWritten() throws {
        let base = link(payload())
        let tolerated: [(String, String)] = [
            ("surrounding whitespace", "  \n" + base + "\n"),
            ("a slash before the query", base.replacingOccurrences(of: "pair?", with: "pair/?")),
            ("an upper case scheme and host", base.replacingOccurrences(of: "ompp://pair", with: "OMPP://PAIR")),
            ("an empty note", link(payload(["note": ""]), padded: true)),
            ("one extra byte of padding", link(payload(["note": "x"]), padded: true)),
            ("two extra bytes of padding", link(payload(["note": "xx"]), padded: true)),
            ("percent encoded padding", link(payload(["note": "x"]), padded: true).replacingOccurrences(of: "=", with: "%3D").replacingOccurrences(of: "payload%3D", with: "payload=")),
            ("percent encoded double padding", link(payload(["note": "xx"]), padded: true).replacingOccurrences(of: "=", with: "%3D").replacingOccurrences(of: "payload%3D", with: "payload=")),
            ("an expiry without fractions", link(payload(["expiresAt": "2026-11-02T12:05:00Z"]))),
            ("an expiry with another offset", link(payload(["expiresAt": "2026-11-02T14:05:00+02:00"]))),
            ("an upper case fingerprint", link(payload(["certificateSHA256": .string(fingerprint.uppercased())]))),
            ("a trailing slash in the address", link(payload(["url": "https://192.168.1.20:8443/"]))),
            ("fields this version does not know", link(payload(["note": "hello", "extra": ["a": 1]]))),
        ]
        for (name, text) in tolerated {
            let parsed = try EverAgentPairingInvitation(string: text, now: now)
            XCTAssertEqual(parsed.serverId, serverId, name)
            XCTAssertEqual(parsed.code, pairingCode, name)
            XCTAssertEqual(parsed.hostLabel, "192.168.1.20:8443", name)
        }
        let offset = try EverAgentPairingInvitation(string: link(payload(["expiresAt": "2026-11-02T14:05:00+02:00"])), now: now)
        XCTAssertEqual(offset.expiresAt.timeIntervalSince1970, 1_793_621_100, accuracy: 0.001)
        let upper = try EverAgentPairingInvitation(string: link(payload(["certificateSHA256": .string(fingerprint.uppercased())])), now: now)
        XCTAssertEqual(upper.certificateSHA256, fingerprint.uppercased())
    }

    func testHostLabelsShowThePortAndBracketIPv6Addresses() throws {
        let cases: [(String, String)] = [
            ("https://mac.local", "mac.local"),
            ("https://mac.local:443", "mac.local:443"),
            ("https://192.168.1.20:8443", "192.168.1.20:8443"),
            ("https://[fe80::1]:8443", "[fe80::1]:8443"),
            ("https://[::1]", "[::1]"),
        ]
        for (address, label) in cases {
            XCTAssertEqual(try invitation(["url": .string(address)]).hostLabel, label, address)
        }
    }

    func testAnInvitationThatHasExpiredIsRefused() throws {
        let text = link(payload())
        let expiry = try EverAgentPairingInvitation(string: text, now: now).expiresAt
        XCTAssertThrowsError(try EverAgentPairingInvitation(string: text, now: expiry)) { error in
            XCTAssertEqual(error as? EverAgentError, .invitationExpired)
        }
        XCTAssertThrowsError(try EverAgentPairingInvitation(string: text, now: expiry.addingTimeInterval(0.001))) { error in
            XCTAssertEqual(error as? EverAgentError, .invitationExpired)
        }
        XCTAssertThrowsError(try EverAgentPairingInvitation(string: text, now: expiry.addingTimeInterval(86_400))) { error in
            XCTAssertEqual(error as? EverAgentError, .invitationExpired)
        }
        XCTAssertNoThrow(try EverAgentPairingInvitation(string: text, now: expiry.addingTimeInterval(-0.001)))
    }

    func testTheInvitationIsCheckedAgainstTheCurrentTimeByDefault() throws {
        let future = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600))
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600))
        XCTAssertNoThrow(try EverAgentPairingInvitation(string: link(payload(["expiresAt": .string(future)]))))
        XCTAssertThrowsError(try EverAgentPairingInvitation(string: link(payload(["expiresAt": .string(past)])))) { error in
            XCTAssertEqual(error as? EverAgentError, .invitationExpired)
        }
    }

    func testTheSchemeHostAndPathMustBeThoseOfAnInvitation() {
        let body = encoded(JSONValue.object(payload()).serialized())
        let refused = [
            "https://pair?payload=\(body)",
            "ompp2://pair?payload=\(body)",
            "pair?payload=\(body)",
            "ompp://other?payload=\(body)",
            "ompp://pair.example.com?payload=\(body)",
            "ompp://pair/extra?payload=\(body)",
            "ompp://user@pair?payload=\(body)",
            "ompp://user:secret@pair?payload=\(body)",
            "ompp://pair?payload=\(body)#fragment",
            "ompp://pair",
            "ompp://pair?",
            "",
            "   ",
            "not a url at all",
        ]
        for text in refused { assertInvalid(text) }
    }

    func testTheQueryMustHoldExactlyOnePayload() {
        let body = encoded(JSONValue.object(payload()).serialized())
        let refused = [
            "ompp://pair?payload=\(body)&extra=1",
            "ompp://pair?extra=1&payload=\(body)",
            "ompp://pair?payload=\(body)&payload=\(body)",
            "ompp://pair?payload=\(body)&",
            "ompp://pair?&payload=\(body)",
            "ompp://pair?payload",
            "ompp://pair?payload=",
            "ompp://pair?Payload=\(body)",
            "ompp://pair?data=\(body)",
            "ompp://pair?\(body)",
        ]
        for text in refused { assertInvalid(text) }
    }

    func testThePayloadSizeLimitIsSixteenKibibytes() throws {
        let limit = 16 * 1024
        let emptyNote = JSONValue.object(payload(["note": ""])).serialized().count
        func body(jsonBytes: Int) -> String {
            encoded(JSONValue.object(payload(["note": .string(String(repeating: "a", count: jsonBytes - emptyNote))])).serialized())
        }
        let atTheLimit = body(jsonBytes: limit / 4 * 3)
        XCTAssertEqual(atTheLimit.utf8.count, limit)
        XCTAssertNoThrow(try EverAgentPairingInvitation(string: "ompp://pair?payload=" + atTheLimit, now: now))
        let overTheLimit = body(jsonBytes: limit / 4 * 3 + 1)
        XCTAssertGreaterThan(overTheLimit.utf8.count, limit)
        assertInvalid("ompp://pair?payload=" + overTheLimit)
        assertInvalid(link(payload(["note": .string(String(repeating: "a", count: 40_000))])))
        XCTAssertNoThrow(try EverAgentPairingInvitation(string: link(payload(["note": .string(String(repeating: "a", count: 9_000))])), now: now))
    }

    func testThePayloadMustBeBase64URLOfJSON() {
        let json = JSONValue.object(payload()).serialized()
        let standard = json.base64EncodedString()
        let url = encoded(json)
        let refused = [
            "ompp://pair?payload=" + standard.replacingOccurrences(of: "=", with: "") + "+/",
            "ompp://pair?payload=" + url + "!",
            "ompp://pair?payload=" + url + " " + url,
            "ompp://pair?payload=" + url + "===",
            "ompp://pair?payload=" + url + "=x",
            "ompp://pair?payload=" + String(url.dropLast(1)) + "=",
            "ompp://pair?payload=" + String(url.prefix(url.count - url.count % 4 - 1)),
            "ompp://pair?payload=====",
            "ompp://pair?payload=%",
            "ompp://pair?payload=" + encoded(Data("not json".utf8)),
            "ompp://pair?payload=" + encoded(Data("[1,2,3]".utf8)),
            "ompp://pair?payload=" + encoded(Data("{}".utf8)),
            "ompp://pair?payload=" + encoded(Data("\"text\"".utf8)),
            "ompp://pair?payload=" + encoded(Data([0xFF, 0xFE, 0xFD, 0x00])),
            link(payload(removing: ["version"])),
            link(payload(removing: ["url"])),
            link(payload(removing: ["code"])),
            link(payload(removing: ["certificateSHA256"])),
            link(payload(removing: ["serverId"])),
            link(payload(removing: ["expiresAt"])),
            link(payload(["version": "1"])),
            link(payload(["url": 7])),
            link(payload(["code": .null])),
        ]
        for text in refused { assertInvalid(text) }
    }

    func testOnlyVersionOneIsSupported() {
        for version: JSONValue in [0, 2, -1, 100] {
            assertInvalid(link(payload(["version": version])))
        }
    }

    func testTheServerAddressMustBeHTTPSWithAHost() {
        let refused: [JSONValue] = [
            "http://192.168.1.20:8443",
            "ftp://192.168.1.20",
            "192.168.1.20:8443",
            "https://",
            "https:///path",
            "https://user@192.168.1.20:8443",
            "https://user:secret@192.168.1.20:8443",
            "https://192.168.1.20:8443#fragment",
            "wss://192.168.1.20:8443",
            "",
            "not a url",
        ]
        for address in refused { assertInvalid(link(payload(["url": address]))) }
    }

    func testTheFingerprintMustBeSixtyFourHexDigits() {
        let refused: [String] = [
            "",
            String(repeating: "a", count: 63),
            String(repeating: "a", count: 65),
            String(repeating: "g", count: 64),
            String(repeating: "a", count: 63) + " ",
            String(repeating: "é", count: 32),
            String(repeating: "a", count: 60) + "٣٣",
            Array(repeating: "ab", count: 31).joined(separator: ":") + ":ab",
            "0x" + String(repeating: "a", count: 62),
        ]
        for value in refused { assertInvalid(link(payload(["certificateSHA256": .string(value)]))) }
    }

    func testTheCodeAndTheServerIdentityMustNotBeEmpty() {
        assertInvalid(link(payload(["code": ""])))
        assertInvalid(link(payload(["serverId": ""])))
        assertInvalid(link(payload(["serverId": "  \n"])))
    }

    func testTheExpiryMustBeADate() {
        let refused: [JSONValue] = ["", "tomorrow", "2026-11-02", "2026-11-02 12:05:00", "1793621100", 1_793_621_100, "2026-13-45T25:61:00Z"]
        for value in refused { assertInvalid(link(payload(["expiresAt": value]))) }
    }

    func testInvitationErrorsDescribeThemselvesForPeople() {
        let errors: [(EverAgentError, [String])] = [
            (.invalidInvitation("This is not an EverAhent pairing code."), ["pairing code"]),
            (.invitationExpired, ["expired", "new one"]),
            (.untrustedServer, ["not the one", "certificate", "Pair again"]),
            (.unauthorizedDevice, ["no longer accepts", "Pair it again"]),
            (.deviceIdentity("The keychain refused."), ["keychain"]),
            (.gatewayNotRunning(path: "https://192.168.1.20:8443"), ["not running", "https://192.168.1.20:8443"]),
        ]
        for (error, fragments) in errors {
            let text = error.errorDescription ?? ""
            for fragment in fragments { XCTAssertTrue(text.contains(fragment), "\(text) should mention \(fragment)") }
        }
    }

    func testTheProfileKeepsItsStoredShape() throws {
        let profile = EverAgentRemoteProfile(
            serverId: serverId,
            name: "192.168.1.20:8443",
            url: "https://192.168.1.20:8443",
            certificateSHA256: fingerprint,
            deviceId: "device-1",
            keyTag: "device.\(serverId).11111111-2222-3333-4444-555555555555",
            development: true
        )
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(EverAgentRemoteProfile.self, from: data), profile)
        XCTAssertEqual(Set(try JSONValue(parsing: data).objectValue.keys), ["serverId", "name", "url", "certificateSHA256", "deviceId", "keyTag", "development"])
        let stored = """
        {"serverId":"s","name":"mac","url":"https://mac.local:8443","certificateSHA256":"\(fingerprint)","deviceId":"d","keyTag":"device.s.t","development":false}
        """
        let decoded = try JSONDecoder().decode(EverAgentRemoteProfile.self, from: Data(stored.utf8))
        XCTAssertEqual(decoded, EverAgentRemoteProfile(serverId: "s", name: "mac", url: "https://mac.local:8443", certificateSHA256: fingerprint, deviceId: "d", keyTag: "device.s.t", development: false))
        var edited = decoded
        edited.name = "Studio"
        edited.development = true
        XCTAssertNotEqual(edited, decoded)
    }
}

final class EverAgentEnrolmentTests: XCTestCase {
    private let identity = MemoryIdentity()

    private func reply(_ status: Int, _ body: JSONValue? = nil, raw: String? = nil, to request: URLRequest) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (Data((raw ?? body?.jsonString ?? "").utf8), response)
    }

    private func success(for request: URLRequest, deviceId: String = "device-1", reportedServer: String = serverId) -> (Data, HTTPURLResponse) {
        reply(200, ["deviceId": .string(deviceId), "serverId": .string(reportedServer), "deviceName": "Tmax iPhone"], to: request)
    }

    private func enrol(
        _ parsed: EverAgentPairingInvitation,
        development: Bool = true,
        exchange: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> EverAgentRemoteProfile {
        try await EverAgentPairing.enroll(parsed, deviceName: "Tmax iPhone", development: development, identity: identity, exchange: exchange)
    }

    private func assertCleanedUp(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(identity.created.count, 1, file: file, line: line)
        XCTAssertEqual(identity.removed, identity.created.map(\.tag), file: file, line: line)
        XCTAssertNil(identity.publicKey(tag: identity.created[0].tag), file: file, line: line)
    }

    func testEnrolmentPostsTheRequestAndReturnsTheProfile() async throws {
        let parsed = try invitation()
        var seen: [URLRequest] = []
        let profile = try await enrol(parsed) { request in
            seen.append(request)
            return self.success(for: request, deviceId: "device-42")
        }
        XCTAssertEqual(seen.count, 1)
        let request = try XCTUnwrap(seen.first)
        XCTAssertEqual(request.url, URL(string: "https://192.168.1.20:8443/v1/pair"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try JSONValue(parsing: try XCTUnwrap(request.httpBody))
        XCTAssertEqual(Set(body.objectValue.keys), ["code", "deviceName", "publicKey", "development"])
        XCTAssertEqual(body["code"], .string(pairingCode))
        XCTAssertEqual(body["deviceName"], "Tmax iPhone")
        XCTAssertEqual(body["development"], true)
        let key = try XCTUnwrap(Data(base64Encoded: body["publicKey"].text))
        XCTAssertEqual(key.count, 65)
        XCTAssertEqual(key.first, 0x04)
        XCTAssertEqual(key, identity.publicKey(tag: profile.keyTag)?.x963Representation)
        XCTAssertEqual(profile, EverAgentRemoteProfile(
            serverId: serverId,
            name: "192.168.1.20:8443",
            url: "https://192.168.1.20:8443",
            certificateSHA256: fingerprint,
            deviceId: "device-42",
            keyTag: profile.keyTag,
            development: true
        ))
        XCTAssertTrue(profile.keyTag.hasPrefix("device.\(serverId)."))
        XCTAssertNotNil(UUID(uuidString: String(profile.keyTag.dropFirst("device.\(serverId).".count))))
        XCTAssertEqual(identity.created, [MemoryIdentity.Creation(tag: profile.keyTag, development: true)])
        XCTAssertTrue(identity.removed.isEmpty)
    }

    func testTheDevelopmentFlagReachesTheKeyAndTheRequest() async throws {
        let parsed = try invitation()
        var flags: [JSONValue] = []
        let profile = try await enrol(parsed, development: false) { request in
            flags.append(try JSONValue(parsing: try XCTUnwrap(request.httpBody))["development"])
            return self.success(for: request)
        }
        XCTAssertEqual(flags, [false])
        XCTAssertFalse(profile.development)
        XCTAssertEqual(identity.created.map(\.development), [false])
    }

    func testTheEnrolmentAddressDropsAnyPathAndQueryOfTheInvitation() async throws {
        let parsed = try invitation(["url": "https://mac.local:9000/base/path?x=1"])
        var addresses: [URL?] = []
        let profile = try await enrol(parsed) { request in
            addresses.append(request.url)
            return self.success(for: request)
        }
        XCTAssertEqual(addresses, [URL(string: "https://mac.local:9000/v1/pair")])
        XCTAssertEqual(profile.url, parsed.serverURL.absoluteString)
        XCTAssertEqual(profile.name, "mac.local:9000")
    }

    func testEveryAttemptUsesItsOwnKeyTag() async throws {
        let parsed = try invitation()
        let first = try await enrol(parsed) { self.success(for: $0) }
        let second = try await enrol(parsed) { self.success(for: $0) }
        XCTAssertNotEqual(first.keyTag, second.keyTag)
        XCTAssertEqual(identity.created.count, 2)
        XCTAssertTrue(identity.removed.isEmpty)
    }

    func testAnAnswerFromAnotherServerIdentityIsRefused() async throws {
        let parsed = try invitation()
        do {
            _ = try await enrol(parsed) { self.success(for: $0, reportedServer: "another-server") }
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual(error as? EverAgentError, .untrustedServer)
        }
        assertCleanedUp()
    }

    func testAnAnswerWithoutAServerIdentityIsAccepted() async throws {
        let parsed = try invitation()
        let profile = try await enrol(parsed) { self.reply(200, ["deviceId": "device-7"], to: $0) }
        XCTAssertEqual(profile.deviceId, "device-7")
        XCTAssertTrue(identity.removed.isEmpty)
    }

    func testGatewayRefusalsBecomeTypedErrorsAndRemoveTheKey() async throws {
        let cases: [(Int, String, EverAgentError)] = [
            (401, #"{"error":{"code":"unauthorized","message":"pairing code has expired or was used"}}"#, .remote(code: "unauthorized", message: "pairing code has expired or was used", details: nil)),
            (401, #"{"error":{"code":"unauthorized","message":"pairing code is invalid"}}"#, .remote(code: "unauthorized", message: "pairing code is invalid", details: nil)),
            (401, #"{"error":{"code":"busy","message":"one physical device is already enrolled"}}"#, .remote(code: "busy", message: "one physical device is already enrolled", details: nil)),
            (400, #"{"error":{"code":"invalid_request","message":"publicKey must be an X9.63 P-256 key"}}"#, .remote(code: "invalid_request", message: "publicKey must be an X9.63 P-256 key", details: nil)),
            (500, #"{"error":{}}"#, .remote(code: "unknown", message: "", details: nil)),
            (502, "<html>Bad gateway</html>", .protocol("EverAgent answered the pairing request with HTTP 502.")),
            (404, "", .protocol("EverAgent answered the pairing request with HTTP 404.")),
            (302, #"{"deviceId":"nope"}"#, .protocol("EverAgent answered the pairing request with HTTP 302.")),
            (200, "{}", .protocol("EverAgent accepted the pairing but did not return a device id.")),
            (200, #"{"deviceId":""}"#, .protocol("EverAgent accepted the pairing but did not return a device id.")),
            (200, #"{"deviceId":7}"#, .protocol("EverAgent accepted the pairing but did not return a device id.")),
            (200, "pairing done", .protocol("EverAgent accepted the pairing but did not return a device id.")),
            (200, "[]", .protocol("EverAgent accepted the pairing but did not return a device id.")),
        ]
        let parsed = try invitation()
        for (status, body, expected) in cases {
            let failing = MemoryIdentity()
            do {
                _ = try await EverAgentPairing.enroll(parsed, deviceName: "Tmax iPhone", development: true, identity: failing) { self.reply(status, raw: body, to: $0) }
                XCTFail("HTTP \(status) \(body) should fail")
            } catch {
                XCTAssertEqual(error as? EverAgentError, expected, "HTTP \(status) \(body)")
            }
            XCTAssertEqual(failing.created.count, 1, body)
            XCTAssertEqual(failing.removed, failing.created.map(\.tag), body)
        }
    }

    func testTransportFailuresPassThroughAndRemoveTheKey() async throws {
        let parsed = try invitation()
        let failures: [Error] = [
            EverAgentError.untrustedServer,
            EverAgentError.gatewayNotRunning(path: "https://192.168.1.20:8443"),
            EverAgentError.cancelled,
            EverAgentError.connectionClosed,
            CancellationError(),
            URLError(.timedOut),
        ]
        for failure in failures {
            let failing = MemoryIdentity()
            do {
                _ = try await EverAgentPairing.enroll(parsed, deviceName: "Tmax iPhone", development: true, identity: failing) { _ in throw failure }
                XCTFail("\(failure) should fail")
            } catch {
                XCTAssertEqual(String(describing: error), String(describing: failure))
            }
            XCTAssertEqual(failing.removed, failing.created.map(\.tag), "\(failure)")
            XCTAssertEqual(failing.created.count, 1)
        }
    }

    func testAFailedKeyCreationNeverReachesTheNetworkOrRemovesAnything() async throws {
        let parsed = try invitation()
        identity.failCreation(with: .deviceIdentity("This device cannot keep a hardware-protected key."))
        var calls = 0
        do {
            _ = try await enrol(parsed, development: false) { request in
                calls += 1
                return self.success(for: request)
            }
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual(error as? EverAgentError, .deviceIdentity("This device cannot keep a hardware-protected key."))
        }
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(identity.created.isEmpty)
        XCTAssertTrue(identity.removed.isEmpty)
    }

    func testThePublicPairingCallReportsAnUnreachableGatewayAndCleansUp() async throws {
        let port = closedLoopbackPort()
        let parsed = try invitation(["url": .string("https://127.0.0.1:\(port)")])
        do {
            _ = try await EverAgentPairing.pair(parsed, deviceName: "Tmax iPhone", development: true, identity: identity)
            XCTFail("Expected a failure")
        } catch {
            XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: "https://127.0.0.1:\(port)"))
        }
        assertCleanedUp()
    }
}
