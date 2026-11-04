import CryptoKit
import Security
import XCTest
@testable import TimeMasterCore

final class EverAgentIdentityTests: XCTestCase {
    private let service = "com.timemaster.everagent.tests.\(UUID().uuidString)"
    private var tags: [(service: String, tag: String)] = []

    override func tearDown() {
        for entry in tags { EverAgentKeychainIdentity(service: entry.service).removeKey(tag: entry.tag) }
        tags = []
    }

    private func newTag(in service: String? = nil) -> String {
        let tag = "device.test.\(UUID().uuidString)"
        tags.append((service ?? self.service, tag))
        return tag
    }

    private func publicKey(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> P256.Signing.PublicKey {
        let raw = try XCTUnwrap(Data(base64Encoded: text), file: file, line: line)
        XCTAssertEqual(raw.count, 65, file: file, line: line)
        XCTAssertEqual(raw.first, 0x04, file: file, line: line)
        return try P256.Signing.PublicKey(x963Representation: raw)
    }

    private func signature(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> P256.Signing.ECDSASignature {
        let der = try XCTUnwrap(Data(base64Encoded: text), file: file, line: line)
        XCTAssertEqual(der.first, 0x30, file: file, line: line)
        return try P256.Signing.ECDSASignature(derRepresentation: der)
    }

    private func failure(_ body: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) -> EverAgentError? {
        do {
            try body()
            XCTFail("Expected a failure", file: file, line: line)
            return nil
        } catch let error as EverAgentError {
            return error
        } catch {
            XCTFail("Expected an EverAgentError but got \(error)", file: file, line: line)
            return nil
        }
    }

    func testTheSignedPayloadIsExactlyTheProtocolString() {
        let payload = EverAgentHandshake.signedPayload(serverId: "srv-1", nonce: "bm9uY2U=")
        XCTAssertEqual(Array(payload), Array("ompp.v1\nsrv-1\nbm9uY2U=".utf8))
        XCTAssertEqual(payload.filter { $0 == 0x0A }.count, 2)
        XCTAssertNotEqual(payload.last, 0x0A)
        let unicode = EverAgentHandshake.signedPayload(serverId: "srv-é", nonce: "n")
        XCTAssertEqual(unicode, Data("ompp.v1\nsrv-é\nn".utf8))
    }

    func testADevelopmentKeySignsDERSignaturesThatVerifyAgainstItsPublicKey() throws {
        let identity = EverAgentKeychainIdentity(service: service)
        let tag = newTag()
        let key = try publicKey(try identity.createKey(tag: tag, development: true))
        let message = EverAgentHandshake.signedPayload(serverId: "5c22b39f-a2c3-44ff-9fc3-29157ec22ac7", nonce: "ZGVhZGJlZWY=")
        let first = try signature(try identity.sign(message, tag: tag))
        let second = try signature(try identity.sign(message, tag: tag))
        XCTAssertTrue(key.isValidSignature(first, for: message))
        XCTAssertTrue(key.isValidSignature(second, for: message))
        XCTAssertFalse(key.isValidSignature(first, for: Data("ompp.v1\nother\nZGVhZGJlZWY=".utf8)))
        XCTAssertFalse(key.isValidSignature(first, for: message + Data([0x0A])))
        XCTAssertFalse(try publicKey(try identity.createKey(tag: newTag(), development: true)).isValidSignature(first, for: message))
    }

    func testAKeyOutlivesTheValueThatCreatedIt() throws {
        let tag = newTag()
        let key = try publicKey(try EverAgentKeychainIdentity(service: service).createKey(tag: tag, development: true))
        let message = Data("persisted".utf8)
        let signed = try signature(try EverAgentKeychainIdentity(service: service).sign(message, tag: tag))
        XCTAssertTrue(key.isValidSignature(signed, for: message))
    }

    func testCreatingAKeyAgainReplacesTheOldOne() throws {
        let identity = EverAgentKeychainIdentity(service: service)
        let tag = newTag()
        let old = try publicKey(try identity.createKey(tag: tag, development: true))
        let new = try publicKey(try identity.createKey(tag: tag, development: true))
        XCTAssertNotEqual(old.x963Representation, new.x963Representation)
        let message = Data("replaced".utf8)
        let signed = try signature(try identity.sign(message, tag: tag))
        XCTAssertTrue(new.isValidSignature(signed, for: message))
        XCTAssertFalse(old.isValidSignature(signed, for: message))
    }

    func testRemovingAKeyMakesItUnavailable() throws {
        let identity = EverAgentKeychainIdentity(service: service)
        let tag = newTag()
        _ = try identity.createKey(tag: tag, development: true)
        XCTAssertNoThrow(try identity.sign(Data("x".utf8), tag: tag))
        identity.removeKey(tag: tag)
        XCTAssertEqual(failure { _ = try identity.sign(Data("x".utf8), tag: tag) }, .unauthorizedDevice)
        identity.removeKey(tag: tag)
        identity.removeKey(tag: "device.test.never-created")
        XCTAssertEqual(failure { _ = try identity.sign(Data("x".utf8), tag: "device.test.never-created") }, .unauthorizedDevice)
    }

    func testServiceNamesKeepKeysApart() throws {
        let other = service + ".other"
        let mine = EverAgentKeychainIdentity(service: service)
        let theirs = EverAgentKeychainIdentity(service: other)
        let tag = newTag()
        tags.append((other, tag))
        _ = try mine.createKey(tag: tag, development: true)
        XCTAssertEqual(failure { _ = try theirs.sign(Data("x".utf8), tag: tag) }, .unauthorizedDevice)
        theirs.removeKey(tag: tag)
        XCTAssertNoThrow(try mine.sign(Data("x".utf8), tag: tag))
        _ = try theirs.createKey(tag: tag, development: true)
        theirs.removeKey(tag: tag)
        XCTAssertNoThrow(try mine.sign(Data("x".utf8), tag: tag))
    }

    func testKeysLiveInTheKeychainAsDeviceOnlyGenericPasswords() throws {
        let identity = EverAgentKeychainIdentity(service: service)
        let tag = newTag()
        _ = try identity.createKey(tag: tag, development: true)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrService as String] as? String, service)
        XCTAssertEqual(attributes[kSecAttrAccount as String] as? String, tag)
        let synchronizable = attributes[kSecAttrSynchronizable as String] as? Bool
        XCTAssertNotEqual(synchronizable, true)
        #if os(iOS)
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #endif
        let wrongService = query.merging([kSecAttrService as String: service + ".none"]) { _, new in new }
        XCTAssertEqual(SecItemCopyMatching(wrongService as CFDictionary, nil), errSecItemNotFound)
    }

    func testAnUnreadableStoredKeyIsTreatedAsMissing() throws {
        let tag = newTag()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: Data("not a key".utf8),
        ]
        XCTAssertEqual(SecItemAdd(item as CFDictionary, nil), errSecSuccess)
        let identity = EverAgentKeychainIdentity(service: service)
        XCTAssertEqual(failure { _ = try identity.sign(Data("x".utf8), tag: tag) }, .unauthorizedDevice)
        let key = try publicKey(try identity.createKey(tag: tag, development: true))
        let message = Data("recovered".utf8)
        XCTAssertTrue(key.isValidSignature(try signature(try identity.sign(message, tag: tag)), for: message))
    }

    func testARealKeyNeedsHardwareProtection() throws {
        let identity = EverAgentKeychainIdentity(service: service, hardwareBacked: false)
        let tag = newTag()
        guard case .deviceIdentity(let reason)? = failure({ _ = try identity.createKey(tag: tag, development: false) }) else {
            return XCTFail("Expected a deviceIdentity error")
        }
        XCTAssertTrue(reason.contains("hardware"), reason)
        XCTAssertEqual(failure { _ = try identity.sign(Data("x".utf8), tag: tag) }, .unauthorizedDevice)
        XCTAssertNoThrow(try identity.createKey(tag: tag, development: true))
    }

    func testTheSecureEnclaveSignsWhenTheDeviceHasOne() throws {
        try XCTSkipUnless(SecureEnclave.isAvailable, "This device has no Secure Enclave")
        let identity = EverAgentKeychainIdentity(service: service)
        let tag = newTag()
        let key = try publicKey(try identity.createKey(tag: tag, development: false))
        let message = EverAgentHandshake.signedPayload(serverId: "srv", nonce: "nonce")
        XCTAssertTrue(key.isValidSignature(try signature(try identity.sign(message, tag: tag)), for: message))
        let again = try publicKey(try identity.createKey(tag: tag, development: false))
        XCTAssertNotEqual(again.x963Representation, key.x963Representation)
    }
}
