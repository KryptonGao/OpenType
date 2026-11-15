import AppKit
import SwiftUI

/// Presents the update flow in small standalone windows (the app lives in the menu bar, so there may be no main
/// window): "new version + release notes", then "download progress", plus a tiny result window for
/// "up to date" / "check failed".
@MainActor
final class UpdateWindowController: NSObject, NSWindowDelegate {
    private let updater: AppUpdater
    private var promptWindow: NSWindow?
    private var progressWindow: NSWindow?
    private var resultWindow: NSWindow?

    init(updater: AppUpdater) {
        self.updater = updater
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
            showResult()
        case .failed:
            if updater.release != nil { showProgress() } else { showResult() }
        case .idle, .checking:
            break
        }
    }

    private func install() {
        promptWindow?.close()
        updater.installUpdate()
        showProgress()
    }

    // MARK: Windows

    private func showPrompt() {
        show(&promptWindow, size: CGSize(width: 460, height: 480)) {
            UpdatePromptView(updater: updater, onLater: { [weak self] in self?.promptWindow?.close() }, onInstall: { [weak self] in self?.install() })
        }
    }

    private func showProgress() {
        show(&progressWindow, size: CGSize(width: 420, height: 140)) {
            UpdateProgressView(updater: updater, onClose: { [weak self] in self?.progressWindow?.close() })
        }
    }

    private func showResult() {
        show(&resultWindow, size: CGSize(width: 380, height: 190)) {
            UpdateResultView(updater: updater, onClose: { [weak self] in self?.resultWindow?.close() })
        }
    }

    private func show<Content: View>(_ slot: inout NSWindow?, size: CGSize, @ViewBuilder content: () -> Content) {
        let window: NSWindow
        if let existing = slot {
            window = existing
        } else {
            window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
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
        if window === resultWindow { resultWindow = nil }
    }
}

// MARK: - Views

private struct AppIconView: View {
    var size: CGFloat = 64

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: size, height: size)
    }
}

/// "New version available" with the release notes and the Later / Install buttons.
private struct UpdatePromptView: View {
    let updater: AppUpdater
    let onLater: () -> Void
    let onInstall: () -> Void

    var body: some View {
        let version = updater.release?.version.description ?? ""
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AppIconView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("发现新版本 \(version)").font(.title3.bold())
                    Text("OpenType \(version) 现已可用，你当前使用的是 \(updater.currentVersion.description)。")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("更新内容").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView {
                Group {
                    if updater.releaseNotes.isEmpty {
                        Text("此版本没有提供更新说明。").foregroundStyle(.secondary)
                    } else {
                        MarkdownView(updater.releaseNotes)
                    }
                }
                .font(.callout)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))

            HStack {
                Spacer()
                Button("稍后", action: onLater).keyboardShortcut(.cancelAction)
                Button("安装更新", action: onInstall).keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 6)
        .frame(width: 460, height: 480)
    }
}

/// Download / verify / install progress.
private struct UpdateProgressView: View {
    let updater: AppUpdater
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppIconView(size: 52)
            VStack(alignment: .leading, spacing: 8) {
                switch updater.state {
                case .failed(let message):
                    Text("更新失败").font(.headline)
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Button("手动下载") { updater.openReleasePage() }
                        Button("关闭", action: onClose)
                        Button("重试") { updater.installUpdate() }.keyboardShortcut(.defaultAction)
                    }
                case .downloading(let progress) where progress < 1:
                    Text("正在更新 OpenType").font(.headline)
                    ProgressView(value: progress)
                    Text("正在下载更新… \(Int(progress * 100))%").font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                case .downloading:
                    Text("正在更新 OpenType").font(.headline)
                    ProgressView()
                    Text("正在校验并准备安装…").font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                default:
                    Text("正在更新 OpenType").font(.headline)
                    ProgressView()
                    Text("更新已就绪，听写结束后将自动重启").font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 6)
        .frame(width: 420, height: 140)
    }
}

/// "You're up to date" / "couldn't check".
private struct UpdateResultView: View {
    let updater: AppUpdater
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            AppIconView(size: 56)
            if case .failed(let message) = updater.state {
                Text("检查更新失败").font(.headline)
                Text(message).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineLimit(3)
            } else {
                Text("已是最新版本").font(.headline)
                Text("OpenType \(updater.currentVersion.description) 是目前最新的版本。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("关闭", action: onClose).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .padding(.top, 6)
        .frame(width: 380, height: 190)
    }
}
