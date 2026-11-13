import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = AppContainer.coordinator
        updateDockVisibility(showDockIcon: coordinator.settingsStore.showDockIcon)
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.coordinator.cancelSession()
        AppContainer.coordinator.hotkeyManager.stopListening()
    }

    func updateDockVisibility(showDockIcon: Bool) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
