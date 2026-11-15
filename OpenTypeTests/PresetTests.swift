import Foundation
import Testing
@testable import OpenType

// MARK: - Deterministic text helpers

struct PunctuationFormatterTests {
    @Test func stripTrailingPeriodRemovesOnlyTheFinalStop() {
        #expect(PunctuationFormatter.stripTrailingPeriod("好的。") == "好的")
        #expect(PunctuationFormatter.stripTrailingPeriod("Sounds good.") == "Sounds good")
        #expect(PunctuationFormatter.stripTrailingPeriod("第一句。第二句。\n") == "第一句。第二句\n")
        #expect(PunctuationFormatter.stripTrailingPeriod("等一下...") == "等一下...")
        #expect(PunctuationFormatter.stripTrailingPeriod("真的吗？") == "真的吗？")
        #expect(PunctuationFormatter.stripTrailingPeriod("") == "")
    }

    @Test func presetFormattingOnlyAppliesToCleanupPresets() {
        let cleanup = PromptPreset(id: "a", symbolName: "x", kind: .cleanup, stripTrailingPeriod: true)
        #expect(cleanup.formatted("你好，world。") == "你好，world")
        let email = PromptPreset(id: "b", symbolName: "x", kind: .helpMeSay, stripTrailingPeriod: true)
        #expect(email.formatted("你好，world。") == "你好，world。")
    }
}

struct ShellCommandSanitizerTests {
    @Test func plainCommandIsKept() {
        #expect(ShellCommandSanitizer.sanitize("ls -la ~/Downloads") == "ls -la ~/Downloads")
    }

    @Test func stripsFencePromptAndBackticks() {
        #expect(ShellCommandSanitizer.sanitize("```bash\n$ git status\n```") == "git status")
        #expect(ShellCommandSanitizer.sanitize("`brew update`") == "brew update")
    }

    @Test func neverReturnsLineBreaks() {
        let joined = ShellCommandSanitizer.sanitize("cd ~/proj\nnpm install\r\nnpm test\n")
        #expect(joined == "cd ~/proj && npm install && npm test")
        #expect(!joined.contains("\n") && !joined.contains("\r"))
    }

    @Test func backslashContinuationsAreJoinedWithASpace() {
        #expect(ShellCommandSanitizer.sanitize("docker run \\\n  -p 80:80 nginx") == "docker run -p 80:80 nginx")
    }

    @Test func commentLinesAreDroppedFromMultiLineAnswers() {
        #expect(ShellCommandSanitizer.sanitize("# list files\nls") == "ls")
    }

    @Test func emptyAnswerStaysEmpty() {
        #expect(ShellCommandSanitizer.sanitize(" \n```\n``` \n") == "")
    }
}

// MARK: - Store

@MainActor
struct PresetStoreTests {
    /// A store whose rules the test chose itself; a fresh store has none.
    private func store(rules: [String: String] = [:]) -> PresetStore {
        let store = PresetStore()
        for (bundleID, presetID) in rules { store.setRule(bundleID: bundleID, appName: bundleID, presetID: presetID) }
        return store
    }

    @Test func freshStoreHasBuiltInPresetsAndNoAppRules() {
        let store = PresetStore()
        #expect(Set(store.presets.map(\.id)) == BuiltInPresets.ids)
        #expect(store.defaultPresetID == BuiltInPresets.general)
        #expect(store.rules.isEmpty)
        #expect(store.resolve(bundleID: "com.apple.Terminal").id == BuiltInPresets.general)
    }

    @Test func generalPresetKeepsTodaysBehaviour() {
        let general = PresetStore().defaultPreset
        #expect(general.kind == .cleanup)
        #expect(general.effectivePrompt == nil) // the active profile's prompt applies
        #expect(!general.stripTrailingPeriod && general.dictionaryPackIDs.isEmpty)
        #expect(general.formatted("你好，世界。") == "你好，世界。")
    }

    @Test func resolvePicksTheRuleOfTheFrontmostApp() {
        let store = store(rules: [
            "com.tinyspeck.slackmacgap": BuiltInPresets.casualChat, "com.apple.dt.Xcode": BuiltInPresets.codeTech
        ])
        #expect(store.resolve(bundleID: "com.tinyspeck.slackmacgap").id == BuiltInPresets.casualChat)
        #expect(store.resolve(bundleID: "com.apple.dt.Xcode").id == BuiltInPresets.codeTech)
        #expect(store.resolve(bundleID: "com.example.Unknown").id == BuiltInPresets.general)
        #expect(store.resolve(bundleID: nil).id == BuiltInPresets.general)
    }

    @Test func switchingOffAutoMatchFallsBackToTheDefaultPreset() {
        let store = store(rules: ["com.tinyspeck.slackmacgap": BuiltInPresets.casualChat])
        store.autoMatchEnabled = false
        #expect(store.resolve(bundleID: "com.tinyspeck.slackmacgap").id == BuiltInPresets.general)
        store.setDefaultPreset(BuiltInPresets.workEmail)
        #expect(store.resolve(bundleID: "com.tinyspeck.slackmacgap").id == BuiltInPresets.workEmail)
    }

    @Test func deletingAPresetRemovesItsRulesAndMovesTheDefault() {
        let store = store(rules: ["com.tinyspeck.slackmacgap": BuiltInPresets.casualChat])
        store.setDefaultPreset(BuiltInPresets.casualChat)
        store.delete(id: BuiltInPresets.casualChat)
        #expect(store.preset(id: BuiltInPresets.casualChat) == nil)
        #expect(store.rule(for: "com.tinyspeck.slackmacgap") == nil)
        #expect(store.preset(id: store.defaultPresetID) != nil)
    }

    @Test func theLastPresetCannotBeDeleted() {
        let store = PresetStore()
        for preset in store.presets { store.delete(id: preset.id) }
        #expect(store.presets.count == 1)
    }

    @Test func restoreBuiltInsAddsMissingOnesWithoutTouchingEdits() {
        let store = PresetStore()
        var edited = store.preset(id: BuiltInPresets.codeTech)!
        edited.stripTrailingPeriod = true
        store.update(edited)
        store.delete(id: BuiltInPresets.workEmail)
        store.restoreBuiltIns()
        #expect(store.preset(id: BuiltInPresets.workEmail) != nil)
        #expect(store.preset(id: BuiltInPresets.codeTech)?.stripTrailingPeriod == true)
    }

    @Test func removeAllRulesClearsEveryRule() {
        let store = store(rules: ["a.b": BuiltInPresets.codeTech, "c.d": BuiltInPresets.casualChat])
        store.removeAllRules()
        #expect(store.rules.isEmpty)
        #expect(store.resolve(bundleID: "a.b").id == BuiltInPresets.general)
    }

    @Test func setRuleAddsAndUpdatesButRejectsUnknownPresets() {
        let store = PresetStore()
        store.setRule(bundleID: "com.example.App", appName: "Example", presetID: BuiltInPresets.workEmail)
        #expect(store.resolve(bundleID: "com.example.App").id == BuiltInPresets.workEmail)
        store.setRule(bundleID: "com.example.App", appName: "Example", presetID: "nope")
        #expect(store.rule(for: "com.example.App")?.presetID == BuiltInPresets.workEmail)
        store.removeRule(bundleID: "com.example.App")
        #expect(store.rule(for: "com.example.App") == nil)
    }

    @Test func duplicateFreezesTheBuiltInPrompt() {
        let store = PresetStore()
        let copy = store.duplicate(BuiltInPresets.codeTech)!
        #expect(copy.id != BuiltInPresets.codeTech && !copy.isBuiltIn)
        #expect(copy.prompt == BuiltInPresets.codeTechPrompt)
        #expect(copy.dictionaryPackIDs == BuiltInPresets.codingPackIDs + ["ai-concepts", "ai-vendors"])
    }

    @Test func persistsAndReloads() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("presets-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PresetStore(fileURL: url)
        let custom = store.addPreset(kind: .shellCommand)
        store.setDefaultPreset(custom.id)
        store.setRule(bundleID: "com.example.App", appName: "Example", presetID: custom.id)
        store.autoMatchEnabled = false
        await store.flush()

        let reloaded = PresetStore(fileURL: url)
        #expect(reloaded.presets == store.presets)
        #expect(reloaded.rules == store.rules)
        #expect(reloaded.defaultPresetID == custom.id)
        #expect(reloaded.autoMatchEnabled == false)
    }

    @Test func unreadableFileFallsBackToBuiltIns() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("presets-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        #expect(Set(PresetStore(fileURL: url).presets.map(\.id)) == BuiltInPresets.ids)
    }

    @Test func presetsDecodeWhenNewerFieldsAreMissing() throws {
        let json = Data(#"{"id":"x","kind":"shellCommand"}"#.utf8)
        let preset = try JSONDecoder().decode(PromptPreset.self, from: json)
        #expect(preset.kind == .shellCommand && preset.prompt.isEmpty && preset.dictionaryPackIDs.isEmpty)
        #expect(preset.effectivePrompt == TextProcessor.defaultShellCommandPrompt)
    }
}

// MARK: - Dictionary packs requested by a preset

@MainActor
struct DictionaryExtraPackTests {
    private func store() -> DictionaryStore {
        let pack = DictionaryPack(id: "shell", entries: [DictionaryEntry(term: "grep", aliases: ["gap"], autoReplace: true)])
        let store = DictionaryStore(packs: [pack])
        store.setPack("shell", enabled: false)
        return store
    }

    @Test func disabledPackStaysOffUnlessAPresetAsksForIt() {
        let store = store()
        #expect(store.correct("run gap now") == "run gap now")
        #expect(store.correct("run gap now", extraPackIDs: ["shell"]) == "run grep now")
        #expect(store.addendum(for: "run gap now").isEmpty)
        #expect(store.addendum(for: "run gap now", extraPackIDs: ["shell"]).contains("grep"))
    }

    @Test func masterSwitchOffWinsOverPresets() {
        let store = store()
        store.isEnabled = false
        #expect(store.correct("run gap now", extraPackIDs: ["shell"]) == "run gap now")
    }
}
