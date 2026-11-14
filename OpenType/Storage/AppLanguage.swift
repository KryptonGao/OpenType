import Foundation

/// The UI language the user picked in Settings. `.system` follows the macOS language list and falls back to
/// English (the bundle's development region) when none of the supported languages match.
///
/// The choice is stored in the app's own `AppleLanguages` default, which macOS reads at launch to pick the
/// localization — so a change only takes effect after the app restarts.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    /// Shown in the picker. Each language is named in itself so it can always be recognised.
    var displayName: String {
        switch self {
        case .system: String(localized: "跟随系统")
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        }
    }

    /// The language this process started with (captured at launch, before Settings can change the stored value).
    static let atLaunch = stored()

    private static let key = "AppleLanguages"

    /// The language stored for this app, or `.system` when nothing (or something unsupported) is stored.
    static func stored(in defaults: UserDefaults = .standard, domain: String = Bundle.main.bundleIdentifier ?? "") -> AppLanguage {
        let list = defaults.persistentDomain(forName: domain)?[key] as? [String]
        guard let first = list?.first, let language = AppLanguage(rawValue: first), language != .system else { return .system }
        return language
    }

    static func store(_ language: AppLanguage, in defaults: UserDefaults = .standard) {
        if language == .system {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set([language.rawValue], forKey: key)
        }
    }
}
