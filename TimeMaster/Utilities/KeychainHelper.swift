import Foundation
import Security

/// Keychain wrapper with UserDefaults fallback (ensures persistence in simulator / no-entitlements builds).
enum KeychainHelper {

    private static let service = Bundle.main.bundleIdentifier ?? "com.timemaster.TimeMaster"

    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)

        // 1. Remove any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 2. Add new item
        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)

        // 3. Always mirror to UserDefaults as fallback (base64, not security-critical in dev)
        UserDefaults.standard.set(data.base64EncodedString(), forKey: "_kc_\(key)")
    }

    static func load(forKey key: String) -> String? {
        // Try Keychain first
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8), !str.isEmpty {
            return str
        }

        // Fallback: UserDefaults mirror
        if let encoded = UserDefaults.standard.string(forKey: "_kc_\(key)"),
           let data = Data(base64Encoded: encoded),
           let str = String(data: data, encoding: .utf8), !str.isEmpty {
            return str
        }
        return nil
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "_kc_\(key)")
    }
}
