import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opens (or raises) the main window. Set by the SwiftUI app once its scenes exist.
    var openMainWindow: (() -> Void)?

    /// Clicking the Dock icon (or launching the app again) shows the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow?()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AppLanguage.atLaunch
        let coordinator = AppContainer.coordinator
        updateDockVisibility(showDockIcon: coordinator.settingsStore.showDockIcon)
        coordinator.start()
        AppContainer.updater.startAutomaticChecks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.coordinator.cancelSession()
        AppContainer.coordinator.hotkeyManager.stopListening()
    }

    func updateDockVisibility(showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
