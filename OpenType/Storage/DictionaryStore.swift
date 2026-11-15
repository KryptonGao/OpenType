import Foundation
import Observation

/// The user's dictionary: the built-in packs (individually switchable) plus custom entries.
/// Settings and custom entries persist as one JSON file, `~/.opentype/dictionary.json`; `fileURL == nil` keeps everything
/// in memory (tests).
@MainActor
@Observable
final class DictionaryStore {
    private struct Snapshot: Codable {
        var enabled = true
        var disabledPacks: [String] = []
        var customEntries: [DictionaryEntry] = []

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            disabledPacks = try container.decodeIfPresent([String].self, forKey: .disabledPacks) ?? []
            customEntries = try container.decodeIfPresent([DictionaryEntry].self, forKey: .customEntries) ?? []
        }
    }

    /// Master switch: off disables hints and replacements entirely.
    var isEnabled: Bool {
        didSet { if isEnabled != oldValue { changed() } }
    }
    let packs: [DictionaryPack]
    private(set) var disabledPackIDs: Set<String>
    private(set) var customEntries: [DictionaryEntry]

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var lastSave: Task<Void, Never>?
    @ObservationIgnored private var matcher: DictionaryMatcher

    init(fileURL: URL? = nil, packs: [DictionaryPack] = BuiltInDictionary.load()) {
        var snapshot = Snapshot()
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
        }
        self.fileURL = fileURL
        self.packs = packs
        self.isEnabled = snapshot.enabled
        self.disabledPackIDs = Set(snapshot.disabledPacks)
        self.customEntries = snapshot.customEntries
        self.matcher = DictionaryMatcher(entries: [])
        rebuildMatcher()
    }

    static var defaultFileURL: URL? { UserDataStorage.url(for: "dictionary.json") }

    // MARK: Packs

    func isPackEnabled(_ id: String) -> Bool { !disabledPackIDs.contains(id) }

    func setPack(_ id: String, enabled: Bool) {
        if enabled { disabledPackIDs.remove(id) } else { disabledPackIDs.insert(id) }
        changed()
    }

    /// Entries currently in effect: custom entries first (they win on equal terms), then the enabled packs.
    var activeEntries: [DictionaryEntry] {
        guard isEnabled else { return [] }
        return customEntries + packs.filter { isPackEnabled($0.id) }.flatMap(\.entries)
    }

    var activeEntryCount: Int { activeEntries.count }

    // MARK: Custom entries

    @discardableResult
    func addCustom(term: String, aliases: [String], autoReplace: Bool = true) -> DictionaryEntry? {
        guard let entry = Self.makeEntry(term: term, aliases: aliases, autoReplace: autoReplace) else { return nil }
        customEntries.insert(entry, at: 0)
        changed()
        return entry
    }

    func updateCustom(id: UUID, term: String, aliases: [String], autoReplace: Bool) {
        guard let index = customEntries.firstIndex(where: { $0.id == id }),
              let updated = Self.makeEntry(id: id, term: term, aliases: aliases, autoReplace: autoReplace) else { return }
        customEntries[index] = updated
        changed()
    }

    func deleteCustom(ids: Set<UUID>) {
        customEntries.removeAll { ids.contains($0.id) }
        changed()
    }

    /// Splits "a, b，c" style input into clean aliases.
    static func parseAliases(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: { ",，、;；\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func makeEntry(id: UUID = UUID(), term: String, aliases: [String], autoReplace: Bool) -> DictionaryEntry? {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return nil }
        let cleaned = aliases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(term) != .orderedSame }
        return DictionaryEntry(id: id, term: term, aliases: cleaned, autoReplace: autoReplace)
    }

    // MARK: Used by the dictation pipeline

    /// Deterministic replacement of the recognised text. `extraPackIDs` are packs that count as enabled for this call
    /// even when switched off (a preset can ask for them); they change nothing while the master switch is off.
    func correct(_ text: String, extraPackIDs: [String] = []) -> String {
        sessionMatcher(extraPackIDs: extraPackIDs).correct(text)
    }

    /// The prompt section listing the dictionary words the transcript mentions; empty when there are none,
    /// so prompts stay unchanged for text without dictionary words.
    func addendum(for transcript: String, extraPackIDs: [String] = []) -> String {
        TextProcessor.dictionaryAddendum(entries: sessionMatcher(extraPackIDs: extraPackIDs).hints(for: transcript))
    }

    /// The shared matcher, or one that also includes the requested packs that are currently switched off.
    private func sessionMatcher(extraPackIDs: [String]) -> DictionaryMatcher {
        guard isEnabled, !extraPackIDs.isEmpty else { return matcher }
        let extra = packs.filter { extraPackIDs.contains($0.id) && !isPackEnabled($0.id) }
        guard !extra.isEmpty else { return matcher }
        return DictionaryMatcher(entries: activeEntries + extra.flatMap(\.entries))
    }

    // MARK: Persistence

    private func changed() {
        rebuildMatcher()
        save()
    }

    private func rebuildMatcher() {
        matcher = DictionaryMatcher(entries: activeEntries)
    }

    private func save() {
        guard let fileURL else { return }
        var snapshot = Snapshot()
        snapshot.enabled = isEnabled
        snapshot.disabledPacks = disabledPackIDs.sorted()
        snapshot.customEntries = customEntries
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let previous = lastSave
        // Chained so writes land in order.
        lastSave = Task.detached(priority: .utility) { [snapshot] in
            await previous?.value
            guard let data = try? encoder.encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Waits for pending writes (tests).
    func flush() async { await lastSave?.value }
}
