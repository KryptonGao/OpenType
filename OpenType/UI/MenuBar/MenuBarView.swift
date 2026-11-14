import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: DictationSessionCoordinator
    let router: MainWindowRouter
    let updater: AppUpdater
    @Environment(\.openWindow) private var openWindow

    private var permissions: PermissionManager { coordinator.permissions }

    var body: some View {
        Label("听写：\(coordinator.settingsStore.hotkey.displayName)", systemImage: "mic")
        if let translationHotkey = coordinator.settingsStore.translationHotkey {
            Label("翻译：\(translationHotkey.displayName)", systemImage: "character.bubble")
        }

        Toggle("暂停全局快捷键", isOn: Bindable(coordinator.settingsStore).hotkeysPaused)

        Divider()

        Section("权限状态") {
            permissionRow(String(localized: "麦克风"), permissions.microphone)
            permissionRow(String(localized: "辅助功能"), permissions.accessibility)
            permissionRow(String(localized: "按键监听"), permissions.inputMonitoring)
            if !coordinator.hotkeyActive {
                Label("全局快捷键未启用（需要上述权限）", systemImage: "exclamationmark.triangle.fill")
            }
            Button("重新检查权限", systemImage: "arrow.clockwise") { permissions.refresh() }
        }

        Divider()

        Button("打开主界面", systemImage: "chart.bar.xaxis") { show(.home) }
        Button("历史记录", systemImage: "clock.arrow.circlepath") { show(.history) }
        Button("设置…", systemImage: "gearshape") { show(.settings(.general)) }
        .keyboardShortcut(",", modifiers: .command)

        updateMenuItem

        Button("退出 OpenType") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
            .onAppear { permissions.refresh() }
    }

    @ViewBuilder
    private var updateMenuItem: some View {
        switch updater.state {
        case .available:
            Button("更新到 \(updater.release?.version.description ?? "")…", systemImage: "arrow.down.circle") { updater.installUpdate() }
        case .downloading(let progress):
            Text("正在下载更新… \(Int(progress * 100))%")
        case .readyToInstall:
            Text("更新已就绪，听写结束后将自动重启")
        case .checking:
            Text("正在检查更新…")
        default:
            Button("检查更新…", systemImage: "arrow.down.circle") { Task { await updater.checkForUpdates() } }
        }
    }

    private func show(_ tab: MainTab) {
        router.tab = tab
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: MainWindow.id)
    }

    private func permissionRow(_ name: String, _ status: PermissionStatus) -> some View {
        Label(name, systemImage: status.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
    }
}
