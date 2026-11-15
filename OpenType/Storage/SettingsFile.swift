import Foundation

/// A value read back from a `SettingsBacking`: never written, explicitly cleared (`nil` stored on purpose), or present.
enum StoredValue<T> {
    case absent
    case cleared
    case value(T)

    var value: T? {
        if case .value(let value) = self { return value }
        return nil
    }
}

/// Key-value storage behind `SettingsStore`. `UserDefaults` backs it in tests; the app uses `SettingsFile`.
protocol SettingsBacking: AnyObject {
    func object(forKey key: String) -> Any?
    func string(forKey key: String) -> String?
    func dictionary(forKey key: String) -> [String: Any]?
    func date(forKey key: String) -> Date?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> StoredValue<T>
    /// `nil` stores an explicit "cleared" marker (as opposed to never having been set).
    func setCodable<T: Encodable>(_ value: T?, forKey key: String)
}

extension UserDefaults: SettingsBacking {
    func date(forKey key: String) -> Date? { object(forKey: key) as? Date }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> StoredValue<T> {
        guard let data = self.data(forKey: key) else { return .absent }
        if data.isEmpty { return .cleared }
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { return .absent }
        return .value(decoded)
    }

    func setCodable<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else { return set(Data(), forKey: key) }
        if let data = try? JSONEncoder().encode(value) { set(data, forKey: key) }
    }
}

/// Settings as one readable JSON object in `~/.opentype/settings.json`, so development and release builds (and a
/// backup or a second Mac) share them. Every write re-reads the file first and changes only its own key, so two
/// running builds do not overwrite each other's unrelated settings.
final class SettingsFile: SettingsBacking, @unchecked Sendable {
    private static let keyPrefix = "opentype."

    private let fileURL: URL
    private let lock = NSLock()
    private var values: [String: Any]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.values = Self.read(fileURL) ?? [:]
    }

    /// The app's file. When it does not exist yet, the settings older versions kept in `UserDefaults` move over once.
    static func makeDefault(legacyDefaults: UserDefaults = .standard) -> SettingsFile {
        let url = UserDataStorage.url(for: "settings.json")
        if !FileManager.default.fileExists(atPath: url.path) {
            let domain = Bundle.main.bundleIdentifier ?? ""
            let legacy = legacyDefaults.persistentDomain(forName: domain) ?? [:]
            let migrated = migrate(legacy)
            if !migrated.isEmpty { write(migrated, to: url) }
        }
        return SettingsFile(fileURL: url)
    }

    // MARK: Reading

    func object(forKey key: String) -> Any? {
        lock.withLock {
            let value = values[Self.fileKey(key)]
            return value is NSNull ? nil : value
        }
    }

    func string(forKey key: String) -> String? { object(forKey: key) as? String }

    func dictionary(forKey key: String) -> [String: Any]? { object(forKey: key) as? [String: Any] }

    func date(forKey key: String) -> Date? {
        guard let string = string(forKey: key) else { return nil }
        return Self.dateFormatter.date(from: string)
    }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> StoredValue<T> {
        let stored = lock.withLock { values[Self.fileKey(key)] }
        guard let stored else { return .absent }
        if stored is NSNull { return .cleared }
        guard let data = try? JSONSerialization.data(withJSONObject: stored, options: [.fragmentsAllowed]),
              let decoded = try? JSONDecoder().decode(T.self, from: data)
        else { return .absent }
        return .value(decoded)
    }

    // MARK: Writing

    func set(_ value: Any?, forKey key: String) {
        guard let value else { return removeObject(forKey: key) }
        if let date = value as? Date {
            store(Self.dateFormatter.string(from: date), forKey: key)
        } else if value is NSNull || value is String || value is Bool || value is Int || value is Double
                    || (value is [String: Any] && JSONSerialization.isValidJSONObject(value)) {
            store(value, forKey: key)
        }
    }

    func removeObject(forKey key: String) {
        store(nil, forKey: key)
    }

    func setCodable<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else { return store(NSNull(), forKey: key) }
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return }
        store(object, forKey: key)
    }

    private func store(_ value: Any?, forKey key: String) {
        lock.withLock {
            var current = Self.read(fileURL) ?? values // fresh from disk: another build may have changed other keys
            if let value { current[Self.fileKey(key)] = value } else { current.removeValue(forKey: Self.fileKey(key)) }
            values = current
            Self.write(current, to: fileURL)
        }
    }

    // MARK: Helpers

    private static func fileKey(_ key: String) -> String {
        key.hasPrefix(keyPrefix) ? String(key.dropFirst(keyPrefix.count)) : key
    }

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = { // read-only after creation
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func read(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func write(_ values: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: values, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? data.write(to: url, options: .atomic)
    }

    /// `UserDefaults` entries of this app → the JSON shape: `Data` blobs (hotkeys, profiles) become real JSON, an empty
    /// blob the "cleared" marker, dates ISO 8601 strings.
    static func migrate(_ legacy: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in legacy where key.hasPrefix(keyPrefix) {
            let name = fileKey(key)
            switch value {
            case let data as Data:
                if data.isEmpty {
                    result[name] = NSNull()
                } else if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                    result[name] = object
                }
            case let date as Date:
                result[name] = dateFormatter.string(from: date)
            case is String, is Bool, is Int, is Double, is NSNumber:
                result[name] = value
            case let dictionary as [String: Any] where JSONSerialization.isValidJSONObject(dictionary):
                result[name] = dictionary
            default:
                break
            }
        }
        return result
    }
}
