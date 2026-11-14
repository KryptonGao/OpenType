import Foundation

/// DeepSeek speech recognition (`POST /v1/tools/asr`).
///
/// The API is not streaming: one request carries a whole 16-bit PCM WAV file (≤ 120 s, ≤ 8 MiB) and returns
/// the full transcript. This client therefore buffers the captured PCM in memory while recording and uploads
/// it when `finish()` is called. Recordings longer than `maxSegmentSeconds` are split into several requests
/// that are transcribed one after another.
actor DeepSeekASR: ASRService {
    static let endpoint = URL(string: "https://api.deepseek.com/v1/tools/asr")!

    static let sampleRate = 16_000
    static let bytesPerSecond = sampleRate * 2
    /// Stays below the documented 120 s per-request limit.
    static let maxSegmentSeconds = 110
    static let maxSegmentBytes = maxSegmentSeconds * bytesPerSecond

    nonisolated let events: AsyncStream<ASREvent>
    /// Upload + recognition happens after the recording ended, so allow far more than the streaming default.
    nonisolated var finalizeTimeout: Duration { .seconds(90) }

    private let continuation: AsyncStream<ASREvent>.Continuation
    private let config: ASRConfig
    private let session: URLSession

    private var buffer = Data()
    private var transcribeTask: Task<Void, Never>?
    private var closed = false

    init(config: ASRConfig) {
        self.config = config
        self.session = URLSession(configuration: .ephemeral)
        let (stream, continuation) = AsyncStream.makeStream(of: ASREvent.self)
        self.events = stream
        self.continuation = continuation
    }

    // MARK: ASRService

    /// There is no connection to open; this only validates that the key can be sent safely.
    func connect() async throws {
        guard config.url.scheme?.lowercased() == "https" else {
            throw ASRError.invalidConfig(String(localized: "仅允许 https:// 连接"))
        }
    }

    func sendAudio(_ pcm: Data) async throws {
        guard !closed else { throw ASRError.disconnected(String(localized: "连接已关闭")) }
        buffer.append(pcm)
    }

    /// Nothing to flush — the whole recording is sent on `finish()`.
    func commit() async throws {}

    func finish() async throws {
        guard !closed else { throw ASRError.disconnected(String(localized: "连接已关闭")) }
        let pcm = buffer
        buffer = Data()
        transcribeTask = Task { [weak self] in
            await self?.transcribe(pcm)
        }
    }

    func close() async {
        guard !closed else { return }
        closed = true
        transcribeTask?.cancel()
        transcribeTask = nil
        buffer = Data()
        session.invalidateAndCancel()
        continuation.finish()
    }

    /// Verifies key and connectivity with a real (0.5 s, silent) request; billed as 1 second.
    func probe() async throws {
        try await connect()
        defer { session.finishTasksAndInvalidate() }
        let silence = Data(count: Self.bytesPerSecond / 2)
        _ = try await upload(pcm: silence)
    }

    // MARK: Transcription

    private func transcribe(_ pcm: Data) async {
        do {
            for (index, segment) in Self.segments(of: pcm).enumerated() {
                try Task.checkCancellation()
                let text = try await upload(pcm: segment)
                guard !closed else { return }
                continuation.yield(.completed(itemID: "segment-\(index)", transcript: text))
            }
            continuation.yield(.finished)
        } catch is CancellationError {
            // close() / cancel: the stream is finished by close().
        } catch {
            guard !closed else { return }
            continuation.yield(.failed(Self.map(error)))
        }
        continuation.finish()
    }

    private func upload(pcm: Data) async throws -> String {
        let request = Self.makeRequest(url: config.url, apiKey: config.apiKey, pcm: pcm)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.map(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ASRError.server(String(localized: "无效的响应"))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(forStatus: http.statusCode)
        }
        return try Self.parseTranscript(data)
    }

    // MARK: Static helpers (unit tests)

    /// Splits PCM into ≤ `maxSegmentBytes` pieces on sample (2-byte) boundaries.
    static func segments(of pcm: Data, maxBytes: Int = maxSegmentBytes) -> [Data] {
        let limit = max(2, maxBytes - maxBytes % 2)
        guard pcm.count > limit else { return [pcm] }
        var result: [Data] = []
        var offset = 0
        while offset < pcm.count {
            let end = min(offset + limit, pcm.count)
            result.append(pcm.subdata(in: offset..<end))
            offset = end
        }
        return result
    }

    /// 44-byte RIFF header + 16-bit mono PCM.
    static func wav(pcm: Data, sampleRate: Int = sampleRate) -> Data {
        var data = Data()
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8))
        append32(UInt32(36 + pcm.count))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append32(16)                          // fmt chunk size
        append16(1)                           // PCM
        append16(1)                           // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))      // byte rate
        append16(2)                           // block align
        append16(16)                          // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append32(UInt32(pcm.count))
        data.append(pcm)
        return data
    }

    static func makeRequest(url: URL, apiKey: String, pcm: Data, boundary: String = "OpenType-" + UUID().uuidString) -> URLRequest {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\n".utf8))
        body.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        body.append(wav(pcm: pcm))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        // Credentials only in the header — never in the URL.
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    static func parseTranscript(_ data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String else {
            throw ASRError.server(String(localized: "响应格式无法识别"))
        }
        return text
    }

    static func error(forStatus status: Int) -> ASRError {
        switch status {
        case 401, 403: .auth(status)
        case 408: .timeout
        case 429: .rateLimited
        case 400: .server(String(localized: "音频格式无效或缺少音频（HTTP 400）"))
        case 413: .server(String(localized: "录音过大（HTTP 413）"))
        case 503: .server(String(localized: "服务繁忙，请稍后重试（HTTP 503）"))
        case 504: .timeout
        default: .server("HTTP \(status)")
        }
    }

    private static func map(_ error: Error) -> ASRError {
        if let asr = error as? ASRError { return asr }
        if (error as? URLError)?.code == .timedOut { return .timeout }
        return .disconnected(error.localizedDescription)
    }
}
