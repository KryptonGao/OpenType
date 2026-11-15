import SwiftUI

/// Single shared object graph (the hotkey must be live before any menu is opened).
@MainActor
enum AppContainer {
    static let overlay = OverlayPanelController()
    static let historyStore = HistoryStore(fileURL: HistoryStore.defaultFileURL)
    static let dictionaryStore = DictionaryStore(fileURL: DictionaryStore.defaultFileURL)
    static let presetStore = PresetStore(fileURL: PresetStore.defaultFileURL)
    static let coordinator = DictationSessionCoordinator(
        historyStore: historyStore, dictionaryStore: dictionaryStore, presetStore: presetStore, overlay: overlay
    )
    static let router = MainWindowRouter()
    static let updater = AppUpdater(settings: coordinator.settingsStore, isIdle: { coordinator.state == .idle })
    static let updateWindows = UpdateWindowController(updater: updater, settings: coordinator.settingsStore)
}

enum MainWindow {
    static let id = "main"
}

@main
struct OpenTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coordinator = AppContainer.coordinator
    private let router = AppContainer.router
    private let updater = AppContainer.updater
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator, router: router, updater: updater)
        } label: {
            Image(menuBarIcon)
                .onAppear { appDelegate.openMainWindow = { openWindow(id: MainWindow.id) } }
        }

        Window("OpenType", id: MainWindow.id) {
            MainWindowView(coordinator: coordinator, router: router, updater: updater)
                .onChange(of: coordinator.settingsStore.showDockIcon) { _, newValue in
                    appDelegate.updateDockVisibility(showDockIcon: newValue)
                }
                .onChange(of: coordinator.settingsStore.hotkey) { _, _ in
                    coordinator.applyHotkeySettings()
                }
                .onChange(of: coordinator.settingsStore.translationHotkey) { _, _ in
                    coordinator.applyHotkeySettings()
                }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    router.tab = .settings(.general)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: MainWindow.id)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    /// Template images from the asset catalog (sources: Design/MenuBar*.svg).
    private var menuBarIcon: String {
        switch coordinator.state {
        case .recording: "MenuBarRecording"
        case .connecting, .finalizing, .processing, .inserting: "MenuBarBusy"
        default: coordinator.settingsStore.hotkeysPaused ? "MenuBarPaused" : "MenuBarIdle"
        }
    }
}
