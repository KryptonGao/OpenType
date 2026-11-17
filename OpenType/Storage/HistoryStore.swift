import Foundation
import Observation

/// LLM token counts for one request (or a sum of them).
struct TokenUsage: Codable, Equatable, Sendable {
    var inputTokens = 0
    var outputTokens = 0

    static let zero = TokenUsage()

    var total: Int { inputTokens + outputTokens }
    var isEmpty: Bool { total == 0 }

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(inputTokens: lhs.inputTokens + rhs.inputTokens, outputTokens: lhs.outputTokens + rhs.outputTokens)
    }

    static func += (lhs: inout TokenUsage, rhs: TokenUsage) { lhs = lhs + rhs }
}

enum SessionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case dictation
    case translation
    case helpMeSay
    case rewrite
    case writingTools
    case screenAsk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation: String(localized: "听写")
        case .translation: String(localized: "翻译")
        case .helpMeSay: String(localized: "帮我说")
        case .rewrite: String(localized: "改写")
        case .writingTools: String(localized: "书写工具")
        case .screenAsk: String(localized: "屏幕提问")
        }
    }

    var symbolName: String {
        switch self {
        case .dictation: "mic"
        case .translation: "character.bubble"
        case .helpMeSay: "wand.and.stars"
        case .rewrite: "pencil.and.outline"
        case .writingTools: "square.and.pencil"
        case .screenAsk: "viewfinder"
        }
    }
}

/// One finished dictation session. Counters are always kept (they feed the home page statistics);
/// `rawText` / `finalText` are only filled in while "save history text" is on.
struct SessionRecord: Codable, Identifiable, Equatable, Sendable {
    enum Delivery: String, Codable, Sendable {
        case inserted
        case manualCopy
        /// Shown in a panel only (Screen Ask): nothing was inserted or copied.
        case displayed
    }

    var id = UUID()
    var date: Date
    var kind: SessionKind
    var rawText: String?
    var finalText: String?
    /// Length of the final text: CJK characters + Latin words (see `TextMetrics`).
    var wordCount: Int
    var recordingSeconds: Double
    var usage: TokenUsage
    /// LLM model that produced the final text (nil when the LLM was skipped).
    var model: String?
    /// Translation target, e.g. "English".
    var translationLabel: String?
    var delivery: Delivery
}

enum TextMetrics {
    /// CJK / kana / hangul characters count one each, runs of other letters or digits count as one word.
    static func wordCount(_ text: String) -> Int {
        var count = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            if isIdeographic(scalar) {
                count += 1
                inWord = false
            } else if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                if !inWord { count += 1 }
                inWord = true
            } else {
                inWord = false
            }
        }
        return count
    }

    static func isIdeographic(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, // hiragana, katakana
             0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, // CJK ideographs
             0x20000...0x2FA1F, // CJK extensions
             0xAC00...0xD7AF: // hangul syllables
            true
        default:
            false
        }
    }
}

/// Local store for the history page and the home statistics. Persisted as one JSON file, `~/.opentype/history.json`;
/// `fileURL == nil` keeps everything in memory (tests).
@MainActor
@Observable
final class HistoryStore {
    static let maxRecords = 5000

    private(set) var records: [SessionRecord] = []   // newest first

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var lastSave: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            let decoder = Self.makeDecoder()
            records = ((try? decoder.decode([SessionRecord].self, from: data)) ?? []).sorted { $0.date > $1.date }
        }
    }

    static var defaultFileURL: URL? { UserDataStorage.url(for: "history.json") }

    func add(_ record: SessionRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords { records.removeLast(records.count - Self.maxRecords) }
        save()
    }

    func delete(ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        save()
    }

    /// Removes the saved texts but keeps the counters, so statistics survive.
    func clearTexts() {
        for index in records.indices {
            records[index].rawText = nil
            records[index].finalText = nil
        }
        save()
    }

    func clearAll() {
        records = []
        save()
    }

    private func save() {
        guard let fileURL else { return }
        let snapshot = records
        let encoder = Self.makeEncoder()
        let previous = lastSave
        // Chained so writes land in order.
        lastSave = Task.detached(priority: .utility) {
            await previous?.value
            guard let data = try? encoder.encode(snapshot) else { return }
            let directory = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
