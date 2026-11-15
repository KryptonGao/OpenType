import Foundation

/// One action of the Writing Tools panel.
enum WritingTool: String, CaseIterable, Identifiable, Sendable {
    case proofread, rewrite
    case friendly, professional, concise
    case summarize, keyPoints, list, table
    case translate
    /// Free-form instruction typed or spoken into the command box.
    case custom
    /// Writes new text from a prompt (also the only tool without a selection).
    case compose

    var id: String { rawValue }

    /// Tools that edit the selected text (everything except composing).
    var needsSelection: Bool { self != .compose }

    /// Name shown on the tiles and in the result header.
    var displayName: String {
        switch self {
        case .proofread: String(localized: "纠错")
        case .rewrite: String(localized: "改写")
        case .friendly: String(localized: "友好")
        case .professional: String(localized: "专业")
        case .concise: String(localized: "简洁")
        case .summarize: String(localized: "摘要")
        case .keyPoints: String(localized: "要点")
        case .list: String(localized: "列表")
        case .table: String(localized: "表格")
        case .translate: String(localized: "翻译")
        case .custom: String(localized: "自定义改写")
        case .compose: String(localized: "创作")
        }
    }

    /// Title of the result page: tone tools read as the effect ("更友好"), the others as the tool.
    var resultTitle: String {
        switch self {
        case .friendly: String(localized: "更友好")
        case .professional: String(localized: "更专业")
        case .concise: String(localized: "更简洁")
        default: displayName
        }
    }

    /// Status line while the model works.
    var loadingText: String {
        switch self {
        case .proofread: String(localized: "正在纠错…")
        case .rewrite, .custom: String(localized: "正在改写…")
        case .friendly, .professional: String(localized: "正在调整语气…")
        case .concise: String(localized: "正在精简…")
        case .summarize: String(localized: "正在摘要…")
        case .keyPoints: String(localized: "正在整理要点…")
        case .list: String(localized: "正在整理成列表…")
        case .table: String(localized: "正在整理成表格…")
        case .translate: String(localized: "正在翻译…")
        case .compose: String(localized: "正在创作…")
        }
    }
}

/// The three rows of the Compose page. Every row ends in a free-text field: typing there replaces the chosen option,
/// choosing an option clears the text again.
struct ComposeOptions: Equatable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case email, post, message, free
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .email: String(localized: "邮件")
            case .post: String(localized: "帖子")
            case .message: String(localized: "消息")
            case .free: String(localized: "自由")
            }
        }
        var promptName: String {
            switch self {
            case .email: "电子邮件（需要主题行、称呼、正文和落款）"
            case .post: "社交媒体帖子"
            case .message: "即时通讯消息（简短、口语化、不加主题行与落款）"
            case .free: "不限体裁的文字"
            }
        }
    }

    enum Tone: String, CaseIterable, Identifiable, Sendable {
        case natural, formal, lively
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .natural: String(localized: "自然")
            case .formal: String(localized: "正式")
            case .lively: String(localized: "活泼")
            }
        }
        var promptName: String {
            switch self {
            case .natural: "自然、得体"
            case .formal: "正式、庄重"
            case .lively: "活泼、有亲和力"
            }
        }
    }

    enum Length: String, CaseIterable, Identifiable, Sendable {
        case short, medium, long
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .short: String(localized: "短")
            case .medium: String(localized: "中")
            case .long: String(localized: "长")
            }
        }
        var promptName: String {
            switch self {
            case .short: "简短（几句话）"
            case .medium: "中等篇幅"
            case .long: "较长、内容充实"
            }
        }
    }

    var kind: Kind = .email
    var tone: Tone = .natural
    var length: Length = .medium
    var customKind = ""
    var customTone = ""
    var customLength = ""

    private static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What the prompt says for each row: the typed text wins over the chosen option.
    var kindPrompt: String { Self.trimmed(customKind).isEmpty ? kind.promptName : Self.trimmed(customKind) }
    var tonePrompt: String { Self.trimmed(customTone).isEmpty ? tone.promptName : Self.trimmed(customTone) }
    var lengthPrompt: String { Self.trimmed(customLength).isEmpty ? length.promptName : Self.trimmed(customLength) }

    var usesCustomKind: Bool { !Self.trimmed(customKind).isEmpty }
    var usesCustomTone: Bool { !Self.trimmed(customTone).isEmpty }
    var usesCustomLength: Bool { !Self.trimmed(customLength).isEmpty }
}

/// Everything one model call needs.
struct WritingRequest: Equatable, Sendable {
    var tool: WritingTool
    /// The selected text (`nil` for Compose).
    var source: String?
    /// Command-box text for `.custom`, the prompt for `.compose`.
    var instruction = ""
    var translationTarget: TranslationLanguage = .english
    var translationRegion: TranslationRegion?
    var compose = ComposeOptions()
    /// Compose only: write the text in Markdown syntax (headings, lists, bold, tables …) instead of plain text.
    var markdown = false
}

/// A finished model answer, ready to show and to write back.
struct WritingResult: Equatable, Sendable {
    /// Plain text that is copied / written to the document (tab-separated for tables).
    var text: String
    /// Parsed Markdown table, when the tool is `.table` and the answer parsed.
    var table: [[String]]?
    /// Inline changes against the selection, for `.proofread`.
    var diff: [DiffSegment]?

    var changeCount: Int { diff.map(TextDiff.changeCount) ?? 0 }
}
