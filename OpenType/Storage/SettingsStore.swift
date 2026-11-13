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
        case .bailian: "阿里云百炼（实时流式）"
        case .deepseek: "DeepSeek（录完后整段识别）"
        }
    }
}

enum ASRRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case beijing
    case singapore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beijing: "北京 (cn-beijing)"
        case .singapore: "新加坡 (ap-southeast-1)"
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
        case .bottomCenter: "屏幕底部居中"
        case .topCenter: "屏幕顶部居中"
        }
    }
}

enum ASRTurnDetection: String, CaseIterable, Identifiable, Codable, Sendable {
    case serverVAD
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serverVAD: "服务端 VAD（自动断句）"
        case .manual: "手动提交（松键时 commit）"
        }
    }
}

enum ASRLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto, zh, en, ja, yue, ko

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: "自动识别"
        case .zh: "中文"
        case .en: "English"
        case .ja: "日本語"
        case .yue: "粤语"
        case .ko: "한국어"
        }
    }

    /// `nil` means "do not send a language" (auto-detect).
    var apiValue: String? { self == .auto ? nil : rawValue }
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

    // MARK: Speech recognition
    var asrProvider: ASRProvider { didSet { defaults.set(asrProvider.rawValue, forKey: Keys.asrProvider) } }
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

    // MARK: Privacy
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

        asrProvider = raw(Keys.asrProvider, .bailian)
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

        diagnosticsEnabled = bool(Keys.diagnosticsEnabled, false)
        Diagnostics.isEnabled = diagnosticsEnabled
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
        profile.name = template == nil ? "新配置" : "\(template!.name) 副本"
        llmProfiles.append(profile)
        activeProfileID = profile.id
        return profile
    }

    /// Removes a profile (keeps at least one). Returns the removed id so callers can drop its Keychain item.
    @discardableResult
    func removeProfile(id: UUID) -> UUID? {
        guard llmProfiles.count > 1, let index = llmProfiles.firstIndex(where: { $0.id == id }) else { return nil }
        llmProfiles.remove(at: index)
        if activeProfileID == id { activeProfileID = llmProfiles.first?.id }
        return id
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
        static let asrProvider = "opentype.asrProvider"
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
        static let diagnosticsEnabled = "opentype.diagnosticsEnabled"
    }
}
