import Foundation

enum ASRError: Error, Equatable, Sendable {
    case invalidConfig(String)
    case auth(Int)              // 401 / 403
    case rateLimited            // 429
    case timeout
    case disconnected(String)
    case server(String)         // `error` event
    case transcriptionFailed(String)

    var userMessage: String {
        switch self {
        case .invalidConfig(let detail): "语音识别配置无效：\(detail)"
        case .auth(let code): "语音识别鉴权失败（HTTP \(code)），请检查 API Key（百炼还需检查 Workspace ID）"
        case .rateLimited: "语音识别被限流（429），请稍后重试"
        case .timeout: "连接语音识别服务超时"
        case .disconnected(let detail): "语音识别连接中断：\(detail)"
        case .server(let detail): "语音识别服务错误：\(detail)"
        case .transcriptionFailed(let detail): "语音识别失败：\(detail)"
        }
    }
}

enum ASREvent: Sendable, Equatable {
    case preview(itemID: String, text: String, stash: String)
    case completed(itemID: String, transcript: String)
    case failed(ASRError)
    case finished
}

struct ASRConfig: Sendable, Equatable {
    enum TurnDetection: Sendable, Equatable {
        case serverVAD(threshold: Double, silenceDurationMS: Int)
        case manual
    }

    var url: URL
    var apiKey: String
    var language: String?
    var turnDetection: TurnDetection
    var provider: ASRProvider = .bailian
    var model: ASRModel = .qwen3Realtime
    /// `qwen-audio-3.1-asr-flash-message` only: filler / repeated-word removal and polishing on the ASR side.
    var disfluencyRemoval = false
    /// `qwen-audio-3.1-asr-flash-message` only: `keep_dialect` (transcribe dialects as spoken, not as Mandarin).
    var keepDialect = false

    static let model = ASRModel.qwen3Realtime.apiName

    /// Builds the WebSocket endpoint. `WorkspaceId` is validated so the API key can only ever be sent to
    /// an Aliyun host derived from it, or to an explicit `wss://` custom URL the user typed.
    static func endpoint(region: ASRRegion, workspaceID: String, customURL: String,
                         model: ASRModel = .qwen3Realtime) throws -> URL {
        let custom = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            guard let components = URLComponents(string: custom),
                  components.scheme?.lowercased() == "wss",
                  components.host?.isEmpty == false,
                  components.user == nil, components.password == nil,
                  let url = components.url else {
                throw ASRError.invalidConfig("自定义地址必须是有效的 wss:// URL")
            }
            return url
        }
        let workspace = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workspace.isEmpty else { throw ASRError.invalidConfig("请填写 Workspace ID") }
        guard workspace.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) != nil else {
            throw ASRError.invalidConfig("Workspace ID 只能包含字母、数字和连字符")
        }
        let host = "wss://\(workspace).\(region.hostSegment).maas.aliyuncs.com"
        let string = switch model {
        case .qwen3Realtime: "\(host)/api-ws/v1/realtime?model=\(model.apiName)"
        case .qwenAudio31Message: "\(host)/api-ws/v1/inference" // model goes into run-task
        }
        guard let url = URL(string: string) else { throw ASRError.invalidConfig("无法生成连接地址") }
        return url
    }
}

/// Streaming ASR client. Instances are single-use (one per dictation session).
protocol ASRService: Sendable {
    /// Events for this session. The stream finishes after `.finished`, a `.failed`, or `close()`.
    var events: AsyncStream<ASREvent> { get }
    /// Opens the socket, sends `session.update` and returns once the server confirmed with `session.updated`.
    func connect() async throws
    func sendAudio(_ pcm: Data) async throws
    /// Manual turn-detection mode only: `input_audio_buffer.commit`.
    func commit() async throws
    /// Sends `session.finish`; the server then flushes pending `completed` events and `session.finished`.
    func finish() async throws
    func close() async
    /// How long the coordinator waits for pending results after `finish()` before using what it has.
    var finalizeTimeout: Duration { get }
    /// Settings "test connection": verifies the credentials end to end.
    func probe() async throws
}

extension ASRService {
    var finalizeTimeout: Duration { .seconds(10) }

    func probe() async throws {
        do {
            try await connect()
            await close()
        } catch {
            await close()
            throw error
        }
    }
}

/// Aliyun Bailian `qwen3-asr-flash-realtime` WebSocket client.
actor BailianRealtimeASR: ASRService {
    nonisolated let events: AsyncStream<ASREvent>
    private let continuation: AsyncStream<ASREvent>.Continuation
    private let config: ASRConfig

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
            try await send(Self.sessionUpdatePayload(config: config))
            while true {
                let message = try await socket.receive()
                guard let object = Self.decode(message) else { continue }
                switch object["type"] as? String {
                case "session.updated":
                    startReceiveLoop(socket)
                    return
                case "error":
                    throw ASRError.server(Self.errorText(object))
                default:
                    continue // session.created etc.
                }
            }
        } catch {
            let mapped = mapTransportError(error)
            await close()
            throw mapped
        }
    }

    func sendAudio(_ pcm: Data) async throws {
        try await send([
            "event_id": Self.eventID(),
            "type": "input_audio_buffer.append",
            "audio": pcm.base64EncodedString()
        ])
    }

    func commit() async throws {
        try await send(["event_id": Self.eventID(), "type": "input_audio_buffer.commit"])
    }

    func finish() async throws {
        try await send(["event_id": Self.eventID(), "type": "session.finish"])
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

    static func sessionUpdatePayload(config: ASRConfig) -> [String: Any] {
        var transcription: [String: Any] = [:]
        if let language = config.language { transcription["language"] = language }

        var session: [String: Any] = [
            "modalities": ["text"],
            "input_audio_format": "pcm",
            "sample_rate": 16000,
            "input_audio_transcription": transcription
        ]
        switch config.turnDetection {
        case .serverVAD(let threshold, let silence):
            session["turn_detection"] = [
                "type": "server_vad",
                "threshold": threshold,
                "silence_duration_ms": silence
            ] as [String: Any]
        case .manual:
            session["turn_detection"] = NSNull()
        }
        return ["event_id": eventID(), "type": "session.update", "session": session]
    }

    // MARK: Internals

    private func send(_ payload: [String: Any]) async throws {
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

    /// Returns `true` when the session is over and the loop should stop.
    private func handle(_ message: URLSessionWebSocketTask.Message) -> Bool {
        guard let object = Self.decode(message), let type = object["type"] as? String else { return false }
        switch type {
        case "conversation.item.input_audio_transcription.text":
            continuation.yield(.preview(
                itemID: object["item_id"] as? String ?? "",
                text: object["text"] as? String ?? "",
                stash: object["stash"] as? String ?? ""
            ))
        case "conversation.item.input_audio_transcription.completed":
            continuation.yield(.completed(
                itemID: object["item_id"] as? String ?? "",
                transcript: object["transcript"] as? String ?? ""
            ))
        case "conversation.item.input_audio_transcription.failed":
            continuation.yield(.failed(.transcriptionFailed(Self.errorText(object))))
            continuation.finish()
            return true
        case "error":
            continuation.yield(.failed(.server(Self.errorText(object))))
            continuation.finish()
            return true
        case "session.finished":
            continuation.yield(.finished)
            continuation.finish()
            return true
        default:
            break
        }
        return false
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

    private static func eventID() -> String {
        "event_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
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

    private static func errorText(_ object: [String: Any]) -> String {
        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "未知错误"
            if let code = error["code"] as? String { return "\(message) (\(code))" }
            return message
        }
        return object["message"] as? String ?? "未知错误"
    }
}
