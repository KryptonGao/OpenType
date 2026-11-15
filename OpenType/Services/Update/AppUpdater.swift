import AppKit
import Foundation
import Observation

/// In-app updater backed by GitHub Releases: detects a newer release, downloads its DMG, verifies and installs it,
/// then relaunches the app. Manual (button) and automatic (background) flows share the same pipeline.
@MainActor
@Observable
final class AppUpdater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case downloading(progress: Double)
        /// Downloaded and verified; installs as soon as no dictation is running.
        case readyToInstall
        case failed(String)
    }

    nonisolated static let repository = "KryptonGao/OpenType"
    private static let checkInterval: TimeInterval = 6 * 3600

    private(set) var state: State = .idle
    /// The newer release found by the last check (while `state` is `available` / `downloading` / `readyToInstall`).
    private(set) var release: ReleaseInfo?
    /// The found release's notes in the UI language, trimmed for display (Markdown).
    private(set) var releaseNotes = ""

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let notifier: any UserNotifying
    @ObservationIgnored private let isIdle: @MainActor () -> Bool
    @ObservationIgnored private var scheduler: Task<Void, Never>?
    @ObservationIgnored private var installTask: Task<Void, Never>?

    let currentVersion: AppVersion

    init(
        settings: SettingsStore,
        notifier: any UserNotifying = SystemUserNotifier(),
        currentVersion: AppVersion? = nil,
        isIdle: @escaping @MainActor () -> Bool
    ) {
        self.settings = settings
        self.notifier = notifier
        self.isIdle = isIdle
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        self.currentVersion = currentVersion ?? bundleVersion.flatMap(AppVersion.init) ?? AppVersion("0")!
    }

    var updateAvailable: Bool {
        switch state {
        case .available, .downloading, .readyToInstall: true
        default: false
        }
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .readyToInstall: true
        default: false
        }
    }

    // MARK: Automatic detection

    /// Checks shortly after launch and then every hour whether the last check is older than six hours.
    func startAutomaticChecks() {
        guard scheduler == nil else { return }
        UpdateInstaller.cleanUpOldUpdates()
        scheduler = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            while !Task.isCancelled {
                guard let self else { return }
                await self.automaticTick()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    private func automaticTick() async {
        guard settings.autoCheckUpdates, !isBusy, state != .available || settings.autoInstallUpdates else { return }
        if let last = settings.lastUpdateCheck, Date().timeIntervalSince(last) < Self.checkInterval { return }
        await checkForUpdates(userInitiated: false)
    }

    // MARK: Checking

    func checkForUpdates(userInitiated: Bool = true) async {
        guard !isBusy else { return }
        let previous = state
        state = .checking
        do {
            let latest = try await Self.fetchLatestRelease()
            settings.lastUpdateCheck = Date()
            if latest.version > currentVersion {
                releaseNotes = await ReleaseNotes.load(for: latest)
                release = latest
                state = .available
                let skipped = !userInitiated && settings.skippedUpdateVersion == latest.version.description
                if settings.autoInstallUpdates, !skipped {
                    installUpdate()
                } else if !userInitiated, !skipped, settings.lastNotifiedUpdateVersion != latest.version.description {
                    settings.lastNotifiedUpdateVersion = latest.version.description
                    notifier.notify(
                        title: String(localized: "OpenType 有新版本"),
                        body: String(localized: "OpenType \(latest.version.description) 已发布，可在菜单栏或设置中更新。")
                    )
                }
            } else {
                release = nil
                releaseNotes = ""
                state = .upToDate
            }
        } catch {
            if userInitiated {
                state = .failed(error.localizedDescription)
            } else {
                state = previous == .checking ? .idle : previous
            }
        }
    }

    nonisolated static func fetchLatestRelease() async throws -> ReleaseInfo {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw UpdateError.badResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("OpenType-Updater", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw UpdateError.badResponse }
        guard http.statusCode == 200 else {
            throw UpdateError.network("HTTP \(http.statusCode)")
        }
        return try ReleaseParser.parseLatest(data)
    }

    // MARK: Installing

    /// Downloads and verifies the found release, then installs it and relaunches once dictation is idle.
    func installUpdate() {
        guard installTask == nil, let release, state == .available || isFailedWithRelease else { return }
        installTask = Task { [weak self] in
            await self?.runInstall(release)
            self?.installTask = nil
        }
    }

    /// "Skip This Version": background checks no longer announce or install this release (manual checks still do).
    func skipCurrentRelease() {
        guard let release else { return }
        settings.skippedUpdateVersion = release.version.description
    }

    /// Stops a running download and goes back to "update available". Does nothing once the download is finished.
    func cancelInstall() {
        guard case .downloading(let progress) = state, progress < 1 else { return }
        installTask?.cancel()
    }

    private var isFailedWithRelease: Bool {
        if case .failed = state { return release != nil }
        return false
    }

    private func runInstall(_ release: ReleaseInfo) async {
        state = .downloading(progress: 0)
        let staged: URL
        do {
            try UpdateInstaller.checkInstallable()
            staged = try await UpdateInstaller.stage(release: release) { [weak self] value in
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(progress: value)
                }
            }
        } catch {
            state = Task.isCancelled ? .available : .failed(error.localizedDescription)
            return
        }

        state = .readyToInstall
        while !isIdle() {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { state = .available; return }
        }
        do {
            try UpdateInstaller.launchInstallScript(staged: staged)
        } catch {
            state = .failed(String(localized: "更新失败：\(error.localizedDescription)"))
            return
        }
        NSApp.terminate(nil)
    }

    /// Opens the release page in the browser (manual fallback).
    func openReleasePage() {
        let url = release?.pageURL ?? URL(string: "https://github.com/\(Self.repository)/releases/latest")!
        NSWorkspace.shared.open(url)
    }
}
