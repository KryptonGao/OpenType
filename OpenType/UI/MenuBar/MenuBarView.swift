import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: DictationSessionCoordinator
    @Environment(\.openSettings) private var openSettings

    private var permissions: PermissionManager { coordinator.permissions }

    var body: some View {
        let recording = coordinator.state == .connecting || coordinator.state == .recording
        Button(recording && coordinator.sessionMode == .toggle ? "结束语音输入" : "开始语音输入") {
            coordinator.toggleFromMenu()
        }
        .disabled(coordinator.state.isBusy && !(recording && coordinator.sessionMode == .toggle))

        Button(recording && coordinator.sessionMode == .toggle && coordinator.translationTarget != nil
               ? "结束语音翻译"
               : "开始语音翻译（→ \(coordinator.settingsStore.translationLabel)）") {
            coordinator.toggleTranslationFromMenu()
        }
        .disabled(coordinator.state.isBusy && !(recording && coordinator.sessionMode == .toggle))

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

        Button("设置…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("退出 OpenType") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
            .onAppear { permissions.refresh() }
    }

    private func permissionRow(_ name: String, _ status: PermissionStatus) -> some View {
        Text("\(status.isGranted ? "✓" : "✗") \(name)")
    }
}
