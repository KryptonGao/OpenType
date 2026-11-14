import Foundation

/// One dictionary word: how it should be written, plus how speech recognition tends to get it wrong.
struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    /// The correct spelling, e.g. "OpenAI".
    var term: String
    /// Spoken forms / frequent mis-recognitions, e.g. "open ai", "欧朋". Used to spot the word in a transcript.
    var aliases: [String] = []
    /// Replace the term and its aliases in the recognised text deterministically (before the LLM sees it).
    /// Only safe for unambiguous spellings, so built-in entries default to `false`; custom entries default to `true`.
    var autoReplace = false

    init(id: UUID = UUID(), term: String, aliases: [String] = [], autoReplace: Bool = false) {
        self.id = id
        self.term = term
        self.aliases = aliases
        self.autoReplace = autoReplace
    }

    private enum CodingKeys: String, CodingKey { case id, term, aliases, autoReplace }

    /// Built-in packs write a plain word as a bare string and a word with extras as an object.
    init(from decoder: Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode(String.self) {
            self.init(term: bare)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            term: try container.decode(String.self, forKey: .term),
            aliases: try container.decodeIfPresent([String].self, forKey: .aliases) ?? [],
            autoReplace: try container.decodeIfPresent(Bool.self, forKey: .autoReplace) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(term, forKey: .term)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(autoReplace, forKey: .autoReplace)
    }
}

/// A built-in, switchable group of entries (bundled as `dict-<id>.json`).
struct DictionaryPack: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var entries: [DictionaryEntry]

    /// Display order of the built-in packs; unknown packs are appended alphabetically.
    static let order = ["coding", "git", "swift", "python", "js-ts", "shell", "sql", "html-css", "ai-concepts", "ai-vendors"]

    var displayName: String {
        switch id {
        case "coding": String(localized: "编程通用")
        case "git": "Git"
        case "swift": "Swift"
        case "python": "Python"
        case "js-ts": "JavaScript / TypeScript"
        case "shell": "Shell"
        case "sql": "SQL"
        case "html-css": "HTML / CSS"
        case "ai-concepts": String(localized: "AI 概念")
        case "ai-vendors": String(localized: "AI 厂商与产品")
        default: id
        }
    }

    var symbolName: String {
        switch id {
        case "coding": "chevron.left.forwardslash.chevron.right"
        case "git": "arrow.triangle.branch"
        case "swift", "python", "js-ts", "html-css": "curlybraces"
        case "shell": "terminal"
        case "sql": "cylinder.split.1x2"
        case "ai-concepts": "brain"
        case "ai-vendors": "building.2"
        default: "character.book.closed"
        }
    }
}

enum BuiltInDictionary {
    static let filePrefix = "dict-"

    /// Loads every bundled `dict-*.json` pack, in `DictionaryPack.order`. Unreadable files are skipped.
    static func load(bundle: Bundle = .main) -> [DictionaryPack] {
        // Look both in a "Dictionary" folder and at the bundle root (synchronized groups may flatten folders).
        var urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Dictionary") ?? []
        urls += bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        var seen = Set<String>()
        var packs: [DictionaryPack] = []
        for url in urls where url.lastPathComponent.hasPrefix(filePrefix) {
            guard let data = try? Data(contentsOf: url),
                  let pack = try? decoder.decode(DictionaryPack.self, from: data),
                  seen.insert(pack.id).inserted else { continue }
            packs.append(pack)
        }
        return packs.sorted { lhs, rhs in
            let l = DictionaryPack.order.firstIndex(of: lhs.id) ?? Int.max
            let r = DictionaryPack.order.firstIndex(of: rhs.id) ?? Int.max
            return l == r ? lhs.id < rhs.id : l < r
        }
    }
}
