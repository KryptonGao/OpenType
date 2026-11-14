import Foundation
import Observation

/// The user's prompt presets and per-app rules. Persists as one JSON file in Application Support; `fileURL == nil`
/// keeps everything in memory (tests). A fresh install (no file) starts with the built-in presets and no app rules: the user adds the apps.
@MainActor
@Observable
final class PresetStore {
    private struct Snapshot: Codable {
        var presets: [PromptPreset]
        var rules: [AppRule]
        var defaultPresetID: String
        var autoMatchEnabled: Bool

        init(presets: [PromptPreset], rules: [AppRule], defaultPresetID: String, autoMatchEnabled: Bool) {
            self.presets = presets
            self.rules = rules
            self.defaultPresetID = defaultPresetID
            self.autoMatchEnabled = autoMatchEnabled
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            presets = try c.decodeIfPresent([PromptPreset].self, forKey: .presets) ?? BuiltInPresets.all
            rules = try c.decodeIfPresent([AppRule].self, forKey: .rules) ?? []
            defaultPresetID = try c.decodeIfPresent(String.self, forKey: .defaultPresetID) ?? BuiltInPresets.general
            autoMatchEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoMatchEnabled) ?? true
        }
    }

    private(set) var presets: [PromptPreset]
    private(set) var rules: [AppRule]
    /// Used when no app rule matches (or matching is off). Also what the menu bar switches.
    private(set) var defaultPresetID: String
    /// Master switch for per-app rules.
    var autoMatchEnabled: Bool {
        didSet { if autoMatchEnabled != oldValue { save() } }
    }

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var lastSave: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        var snapshot = Snapshot(
            presets: BuiltInPresets.all, rules: [],
            defaultPresetID: BuiltInPresets.general, autoMatchEnabled: true
        )
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data), !decoded.presets.isEmpty {
            snapshot = decoded
        }
        self.fileURL = fileURL
        self.presets = snapshot.presets
        self.rules = snapshot.rules
        self.autoMatchEnabled = snapshot.autoMatchEnabled
        self.defaultPresetID = snapshot.presets.contains { $0.id == snapshot.defaultPresetID }
            ? snapshot.defaultPresetID : snapshot.presets[0].id
    }

    static var defaultFileURL: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return base.appendingPathComponent("OpenType", isDirectory: true).appendingPathComponent("presets.json")
    }

    // MARK: Lookup

    func preset(id: String?) -> PromptPreset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    var defaultPreset: PromptPreset { preset(id: defaultPresetID) ?? presets[0] }

    func rule(for bundleID: String?) -> AppRule? {
        guard let bundleID else { return nil }
        return rules.first { $0.bundleID == bundleID }
    }

    /// The preset for a session that started in the app with `bundleID`: its rule's preset when matching is on and the
    /// rule points at an existing preset, otherwise the default preset.
    func resolve(bundleID: String?) -> PromptPreset {
        if autoMatchEnabled, let rule = rule(for: bundleID), let matched = preset(id: rule.presetID) { return matched }
        return defaultPreset
    }

    // MARK: Presets

    func setDefaultPreset(_ id: String) {
        guard preset(id: id) != nil, id != defaultPresetID else { return }
        defaultPresetID = id
        save()
    }

    @discardableResult
    func addPreset(kind: PresetKind = .cleanup) -> PromptPreset {
        let preset = PromptPreset(
            id: UUID().uuidString, name: String(localized: "新预设"), symbolName: kind.defaultSymbolName, kind: kind
        )
        presets.append(preset)
        save()
        return preset
    }

    @discardableResult
    func duplicate(_ id: String) -> PromptPreset? {
        guard var copy = preset(id: id) else { return nil }
        let effective = copy.effectivePrompt // resolved before the id changes: built-in wording is keyed by id
        copy.name = String(localized: "\(copy.displayName) 副本")
        copy.id = UUID().uuidString
        if copy.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let effective {
            copy.prompt = effective // a copy no longer follows the built-in wording
        }
        presets.append(copy)
        save()
        return copy
    }

    func update(_ preset: PromptPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }

    /// Deletes a preset together with the rules that pointed at it. The last preset cannot be deleted.
    func delete(id: String) {
        guard presets.count > 1, let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets.remove(at: index)
        rules.removeAll { $0.presetID == id }
        if defaultPresetID == id { defaultPresetID = presets[0].id }
        save()
    }

    /// Adds back built-in presets that were deleted. Edited presets are untouched.
    func restoreBuiltIns() {
        for builtIn in BuiltInPresets.all where !presets.contains(where: { $0.id == builtIn.id }) {
            presets.append(builtIn)
        }
        save()
    }

    // MARK: Rules

    /// Adds or changes the rule of an app.
    func setRule(bundleID: String, appName: String, presetID: String) {
        guard preset(id: presetID) != nil, !bundleID.isEmpty else { return }
        if let index = rules.firstIndex(where: { $0.bundleID == bundleID }) {
            rules[index].presetID = presetID
            if !appName.isEmpty { rules[index].appName = appName }
        } else {
            rules.append(AppRule(bundleID: bundleID, appName: appName.isEmpty ? bundleID : appName, presetID: presetID))
        }
        save()
    }

    func removeAllRules() {
        guard !rules.isEmpty else { return }
        rules.removeAll()
        save()
    }

    func removeRule(bundleID: String) {
        rules.removeAll { $0.bundleID == bundleID }
        save()
    }

    // MARK: Persistence

    private func save() {
        guard let fileURL else { return }
        let snapshot = Snapshot(presets: presets, rules: rules, defaultPresetID: defaultPresetID, autoMatchEnabled: autoMatchEnabled)
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
