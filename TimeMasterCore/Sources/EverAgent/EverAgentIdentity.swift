import CryptoKit
import Foundation
import Security

public protocol EverAgentDeviceIdentity: Sendable {
    func createKey(tag: String, development: Bool) throws -> String
    func sign(_ message: Data, tag: String) throws -> String
    func removeKey(tag: String)
}

public struct EverAgentKeychainIdentity: EverAgentDeviceIdentity {
    private struct StoredKey: Codable {
        enum Kind: String, Codable {
            case secureEnclave
            case software
        }

        let kind: Kind
        let data: Data
    }

    private let service: String
    private let hardwareBacked: Bool

    public init(service: String = "com.timemaster.everagent") {
        self.init(service: service, hardwareBacked: SecureEnclave.isAvailable)
    }

    init(service: String, hardwareBacked: Bool) {
        self.service = service
        self.hardwareBacked = hardwareBacked
    }

    public func createKey(tag: String, development: Bool) throws -> String {
        guard development || hardwareBacked else {
            throw EverAgentError.deviceIdentity("This device cannot keep a hardware-protected key, which pairing needs. Pair from a physical iPhone, or use a pairing code made for development in the simulator.")
        }
        do {
            let stored: StoredKey
            let publicKey: Data
            if development {
                let key = P256.Signing.PrivateKey()
                stored = StoredKey(kind: .software, data: key.rawRepresentation)
                publicKey = key.publicKey.x963Representation
            } else {
                let key = try SecureEnclave.P256.Signing.PrivateKey()
                stored = StoredKey(kind: .secureEnclave, data: key.dataRepresentation)
                publicKey = key.publicKey.x963Representation
            }
            try save(stored, tag: tag)
            return publicKey.base64EncodedString()
        } catch {
            throw error as? EverAgentError ?? .deviceIdentity("This device could not create its pairing key: \(error.localizedDescription)")
        }
    }

    public func sign(_ message: Data, tag: String) throws -> String {
        guard let stored = try load(tag: tag) else { throw EverAgentError.unauthorizedDevice }
        do {
            let signature: P256.Signing.ECDSASignature
            switch stored.kind {
            case .software:
                signature = try P256.Signing.PrivateKey(rawRepresentation: stored.data).signature(for: message)
            case .secureEnclave:
                signature = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored.data).signature(for: message)
            }
            return signature.derRepresentation.base64EncodedString()
        } catch {
            throw EverAgentError.deviceIdentity("This device could not sign in to EverAgent: \(error.localizedDescription)")
        }
    }

    public func removeKey(tag: String) {
        SecItemDelete(query(tag) as CFDictionary)
    }

    private func query(_ tag: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tag,
            kSecAttrSynchronizable as String: false,
        ]
    }

    private func load(tag: String) throws -> StoredKey? {
        var match = query(tag)
        match[kSecReturnData as String] = true
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(match as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Self.keychainFailure(status) }
        return try? JSONDecoder().decode(StoredKey.self, from: data)
    }

    private func save(_ key: StoredKey, tag: String) throws {
        let data = try JSONEncoder().encode(key)
        let match = query(tag)
        let updated = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw Self.keychainFailure(updated) }
        var item = match
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw Self.keychainFailure(added) }
    }

    private static func keychainFailure(_ status: OSStatus) -> EverAgentError {
        .deviceIdentity("The keychain refused to open this device's pairing key (error \(status)).")
    }
}
