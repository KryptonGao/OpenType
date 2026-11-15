import SwiftUI

struct MenuBarView: View {
    @Bindable var coordinator: DictationSessionCoordinator
    let router: MainWindowRouter
    let updater: AppUpdater
    @Environment(\.openWindow) private var openWindow

    private var permissions: PermissionManager { coordinator.permissions }
    private var settingsStore: SettingsStore { coordinator.settingsStore }
    private var audioInputMonitor: AudioInputMonitor { coordinator.audioInputMonitor }

    var body: some View {
        Label("听写：\(coordinator.settingsStore.hotkey.displayName)", systemImage: "mic")
        if let translationHotkey = coordinator.settingsStore.translationHotkey {
            Label("翻译：\(translationHotkey.displayName)", systemImage: "character.bubble")
        }

        if coordinator.settingsStore.writingToolsEnabled {
            Label("书写工具：\(coordinator.settingsStore.writingToolsHotkey.displayName)", systemImage: "wand.and.sparkles")
        }

        Toggle("暂停全局快捷键", isOn: Bindable(coordinator.settingsStore).hotkeysPaused)

        microphoneMenu
        presetMenu

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
            .onAppear {
                permissions.refresh()
                audioInputMonitor.refresh()
            }
    }

    /// Switches the default preset (the one used when no app rule matches) and the per-app matching.
    private var presetMenu: some View {
        let store = coordinator.presetStore
        return Menu {
            ForEach(store.presets) { preset in
                Toggle(isOn: Binding(
                    get: { store.defaultPresetID == preset.id },
                    set: { if $0 { store.setDefaultPreset(preset.id) } }
                )) {
                    Label(preset.displayName, systemImage: preset.symbolName)
                }
            }
            Divider()
            Toggle("按应用自动匹配", isOn: Bindable(store).autoMatchEnabled)
            Button("管理预设…", systemImage: "square.stack.3d.up") { show(.presets) }
        } label: {
            Label("预设：\(store.defaultPreset.displayName)", systemImage: "square.stack.3d.up")
        }
    }

    private var microphoneMenu: some View {
        let missing = audioInputMonitor.disconnectedLockedDevice(
            uid: settingsStore.audioInputDeviceUID,
            cachedName: settingsStore.audioInputDeviceName
        )
        let summary = audioInputMonitor.menuSummaryLabel(
            lockedUID: settingsStore.audioInputDeviceUID,
            cachedName: settingsStore.audioInputDeviceName
        )
        return Menu {
            Toggle(audioInputMonitor.systemDefaultLabel(), isOn: Binding(
                get: { settingsStore.audioInputDeviceUID == nil },
                set: { if $0 { settingsStore.selectAudioInputDevice(nil) } }
            ))
            if !audioInputMonitor.devices.isEmpty {
                Divider()
                ForEach(audioInputMonitor.devices) { device in
                    Toggle(device.displayName, isOn: Binding(
                        get: { settingsStore.audioInputDeviceUID == device.uid },
                        set: { if $0 { settingsStore.selectAudioInputDevice(device) } }
                    ))
                }
            }
            if let missing {
                Divider()
                Toggle(String(localized: "\(missing.name)（未连接）"), isOn: .constant(true))
                    .disabled(true)
            }
        } label: {
            Label(summary, systemImage: "mic.circle")
        }
    }

    @ViewBuilder
    private var updateMenuItem: some View {
        switch updater.state {
        case .available:
            Button("更新到 \(updater.release?.version.description ?? "")…", systemImage: "arrow.down.circle") { AppContainer.updateWindows.present() }
        case .downloading(let progress):
            Button("正在下载更新… \(Int(progress * 100))%") { AppContainer.updateWindows.present() }
        case .readyToInstall:
            Button("更新已就绪，听写结束后将自动重启") { AppContainer.updateWindows.present() }
        case .checking:
            Text("正在检查更新…")
        default:
            Button("检查更新…", systemImage: "arrow.down.circle") { Task { await AppContainer.updateWindows.checkAndPresent() } }
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
