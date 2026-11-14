import Foundation
import Testing
@testable import OpenType

// MARK: - Matching and replacement

struct DictionaryMatcherTests {
    private func matcher(_ entries: [DictionaryEntry]) -> DictionaryMatcher { DictionaryMatcher(entries: entries) }

    @Test func autoReplaceIsCaseInsensitiveAndKeepsTheCorrectSpelling() {
        let m = matcher([DictionaryEntry(term: "GitHub", aliases: ["get hub"], autoReplace: true)])
        #expect(m.correct("push to github and Get Hub") == "push to GitHub and GitHub")
    }

    @Test func spacesAndHyphensInAliasesAreInterchangeable() {
        let m = matcher([DictionaryEntry(term: "OpenAI", aliases: ["open ai"], autoReplace: true)])
        #expect(m.correct("open ai, open-ai, openai, Open  AI") == "OpenAI, OpenAI, OpenAI, OpenAI")
    }

    @Test func asciiAliasesMustStandAlone() {
        let m = matcher([DictionaryEntry(term: "Go", aliases: ["go lang"], autoReplace: true)])
        #expect(m.correct("good gopher, going") == "good gopher, going")
        #expect(m.correct("write go lang code") == "write Go code")
    }

    @Test func entriesWithoutAutoReplaceNeverChangeText() {
        let m = matcher([DictionaryEntry(term: "Kubernetes", aliases: ["k8s"], autoReplace: false)])
        #expect(m.correct("deploy to k8s") == "deploy to k8s")
    }

    @Test func nonAsciiAliasesAreReplacedAsPlainText() {
        let m = matcher([DictionaryEntry(term: "OpenAI", aliases: ["欧朋艾"], autoReplace: true)])
        #expect(m.correct("我用欧朋艾的模型") == "我用OpenAI的模型")
    }

    @Test func overlappingMatchesPreferTheLongestAndNeverChain() {
        let m = matcher([
            DictionaryEntry(term: "GitHub", aliases: ["git hub"], autoReplace: true),
            DictionaryEntry(term: "Git", aliases: ["gith"], autoReplace: true),
            DictionaryEntry(term: "GitHub Actions", aliases: ["git hub actions"], autoReplace: true)
        ])
        #expect(m.correct("use git hub actions") == "use GitHub Actions")
    }

    @Test func symbolsInTermsAreKept() {
        let m = matcher([DictionaryEntry(term: "C++", aliases: ["c plus plus"], autoReplace: true)])
        #expect(m.correct("I write c plus plus daily and C++ too") == "I write C++ daily and C++ too")
    }

    @Test func replacementTextIsNotTreatedAsARegexTemplate() {
        let m = matcher([DictionaryEntry(term: "$PATH", aliases: ["dollar path"], autoReplace: true)])
        #expect(m.correct("edit dollar path now") == "edit $PATH now")
    }

    @Test func hintsFindTermsAliasesAndSpacedSpellings() {
        let m = matcher([
            DictionaryEntry(term: "SwiftUI"),
            DictionaryEntry(term: "cherry-pick", aliases: ["樱桃pick"]),
            DictionaryEntry(term: "DeepSeek", aliases: ["deep seek"]),
            DictionaryEntry(term: "Kubernetes", aliases: ["k8s"])
        ])
        let found = m.hints(for: "我想 swift ui 里 cherry pick 一下，再用 deep seek 看看").map(\.term)
        #expect(found == ["SwiftUI", "cherry-pick", "DeepSeek"])
        #expect(m.hints(for: "把樱桃pick 的结果发给我").map(\.term) == ["cherry-pick"])
    }

    @Test func hintsDoNotMatchInsideOtherWords() {
        let m = matcher([DictionaryEntry(term: "Go"), DictionaryEntry(term: "sed")])
        #expect(m.hints(for: "that was a good used case").isEmpty)
    }

    @Test func hintsAreCapped() {
        let entries = (0..<100).map { DictionaryEntry(term: "term\($0)") }
        let transcript = (0..<100).map { "term\($0)" }.joined(separator: " ")
        #expect(matcher(entries).hints(for: transcript).count == DictionaryMatcher.maxHints)
    }

    @Test func emptyDictionaryChangesNothing() {
        let m = matcher([])
        #expect(m.correct("anything") == "anything")
        #expect(m.hints(for: "anything").isEmpty)
    }
}

// MARK: - Prompt addendum

struct DictionaryAddendumTests {
    @Test func emptyWhenNoEntries() {
        #expect(TextProcessor.dictionaryAddendum(entries: []).isEmpty)
    }

    @Test func listsTermsWithTheirMishearings() {
        let text = TextProcessor.dictionaryAddendum(entries: [
            DictionaryEntry(term: "OpenAI", aliases: ["open ai", "欧朋"]),
            DictionaryEntry(term: "SwiftUI")
        ])
        #expect(text.contains("- OpenAI（常被识别成：open ai、欧朋）"))
        #expect(text.contains("- SwiftUI"))
    }
}

// MARK: - Store

@MainActor
struct DictionaryStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("dictionary-\(UUID().uuidString).json")
    }

    private let pack = DictionaryPack(id: "test", entries: [DictionaryEntry(term: "OpenAI", aliases: ["open ai"], autoReplace: true)])

    @Test func customEntriesCanBeAddedEditedAndDeleted() throws {
        let store = DictionaryStore(packs: [])
        let entry = try #require(store.addCustom(term: "  GitHub ", aliases: ["get hub", "", "GITHUB"]))
        #expect(entry.term == "GitHub")
        #expect(entry.aliases == ["get hub"]) // blank and same-as-term aliases are dropped
        #expect(store.correct("push to get hub") == "push to GitHub")

        store.updateCustom(id: entry.id, term: "GitLab", aliases: ["git lab"], autoReplace: true)
        #expect(store.customEntries.map(\.term) == ["GitLab"])
        #expect(store.correct("get hub") == "get hub")

        store.deleteCustom(ids: [entry.id])
        #expect(store.customEntries.isEmpty)
        #expect(store.addCustom(term: "   ", aliases: []) == nil)
    }

    @Test func packsAndTheMasterSwitchControlWhatIsActive() {
        let store = DictionaryStore(packs: [pack])
        #expect(store.correct("open ai") == "OpenAI")
        store.setPack("test", enabled: false)
        #expect(store.correct("open ai") == "open ai")
        #expect(store.addendum(for: "open ai").isEmpty)
        store.setPack("test", enabled: true)
        #expect(store.addendum(for: "open ai").contains("OpenAI"))
        store.isEnabled = false
        #expect(store.activeEntryCount == 0)
        #expect(store.correct("open ai") == "open ai")
    }

    @Test func settingsAndCustomEntriesSurviveARestart() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictionaryStore(fileURL: url, packs: [pack])
        store.addCustom(term: "DeepSeek", aliases: ["deep seek"])
        store.setPack("test", enabled: false)
        store.isEnabled = true
        await store.flush()

        let reloaded = DictionaryStore(fileURL: url, packs: [pack])
        #expect(reloaded.customEntries.map(\.term) == ["DeepSeek"])
        #expect(reloaded.customEntries.first?.autoReplace == true)
        #expect(!reloaded.isPackEnabled("test"))
        #expect(reloaded.correct("deep seek") == "DeepSeek")
    }

    @Test func aFileMissingFieldsStillLoads() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"customEntries":[{"term":"Foo"}]}"#.utf8).write(to: url)
        let store = DictionaryStore(fileURL: url, packs: [])
        #expect(store.isEnabled)
        #expect(store.customEntries.map(\.term) == ["Foo"])
        #expect(store.customEntries.first?.autoReplace == false)
    }

    @Test func aliasInputIsSplitOnCommonSeparators() {
        #expect(DictionaryStore.parseAliases("gee hub、吉特哈布, Git Hub；gee hub\n x ") == ["gee hub", "吉特哈布", "Git Hub", "x"])
    }
}

// MARK: - Built-in packs

struct BuiltInDictionaryTests {
    private let packs = BuiltInDictionary.load(bundle: Bundle(for: DictionaryStore.self))

    @Test func allTenPacksLoadInOrder() {
        #expect(packs.map(\.id) == DictionaryPack.order)
    }

    @Test func entriesAreWellFormedAndUniquePerPack() {
        for pack in packs {
            #expect(!pack.entries.isEmpty, "\(pack.id) is empty")
            var seen = Set<String>()
            for entry in pack.entries {
                #expect(!entry.term.trimmingCharacters(in: .whitespaces).isEmpty, "empty term in \(pack.id)")
                #expect(seen.insert(entry.term).inserted, "duplicate \(entry.term) in \(pack.id)")
                #expect(!entry.aliases.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }, "blank alias for \(entry.term)")
            }
        }
    }

    @Test func requestedTermsAreCovered() {
        let all = Set(packs.flatMap(\.entries).map { $0.term.lowercased() })
        for term in ["agent harness", "deepseek", "openai", "anthropic", "cherry-pick", "rebase", "guard let", "git", "claude code"] {
            #expect(all.contains(term), "missing \(term)")
        }
    }

    @Test func builtInSpellingsAreRecognisedEndToEnd() async {
        let store = await MainActor.run { DictionaryStore(packs: packs) }
        let fixed = await store.correct("I use open ai and deep seek with get hub")
        #expect(fixed == "I use OpenAI and DeepSeek with GitHub")
        let note = await store.addendum(for: "agent harness 和 cherry pick")
        #expect(note.contains("- Agent Harness"))
        #expect(note.contains("- cherry-pick"))
    }
}
