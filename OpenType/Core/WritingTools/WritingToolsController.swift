import AppKit
import Foundation
import Observation

/// Shows the Writing Tools panel (and the "replaced · undo" toast). Implemented by `WritingToolsPanelController`.
@MainActor
protocol WritingToolsPresenting: AnyObject {
    /// Shows the panel next to the mouse pointer.
    func show(controller: WritingToolsController)
    func hide()
    func showToast(message: String, onUndo: @escaping () -> Void)
}

/// State and logic of the Writing Tools panel: global shortcut → read the selection → pick a tool → model → write back.
/// Every request has a generation number; answers of a request that was cancelled or replaced are dropped.
@MainActor
@Observable
final class WritingToolsController {
    enum Screen: Equatable {
        case menu, compose, loading, result, error
    }

    enum Failure: Equatable {
        /// No profile / API key to talk to.
        case noService
        /// The request itself failed (network, model, rate limit …).
        case failed(String)
    }

    /// The text field a microphone button fills.
    enum VoiceField: Equatable {
        case instruction, composePrompt, refine
    }

    // MARK: Observable state

    private(set) var screen: Screen = .menu
    private(set) var isVisible = false
    /// `true` when text was selected: the full menu is available and the result replaces the selection.
    private(set) var hasSelection = false
    private(set) var selection: String?
    private(set) var tool: WritingTool?
    private(set) var result: WritingResult?
    private(set) var failure: Failure?
    private(set) var copied = false
    private(set) var voiceState: VoiceInputRecorder.State = .idle
    private(set) var voiceField: VoiceField?
    private(set) var voiceError: String?
    /// Counts openings, so the views can move the keyboard focus each time the panel appears.
    private(set) var openCount = 0

    var instruction = ""
    var composePrompt = ""
    var compose = ComposeOptions()
    var translationTarget: TranslationLanguage = .english
    var refineText = ""
    /// Proofreading result: show the inline changes (`true`) or the clean text.
    var showDiff = true
    var showOriginal = false

    // MARK: Dependencies

    @ObservationIgnored let settingsStore: SettingsStore
    @ObservationIgnored private let credentialStore: any CredentialStoring
    @ObservationIgnored private let inserter: any TextInserting
    @ObservationIgnored private let historyStore: HistoryStore
    @ObservationIgnored private let notifier: any UserNotifying
    @ObservationIgnored private let makeLLM: (LLMProfile, String) -> any LLMProvider
    @ObservationIgnored private let recorder: VoiceInputRecorder?
    @ObservationIgnored private let copyToPasteboard: (String) -> Void
    @ObservationIgnored private let isDictationBusy: () -> Bool
    @ObservationIgnored private let setMicrophoneBusy: (Bool) -> Void
    @ObservationIgnored private let openSettingsWindow: () -> Void
    /// Time between hiding the panel and writing back, so the app's own window is key again (⌘V goes to the key window).
    @ObservationIgnored private let applyDelay: Duration
    @ObservationIgnored weak var presenter: (any WritingToolsPresenting)?

    // MARK: Private state

    @ObservationIgnored private var target: InsertionTarget?
    @ObservationIgnored private var request: WritingRequest?
    /// The turns of the last request sent, and (after it succeeded) its answer.
    @ObservationIgnored private var pendingMessages: [LLMMessage] = []
    @ObservationIgnored private var conversation: [LLMMessage] = []
    @ObservationIgnored private var origin: Screen = .menu
    @ObservationIgnored private var previousScreen: Screen = .menu
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var voiceTask: Task<Void, Never>?
    @ObservationIgnored private var openToken = UUID()
    @ObservationIgnored private var isOpening = false
    @ObservationIgnored private var isApplying = false
    @ObservationIgnored private var sessionUsage = TokenUsage.zero
    @ObservationIgnored private var sessionModel: String?
    @ObservationIgnored private var copiedTask: Task<Void, Never>?

    @ObservationIgnored let hotkeyManager: HotkeyManager
    @ObservationIgnored private var hotkeyRetryTask: Task<Void, Never>?

    init(
        settingsStore: SettingsStore,
        credentialStore: any CredentialStoring,
        inserter: any TextInserting,
        historyStore: HistoryStore,
        notifier: any UserNotifying = SystemUserNotifier(),
        makeLLM: @escaping (LLMProfile, String) -> any LLMProvider = { HTTPLLMProvider(profile: $0, apiKey: $1) },
        recorder: VoiceInputRecorder? = nil,
        hotkeyManager: HotkeyManager = HotkeyManager(),
        copyToPasteboard: @escaping (String) -> Void = { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        },
        isDictationBusy: @escaping () -> Bool = { false },
        setMicrophoneBusy: @escaping (Bool) -> Void = { _ in },
        openSettings: @escaping () -> Void = {},
        applyDelay: Duration = .milliseconds(150)
    ) {
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.inserter = inserter
        self.historyStore = historyStore
        self.notifier = notifier
        self.makeLLM = makeLLM
        self.recorder = recorder
        self.hotkeyManager = hotkeyManager
        self.copyToPasteboard = copyToPasteboard
        self.isDictationBusy = isDictationBusy
        self.setMicrophoneBusy = setMicrophoneBusy
        self.openSettingsWindow = openSettings
        self.applyDelay = applyDelay
        recorder?.onStateChange = { [weak self] state in self?.voiceState = state }
    }

    // MARK: - Global shortcut

    /// Wires the Writing Tools shortcut. `isRecordingHotkey` / `otherHotkeys` keep it from firing while another shortcut is
    /// being recorded in Settings or when it equals the dictation / translation shortcut.
    func start(isRecordingHotkey: @escaping () -> Bool, otherHotkeys: @escaping () -> [HotkeyConfig?]) {
        hotkeyManager.hotkey = settingsStore.writingToolsHotkey
        hotkeyManager.isEnabled = { [weak self] in
            guard let self else { return false }
            return settingsStore.writingToolsEnabled && !settingsStore.hotkeysPaused && !isRecordingHotkey()
                && !otherHotkeys().contains(settingsStore.writingToolsHotkey)
        }
        hotkeyManager.onPress = { [weak self] in
            guard let self else { return }
            Task { await self.toggle() }
        }
        hotkeyManager.startListening()
        hotkeyRetryTask?.cancel()
        hotkeyRetryTask = Task { [weak self] in // permissions may be granted later
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard let self else { return }
                hotkeyManager.startListening()
            }
        }
    }

    func applyHotkeySettings() {
        hotkeyManager.hotkey = settingsStore.writingToolsHotkey
    }

    // MARK: - Opening and closing

    /// Shortcut handler: opens the panel for the focused control, or closes it when it is already open.
    func toggle() async {
        if isVisible { close(); return }
        await open()
    }

    func open() async {
        guard settingsStore.writingToolsEnabled, !isDictationBusy(), !isOpening, !isVisible else { return }
        isOpening = true
        defer { isOpening = false }
        let token = UUID()
        openToken = token
        guard let captured = await inserter.captureForWritingTools(), !captured.isSecure, token == openToken else { return }

        resetSession()
        target = captured
        selection = captured.selectedText
        hasSelection = captured.selectedText != nil
        translationTarget = settingsStore.translationTargetLanguage
        origin = hasSelection ? .menu : .compose
        screen = origin
        isVisible = true
        openCount += 1
        Diagnostics.log("writing tools open selection=\(hasSelection) app=\(captured.bundleIdentifier ?? "?")")
        presenter?.show(controller: self)
    }

    /// Esc / the close button: drops everything. Nothing is written.
    func close() {
        openToken = UUID()
        resetSession()
        isVisible = false
        presenter?.hide()
    }

    private func resetSession() {
        generation = UUID()
        generationTask?.cancel()
        generationTask = nil
        stopVoiceInput(cancel: true)
        copiedTask?.cancel()
        screen = .menu
        tool = nil
        result = nil
        failure = nil
        copied = false
        voiceError = nil
        instruction = ""
        composePrompt = ""
        refineText = ""
        showDiff = true
        showOriginal = false
        request = nil
        pendingMessages = []
        conversation = []
        sessionUsage = .zero
        sessionModel = nil
        selection = nil
        hasSelection = false
        target = nil
        isApplying = false
    }

    // MARK: - Navigation

    /// The back button is shown on every screen except the one the panel opened with.
    var showsBackButton: Bool {
        switch screen {
        case .menu: false
        case .compose: hasSelection
        case .error: false // "Try again" / "Open Settings" are the way on; Esc closes
        default: true
        }
    }

    func back() {
        switch screen {
        case .compose: if hasSelection { screen = .menu }
        case .loading, .error:
            generation = UUID() // drop a pending answer
            generationTask?.cancel()
            screen = previousScreen == .result && result == nil ? origin : previousScreen
        case .result: screen = origin
        case .menu: break
        }
    }

    func openCompose() {
        guard hasSelection else { return }
        screen = .compose
    }

    // MARK: - Running tools

    var canSubmitInstruction: Bool { !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canSubmitCompose: Bool { !composePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canSubmitRefine: Bool { !refineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// A one-tap tool of the main menu (everything except the free-form command and Compose).
    func run(_ tool: WritingTool) {
        switch tool {
        case .custom: submitInstruction()
        case .compose: submitCompose()
        default:
            guard let selection else { return }
            var request = WritingRequest(tool: tool, source: selection)
            if tool == .translate {
                request.translationTarget = translationTarget
                request.translationRegion = settingsStore.translationRegion(for: translationTarget)
            }
            origin = .menu
            begin(request, messages: [.user(WritingToolsPrompts.userMessage(for: request))])
        }
    }

    func submitInstruction() {
        guard canSubmitInstruction, let selection else { return }
        let request = WritingRequest(tool: .custom, source: selection, instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines))
        origin = .menu
        begin(request, messages: [.user(WritingToolsPrompts.userMessage(for: request))])
    }

    /// "Generate" (plain text) or "Generate Markdown".
    func submitCompose(markdown: Bool = false) {
        guard canSubmitCompose else { return }
        let request = WritingRequest(
            tool: .compose, source: nil, instruction: composePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            compose: compose, markdown: markdown
        )
        origin = .compose
        begin(request, messages: [.user(WritingToolsPrompts.userMessage(for: request))])
    }

    /// "Keep refining": the previous answer and the new instruction go back to the model as a conversation.
    func submitRefine() {
        guard canSubmitRefine, screen == .result, let request, !conversation.isEmpty else { return }
        let instruction = refineText.trimmingCharacters(in: .whitespacesAndNewlines)
        begin(request, messages: conversation + [.user(WritingToolsPrompts.refineMessage(instruction))])
    }

    /// "Regenerate" / "Try again": the same turns once more.
    func regenerate() {
        guard let request, !pendingMessages.isEmpty else { return }
        begin(request, messages: pendingMessages)
    }

    private func begin(_ request: WritingRequest, messages: [LLMMessage]) {
        self.request = request
        pendingMessages = messages
        tool = request.tool
        if screen != .loading, screen != .error { previousScreen = screen }
        failure = nil
        voiceError = nil
        screen = .loading
        let id = UUID()
        generation = id
        generationTask?.cancel()
        generationTask = Task { [weak self] in await self?.perform(id, request: request, messages: messages) }
    }

    private func perform(_ id: UUID, request: WritingRequest, messages: [LLMMessage]) async {
        do {
            let (provider, profile) = try resolveProvider()
            let output = try await provider.complete(messages: messages, systemPrompt: WritingToolsPrompts.systemPrompt(for: request))
            guard id == generation else { return }
            let answer = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !answer.isEmpty else { throw LLMError.emptyOutput }
            result = WritingToolsPrompts.makeResult(tool: request.tool, source: request.source, output: answer)
            conversation = messages + [.assistant(answer)]
            sessionUsage += output.usage
            sessionModel = profile.modelID
            refineText = ""
            showOriginal = false
            copied = false
            screen = .result
        } catch is CancellationError {
            return
        } catch {
            guard id == generation else { return }
            switch error as? LLMError {
            case .missingAPIKey?, .invalidConfig?: failure = .noService
            case let llmError?: failure = .failed(llmError.userMessage)
            case nil: failure = .failed(error.localizedDescription)
            }
            screen = .error
        }
    }

    /// The Writing Tools profile (own model / effort applied) and its provider. The request may run long on a big
    /// selection, so the timeout is at least 30 s.
    private func resolveProvider() throws -> (any LLMProvider, LLMProfile) {
        guard var profile = settingsStore.writingToolsProfile else { throw LLMError.invalidConfig(String(localized: "未配置 AI 处理 Profile")) }
        // The API key belongs to the profile's own id (the overrides never change it).
        guard let key = try? credentialStore.load(account: CredentialAccount.llmProfile(profile.id)), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        profile.timeout = max(profile.timeout, 30)
        return (makeLLM(profile, key), profile)
    }

    // MARK: - Result actions

    var resultTitle: String {
        switch screen {
        case .menu, .error: return String(localized: "书写工具")
        case .compose: return WritingTool.compose.displayName
        case .loading, .result:
            guard let tool else { return String(localized: "书写工具") }
            if tool == .translate { return "\(tool.displayName) · \(translationTarget.displayName)" }
            return tool.resultTitle
        }
    }

    /// The primary button replaces the selection (a selection exists and the tool edits it) or inserts at the caret.
    var replacesSelection: Bool { hasSelection && tool?.needsSelection == true }

    var canApply: Bool { screen == .result && result != nil && !isApplying }

    func copyResult() {
        guard let text = result?.text else { return }
        copyToPasteboard(text)
        copied = true
        copiedTask?.cancel()
        copiedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.copied = false
        }
    }

    /// Writes the result back into the app the panel was opened from: replaces the selection, or inserts at the caret.
    func apply() async {
        guard canApply, let result, let target else { return }
        isApplying = true
        let text = result.text
        let replacing = replacesSelection
        let source = selection
        let prompt = composePrompt
        let usage = sessionUsage
        let model = sessionModel
        let translationLabel = tool == .translate ? translationTarget.displayName(region: settingsStore.translationRegion(for: translationTarget)) : nil
        let usedTool = tool

        // Hide first so the app's window is key again: pasting goes to the key window.
        openToken = UUID()
        isVisible = false
        presenter?.hide()
        generation = UUID()
        generationTask?.cancel()
        stopVoiceInput(cancel: true)
        if applyDelay > .zero { try? await Task.sleep(for: applyDelay) }

        let outcome = await inserter.insert(text, into: target)
        var delivery = SessionRecord.Delivery.inserted
        switch outcome {
        case .insertedViaAccessibility, .insertedViaPasteboard:
            let message = replacing ? String(localized: "已替换") : String(localized: "已插入")
            presenter?.showToast(message: message) { [inserter] in _ = inserter.sendUndo(to: target) }
        case .requiresManualCopy(let reason), .focusLost(let reason):
            delivery = .manualCopy
            copyToPasteboard(text)
            notifier.notify(
                title: String(localized: "OpenType：结果已复制到剪贴板"),
                body: String(localized: "\(reason)。按 ⌘V 即可粘贴。")
            )
        }
        let keepText = settingsStore.saveHistoryText
        historyStore.add(SessionRecord(
            date: .now, kind: .writingTools,
            rawText: keepText ? (replacing ? source : prompt) : nil,
            finalText: keepText ? text : nil,
            wordCount: TextMetrics.wordCount(text), recordingSeconds: 0,
            usage: usage, model: model, translationLabel: usedTool == .translate ? translationLabel : nil,
            delivery: delivery
        ))
        Diagnostics.log("writing tools applied tool=\(usedTool?.rawValue ?? "?") delivery=\(delivery.rawValue)")
        resetSession()
    }

    func openSettings() {
        close()
        openSettingsWindow()
    }

    // MARK: - Voice input

    /// `true` when the microphone buttons can be used (a dictation session owns the microphone otherwise).
    var voiceInputAvailable: Bool { recorder != nil && !isDictationBusy() }

    /// Microphone button: starts listening, or stops and fills `field` with what was said.
    func toggleVoice(_ field: VoiceField) {
        guard let recorder else { return }
        if voiceState == .recording {
            recorder.stop()
            return
        }
        guard voiceState == .idle, !isDictationBusy() else { return }
        voiceField = field
        voiceError = nil
        setMicrophoneBusy(true)
        voiceTask = Task { [weak self] in
            do {
                let text = try await recorder.record()
                guard let self, !Task.isCancelled else { return }
                insertSpoken(text, into: field)
            } catch is CancellationError {
            } catch {
                guard let self, !Task.isCancelled else { return }
                voiceError = (error as? ASRError)?.userMessage ?? (error as? VoiceInputError)?.userMessage ?? error.localizedDescription
            }
            self?.voiceField = nil
            self?.voiceTask = nil
            self?.setMicrophoneBusy(false)
        }
    }

    private func stopVoiceInput(cancel: Bool) {
        guard let recorder, recorder.isActive || voiceTask != nil else { return }
        if cancel { recorder.cancel() } else { recorder.stop() }
        voiceTask?.cancel()
        voiceTask = nil
        voiceField = nil
        setMicrophoneBusy(false)
    }

    private func insertSpoken(_ text: String, into field: VoiceField) {
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        func merged(_ existing: String) -> String {
            existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? spoken : existing + " " + spoken
        }
        switch field {
        case .instruction: instruction = merged(instruction)
        case .composePrompt: composePrompt = merged(composePrompt)
        case .refine: refineText = merged(refineText)
        }
    }
}
