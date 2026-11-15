import SwiftUI

/// Official sites of the China-based services OpenType can use (Alibaba Cloud Bailian, DeepSeek). People outside
/// China often have never heard of them, so Settings puts a link to the site next to the API key field in every UI
/// language except Simplified Chinese.
enum ProviderSite {
    case bailian
    case deepseek

    var url: URL {
        switch self {
        // International Model Studio (Bailian) product page; it leads on to the console where keys are created.
        case .bailian: URL(string: "https://www.alibabacloud.com/en/product/modelstudio")!
        // DeepSeek open platform: sign-up, top-up and API key management.
        case .deepseek: URL(string: "https://platform.deepseek.com")!
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .bailian: "阿里云百炼官网（获取 API Key）"
        case .deepseek: "DeepSeek 官网（获取 API Key）"
        }
    }

    /// Whether the links are shown for the localization the app is running in. Simplified Chinese users are the ones
    /// who already know these services; everyone else gets the link.
    static func isShown(forLocalization localization: String?) -> Bool {
        localization != "zh-Hans"
    }

    static var isShownInCurrentLanguage: Bool {
        isShown(forLocalization: Bundle.main.preferredLocalizations.first)
    }
}

/// A "go to the official site" link under an API key field; renders nothing when the UI is Simplified Chinese.
struct ProviderSiteLink: View {
    let site: ProviderSite

    var body: some View {
        if ProviderSite.isShownInCurrentLanguage {
            Link(destination: site.url) {
                Label(site.title, systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        }
    }
}
