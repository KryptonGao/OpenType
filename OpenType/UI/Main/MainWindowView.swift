import Observation
import SwiftUI

/// The settings pages, listed in the sidebar's "设置" section.
enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general, speech, ai, translation, helpMeSay, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "通用")
        case .speech: String(localized: "语音识别")
        case .ai: String(localized: "AI 处理")
        case .translation: String(localized: "翻译")
        case .helpMeSay: String(localized: "帮我说")
        case .privacy: String(localized: "隐私与权限")
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .speech: "mic"
        case .ai: "sparkles"
        case .translation: "character.bubble"
        case .helpMeSay: "wand.and.stars"
        case .privacy: "checkmark.shield"
        }
    }
}

enum MainTab: Hashable {
    case home, history, dictionary
    case settings(SettingsPage)
}

/// Lets the menu bar and the app menu pick the tab the main window shows.
@MainActor
@Observable
final class MainWindowRouter {
    var tab: MainTab = .home
}

extension DictationSessionCoordinator {
    /// One-line hotkey status shown on the home page and at the bottom of the sidebar.
    var hotkeyStatusText: String {
        if settingsStore.hotkeysPaused { return String(localized: "全局快捷键已暂停") }
        guard hotkeyActive else { return String(localized: "全局快捷键未启用") }
        return String(localized: "按 \(settingsStore.hotkey.displayName) 开始语音输入")
    }
}

/// The app's main window: a sidebar (home / history / dictionary, then the settings pages) and the selected page.
struct MainWindowView: View {
    let coordinator: DictationSessionCoordinator
    @Bindable var router: MainWindowRouter
    let updater: AppUpdater

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 860, minHeight: 560)
    }

    private var selection: Binding<MainTab?> {
        Binding(get: { router.tab }, set: { if let newValue = $0 { router.tab = newValue } })
    }

    private var sidebar: some View {
        List(selection: selection) {
            Label("首页", systemImage: "chart.bar.xaxis").tag(MainTab.home)
            Label("历史", systemImage: "clock.arrow.circlepath").tag(MainTab.history)
            Label("词典", systemImage: "character.book.closed").tag(MainTab.dictionary)

            Section("设置") {
                ForEach(SettingsPage.allCases) { page in
                    HStack {
                        Label(page.title, systemImage: page.symbolName)
                        if page == .privacy, !coordinator.hotkeyActive {
                            Spacer()
                            Circle().fill(.orange).frame(width: 8, height: 8)
                        }
                    }
                    .tag(MainTab.settings(page))
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(coordinator.hotkeyStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(10)
        }
    }

    private var statusColor: Color {
        if coordinator.settingsStore.hotkeysPaused { return .secondary }
        return coordinator.hotkeyActive ? .green : .orange
    }

    @ViewBuilder
    private var detail: some View {
        switch router.tab {
        case .home:
            HomeView(coordinator: coordinator, router: router)
        case .history:
            HistoryView(coordinator: coordinator)
        case .dictionary:
            DictionaryView(store: coordinator.dictionaryStore)
        case .settings(let page):
            SettingsView(page: page, coordinator: coordinator, updater: updater)
        }
    }
}
