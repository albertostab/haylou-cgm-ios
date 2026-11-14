import Foundation
import Security
enum KeychainStore {
    private static let service = "it.albertostabile.haylou-cgm.nightscout"
    private static let account = "readable-token"
    static func load() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let code = SecItemCopyMatching(query as CFDictionary, &result)
        guard code == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return "" }
        return token
    }
    @discardableResult
    static func save(_ token: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty else { return true }
        let attributes: [String: Any] = query.merging([
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, new in new }
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
