import Foundation

/// Where the user's own data lives: `~/.opentype/` (outside the app bundle and any container, so development and
/// release builds share it). Older versions kept some files in Application Support; those are copied over once.
enum UserDataStorage {
    static var directory: URL { CredentialStore.defaultDirectory }

    /// `~/.opentype/<name>`. If it does not exist yet but `Application Support/OpenType/<name>` does, that file is
    /// copied in first (the old one stays).
    static func url(for name: String) -> URL {
        let url = directory.appendingPathComponent(name)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path),
              let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return url }
        let legacy = base.appendingPathComponent("OpenType", isDirectory: true).appendingPathComponent(name)
        if fm.fileExists(atPath: legacy.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try? fm.copyItem(at: legacy, to: url)
        }
        return url
    }
}
