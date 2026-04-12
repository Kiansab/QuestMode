import Foundation
import Security

/// Stores the user’s OpenAI API secret in the Keychain (not in UserDefaults, not in the repo).
enum OpenAIAPIKeyStore {
    private static var service: String {
        (Bundle.main.bundleIdentifier ?? "QuestMode") + ".openai.apiKey"
    }

    private static let account = "OPENAI_API_KEY"

    enum StoreError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let code):
                return "Couldn’t save API key (Keychain error \(code))."
            }
        }
    }

    /// Raw UTF-8 string as stored; may contain paste noise until normalized by `AIQuestGenerator`.
    static func loadRaw() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasStoredKey: Bool {
        guard let raw = loadRaw() else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Persists a normalized `sk-…` key, or clears storage if `normalizedKey` is empty.
    static func saveNormalizedKey(_ normalizedKey: String) throws {
        let trimmed = normalizedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try delete()
            return
        }
        let data = Data(trimmed.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }
}
