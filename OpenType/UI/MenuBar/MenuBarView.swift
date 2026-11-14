import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: DictationSessionCoordinator
    let router: MainWindowRouter
    @Environment(\.openWindow) private var openWindow

    private var permissions: PermissionManager { coordinator.permissions }

    var body: some View {
        Text("听写：\(coordinator.settingsStore.hotkey.displayName)")
        if let translationHotkey = coordinator.settingsStore.translationHotkey {
            Text("翻译：\(translationHotkey.displayName)")
        }

        Toggle("暂停全局快捷键", isOn: Bindable(coordinator.settingsStore).hotkeysPaused)

        Divider()

        Section("权限状态") {
            permissionRow("麦克风", permissions.microphone)
            permissionRow("辅助功能", permissions.accessibility)
            permissionRow("按键监听", permissions.inputMonitoring)
            if !coordinator.hotkeyActive {
                Text("⚠︎ 全局快捷键未启用（需要上述权限）")
            }
            Button("重新检查权限") { permissions.refresh() }
        }

        Divider()

        Button("打开主界面") { show(.home) }
        Button("历史记录") { show(.history) }
        Button("设置…") { show(.settings) }
        .keyboardShortcut(",", modifiers: .command)

        Button("退出 OpenType") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
            .onAppear { permissions.refresh() }
    }

    private func show(_ tab: MainTab) {
        router.tab = tab
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: MainWindow.id)
    }

    private func permissionRow(_ name: String, _ status: PermissionStatus) -> some View {
        Text("\(status.isGranted ? "✓" : "✗") \(name)")
    }
}
