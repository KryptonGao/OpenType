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

/// Stores API credentials as plain JSON in `~/.opentype/credentials.json` (a flat `{account: value}` object).
///
/// Deliberately not the Keychain: Keychain ACLs are bound to the code signature, so every upgrade
/// re-prompted for the login password. The directory is created `0700` and the file `0600`.
final class CredentialStore: CredentialStoring, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".opentype", isDirectory: true)
    }

    /// The store the app uses: the default file, after moving over anything older versions left in the Keychain.
    static func makeDefault() -> CredentialStore {
        let store = CredentialStore()
        store.migrateLegacyKeychainItems()
        return store
    }

    init(directory: URL = CredentialStore.defaultDirectory) {
        self.fileURL = directory.appendingPathComponent("credentials.json")
    }

    func save(_ value: String, account: String) throws {
        try lock.withLock {
            var values = try readAll()
            values[account] = value
            try writeAll(values)
        }
    }

    func load(account: String) throws -> String? {
        try lock.withLock { try readAll()[account] }
    }

    func delete(account: String) throws {
        try lock.withLock {
            var values = try readAll()
            guard values.removeValue(forKey: account) != nil else { return }
            try writeAll(values)
        }
    }

    private func readAll() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let values = try? JSONDecoder().decode([String: String].self, from: data) else {
            throw CredentialStoreError.invalidData
        }
        return values
    }

    private func writeAll(_ values: [String: String]) throws {
        let fm = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(values)
        try data.write(to: fileURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// One-time move of credentials left in the Keychain by earlier versions into the JSON file.
    /// Listing item attributes needs no password; only when legacy items exist is their data read
    /// (which may prompt once) before they are removed. Existing file entries are never overwritten.
    func migrateLegacyKeychainItems(service: String = Bundle.main.bundleIdentifier ?? "com.opentype.OpenType") {
        let listQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(listQuery as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return }
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String else { continue }
            let itemQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            var dataRef: CFTypeRef?
            var readQuery = itemQuery
            readQuery[kSecReturnData as String] = true
            readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
            guard SecItemCopyMatching(readQuery as CFDictionary, &dataRef) == errSecSuccess,
                  let data = dataRef as? Data, let value = String(data: data, encoding: .utf8) else { continue }
            if ((try? load(account: account)) ?? nil) == nil {
                guard (try? save(value, account: account)) != nil else { continue }
            }
            SecItemDelete(itemQuery as CFDictionary)
        }
    }
}

/// In-memory store used by tests and previews. Never touches the disk.
final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func save(_ value: String, account: String) throws { lock.withLock { values[account] = value } }
    func load(account: String) throws -> String? { lock.withLock { values[account] } }
    func delete(account: String) throws { lock.withLock { values[account] = nil } }
}
