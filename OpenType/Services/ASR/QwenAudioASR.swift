import Foundation

/// Aliyun Bailian `qwen-audio-3.1-asr-flash-message` WebSocket client (DashScope `run-task` protocol).
///
/// Flow: `run-task` → `task-started` → binary PCM frames (16 kHz mono) → `finish-task` → `task-finished`.
/// Results arrive as `result-generated`; with `intermediate_result_enabled` each sentence is first streamed as
/// revisable intermediate results (`sentence_end == false`) and then closed by a final one (`sentence_end == true`).
/// Intermediate results map to `.preview` and final ones to `.completed`, keyed by `sentence_id`.
actor QwenAudioMessageASR: ASRService {
    static let sampleRate = 16_000

    nonisolated let events: AsyncStream<ASREvent>
    private let continuation: AsyncStream<ASREvent>.Continuation
    private let config: ASRConfig
    private let taskID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    private var urlSession: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var closed = false
    private var abortReason: ASRError?

    init(config: ASRConfig) {
        self.config = config
        let (stream, continuation) = AsyncStream.makeStream(of: ASREvent.self)
        self.events = stream
        self.continuation = continuation
    }

    // MARK: ASRService

    func connect() async throws {
        guard config.url.scheme?.lowercased() == "wss" else {
            throw ASRError.invalidConfig("仅允许 wss:// 连接")
        }
        var request = URLRequest(url: config.url)
        request.timeoutInterval = 10
        // Credentials only in the handshake header — never in the URL.
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .ephemeral)
        let socket = session.webSocketTask(with: request)
        self.urlSession = session
        self.socket = socket
        socket.resume()

        let watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            await self?.abort(.timeout)
        }
        defer { watchdog.cancel() }

        do {
            try await sendJSON(Self.runTaskPayload(config: config, taskID: taskID))
            while true {
                let message = try await socket.receive()
                guard let object = Self.decode(message) else { continue }
                switch Self.event(of: object) {
                case "task-started":
                    startReceiveLoop(socket)
                    return
                case "task-failed":
                    throw ASRError.server(Self.errorText(object))
                default:
                    continue
                }
            }
        } catch {
            let mapped = mapTransportError(error)
            await close()
            throw mapped
        }
    }

    func sendAudio(_ pcm: Data) async throws {
        guard let socket, !closed else { throw ASRError.disconnected("连接已关闭") }
        do {
            try await socket.send(.data(pcm))
        } catch {
            throw mapTransportError(error)
        }
    }

    /// Sentence boundaries come from the server-side VAD; there is no manual commit.
    func commit() async throws {}

    func finish() async throws {
        try await sendJSON(Self.finishTaskPayload(taskID: taskID))
    }

    func close() async {
        guard !closed else { return }
        closed = true
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        continuation.finish()
    }

    // MARK: Payloads (static for unit tests)

    static func runTaskPayload(config: ASRConfig, taskID: String) -> [String: Any] {
        var parameters: [String: Any] = [
            "format": "pcm",
            "sample_rate": sampleRate,
            // Live preview while speaking; revisable, replaced by the final result of the sentence.
            "intermediate_result_enabled": true,
            // Filler words / repeated words removal and polishing (final results).
            "disfluency_removal_enabled": config.disfluencyRemoval
        ]
        if let language = config.language {
            parameters["language_hints"] = [language]
        }
        // Default is to write dialects as Mandarin; Cantonese users want the Cantonese wording.
        if config.keepDialect { parameters["keep_dialect"] = true }
        switch config.turnDetection {
        case .serverVAD(let threshold, let silence):
            parameters["speech_noise_threshold"] = threshold
            parameters["max_sentence_silence"] = silence
        case .manual:
            parameters["max_sentence_silence"] = 6000 // longest allowed: split only on long pauses
        }
        return [
            "header": ["action": "run-task", "task_id": taskID, "streaming": "duplex"],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": ASRModel.qwenAudio31Message.apiName,
                "parameters": parameters,
                "input": [String: Any]()
            ] as [String: Any]
        ]
    }

    static func finishTaskPayload(taskID: String) -> [String: Any] {
        [
            "header": ["action": "finish-task", "task_id": taskID, "streaming": "duplex"],
            "payload": ["input": [String: Any]()]
        ]
    }

    /// Maps a decoded server message to the ASR event it produces (`nil` for events that need no action).
    static func asrEvent(from object: [String: Any]) -> ASREvent? {
        switch event(of: object) {
        case "result-generated":
            let payload = object["payload"] as? [String: Any]
            let output = payload?["output"] as? [String: Any]
            guard let sentence = output?["sentence"] as? [String: Any] else { return nil }
            if sentence["heartbeat"] as? Bool == true { return nil }
            let text = sentence["text"] as? String ?? ""
            let id = String(describing: sentence["sentence_id"] ?? "")
            if sentence["sentence_end"] as? Bool == true {
                return .completed(itemID: id, transcript: text)
            }
            return .preview(itemID: id, text: text, stash: "")
        case "task-finished":
            return .finished
        case "task-failed":
            return .failed(.server(errorText(object)))
        default:
            return nil
        }
    }

    // MARK: Internals

    private func sendJSON(_ payload: [String: Any]) async throws {
        guard let socket, !closed else { throw ASRError.disconnected("连接已关闭") }
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else { return }
        do {
            try await socket.send(.string(text))
        } catch {
            throw mapTransportError(error)
        }
    }

    private func startReceiveLoop(_ socket: URLSessionWebSocketTask) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    guard let self else { return }
                    if await self.handle(message) { return }
                } catch {
                    await self?.receiveFailed(error)
                    return
                }
            }
        }
    }

    /// Returns `true` when the task is over and the loop should stop.
    private func handle(_ message: URLSessionWebSocketTask.Message) -> Bool {
        guard let object = Self.decode(message), let event = Self.asrEvent(from: object) else { return false }
        continuation.yield(event)
        switch event {
        case .failed, .finished:
            continuation.finish()
            return true
        default:
            return false
        }
    }

    private func receiveFailed(_ error: Error) {
        guard !closed else { return }
        continuation.yield(.failed(mapTransportError(error)))
        continuation.finish()
    }

    private func abort(_ reason: ASRError) {
        abortReason = reason
        socket?.cancel(with: .goingAway, reason: nil)
    }

    private func mapTransportError(_ error: Error) -> ASRError {
        if let asr = error as? ASRError { return asr }
        if let abortReason { return abortReason }
        if let http = socket?.response as? HTTPURLResponse {
            switch http.statusCode {
            case 401, 403: return .auth(http.statusCode)
            case 429: return .rateLimited
            case 200..<300, 101: break
            default: return .server("HTTP \(http.statusCode)")
            }
        }
        if (error as? URLError)?.code == .timedOut { return .timeout }
        return .disconnected(error.localizedDescription)
    }

    private static func event(of object: [String: Any]) -> String? {
        (object["header"] as? [String: Any])?["event"] as? String
    }

    private static func decode(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func errorText(_ object: [String: Any]) -> String {
        let header = object["header"] as? [String: Any]
        let message = header?["error_message"] as? String
            ?? (object["payload"] as? [String: Any])?["message"] as? String
            ?? "未知错误"
        if let code = header?["error_code"] as? String { return "\(message) (\(code))" }
        return message
    }
}
