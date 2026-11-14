import AppKit
import Foundation
import Observation

@MainActor
protocol OverlayPresenting: AnyObject {
    func show(coordinator: DictationSessionCoordinator)
    func hide()
}

enum SessionMode: Sendable {
    case hold    // press & hold: release ends the recording (used by "help me say")
    case toggle  // global hotkey / menu / overlay button: start, then stop explicitly
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
    private(set) var sessionMode: SessionMode = .toggle
    private(set) var hotkeyActive = false
    /// Non-nil while the current session translates the dictation into this language.
    /// Pre-set from Settings when the session starts; the overlay popup may change it until processing begins.
    private(set) var translationTarget: TranslationLanguage?
    /// Regional variant of `translationTarget` (e.g. Brazil vs. Portugal); `nil` for languages without variants.
    private(set) var translationRegion: TranslationRegion?
    /// `true` while the current session is "help me say": the speech is turned into a polished, elaborated message.
    /// Combined with `translationTarget` it is "translate help me say": the finished message is written in that language.
    private(set) var isHelpMeSay = false
    /// Live line while the model searches the web during "help me say" (e.g. "正在搜索「…」 · 已搜到 8 条结果").
    private(set) var webSearchStatus: String?
    /// While the settings recorder is capturing a new shortcut the global hotkey must not fire.
    var isRecordingHotkey = false

    @ObservationIgnored let settingsStore: SettingsStore
    @ObservationIgnored let credentialStore: any CredentialStoring
    @ObservationIgnored let hotkeyManager: HotkeyManager
    @ObservationIgnored let translationHotkeyManager: HotkeyManager
    @ObservationIgnored let permissions: PermissionManager
    @ObservationIgnored let historyStore: HistoryStore
    @ObservationIgnored private let audio: any AudioCapturing
    @ObservationIgnored private let permissionChecker: any PermissionChecking
    @ObservationIgnored private let makeASR: (ASRConfig) -> any ASRService
    @ObservationIgnored private let makeLLM: (LLMProfile, String) -> any LLMProvider
    @ObservationIgnored private let textProcessor: TextProcessor
    @ObservationIgnored private let inserter: any TextInserting
    @ObservationIgnored private let overlay: (any OverlayPresenting)?
    @ObservationIgnored private let notifier: any UserNotifying
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
    /// The session the current hotkey press started; only that one may be upgraded to help-me-say by a long press.
    @ObservationIgnored private var holdCandidateID: UUID?
    /// The user is still holding the shortcut of a help-me-say session: releasing it ends the recording.
    @ObservationIgnored private var helpMeSayHolding = false

    init(
        settingsStore: SettingsStore = SettingsStore(),
        credentialStore: any CredentialStoring = CredentialStore(),
        hotkeyManager: HotkeyManager = HotkeyManager(),
        translationHotkeyManager: HotkeyManager = HotkeyManager(),
        permissions: PermissionManager = PermissionManager(),
        historyStore: HistoryStore = HistoryStore(), // in memory unless the app passes a file-backed one
        audio: any AudioCapturing = AudioCaptureService(),
        permissionChecker: (any PermissionChecking)? = nil,
        makeASR: @escaping (ASRConfig) -> any ASRService = { config in
            switch config.provider {
            case .bailian:
                switch config.model {
                case .qwen3Realtime: BailianRealtimeASR(config: config)
                case .qwenAudio31Message: QwenAudioMessageASR(config: config)
                }
            case .deepseek: DeepSeekASR(config: config)
            }
        },
        makeLLM: @escaping (LLMProfile, String) -> any LLMProvider = { HTTPLLMProvider(profile: $0, apiKey: $1) },
        textProcessor: TextProcessor = TextProcessor(),
        inserter: any TextInserting = TextInsertionService(),
        overlay: (any OverlayPresenting)? = nil,
        notifier: any UserNotifying = SystemUserNotifier(),
        playsSounds: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.hotkeyManager = hotkeyManager
        self.translationHotkeyManager = translationHotkeyManager
        self.permissions = permissions
        self.historyStore = historyStore
        self.audio = audio
        self.permissionChecker = permissionChecker ?? permissions
        self.makeASR = makeASR
        self.makeLLM = makeLLM
        self.textProcessor = textProcessor
        self.inserter = inserter
        self.overlay = overlay
        self.notifier = notifier
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
        // Tap-to-toggle: the first press starts dictation, the next press ends it. Key release is ignored.
        hotkeyManager.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkeyManager.onCancel = { [weak self] in self?.cancelSession() }
        // Hold the dictation shortcut: "help me say" (push-to-talk; releasing ends the recording).
        hotkeyManager.onLongPress = { [weak self] in self?.handleHotkeyLongPress() ?? false }
        hotkeyManager.onRelease = { [weak self] in self?.handleHotkeyRelease() }
        // Second shortcut: same tap-to-toggle behaviour, but the session translates the speech.
        // Holding it is "translate help me say" (push-to-talk, like holding the dictation shortcut).
        translationHotkeyManager.hotkey = settingsStore.translationHotkey ?? .defaultTranslation
        translationHotkeyManager.isEnabled = { [weak self] in
            guard let self, let shortcut = settingsStore.translationHotkey else { return false }
            return !settingsStore.hotkeysPaused && !isRecordingHotkey && shortcut != settingsStore.hotkey
        }
        translationHotkeyManager.onPress = { [weak self] in self?.handleTranslationHotkeyPress() }
        translationHotkeyManager.onLongPress = { [weak self] in self?.handleTranslationHotkeyLongPress() ?? false }
        translationHotkeyManager.onRelease = { [weak self] in self?.handleHotkeyRelease() }
        translationHotkeyManager.onCancel = { [weak self] in self?.cancelSession() }
        translationHotkeyManager.shouldInterceptEscape = { [weak self] in (self?.state ?? .idle) != .idle }
        hotkeyActive = hotkeyManager.startListening()
        translationHotkeyManager.startListening()
        // Permissions can be granted at any time: keep the status fresh and (re)try the event tap.
        hotkeyRetryTask?.cancel()
        hotkeyRetryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard let self else { return }
                permissions.refresh()
                if !hotkeyActive, hotkeyManager.startListening() { hotkeyActive = true }
                translationHotkeyManager.startListening()
            }
        }
    }

    /// Global hotkey press: starts a session when idle, ends the recording when one is running.
    func handleHotkeyPress() {
        if state == .connecting || state == .recording {
            stopRecording()
        } else {
            let canStart = !state.isBusy
            beginSession(mode: .toggle)
            holdCandidateID = canStart ? currentSessionID : nil
        }
    }

    /// The dictation shortcut was held past the long-press threshold: turns the session into "help me say".
    /// Chord shortcuts already started a session on key-down, so it is upgraded in place; modifier-only
    /// shortcuts only report a press on release, so there a long press starts the session itself.
    /// Returns whether the hold was claimed (the matching release then ends the recording).
    func handleHotkeyLongPress() -> Bool { upgradeToHelpMeSay(translating: false) }

    /// The translation shortcut was held: the same, but the finished message is written in the target language.
    func handleTranslationHotkeyLongPress() -> Bool { upgradeToHelpMeSay(translating: true) }

    private func upgradeToHelpMeSay(translating: Bool) -> Bool {
        guard settingsStore.helpMeSayEnabled else { return false }
        if let id = holdCandidateID, id == currentSessionID, state == .connecting || state == .recording, !isHelpMeSay {
            // The key press started this session itself, so its translation target already matches the shortcut.
            isHelpMeSay = true
            helpMeSayHolding = true
            sessionMode = .hold
            playSound("Tink")
            Diagnostics.log("session \(id.uuidString.prefix(8)) upgraded to help-me-say translate=\(translating)")
            return true
        }
        if !state.isBusy {
            beginSession(mode: .hold, translating: translating, helpMeSay: true)
            helpMeSayHolding = state == .connecting
            return helpMeSayHolding
        }
        return false
    }

    /// The dictation shortcut was released: ends a held help-me-say recording (push-to-talk).
    func handleHotkeyRelease() {
        holdCandidateID = nil
        guard helpMeSayHolding else { return }
        helpMeSayHolding = false
        stopRecording()
    }

    /// Translation shortcut: starts a translation session when idle, ends the recording when one is running.
    func handleTranslationHotkeyPress() {
        if state == .connecting || state == .recording {
            stopRecording()
        } else {
            let canStart = !state.isBusy
            beginSession(mode: .toggle, translating: true)
            holdCandidateID = canStart ? currentSessionID : nil
        }
    }

    func applyHotkeySettings() {
        hotkeyManager.hotkey = settingsStore.hotkey
        translationHotkeyManager.hotkey = settingsStore.translationHotkey ?? .defaultTranslation
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

    /// Menu entry point for voice translation: toggles recording like `toggleFromMenu`.
    func toggleTranslationFromMenu() {
        if state == .connecting || state == .recording, sessionMode == .toggle {
            stopRecording()
        } else {
            beginSession(mode: .toggle, translating: true)
        }
    }

    /// Menu entry point for "help me say": toggles recording like `toggleFromMenu` (for when holding a key is inconvenient).
    func toggleHelpMeSayFromMenu() {
        if state == .connecting || state == .recording, sessionMode == .toggle {
            stopRecording()
        } else {
            beginSession(mode: .toggle, helpMeSay: true)
        }
    }

    /// Menu entry point for "translate help me say" (for when holding a key is inconvenient).
    func toggleTranslatedHelpMeSayFromMenu() {
        if state == .connecting || state == .recording, sessionMode == .toggle {
            stopRecording()
        } else {
            beginSession(mode: .toggle, translating: true, helpMeSay: true)
        }
    }

    /// Switches the translation language from the overlay popup. Only possible until the LLM step starts.
    /// The region falls back to the one configured in Settings for that language.
    func setTranslationTarget(_ language: TranslationLanguage) {
        guard translationTarget != nil, canChangeTranslationTarget else { return }
        translationTarget = language
        translationRegion = settingsStore.translationRegion(for: language)
    }

    /// Switches the regional variant (only variants of the current target language are accepted).
    func setTranslationRegion(_ region: TranslationRegion) {
        guard let target = translationTarget, canChangeTranslationTarget, target.regions.contains(region) else { return }
        translationRegion = region
    }

    var canChangeTranslationTarget: Bool {
        translationTarget != nil && (state == .connecting || state == .recording || state == .finalizing)
    }

    /// Stops capturing and moves on to finalisation (hotkey pressed again / "完成" pressed).
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
        translationTarget = nil
        translationRegion = nil
        isHelpMeSay = false
        helpMeSayHolding = false
        holdCandidateID = nil
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

    func beginSession(mode: SessionMode, translating: Bool = false, helpMeSay: Bool = false) {
        guard !state.isBusy else { return }
        dismissTask?.cancel()
        let id = UUID()
        currentSessionID = id
        sessionMode = mode
        isHelpMeSay = helpMeSay
        helpMeSayHolding = false
        holdCandidateID = nil
        translationTarget = translating ? settingsStore.translationTargetLanguage : nil
        translationRegion = translationTarget.flatMap { settingsStore.translationRegion(for: $0) }
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
        Diagnostics.log("session \(id.uuidString.prefix(8)) begin mode=\(mode) translate=\(translating) helpMeSay=\(helpMeSay)")
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
            return fail(id, String(localized: "无法读取语音识别配置"))
        }
        guard await permissionChecker.ensureMicrophone() else {
            return fail(id, String(localized: "未授予麦克风权限，请在「系统设置 → 隐私与安全性 → 麦克风」中允许 OpenType"))
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
            return fail(id, String(localized: "无法启动麦克风：\(error.localizedDescription)"))
        }
        timings.captureStartedAt = .now
        if stopRequested { audio.stop() } // stop requested while the permission prompt / startup was in flight

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

        // 4. Stream audio until the capture stream ends (stop requested).
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
        let finalizeTimeout = asr.finalizeTimeout
        let watchdog = Task { [asr] in
            try? await Task.sleep(for: finalizeTimeout)
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

        // 7. LLM post-processing (with fallback to raw text), or translation
        state = .processing
        var finalText = rawText
        var usage = TokenUsage.zero
        var modelName: String?
        var notes: [String] = []
        if let interruptionNote { notes.append(interruptionNote) }
        if timedOut { notes.append(String(localized: "语音识别收尾超时，已使用当前识别内容")) }
        if isHelpMeSay {
            // Always needs the LLM (like translation), regardless of the cleanup switches.
            do {
                let level = settingsStore.helpMeSayWebSearchLevel // nil: off (switch off or 0 %)
                // With web search the request goes to DeepSeek with its own key, independent of the active Profile.
                let provider: any LLMProvider
                var profileModel: String?
                if level != nil {
                    provider = try resolveWebSearchProvider()
                } else {
                    let resolved = try resolveProvider()
                    provider = resolved.0
                    profileModel = resolved.1.modelID
                }
                var prompt = TextProcessor.helpMeSaySystemPrompt(custom: settingsStore.helpMeSayPrompt)
                if let target = translationTarget { // "translate help me say": language and region are locked from here on
                    prompt += "\n" + TextProcessor.helpMeSayTranslationAddendum(target: target, region: translationRegion)
                }
                if let level { prompt += "\n" + TextProcessor.webSearchAddendum(for: level) }
                if let level {
                    webSearchStatus = WebSearchProgress().statusText
                    let result = try await provider.processWithWebSearch(
                        transcript: rawText, systemPrompt: prompt, level: level,
                        onProgress: { [weak self] progress in
                            Task { @MainActor in self?.updateWebSearchStatus(progress, sessionID: id) }
                        }
                    )
                    webSearchStatus = nil
                    guard isCurrent(id) else { return }
                    finalText = result.text
                    usage = result.usage
                    modelName = LLMProfile.deepSeekWebSearchModel
                    notes.append(result.progress.madeAnyCall ? String(localized: "已联网搜索：\(result.progress.summary)") : String(localized: "模型未联网搜索"))
                } else {
                    let output = try await provider.processWithUsage(transcript: rawText, systemPrompt: prompt)
                    guard isCurrent(id) else { return }
                    finalText = output.text
                    usage = output.usage
                    modelName = profileModel
                }
            } catch is CancellationError {
                return
            } catch {
                guard isCurrent(id) else { return }
                let reason = (error as? LLMError)?.userMessage ?? error.localizedDescription
                // Like plain translation, never insert untranslated text silently.
                if settingsStore.fallbackToRawOnLLMFailure, translationTarget == nil {
                    notes.append(String(localized: "帮我说失败，已使用识别原文（\(reason)）"))
                } else {
                    return fail(id, String(localized: "\(helpMeSayName)失败：\(reason)。已保留识别原文，可复制后重试"), recoverableText: rawText)
                }
            }
        } else if let target = translationTarget { // language and region are locked from here on (state is .processing)
            let region = translationRegion
            do {
                let (provider, profile) = try resolveProvider()
                let output = try await provider.processWithUsage(
                    transcript: rawText,
                    systemPrompt: TextProcessor.translationSystemPrompt(target: target, region: region)
                )
                guard isCurrent(id) else { return }
                finalText = output.text
                usage = output.usage
                modelName = profile.modelID
            } catch is CancellationError {
                return
            } catch {
                guard isCurrent(id) else { return }
                // Never insert untranslated text silently: keep the recognised text for manual copy instead.
                let reason = (error as? LLMError)?.userMessage ?? error.localizedDescription
                return fail(id, String(localized: "翻译失败：\(reason)。已保留识别原文，可复制后重试"), recoverableText: rawText)
            }
        } else {
            do {
                if let (provider, profile) = try resolveLLM() {
                    let output = try await textProcessor.processWithUsage(
                        transcript: rawText,
                        level: settingsStore.processingLevel,
                        basePrompt: profile.systemPrompt,
                        provider: provider
                    )
                    guard isCurrent(id) else { return }
                    finalText = output.text
                    usage = output.usage
                    modelName = profile.modelID
                }
            } catch is CancellationError {
                return
            } catch {
                guard isCurrent(id) else { return }
                let reason = (error as? LLMError)?.userMessage ?? error.localizedDescription
                if settingsStore.fallbackToRawOnLLMFailure {
                    notes.append(String(localized: "AI 整理失败，已使用原文（\(reason)）"))
                } else {
                    return fail(id, String(localized: "AI 整理失败：\(reason)"), recoverableText: rawText)
                }
            }
        }
        guard isCurrent(id) else { return }
        timings.processedAt = .now

        // 8. Insert
        let record = makeRecord(rawText: rawText, finalText: finalText, usage: usage, model: modelName)
        guard settingsStore.autoInsertEnabled else {
            history(record, delivery: .manualCopy)
            return showManualCopy(id, text: finalText, reason: String(localized: "已关闭自动插入"), notes: notes)
        }
        state = .inserting
        let outcome = await inserter.insert(finalText, into: target)
        guard isCurrent(id) else { return }
        timings.insertedAt = .now
        switch outcome {
        case .insertedViaAccessibility, .insertedViaPasteboard:
            history(record, delivery: .inserted)
            showSuccess(id, notes: notes)
        case .requiresManualCopy(let reason):
            history(record, delivery: .manualCopy)
            showManualCopy(id, text: finalText, reason: reason, notes: notes)
        case .focusLost(let reason):
            // Focus left the input box: never write elsewhere. Put the result on the clipboard and tell the user.
            history(record, delivery: .manualCopy)
            showManualCopy(id, text: finalText, reason: String(localized: "\(reason)，结果已复制到剪贴板"), notes: notes)
            copyPendingText()
            notifier.notify(title: String(localized: "OpenType：结果已复制到剪贴板"), body: String(localized: "\(reason)。按 ⌘V 即可粘贴。"))
            playSound("Glass")
        }
    }

    // MARK: - History

    private func makeRecord(rawText: String, finalText: String, usage: TokenUsage, model: String?) -> SessionRecord {
        let keepText = settingsStore.saveHistoryText
        var seconds = 0.0
        if let start = timings.captureStartedAt, let end = timings.releasedAt {
            seconds = Double((end - start) / .milliseconds(1)) / 1000
        }
        let kind: SessionKind = isHelpMeSay ? .helpMeSay : (translationTarget != nil ? .translation : .dictation)
        return SessionRecord(
            date: .now,
            kind: kind,
            rawText: keepText ? rawText : nil,
            finalText: keepText ? finalText : nil,
            wordCount: TextMetrics.wordCount(finalText),
            recordingSeconds: max(seconds, 0),
            usage: usage,
            model: model,
            translationLabel: translationTarget.map { $0.displayName(region: translationRegion) },
            delivery: .inserted
        )
    }

    private func history(_ record: SessionRecord, delivery: SessionRecord.Delivery) {
        var record = record
        record.delivery = delivery
        historyStore.add(record)
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
        if !recovered.isEmpty { message += String(localized: "。已保留已识别的内容，可复制后重试") }
        else { message += String(localized: "，请重试") }
        fail(id, message, recoverableText: recovered)
    }

    private func updateWebSearchStatus(_ progress: WebSearchProgress, sessionID id: UUID) {
        guard isCurrent(id), state == .processing else { return }
        webSearchStatus = progress.statusText
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
        let extra = notes.isEmpty ? "" : String(localized: "（\(notes.joined(separator: String(localized: "；")))）")
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
        webSearchStatus = nil
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

    /// "帮我说", or "翻译帮我说" when the session also translates.
    var helpMeSayName: String { translationTarget == nil ? String(localized: "帮我说") : String(localized: "翻译帮我说") }

    private func isCurrent(_ id: UUID) -> Bool { currentSessionID == id }

    // MARK: - Configuration

    func asrConfig() throws -> ASRConfig {
        if settingsStore.asrProvider == .deepseek {
            guard let key = try? credentialStore.load(account: CredentialAccount.deepseekASRAPIKey), !key.isEmpty else {
                throw ASRError.invalidConfig(String(localized: "请先在设置中填写 DeepSeek API Key"))
            }
            return ASRConfig(url: DeepSeekASR.endpoint, apiKey: key, language: nil, turnDetection: .manual, provider: .deepseek)
        }
        let url = try ASRConfig.endpoint(
            region: settingsStore.asrRegion,
            workspaceID: settingsStore.asrWorkspaceID,
            customURL: settingsStore.asrCustomURL,
            model: settingsStore.asrModel
        )
        guard let key = try? credentialStore.load(account: CredentialAccount.bailianAPIKey), !key.isEmpty else {
            throw ASRError.invalidConfig(String(localized: "请先在设置中填写百炼 API Key"))
        }
        let detection: ASRConfig.TurnDetection = switch settingsStore.asrTurnDetection {
        case .serverVAD: .serverVAD(threshold: settingsStore.asrVADThreshold, silenceDurationMS: settingsStore.asrSilenceDurationMS)
        case .manual: .manual
        }
        switch settingsStore.asrModel {
        case .qwen3Realtime:
            return ASRConfig(url: url, apiKey: key, language: settingsStore.asrLanguage.apiValue, turnDetection: detection)
        case .qwenAudio31Message:
            // Sentence splitting is always server-side VAD; "manual" is not available for this model.
            let vad: ASRConfig.TurnDetection = .serverVAD(
                threshold: settingsStore.asrVADThreshold, silenceDurationMS: settingsStore.asrSilenceDurationMS
            )
            return ASRConfig(
                url: url, apiKey: key, language: settingsStore.asrLanguage.qwenAudioHint, turnDetection: vad,
                model: .qwenAudio31Message,
                disfluencyRemoval: settingsStore.asrDisfluencyRemoval,
                keepDialect: settingsStore.asrLanguage == .yue
            )
        }
    }

    private func resolveLLM() throws -> (any LLMProvider, LLMProfile)? {
        guard settingsStore.llmEnabled, settingsStore.processingLevel != .raw else { return nil }
        return try resolveProvider()
    }

    /// The active profile's provider, regardless of the AI-processing switches (translation always needs the LLM).
    private func resolveProvider() throws -> (any LLMProvider, LLMProfile) {
        guard let profile = settingsStore.activeProfile else { throw LLMError.invalidConfig(String(localized: "未配置 AI 处理 Profile")) }
        guard let key = try? credentialStore.load(account: CredentialAccount.llmProfile(profile.id)), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        return (makeLLM(profile, key), profile)
    }

    /// Fixed DeepSeek endpoint / model with the dedicated web-search API key.
    private func resolveWebSearchProvider() throws -> any LLMProvider {
        guard let key = try? credentialStore.load(account: CredentialAccount.deepseekWebSearchAPIKey), !key.isEmpty else {
            throw LLMError.invalidConfig(String(localized: "未填写联网搜索的 DeepSeek API Key"))
        }
        return makeLLM(LLMProfile.makeDeepSeekWebSearch(), key)
    }

    // MARK: - Connection tests (Settings)

    func testASRConnection() async throws {
        try await makeASR(try asrConfig()).probe()
    }

    /// Sends a tiny sample through the profile's adapter. Distinguishes auth / model / network / format errors.
    /// Sends a tiny request to DeepSeek with the web-search tool declared, using the dedicated key.
    func testWebSearchConnection() async throws -> String {
        try await resolveWebSearchProvider().processWithWebSearch(
            transcript: "嗯那个今天天气呃很好我们去公园",
            systemPrompt: TextProcessor.systemPrompt(base: "", level: .standard),
            level: settingsStore.helpMeSayWebSearchLevel ?? .aggressive,
            onProgress: { _ in }
        ).text
    }

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
