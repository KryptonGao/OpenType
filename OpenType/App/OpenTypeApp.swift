import SwiftUI

/// Single shared object graph (the hotkey must be live before any menu is opened).
@MainActor
enum AppContainer {
    static let overlay = OverlayPanelController()
    static let coordinator = DictationSessionCoordinator(overlay: overlay)
}

@main
struct OpenTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coordinator = AppContainer.coordinator

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            Image(menuBarIcon)
        }

        Settings {
            SettingsView(coordinator: coordinator)
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
