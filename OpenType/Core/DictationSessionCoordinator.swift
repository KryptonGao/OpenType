import AppKit
import Foundation
import Observation

@MainActor
protocol OverlayPresenting: AnyObject {
    func show(coordinator: DictationSessionCoordinator)
    func hide()
}

enum SessionMode: Sendable {
    case hold    // global hotkey: press & hold
    case toggle  // menu / overlay button: start, then stop explicitly
}

/// Orchestrates hotkey → audio → ASR → LLM → insertion (PRD §2 / §8).
/// Every session has a unique ID; all asynchronous continuations verify it before touching state.
@MainActor
@Observable
final class DictationSessionCoordinator {
    private(set) var state: DictationState = .idle
    private(set) var currentSessionID: UUID?
    private(set) var aggregator = TranscriptAggregator()
    private(set) var audioLevel: Float = 0
    private(set) var levelHistory: [Float] = Array(repeating: 0, count: 28)
    /// Text kept for manual copy (manual-copy result, or recovered text after a failure).
    private(set) var pendingText: String = ""
    private(set) var sessionMode: SessionMode = .hold
    private(set) var hotkeyActive = false
    /// While the settings recorder is capturing a new shortcut the global hotkey must not fire.
    var isRecordingHotkey = false

    @ObservationIgnored let settingsStore: SettingsStore
    @ObservationIgnored let credentialStore: any CredentialStoring
    @ObservationIgnored let hotkeyManager: HotkeyManager
    @ObservationIgnored let permissions: PermissionManager
    @ObservationIgnored private let audio: any AudioCapturing
    @ObservationIgnored private let permissionChecker: any PermissionChecking
    @ObservationIgnored private let makeASR: (ASRConfig) -> any ASRService
    @ObservationIgnored private let makeLLM: (LLMProfile, String) -> any LLMProvider
    @ObservationIgnored private let textProcessor: TextProcessor
    @ObservationIgnored private let inserter: any TextInserting
    @ObservationIgnored private let overlay: (any OverlayPresenting)?
    @ObservationIgnored private let playsSounds: Bool

    @ObservationIgnored private var pipelineTask: Task<Void, Never>?
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var hotkeyRetryTask: Task<Void, Never>?
    @ObservationIgnored private var activeASR: (any ASRService)?
    @ObservationIgnored private var target: InsertionTarget?
    @ObservationIgnored private var stopRequested = false
    @ObservationIgnored private var interruptionNote: String?
    @ObservationIgnored private var overlayToken = UUID()
    @ObservationIgnored private var timings = SessionTimings()

    init(
        settingsStore: SettingsStore = SettingsStore(),
        credentialStore: any CredentialStoring = CredentialStore(),
        hotkeyManager: HotkeyManager = HotkeyManager(),
        permissions: PermissionManager = PermissionManager(),
        audio: any AudioCapturing = AudioCaptureService(),
        permissionChecker: (any PermissionChecking)? = nil,
        makeASR: @escaping (ASRConfig) -> any ASRService = { BailianRealtimeASR(config: $0) },
        makeLLM: @escaping (LLMProfile, String) -> any LLMProvider = { HTTPLLMProvider(profile: $0, apiKey: $1) },
        textProcessor: TextProcessor = TextProcessor(),
        inserter: any TextInserting = TextInsertionService(),
        overlay: (any OverlayPresenting)? = nil,
        playsSounds: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.hotkeyManager = hotkeyManager
        self.permissions = permissions
        self.audio = audio
        self.permissionChecker = permissionChecker ?? permissions
        self.makeASR = makeASR
        self.makeLLM = makeLLM
        self.textProcessor = textProcessor
        self.inserter = inserter
        self.overlay = overlay
        self.playsSounds = playsSounds
    }

    // MARK: - App lifecycle

    /// Wires the global hotkey. The tap needs permissions that may be granted later, so retry in the background.
    func start() {
        hotkeyManager.hotkey = settingsStore.hotkey
        hotkeyManager.isEnabled = { [weak self] in
            guard let self else { return false }
            return !settingsStore.hotkeysPaused && !isRecordingHotkey
        }
        hotkeyManager.shouldInterceptEscape = { [weak self] in (self?.state ?? .idle) != .idle }
        hotkeyManager.onPress = { [weak self] in self?.beginSession(mode: .hold) }
        hotkeyManager.onRelease = { [weak self] in
            guard let self, sessionMode == .hold else { return }
            stopRecording()
        }
        hotkeyManager.onCancel = { [weak self] in self?.cancelSession() }
        hotkeyActive = hotkeyManager.startListening()
        // Permissions can be granted at any time: keep the status fresh and (re)try the event tap.
        hotkeyRetryTask?.cancel()
        hotkeyRetryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard let self else { return }
                permissions.refresh()
                if !hotkeyActive, hotkeyManager.startListening() { hotkeyActive = true }
            }
        }
    }

    func applyHotkeySettings() {
        hotkeyManager.hotkey = settingsStore.hotkey
    }

    // MARK: - Public controls

    /// Menu / button entry point: toggles recording.
    func startSession() { beginSession(mode: .toggle) }

    func toggleFromMenu() {
        if state == .connecting || state == .recording, sessionMode == .toggle {
            stopRecording()
        } else {
            beginSession(mode: .toggle)
        }
    }

    /// Stops capturing and moves on to finalisation (key released / "完成" pressed).
    func stopRecording() {
        guard currentSessionID != nil, state == .connecting || state == .recording else { return }
        stopRequested = true
        audio.stop() // flushes the last partial chunk and ends the audio stream
        playSound("Pop")
    }

    /// Escape / close: aborts everything immediately. Nothing is inserted.
    func cancelSession() {
        teardown()
        pipelineTask?.cancel()
        pipelineTask = nil
        currentSessionID = nil
        dismissTask?.cancel()
        overlayToken = UUID()
        audioLevel = 0
        pendingText = ""
        aggregator = TranscriptAggregator()
        state = .idle
        overlay?.hide()
    }

    func copyPendingText() {
        guard !pendingText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pendingText, forType: .string)
    }

    func clearTemporaryData() {
        guard !state.isBusy else { return }
        cancelSession()
    }

    /// Text shown in normal weight / light weight in the overlay.
    var solidText: String { aggregator.solidText }
    var stashText: String { aggregator.stashText }

    // MARK: - Session start

    func beginSession(mode: SessionMode) {
        guard !state.isBusy else { return }
        dismissTask?.cancel()
        let id = UUID()
        currentSessionID = id
        sessionMode = mode
        aggregator = TranscriptAggregator()
        pendingText = ""
        audioLevel = 0
        levelHistory = Array(repeating: 0, count: levelHistory.count)
        stopRequested = false
        interruptionNote = nil
        timings = SessionTimings(triggeredAt: .now)
        target = inserter.captureTarget()
        state = .connecting
        overlay?.show(coordinator: self)
        playSound("Tink")
        Diagnostics.log("session \(id.uuidString.prefix(8)) begin mode=\(mode)")
        pipelineTask = Task { [weak self] in await self?.runPipeline(id) }
    }

    // MARK: - Pipeline

    private func runPipeline(_ id: UUID) async {
        // 1. Preconditions
        let config: ASRConfig
        do {
            config = try asrConfig()
        } catch let error as ASRError {
            return fail(id, error.userMessage)
        } catch {
            return fail(id, "无法读取语音识别配置")
        }
        guard await permissionChecker.ensureMicrophone() else {
            return fail(id, "未授予麦克风权限，请在「系统设置 → 隐私与安全性 → 麦克风」中允许 OpenType")
        }
        guard isCurrent(id) else { return }

        // 2. Start capturing immediately; chunks queue in the bounded stream while ASR connects.
        let chunks: AsyncStream<Data>
        do {
            chunks = try audio.start(
                onLevel: { [weak self] level in
                    Task { @MainActor in self?.receiveLevel(level, sessionID: id) }
                },
                onInterruption: { [weak self] error in
                    Task { @MainActor in self?.audioInterrupted(error, sessionID: id) }
                }
            )
        } catch let error as AudioCaptureError {
            return fail(id, error.userMessage)
        } catch {
            return fail(id, "无法启动麦克风：\(error.localizedDescription)")
        }
        timings.captureStartedAt = .now
        if stopRequested { audio.stop() } // released while the permission prompt / startup was in flight

        // 3. Connect ASR (session.update → session.updated)
        let asr = makeASR(config)
        activeASR = asr
        eventsTask = Task { [weak self] in
            for await event in asr.events { self?.handleASREvent(event, sessionID: id) }
        }
        do {
            try await asr.connect()
        } catch let error as ASRError {
            return fail(id, error.userMessage)
        } catch {
            return fail(id, ASRError.disconnected(error.localizedDescription).userMessage)
        }
        guard isCurrent(id) else { return await asr.close() }
        timings.connectedAt = .now
        if state == .connecting { state = .recording }

        // 4. Stream audio until the capture stream ends (hotkey released / stop requested).
        var sentBytes = 0
        for await chunk in chunks {
            guard isCurrent(id) else { return }
            do {
                try await asr.sendAudio(chunk)
                sentBytes += chunk.count
            } catch let error as ASRError {
                return handleASRFailure(error, sessionID: id)
            } catch {
                return handleASRFailure(.disconnected(error.localizedDescription), sessionID: id)
            }
        }
        guard isCurrent(id) else { return }
        timings.releasedAt = .now

        // 5. Too little audio (accidental tap): end quietly.
        if sentBytes < AudioPipeline.chunkSize * 2 {
            finishSilently(id)
            return
        }

        // 6. Finalise: flush → session.finish → wait for pending `completed` + `session.finished`.
        state = .finalizing
        do {
            if config.turnDetection == .manual { try await asr.commit() }
            try await asr.finish()
        } catch let error as ASRError {
            return handleASRFailure(error, sessionID: id)
        } catch {
            return handleASRFailure(.disconnected(error.localizedDescription), sessionID: id)
        }
        var timedOut = false
        let watchdog = Task { [asr] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            timedOut = true
            await asr.close() // ends the event stream so the wait below returns
        }
        await eventsTask?.value
        watchdog.cancel()
        guard isCurrent(id), state == .finalizing else { return }
        await asr.close()
        activeASR = nil
        timings.asrFinishedAt = .now

        let rawText = (timedOut ? aggregator.bestEffortText : aggregator.finalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { // no valid speech: skip LLM, insert nothing
            finishSilently(id)
            return
        }

        // 7. LLM post-processing (with fallback to raw text)
        state = .processing
        var finalText = rawText
        var notes: [String] = []
        if let interruptionNote { notes.append(interruptionNote) }
        if timedOut { notes.append("语音识别收尾超时，已使用当前识别内容") }
        do {
            if let (provider, profile) = try resolveLLM() {
                let output = try await textProcessor.process(
                    transcript: rawText,
                    level: settingsStore.processingLevel,
                    basePrompt: profile.systemPrompt,
                    provider: provider
                )
                guard isCurrent(id) else { return }
                finalText = output
            }
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(id) else { return }
            let reason = (error as? LLMError)?.userMessage ?? error.localizedDescription
            if settingsStore.fallbackToRawOnLLMFailure {
                notes.append("AI 整理失败，已使用原文（\(reason)）")
            } else {
                return fail(id, "AI 整理失败：\(reason)", recoverableText: rawText)
            }
        }
        guard isCurrent(id) else { return }
        timings.processedAt = .now

        // 8. Insert
        guard settingsStore.autoInsertEnabled else {
            return showManualCopy(id, text: finalText, reason: "已关闭自动插入", notes: notes)
        }
        state = .inserting
        let outcome = await inserter.insert(finalText, into: target)
        guard isCurrent(id) else { return }
        timings.insertedAt = .now
        switch outcome {
        case .insertedViaAccessibility, .insertedViaPasteboard:
            showSuccess(id, notes: notes)
        case .requiresManualCopy(let reason):
            showManualCopy(id, text: finalText, reason: reason, notes: notes)
        }
    }

    // MARK: - Event handling (all validated against the session ID)

    private func handleASREvent(_ event: ASREvent, sessionID id: UUID) {
        guard isCurrent(id) else { return }
        switch event {
        case .preview(let itemID, let text, let stash):
            aggregator.updatePreview(itemID: itemID, text: text, stash: stash)
        case .completed(let itemID, let transcript):
            aggregator.complete(itemID: itemID, transcript: transcript)
        case .failed(let error):
            handleASRFailure(error, sessionID: id)
        case .finished:
            break
        }
    }

    /// ASR failed / disconnected: never guess missing text; keep what was already recognised.
    private func handleASRFailure(_ error: ASRError, sessionID id: UUID) {
        guard isCurrent(id) else { return }
        let recovered = aggregator.bestEffortText.trimmingCharacters(in: .whitespacesAndNewlines)
        var message = error.userMessage
        if !recovered.isEmpty { message += "。已保留已识别的内容，可复制后重试" }
        else { message += "，请重试" }
        fail(id, message, recoverableText: recovered)
    }

    private func receiveLevel(_ level: Float, sessionID id: UUID) {
        guard isCurrent(id), state == .recording || state == .connecting else { return }
        audioLevel = level
        levelHistory.removeFirst()
        levelHistory.append(level)
    }

    /// Device unplugged / config change / backlog overflow: finish with what we already have.
    private func audioInterrupted(_ error: AudioCaptureError, sessionID id: UUID) {
        guard isCurrent(id), state == .connecting || state == .recording else { return }
        interruptionNote = error.userMessage
        stopRequested = true
        audio.stop()
    }

    // MARK: - Results

    private func showSuccess(_ id: UUID, notes: [String]) {
        guard isCurrent(id) else { return }
        finishActiveWork()
        let note = notes.isEmpty ? nil : notes.joined(separator: "；")
        state = .success(note: note)
        playSound("Glass")
        logTimings()
        currentSessionID = nil
        scheduleDismiss(after: note == nil ? 0.9 : 3.5)
    }

    private func showManualCopy(_ id: UUID, text: String, reason: String, notes: [String]) {
        guard isCurrent(id) else { return }
        finishActiveWork()
        pendingText = text
        let extra = notes.isEmpty ? "" : "（\(notes.joined(separator: "；"))）"
        state = .manualCopy(reason: reason + extra)
        logTimings()
        currentSessionID = nil
        overlayToken = UUID() // stays until the user copies / dismisses it
    }

    private func finishSilently(_ id: UUID) {
        guard isCurrent(id) else { return }
        cancelSession()
    }

    private func fail(_ id: UUID, _ message: String, recoverableText: String = "") {
        guard isCurrent(id) else { return }
        finishActiveWork()
        pipelineTask?.cancel()
        currentSessionID = nil
        audioLevel = 0
        pendingText = recoverableText
        state = .error(message)
        playSound("Basso")
        Diagnostics.log("session failed")
        if recoverableText.isEmpty { scheduleDismiss(after: 6) } else { overlayToken = UUID() }
    }

    private func finishActiveWork() {
        audio.stop()
        eventsTask?.cancel()
        eventsTask = nil
        if let asr = activeASR {
            activeASR = nil
            Task { await asr.close() }
        }
        audioLevel = 0
    }

    private func teardown() { finishActiveWork() }

    private func scheduleDismiss(after seconds: Double) {
        let token = UUID()
        overlayToken = token
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, overlayToken == token, !state.isBusy else { return }
            cancelSession()
        }
    }

    private func isCurrent(_ id: UUID) -> Bool { currentSessionID == id }

    // MARK: - Configuration

    func asrConfig() throws -> ASRConfig {
        let url = try ASRConfig.endpoint(
            region: settingsStore.asrRegion,
            workspaceID: settingsStore.asrWorkspaceID,
            customURL: settingsStore.asrCustomURL
        )
        guard let key = try? credentialStore.load(account: CredentialAccount.bailianAPIKey), !key.isEmpty else {
            throw ASRError.invalidConfig("请先在设置中填写百炼 API Key")
        }
        let detection: ASRConfig.TurnDetection = switch settingsStore.asrTurnDetection {
        case .serverVAD: .serverVAD(threshold: settingsStore.asrVADThreshold, silenceDurationMS: settingsStore.asrSilenceDurationMS)
        case .manual: .manual
        }
        return ASRConfig(url: url, apiKey: key, language: settingsStore.asrLanguage.apiValue, turnDetection: detection)
    }

    private func resolveLLM() throws -> (any LLMProvider, LLMProfile)? {
        guard settingsStore.llmEnabled, settingsStore.processingLevel != .raw else { return nil }
        guard let profile = settingsStore.activeProfile else { throw LLMError.invalidConfig("未配置 AI 处理 Profile") }
        guard let key = try? credentialStore.load(account: CredentialAccount.llmProfile(profile.id)), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        return (makeLLM(profile, key), profile)
    }

    // MARK: - Connection tests (Settings)

    func testASRConnection() async throws {
        let asr = makeASR(try asrConfig())
        do {
            try await asr.connect()
            await asr.close()
        } catch {
            await asr.close()
            throw error
        }
    }

    /// Sends a tiny sample through the profile's adapter. Distinguishes auth / model / network / format errors.
    func testLLMConnection(profile: LLMProfile) async throws -> String {
        guard let key = try? credentialStore.load(account: CredentialAccount.llmProfile(profile.id)), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        return try await makeLLM(profile, key).process(
            transcript: "嗯那个今天天气呃很好我们去公园",
            systemPrompt: TextProcessor.systemPrompt(base: profile.systemPrompt, level: .standard)
        )
    }

    // MARK: - Helpers

    private func playSound(_ name: String) {
        guard playsSounds, settingsStore.soundFeedbackEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func logTimings() {
        guard Diagnostics.isEnabled else { return }
        Diagnostics.log(timings.summary)
    }
}

/// Per-phase timings for troubleshooting. Contains no speech content.
struct SessionTimings {
    var triggeredAt: ContinuousClock.Instant = .now
    var captureStartedAt: ContinuousClock.Instant?
    var connectedAt: ContinuousClock.Instant?
    var releasedAt: ContinuousClock.Instant?
    var asrFinishedAt: ContinuousClock.Instant?
    var processedAt: ContinuousClock.Instant?
    var insertedAt: ContinuousClock.Instant?

    var summary: String {
        func ms(_ from: ContinuousClock.Instant?, _ to: ContinuousClock.Instant?) -> String {
            guard let from, let to else { return "-" }
            return "\(Int((to - from) / .milliseconds(1)))ms"
        }
        return """
        timings keyToCapture=\(ms(triggeredAt, captureStartedAt)) connect=\(ms(captureStartedAt, connectedAt)) \
        asrFinalize=\(ms(releasedAt, asrFinishedAt)) llm=\(ms(asrFinishedAt, processedAt)) \
        insert=\(ms(processedAt, insertedAt)) releaseToInserted=\(ms(releasedAt, insertedAt))
        """
    }
}
