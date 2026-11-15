import Foundation

enum VoiceInputError: Error, Equatable {
    case microphoneDenied

    var userMessage: String {
        String(localized: "未授予麦克风权限，请在「系统设置 → 隐私与安全性 → 麦克风」中允许 OpenType")
    }
}

/// Records one utterance and returns what was said, for the microphone buttons of the Writing Tools panel.
/// It reuses the dictation audio capture and speech recognition services but none of the dictation pipeline.
@MainActor
final class VoiceInputRecorder {
    enum State: Equatable {
        case idle
        /// Capturing (the microphone button is a "stop" button).
        case recording
        /// Capture ended, waiting for the final transcript.
        case transcribing
    }

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    var onStateChange: ((State) -> Void)?

    private let audio: any AudioCapturing
    private let audioInputTarget: () -> AudioInputTarget?
    private let ensureMicrophone: () async -> Bool
    private let makeConfig: () throws -> ASRConfig
    private let makeASR: (ASRConfig) -> any ASRService
    private let correct: (String) -> String

    private var activeASR: (any ASRService)?
    private var stopRequested = false

    init(
        audio: any AudioCapturing,
        audioInputTarget: @escaping () -> AudioInputTarget?,
        ensureMicrophone: @escaping () async -> Bool,
        makeConfig: @escaping () throws -> ASRConfig,
        makeASR: @escaping (ASRConfig) -> any ASRService,
        correct: @escaping (String) -> String = { $0 }
    ) {
        self.audio = audio
        self.audioInputTarget = audioInputTarget
        self.ensureMicrophone = ensureMicrophone
        self.makeConfig = makeConfig
        self.makeASR = makeASR
        self.correct = correct
    }

    var isActive: Bool { state != .idle }

    /// Ends the capture; `record()` then finishes with the transcript.
    func stop() {
        guard state == .recording else { return }
        stopRequested = true
        audio.stop()
    }

    /// Aborts without a result (the surrounding task is cancelled as well).
    func cancel() {
        stopRequested = true
        audio.stop()
        if let asr = activeASR {
            activeASR = nil
            Task { await asr.close() }
        }
    }

    /// Starts capturing and returns the recognised text once `stop()` was called. Empty for an accidental tap.
    func record() async throws -> String {
        guard state == .idle else { return "" }
        state = .recording
        stopRequested = false
        defer { state = .idle; activeASR = nil }

        let config = try makeConfig()
        guard await ensureMicrophone() else { throw VoiceInputError.microphoneDenied }
        try Task.checkCancellation()

        let chunks = try await audio.start(
            inputDevice: audioInputTarget(),
            onLevel: { _ in },
            onInterruption: { [weak self] _ in
                Task { @MainActor in self?.stop() } // device lost: finish with what was heard
            }
        )
        if stopRequested { audio.stop() }

        let asr = makeASR(config)
        activeASR = asr
        let events = Task { () -> (TranscriptAggregator, ASRError?) in
            var aggregator = TranscriptAggregator()
            var failure: ASRError?
            for await event in asr.events {
                switch event {
                case .preview(let id, let text, let stash): aggregator.updatePreview(itemID: id, text: text, stash: stash)
                case .completed(let id, let transcript): aggregator.complete(itemID: id, transcript: transcript)
                case .failed(let error): failure = error
                case .finished: break
                }
            }
            return (aggregator, failure)
        }
        do {
            try await asr.connect()
        } catch {
            audio.stop()
            await asr.close()
            events.cancel()
            throw error
        }

        var sentBytes = 0
        do {
            for await chunk in chunks {
                try Task.checkCancellation()
                try await asr.sendAudio(chunk)
                sentBytes += chunk.count
            }
        } catch {
            audio.stop()
            await asr.close()
            events.cancel()
            throw error
        }
        guard sentBytes >= AudioPipeline.chunkSize * 2 else { // an accidental tap
            await asr.close()
            events.cancel()
            return ""
        }

        state = .transcribing
        do {
            if config.turnDetection == .manual { try await asr.commit() }
            try await asr.finish()
        } catch {
            await asr.close()
            events.cancel()
            throw error
        }
        let timeout = asr.finalizeTimeout
        let watchdog = Task { [asr] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            await asr.close() // ends the event stream so the wait below returns
        }
        let (aggregator, failure) = await events.value
        watchdog.cancel()
        await asr.close()
        try Task.checkCancellation()

        var text = aggregator.finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { text = aggregator.bestEffortText.trimmingCharacters(in: .whitespacesAndNewlines) }
        if text.isEmpty, let failure { throw failure }
        return correct(text)
    }
}
