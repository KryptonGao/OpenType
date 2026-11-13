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
            Image(systemName: menuBarSymbol)
        }

        Settings {
            SettingsView(coordinator: coordinator)
                .onChange(of: coordinator.settingsStore.showDockIcon) { _, newValue in
                    appDelegate.updateDockVisibility(showDockIcon: newValue)
                }
                .onChange(of: coordinator.settingsStore.hotkey) { _, _ in
                    coordinator.applyHotkeySettings()
                }
        }
    }

    private var menuBarSymbol: String {
        switch coordinator.state {
        case .recording: "waveform.circle.fill"
        case .connecting, .finalizing, .processing, .inserting: "ellipsis.circle"
        default: coordinator.settingsStore.hotkeysPaused ? "mic.slash" : "mic.fill"
        }
    }
}
