import Foundation
import Security

enum CredentialStoreError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

protocol CredentialStoring: Sendable {
    func save(_ value: String, account: String) throws
    func load(account: String) throws -> String?
    func delete(account: String) throws
}

extension CredentialStoring {
    func hasValue(account: String) -> Bool {
        ((try? load(account: account)) ?? nil)?.isEmpty == false
    }
}

enum CredentialAccount {
    static let bailianAPIKey = "bailian_api_key"
    static let deepseekASRAPIKey = "deepseek_asr_api_key"
    static let deepseekWebSearchAPIKey = "deepseek_web_search_api_key"
    static func llmProfile(_ id: UUID) -> String { "llm_profile_\(id.uuidString)" }
}

/// Stores sensitive API credentials exclusively in the macOS Keychain.
final class CredentialStore: CredentialStoring, Sendable {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.opentype.OpenType") {
        self.service = service
    }

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw CredentialStoreError.unexpectedStatus(addStatus) }
    }

    func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.unexpectedStatus(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidData
        }
        return value
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }
}

/// In-memory store used by tests and previews. Never touches the Keychain.
final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func save(_ value: String, account: String) throws { lock.withLock { values[account] = value } }
    func load(account: String) throws -> String? { lock.withLock { values[account] } }
    func delete(account: String) throws { lock.withLock { values[account] = nil } }
}
