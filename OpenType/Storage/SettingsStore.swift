import CoreGraphics
import Foundation
import Observation
import ServiceManagement

enum ASRProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case bailian
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bailian: String(localized: "阿里云百炼（实时流式）")
        case .deepseek: String(localized: "DeepSeek（录完后整段识别）")
        }
    }
}

/// Which Bailian model the `.bailian` provider talks to. They use different WebSocket protocols.
enum ASRModel: String, CaseIterable, Identifiable, Codable, Sendable {
    /// `qwen3-asr-flash-realtime` — OpenAI-realtime-style events on `/api-ws/v1/realtime`.
    case qwen3Realtime
    /// `qwen-audio-3.1-asr-flash-message` — DashScope `run-task` protocol on `/api-ws/v1/inference`.
    case qwenAudio31Message

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen3Realtime: "qwen3-asr-flash-realtime"
        case .qwenAudio31Message: "qwen-audio-3.1-asr-flash-message"
        }
    }

    var apiName: String { displayName }
}

enum ASRRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case beijing
    case singapore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beijing: String(localized: "北京 (cn-beijing)")
        case .singapore: String(localized: "新加坡 (ap-southeast-1)")
        }
    }

    var hostSegment: String {
        switch self {
        case .beijing: "cn-beijing"
        case .singapore: "ap-southeast-1"
        }
    }
}

enum OverlayPosition: String, CaseIterable, Identifiable, Codable, Sendable {
    case bottomCenter
    case topCenter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter: String(localized: "屏幕底部居中")
        case .topCenter: String(localized: "屏幕顶部居中")
        }
    }
}

/// Background material of the dictation overlay. Chosen separately for the full window and the minimal capsules.
enum OverlayMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case blur
    case liquidGlass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blur: String(localized: "毛玻璃")
        case .liquidGlass: "Liquid Glass"
        }
    }
}

enum ASRTurnDetection: String, CaseIterable, Identifiable, Codable, Sendable {
    case serverVAD
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serverVAD: String(localized: "服务端 VAD（自动断句）")
        case .manual: String(localized: "手动提交（松键时 commit）")
        }
    }
}

/// Default recognition language. Raw values are the codes accepted by Bailian's
/// `input_audio_transcription.language` (27 languages). DeepSeek has no language parameter and always auto-detects.
enum ASRLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case zh, yue, en, ja, ko
    case de, fr, es, pt, it, ru, ar, hi, id, th, tr, uk, vi
    case cs, da, fil, fi, `is`, ms, no, pl, sv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: String(localized: "自动识别")
        case .zh: String(localized: "中文（普通话、四川话、闽南语、吴语）")
        case .yue: String(localized: "粤语")
        case .en: "English"
        case .ja: "日本語"
        case .ko: "한국어"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .pt: "Português"
        case .it: "Italiano"
        case .ru: "Русский"
        case .ar: "العربية"
        case .hi: "हिन्दी"
        case .id: "Bahasa Indonesia"
        case .th: "ไทย"
        case .tr: "Türkçe"
        case .uk: "Українська"
        case .vi: "Tiếng Việt"
        case .cs: "Čeština"
        case .da: "Dansk"
        case .fil: "Filipino"
        case .fi: "Suomi"
        case .is: "Íslenska"
        case .ms: "Bahasa Melayu"
        case .no: "Norsk"
        case .pl: "Polski"
        case .sv: "Svenska"
        }
    }

    /// `nil` means "do not send a language" (auto-detect).
    var apiValue: String? { self == .auto ? nil : rawValue }

    /// `language_hints` code for `qwen-audio-3.1-asr-flash-*`; `nil` (auto-detect) when that model has no such code.
    /// Differs from `apiValue`: Filipino is `tl`, and yue / uk / tr / is are not in its hint list.
    var qwenAudioHint: String? {
        switch self {
        case .auto, .yue, .uk, .tr, .is: nil
        case .fil: "tl"
        default: rawValue
        }
    }
}

/// Regional variant of a translation language whose wording differs noticeably between regions.
enum TranslationRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case brazil
    case portugal
    case taiwan
    case hongKongMacau

    var id: String { rawValue }

    /// Short name shown in menus.
    var displayName: String {
        switch self {
        case .brazil: String(localized: "巴西")
        case .portugal: String(localized: "葡萄牙")
        case .taiwan: String(localized: "台湾")
        case .hongKongMacau: String(localized: "港澳")
        }
    }

    /// Language name used inside the translation prompt.
    var promptName: String {
        switch self {
        case .brazil: "Brazilian Portuguese（巴西葡萄牙语）"
        case .portugal: "European Portuguese（葡萄牙本土葡萄牙语）"
        case .taiwan: "Traditional Chinese as written in Taiwan（台湾繁体中文）"
        case .hongKongMacau: "Traditional Chinese as written in Hong Kong and Macau（港澳繁体中文）"
        }
    }

    /// Extra instruction making the regional wording explicit.
    var promptRule: String {
        switch self {
        case .brazil:
            "必须使用巴西葡萄牙语的拼写、词汇和语法习惯（如 você、ônibus、celular、café da manhã），不要使用葡萄牙本土的说法"
        case .portugal:
            "必须使用葡萄牙本土葡萄牙语的拼写、词汇和语法习惯（如 autocarro、telemóvel、pequeno-almoço，第二人称使用 tu / você 的欧洲用法），不要使用巴西的说法"
        case .taiwan:
            "必须使用台湾的繁体中文用词和书写习惯（如「軟體」「資訊」「網路」「滑鼠」「影片」「品質」），标点使用「」引号，不要使用大陆或港澳的说法"
        case .hongKongMacau:
            "必须使用香港、澳门的繁体中文书面用词和书写习惯（如「軟件」「資訊」「網絡」「滑鼠」「影片」「質素」），不要使用台湾或大陆的说法；保持书面语，不要写成粤语口语"
        }
    }
}

/// Target languages for voice translation.
enum TranslationLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case italian = "it"
    case russian = "ru"
    case arabic = "ar"
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"

    var id: String { rawValue }

    /// Name in the language itself (shown in menus).
    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .italian: "Italiano"
        case .russian: "Русский"
        case .arabic: "العربية"
        case .thai: "ไทย"
        case .vietnamese: "Tiếng Việt"
        case .indonesian: "Bahasa Indonesia"
        }
    }

    /// Regional variants the user can choose between (empty when the language has none).
    var regions: [TranslationRegion] {
        switch self {
        case .portuguese: [.brazil, .portugal]
        case .traditionalChinese: [.taiwan, .hongKongMacau]
        default: []
        }
    }

    /// Menu label including the region, e.g. "繁體中文（台湾）".
    func displayName(region: TranslationRegion?) -> String {
        guard let region, regions.contains(region) else { return displayName }
        return String(localized: "\(displayName)（\(region.displayName)）")
    }

    /// Name used inside the translation prompt.
    var promptName: String {
        switch self {
        case .english: "English（英语）"
        case .simplifiedChinese: "Simplified Chinese（简体中文）"
        case .traditionalChinese: "Traditional Chinese（繁體中文）"
        case .japanese: "Japanese（日语）"
        case .korean: "Korean（韩语）"
        case .french: "French（法语）"
        case .german: "German（德语）"
        case .spanish: "Spanish（西班牙语）"
        case .portuguese: "Portuguese（葡萄牙语）"
        case .italian: "Italian（意大利语）"
        case .russian: "Russian（俄语）"
        case .arabic: "Arabic（阿拉伯语）"
        case .thai: "Thai（泰语）"
        case .vietnamese: "Vietnamese（越南语）"
        case .indonesian: "Indonesian（印尼语）"
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    // MARK: General
    var showDockIcon: Bool { didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon) } }
    var hotkeysPaused: Bool { didSet { defaults.set(hotkeysPaused, forKey: Keys.hotkeysPaused) } }
    var autoInsertEnabled: Bool { didSet { defaults.set(autoInsertEnabled, forKey: Keys.autoInsertEnabled) } }
    var hotkey: HotkeyConfig { didSet { persistHotkey() } }
    var overlayPosition: OverlayPosition { didSet { defaults.set(overlayPosition.rawValue, forKey: Keys.overlayPosition) } }
    var soundFeedbackEnabled: Bool { didSet { defaults.set(soundFeedbackEnabled, forKey: Keys.soundFeedbackEnabled) } }
    /// Minimal overlay: a small waveform capsule (no transcript / result), plus extra capsules for translation language and web search.
    var overlayMinimalMode: Bool { didSet { defaults.set(overlayMinimalMode, forKey: Keys.overlayMinimalMode) } }
    /// Material of the full overlay window (default Liquid Glass) and of the minimal capsules (default frosted blur).
    var overlayMaterial: OverlayMaterial { didSet { defaults.set(overlayMaterial.rawValue, forKey: Keys.overlayMaterial) } }
    var overlayMinimalMaterial: OverlayMaterial { didSet { defaults.set(overlayMinimalMaterial.rawValue, forKey: Keys.overlayMinimalMaterial) } }

    // MARK: Software update
    /// Periodically look for a newer GitHub Release in the background (default on).
    var autoCheckUpdates: Bool { didSet { defaults.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) } }
    /// Download a found update in the background and install + relaunch once dictation is idle (default off).
    var autoInstallUpdates: Bool { didSet { defaults.set(autoInstallUpdates, forKey: Keys.autoInstallUpdates) } }
    var lastUpdateCheck: Date? { didSet { defaults.set(lastUpdateCheck, forKey: Keys.lastUpdateCheck) } }
    /// Version a "new version available" notification was already shown for.
    var lastNotifiedUpdateVersion: String? { didSet { defaults.set(lastNotifiedUpdateVersion, forKey: Keys.lastNotifiedUpdateVersion) } }
    /// Version the user chose to skip ("Skip This Version"): background checks stay quiet about it.
    var skippedUpdateVersion: String? { didSet { defaults.set(skippedUpdateVersion, forKey: Keys.skippedUpdateVersion) } }

    // MARK: Speech recognition
    /// CoreAudio UID of the locked input device, or `nil` to follow the system default.
    var audioInputDeviceUID: String? {
        didSet {
            if let audioInputDeviceUID, !audioInputDeviceUID.isEmpty {
                defaults.set(audioInputDeviceUID, forKey: Keys.audioInputDeviceUID)
            } else {
                defaults.removeObject(forKey: Keys.audioInputDeviceUID)
            }
        }
    }
    /// Cached display name of `audioInputDeviceUID` so an unplugged device can still be shown and named.
    var audioInputDeviceName: String? {
        didSet {
            if let audioInputDeviceName, !audioInputDeviceName.isEmpty {
                defaults.set(audioInputDeviceName, forKey: Keys.audioInputDeviceName)
            } else {
                defaults.removeObject(forKey: Keys.audioInputDeviceName)
            }
        }
    }
    var asrProvider: ASRProvider { didSet { defaults.set(asrProvider.rawValue, forKey: Keys.asrProvider) } }
    var asrModel: ASRModel { didSet { defaults.set(asrModel.rawValue, forKey: Keys.asrModel) } }
    /// `qwen-audio-3.1-asr-flash-message` only: let the ASR drop filler words / repeated words and polish the text
    /// (`disfluency_removal_enabled`). Off by default because the AI post-processing step already does this.
    var asrDisfluencyRemoval: Bool { didSet { defaults.set(asrDisfluencyRemoval, forKey: Keys.asrDisfluencyRemoval) } }
    var asrRegion: ASRRegion { didSet { defaults.set(asrRegion.rawValue, forKey: Keys.asrRegion) } }
    var asrWorkspaceID: String { didSet { defaults.set(asrWorkspaceID, forKey: Keys.asrWorkspaceID) } }
    /// Advanced: full custom `wss://` endpoint. Overrides region / workspace when non-empty.
    var asrCustomURL: String { didSet { defaults.set(asrCustomURL, forKey: Keys.asrCustomURL) } }
    var asrLanguage: ASRLanguage { didSet { defaults.set(asrLanguage.rawValue, forKey: Keys.asrLanguage) } }
    var asrTurnDetection: ASRTurnDetection { didSet { defaults.set(asrTurnDetection.rawValue, forKey: Keys.asrTurnDetection) } }
    var asrVADThreshold: Double { didSet { defaults.set(asrVADThreshold, forKey: Keys.asrVADThreshold) } }
    var asrSilenceDurationMS: Int { didSet { defaults.set(asrSilenceDurationMS, forKey: Keys.asrSilenceDurationMS) } }

    // MARK: AI processing
    var llmEnabled: Bool { didSet { defaults.set(llmEnabled, forKey: Keys.llmEnabled) } }
    var fallbackToRawOnLLMFailure: Bool { didSet { defaults.set(fallbackToRawOnLLMFailure, forKey: Keys.fallbackToRawOnLLMFailure) } }
    var processingLevel: ProcessingLevel { didSet { defaults.set(processingLevel.rawValue, forKey: Keys.processingLevel) } }
    var llmProfiles: [LLMProfile] { didSet { persistProfiles() } }
    var activeProfileID: UUID? { didSet { defaults.set(activeProfileID?.uuidString, forKey: Keys.activeProfileID) } }

    // MARK: Translation
    /// Language pre-selected in the translation popup (can be changed per session there).
    var translationTargetLanguage: TranslationLanguage { didSet { defaults.set(translationTargetLanguage.rawValue, forKey: Keys.translationTargetLanguage) } }
    /// Preferred regional variant per language (keyed by `TranslationLanguage.rawValue`), e.g. Brazilian vs. European Portuguese.
    var translationRegions: [String: String] { didSet { defaults.set(translationRegions, forKey: Keys.translationRegions) } }
    /// Tap-to-toggle shortcut that starts a translation session. `nil` = no shortcut (menu only).
    var translationHotkey: HotkeyConfig? { didSet { persistTranslationHotkey() } }

    // MARK: Help me say (长按听写快捷键)
    /// Holding the dictation shortcut starts a "help me say" session (speech → polished and elaborated text).
    var helpMeSayEnabled: Bool { didSet { defaults.set(helpMeSayEnabled, forKey: Keys.helpMeSayEnabled) } }
    /// Custom system prompt for help-me-say; blank falls back to `TextProcessor.defaultHelpMeSayPrompt`.
    var helpMeSayPrompt: String { didSet { defaults.set(helpMeSayPrompt, forKey: Keys.helpMeSayPrompt) } }

    /// Lets the model search the web (DeepSeek's server-side `deepseek_web_search`) to enrich the result.
    /// Only takes effect when the active profile points at DeepSeek's API.
    var helpMeSayWebSearchEnabled: Bool { didSet { defaults.set(helpMeSayWebSearchEnabled, forKey: Keys.helpMeSayWebSearchEnabled) } }
    /// How readily the model searches, 0–100 %. 0 % is the same as switching web search off.
    var helpMeSayWebSearchEagerness: Int {
        didSet {
            let clamped = min(100, max(0, helpMeSayWebSearchEagerness))
            if clamped != helpMeSayWebSearchEagerness { helpMeSayWebSearchEagerness = clamped; return }
            defaults.set(clamped, forKey: Keys.helpMeSayWebSearchEagerness)
        }
    }

    /// The level to run with, or `nil` when web search is off (switch off or 0 %).
    var helpMeSayWebSearchLevel: WebSearchLevel? {
        helpMeSayWebSearchEnabled ? WebSearchLevel(eagerness: helpMeSayWebSearchEagerness) : nil
    }

    // MARK: Privacy
    /// Keep the recognised and final text of each session in the local history. Off: only counters are kept.
    var saveHistoryText: Bool { didSet { defaults.set(saveHistoryText, forKey: Keys.saveHistoryText) } }
    var diagnosticsEnabled: Bool {
        didSet {
            defaults.set(diagnosticsEnabled, forKey: Keys.diagnosticsEnabled)
            Diagnostics.isEnabled = diagnosticsEnabled
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        func raw<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
            guard let string = defaults.string(forKey: key), let value = T(rawValue: string) else { return fallback }
            return value
        }

        showDockIcon = bool(Keys.showDockIcon, false)
        hotkeysPaused = bool(Keys.hotkeysPaused, false)
        autoInsertEnabled = bool(Keys.autoInsertEnabled, true)
        if let data = defaults.data(forKey: Keys.hotkey),
           let stored = try? JSONDecoder().decode(HotkeyConfig.self, from: data),
           stored.validation == .ok {
            hotkey = stored
        } else {
            hotkey = .default
        }
        overlayPosition = raw(Keys.overlayPosition, .bottomCenter)
        soundFeedbackEnabled = bool(Keys.soundFeedbackEnabled, false)
        overlayMinimalMode = bool(Keys.overlayMinimalMode, false)
        overlayMaterial = raw(Keys.overlayMaterial, .liquidGlass)
        overlayMinimalMaterial = raw(Keys.overlayMinimalMaterial, .blur)
        autoCheckUpdates = bool(Keys.autoCheckUpdates, true)
        autoInstallUpdates = bool(Keys.autoInstallUpdates, false)
        lastUpdateCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date
        lastNotifiedUpdateVersion = defaults.string(forKey: Keys.lastNotifiedUpdateVersion)
        skippedUpdateVersion = defaults.string(forKey: Keys.skippedUpdateVersion)

        let storedInputUID = defaults.string(forKey: Keys.audioInputDeviceUID)
        audioInputDeviceUID = storedInputUID?.isEmpty == false ? storedInputUID : nil
        let storedInputName = defaults.string(forKey: Keys.audioInputDeviceName)
        audioInputDeviceName = storedInputName?.isEmpty == false ? storedInputName : nil

        asrProvider = raw(Keys.asrProvider, .bailian)
        asrModel = raw(Keys.asrModel, .qwen3Realtime)
        asrDisfluencyRemoval = bool(Keys.asrDisfluencyRemoval, false)
        asrRegion = raw(Keys.asrRegion, .beijing)
        asrWorkspaceID = defaults.string(forKey: Keys.asrWorkspaceID) ?? ""
        asrCustomURL = defaults.string(forKey: Keys.asrCustomURL) ?? ""
        asrLanguage = raw(Keys.asrLanguage, .auto)
        asrTurnDetection = raw(Keys.asrTurnDetection, .serverVAD)
        asrVADThreshold = defaults.object(forKey: Keys.asrVADThreshold) as? Double ?? 0.0
        asrSilenceDurationMS = defaults.object(forKey: Keys.asrSilenceDurationMS) as? Int ?? 400

        llmEnabled = bool(Keys.llmEnabled, true)
        fallbackToRawOnLLMFailure = bool(Keys.fallbackToRawOnLLMFailure, true)
        processingLevel = raw(Keys.processingLevel, .standard)

        var profiles: [LLMProfile] = []
        if let data = defaults.data(forKey: Keys.llmProfiles),
           let decoded = try? JSONDecoder().decode([LLMProfile].self, from: data) {
            profiles = decoded
        }
        if profiles.isEmpty { profiles = [LLMProfile.makeDefault()] }
        llmProfiles = profiles
        let storedActive = defaults.string(forKey: Keys.activeProfileID).flatMap(UUID.init(uuidString:))
        activeProfileID = profiles.contains(where: { $0.id == storedActive }) ? storedActive : profiles.first?.id

        translationTargetLanguage = raw(Keys.translationTargetLanguage, .english)
        translationRegions = defaults.dictionary(forKey: Keys.translationRegions) as? [String: String] ?? [:]
        if let data = defaults.data(forKey: Keys.translationHotkey) {
            // Empty data means the user explicitly cleared the shortcut.
            if data.isEmpty {
                translationHotkey = nil
            } else if let stored = try? JSONDecoder().decode(HotkeyConfig.self, from: data), stored.validation == .ok {
                translationHotkey = stored
            } else {
                translationHotkey = .defaultTranslation
            }
        } else {
            translationHotkey = .defaultTranslation
        }

        helpMeSayEnabled = bool(Keys.helpMeSayEnabled, true)
        helpMeSayPrompt = defaults.string(forKey: Keys.helpMeSayPrompt) ?? TextProcessor.defaultHelpMeSayPrompt

        helpMeSayWebSearchEnabled = bool(Keys.helpMeSayWebSearchEnabled, false)
        helpMeSayWebSearchEagerness = min(100, max(0, defaults.object(forKey: Keys.helpMeSayWebSearchEagerness) as? Int ?? 80))

        saveHistoryText = bool(Keys.saveHistoryText, true)
        diagnosticsEnabled = bool(Keys.diagnosticsEnabled, false)
        Diagnostics.isEnabled = diagnosticsEnabled
    }

    var audioInputTarget: AudioInputTarget? {
        guard let uid = audioInputDeviceUID, !uid.isEmpty else { return nil }
        return AudioInputTarget(uid: uid, name: audioInputDeviceName ?? uid)
    }

    func selectAudioInputDevice(_ device: AudioInputDevice?) {
        audioInputDeviceUID = device?.uid
        audioInputDeviceName = device?.name
    }

    // MARK: Profiles

    var activeProfile: LLMProfile? {
        llmProfiles.first { $0.id == activeProfileID } ?? llmProfiles.first
    }

    func updateProfile(_ profile: LLMProfile) {
        guard let index = llmProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        llmProfiles[index] = profile
    }

    @discardableResult
    func addProfile(from template: LLMProfile? = nil) -> LLMProfile {
        var profile = template ?? LLMProfile.makeDefault()
        profile.id = UUID()
        profile.name = template == nil ? String(localized: "新配置") : String(localized: "\(template!.name) 副本")
        llmProfiles.append(profile)
        activeProfileID = profile.id
        return profile
    }

    /// Removes a profile (keeps at least one). Returns the removed id so callers can drop its stored API key.
    @discardableResult
    func removeProfile(id: UUID) -> UUID? {
        guard llmProfiles.count > 1, let index = llmProfiles.firstIndex(where: { $0.id == id }) else { return nil }
        llmProfiles.remove(at: index)
        if activeProfileID == id { activeProfileID = llmProfiles.first?.id }
        return id
    }

    /// The configured regional variant for `language`, or its first (default) variant; `nil` if the language has none.
    func translationRegion(for language: TranslationLanguage) -> TranslationRegion? {
        guard let first = language.regions.first else { return nil }
        if let raw = translationRegions[language.rawValue], let region = TranslationRegion(rawValue: raw),
           language.regions.contains(region) {
            return region
        }
        return first
    }

    /// Default target with its region, e.g. "繁體中文（台湾）".
    var translationLabel: String {
        translationTargetLanguage.displayName(region: translationRegion(for: translationTargetLanguage))
    }

    func setTranslationRegion(_ region: TranslationRegion, for language: TranslationLanguage) {
        guard language.regions.contains(region) else { return }
        translationRegions[language.rawValue] = region.rawValue
    }

    // MARK: Login item

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private func persistHotkey() {
        if let data = try? JSONEncoder().encode(hotkey) { defaults.set(data, forKey: Keys.hotkey) }
    }

    private func persistTranslationHotkey() {
        if let translationHotkey, let data = try? JSONEncoder().encode(translationHotkey) {
            defaults.set(data, forKey: Keys.translationHotkey)
        } else {
            defaults.set(Data(), forKey: Keys.translationHotkey)
        }
    }

    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(llmProfiles) {
            defaults.set(data, forKey: Keys.llmProfiles)
        }
    }

    private enum Keys {
        static let showDockIcon = "opentype.showDockIcon"
        static let hotkeysPaused = "opentype.hotkeysPaused"
        static let autoInsertEnabled = "opentype.autoInsertEnabled"
        static let hotkey = "opentype.hotkey"
        static let overlayPosition = "opentype.overlayPosition"
        static let soundFeedbackEnabled = "opentype.soundFeedbackEnabled"
        static let overlayMinimalMode = "opentype.overlayMinimalMode"
        static let overlayMaterial = "opentype.overlayMaterial"
        static let overlayMinimalMaterial = "opentype.overlayMinimalMaterial"
        static let autoCheckUpdates = "opentype.autoCheckUpdates"
        static let autoInstallUpdates = "opentype.autoInstallUpdates"
        static let lastUpdateCheck = "opentype.lastUpdateCheck"
        static let lastNotifiedUpdateVersion = "opentype.lastNotifiedUpdateVersion"
        static let skippedUpdateVersion = "opentype.skippedUpdateVersion"
        static let audioInputDeviceUID = "opentype.audioInputDeviceUID"
        static let audioInputDeviceName = "opentype.audioInputDeviceName"
        static let asrProvider = "opentype.asrProvider"
        static let asrModel = "opentype.asrModel"
        static let asrDisfluencyRemoval = "opentype.asrDisfluencyRemoval"
        static let asrRegion = "opentype.asrRegion"
        static let asrWorkspaceID = "opentype.asrWorkspaceID"
        static let asrCustomURL = "opentype.asrCustomURL"
        static let asrLanguage = "opentype.asrLanguage"
        static let asrTurnDetection = "opentype.asrTurnDetection"
        static let asrVADThreshold = "opentype.asrVADThreshold"
        static let asrSilenceDurationMS = "opentype.asrSilenceDurationMS"
        static let llmEnabled = "opentype.llmEnabled"
        static let fallbackToRawOnLLMFailure = "opentype.fallbackToRawOnLLMFailure"
        static let processingLevel = "opentype.processingLevel"
        static let llmProfiles = "opentype.llmProfiles"
        static let activeProfileID = "opentype.activeProfileID"
        static let translationTargetLanguage = "opentype.translationTargetLanguage"
        static let translationRegions = "opentype.translationRegions"
        static let translationHotkey = "opentype.translationHotkey"
        static let helpMeSayEnabled = "opentype.helpMeSayEnabled"
        static let helpMeSayPrompt = "opentype.helpMeSayPrompt"
        static let helpMeSayWebSearchEnabled = "opentype.helpMeSayWebSearchEnabled"
        static let helpMeSayWebSearchEagerness = "opentype.helpMeSayWebSearchEagerness"
        static let saveHistoryText = "opentype.saveHistoryText"
        static let diagnosticsEnabled = "opentype.diagnosticsEnabled"
    }
}
