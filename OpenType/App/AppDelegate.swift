import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    /// Opens (or raises) the main window. Set by the SwiftUI app once its scenes exist.
    var openMainWindow: (() -> Void)?

    /// Clicking the Dock icon (or launching the app again) shows the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow?()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        _ = AppLanguage.atLaunch
        let coordinator = AppContainer.coordinator
        updateDockVisibility(showDockIcon: coordinator.settingsStore.showDockIcon)
        coordinator.start()
        AppContainer.writingTools.start(
            isRecordingHotkey: { coordinator.isRecordingHotkey },
            otherHotkeys: { [coordinator.settingsStore.hotkey, coordinator.settingsStore.translationHotkey] }
        )
        AppContainer.screenAsk.start(
            isRecordingHotkey: { coordinator.isRecordingHotkey },
            otherHotkeys: { [coordinator.settingsStore.hotkey, coordinator.settingsStore.translationHotkey,
                             coordinator.settingsStore.writingToolsEnabled ? coordinator.settingsStore.writingToolsHotkey : nil] }
        )
        // The screen selection owns keyboard input until it closes, including Escape.
        let dictationEnabled = coordinator.hotkeyManager.isEnabled
        coordinator.hotkeyManager.isEnabled = { dictationEnabled() && !AppContainer.screenAsk.isVisible }
        let translationEnabled = coordinator.translationHotkeyManager.isEnabled
        coordinator.translationHotkeyManager.isEnabled = { translationEnabled() && !AppContainer.screenAsk.isVisible }
        AppContainer.updater.startAutomaticChecks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.screenAsk.close()
        AppContainer.screenAsk.hotkeyManager.stopListening()
        AppContainer.coordinator.cancelSession()
        AppContainer.coordinator.hotkeyManager.stopListening()
        AppContainer.writingTools.hotkeyManager.stopListening()
    }

    func updateDockVisibility(showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
