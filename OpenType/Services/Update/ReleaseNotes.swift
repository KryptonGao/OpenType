import Foundation

/// Release notes shown in the update window: the notes file matching the UI language is fetched from the repository
/// (the GitHub Release itself only carries the English file), then trimmed down to the "what's new" part.
enum ReleaseNotes {
    /// The notes file for a UI language code (`zh-Hans`, `zh-Hant`, `ja`, `ko`, anything else → English).
    static func fileName(forLanguage code: String) -> String {
        let code = code.lowercased()
        if code.hasPrefix("zh") {
            let traditional = code.contains("hant") || code.hasSuffix("-tw") || code.hasSuffix("-hk") || code.hasSuffix("-mo")
            return traditional ? "release-notes.zh-Hant.md" : "release-notes.zh-Hans.md"
        }
        if code.hasPrefix("ja") { return "release-notes.ja.md" }
        if code.hasPrefix("ko") { return "release-notes.ko.md" }
        return "release-notes.md"
    }

    /// The language the running app's UI uses (honours the language picked in Settings).
    static var currentLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }

    static func url(for release: ReleaseInfo, language: String, repository: String = AppUpdater.repository) -> URL? {
        URL(string: "https://raw.githubusercontent.com/\(repository)/\(release.tag)/release-notes/\(release.version)/\(fileName(forLanguage: language))")
    }

    /// Notes to display for `release`: the localized file when it can be fetched, otherwise the Release body.
    static func load(for release: ReleaseInfo, language: String = currentLanguage) async -> String {
        if fileName(forLanguage: language) != "release-notes.md",
           let url = url(for: release, language: language),
           let text = await fetch(url) {
            return clean(text)
        }
        return clean(release.notes)
    }

    private static func fetch(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("OpenType-Updater", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return text
    }

    /// Drops what an update window does not need: the language-switcher line, the `# OpenType x.y.z` title, and every
    /// section after the first `##` one (requirements, install steps, download table).
    static func clean(_ markdown: String) -> String {
        var kept: [String] = []
        var inFence = false
        var sections = 0
        var droppedTitle = false
        for line in markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if line.hasPrefix("```") { inFence.toggle() }
            if !inFence {
                if line.contains("](https://") && line.contains(" · ") && line.hasPrefix("[") { continue }
                if !droppedTitle, line.hasPrefix("# ") { droppedTitle = true; continue }
                if line.hasPrefix("## ") {
                    sections += 1
                    if sections > 1 { break }
                }
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
