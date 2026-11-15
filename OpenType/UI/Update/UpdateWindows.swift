import AppKit
import SwiftUI

/// Presents the update flow the way Sparkle does (the de-facto standard on macOS): a "Software Update" window with
/// the new version and its release notes, an "Updating OpenType" progress window, and plain alerts for
/// "you're up to date" / errors. The app lives in the menu bar, so these are standalone windows.
@MainActor
final class UpdateWindowController: NSObject, NSWindowDelegate {
    private let updater: AppUpdater
    private let settings: SettingsStore
    private var promptWindow: NSWindow?
    private var progressWindow: NSWindow?

    init(updater: AppUpdater, settings: SettingsStore) {
        self.updater = updater
        self.settings = settings
    }

    /// Manual "Check for Updates": checks, then shows whichever window fits the outcome.
    func checkAndPresent() async {
        if updater.state == .checking { return }
        if !updater.isBusy { await updater.checkForUpdates() }
        present()
    }

    /// Shows the window that matches the updater's current state.
    func present() {
        switch updater.state {
        case .available:
            showPrompt()
        case .downloading, .readyToInstall:
            showProgress()
        case .upToDate:
            showUpToDateAlert()
        case .failed(let message):
            if updater.release != nil { showUpdateFailedAlert(message) } else { showCheckFailedAlert(message) }
        case .idle, .checking:
            break
        }
    }

    private func install() {
        promptWindow?.close()
        updater.installUpdate()
        showProgress()
    }

    private func skip() {
        updater.skipCurrentRelease()
        promptWindow?.close()
    }

    // MARK: Windows

    private func showPrompt() {
        show(&promptWindow, title: String(localized: "软件更新"), size: CGSize(width: 520, height: 440)) {
            UpdatePromptView(
                updater: updater, settings: settings,
                onSkip: { [weak self] in self?.skip() },
                onLater: { [weak self] in self?.promptWindow?.close() },
                onInstall: { [weak self] in self?.install() }
            )
        }
    }

    private func showProgress() {
        show(&progressWindow, title: String(localized: "正在更新 OpenType"), size: CGSize(width: 440, height: 130)) {
            UpdateProgressView(
                updater: updater,
                onCancel: { [weak self] in self?.updater.cancelInstall() },
                onStopped: { [weak self] failure in
                    self?.progressWindow?.close()
                    if let failure { self?.showUpdateFailedAlert(failure) }
                }
            )
        }
    }

    private func show<Content: View>(_ slot: inout NSWindow?, title: String, size: CGSize, @ViewBuilder content: () -> Content) {
        let window: NSWindow
        if let existing = slot {
            window = existing
        } else {
            window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.styleMask = [.titled, .closable]
            window.title = title
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(size)
            window.center()
            slot = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === promptWindow { promptWindow = nil }
        if window === progressWindow { progressWindow = nil }
    }

    // MARK: Alerts (standard NSAlert, like Sparkle's)

    private func showUpToDateAlert() {
        runAlert(
            title: String(localized: "已是最新版本"),
            message: String(localized: "OpenType \(updater.currentVersion.description) 是目前最新的版本。"),
            buttons: [String(localized: "好")]
        )
    }

    private func showCheckFailedAlert(_ message: String) {
        runAlert(title: String(localized: "检查更新失败"), message: message, buttons: [String(localized: "好")])
    }

    private func showUpdateFailedAlert(_ message: String) {
        let choice = runAlert(
            title: String(localized: "更新失败"), message: message,
            buttons: [String(localized: "重试"), String(localized: "手动下载"), String(localized: "关闭")]
        )
        switch choice {
        case .alertFirstButtonReturn:
            updater.installUpdate()
            showProgress()
        case .alertSecondButtonReturn:
            updater.openReleasePage()
        default:
            break
        }
    }

    @discardableResult
    private func runAlert(title: String, message: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}

// MARK: - Views

private struct AppIconView: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 64, height: 64)
    }
}

/// "A new version is available": icon, headline, release notes, auto-update checkbox, Skip / Remind Me Later / Install.
private struct UpdatePromptView: View {
    let updater: AppUpdater
    let settings: SettingsStore
    let onSkip: () -> Void
    let onLater: () -> Void
    let onInstall: () -> Void

    var body: some View {
        @Bindable var settings = settings
        let version = updater.release?.version.description ?? ""
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AppIconView()
                VStack(alignment: .leading, spacing: 8) {
                    Text("发现新版本 \(version)").font(.headline)
                    Text("OpenType \(version) 现已可用，你当前使用的是 \(updater.currentVersion.description)。")
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        Group {
                            if updater.releaseNotes.isEmpty {
                                Text("此版本没有提供更新说明。").foregroundStyle(.secondary)
                            } else {
                                MarkdownView(updater.releaseNotes)
                            }
                        }
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(Rectangle().strokeBorder(Color(nsColor: .separatorColor)))
                    Toggle("以后自动下载并安装更新", isOn: $settings.autoInstallUpdates)
                        .toggleStyle(.checkbox)
                }
            }
            HStack {
                Button("跳过这个版本", action: onSkip)
                Spacer()
                Button("稍后提醒我", action: onLater).keyboardShortcut(.cancelAction)
                Button("安装更新", action: onInstall).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 440)
    }
}

/// Download / verify / install progress: status line, progress bar and a Cancel button while downloading.
private struct UpdateProgressView: View {
    let updater: AppUpdater
    let onCancel: () -> Void
    /// Called when the update stopped: with the error message when it failed, `nil` when it was cancelled.
    let onStopped: (String?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AppIconView()
            VStack(alignment: .leading, spacing: 8) {
                Text(statusText).lineLimit(1)
                switch updater.state {
                case .downloading(let progress) where progress < 1:
                    ProgressView(value: progress)
                    HStack {
                        Spacer()
                        Button("取消", action: onCancel)
                    }
                default:
                    ProgressView()
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 130)
        .onChange(of: updater.state) { _, state in
            switch state {
            case .failed(let message): onStopped(message)
            case .available: onStopped(nil)
            default: break
            }
        }
    }

    private var statusText: String {
        switch updater.state {
        case .downloading(let progress) where progress < 1:
            guard progress > 0, let total = updater.release?.dmgSize, total > 0 else { return String(localized: "正在下载更新…") }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return String(localized: "\(formatter.string(fromByteCount: Int64(Double(total) * progress))) / \(formatter.string(fromByteCount: total))")
        case .downloading:
            return String(localized: "正在校验并准备安装…")
        default:
            return String(localized: "更新已就绪，听写结束后将自动重启")
        }
    }
}
