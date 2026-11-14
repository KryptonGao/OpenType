import Observation
import SwiftUI

enum MainTab: Hashable {
    case home, history, dictionary, settings
}

/// Lets the menu bar and the app menu pick the tab the main window shows.
@MainActor
@Observable
final class MainWindowRouter {
    var tab: MainTab = .home
}

/// The app's main window: home (statistics) → history → settings.
struct MainWindowView: View {
    let coordinator: DictationSessionCoordinator
    @Bindable var router: MainWindowRouter
    let updater: AppUpdater

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("首页", systemImage: "chart.bar.xaxis", value: MainTab.home) {
                HomeView(coordinator: coordinator, router: router)
            }
            Tab("历史", systemImage: "clock.arrow.circlepath", value: MainTab.history) {
                HistoryView(coordinator: coordinator)
            }
            Tab("词典", systemImage: "character.book.closed", value: MainTab.dictionary) {
                DictionaryView(store: coordinator.dictionaryStore)
            }
            Tab("设置", systemImage: "gearshape", value: MainTab.settings) {
                SettingsView(coordinator: coordinator, updater: updater)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}
