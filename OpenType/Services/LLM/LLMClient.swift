import Foundation

enum LLMError: Error, Equatable, Sendable {
    case invalidConfig(String)
    case missingAPIKey
    case auth(Int)
    case modelNotFound(String)
    case rateLimited
    case timeout
    case network(String)
    case server(Int, String)
    case badResponse(String)
    case emptyOutput

    var userMessage: String {
        switch self {
        case .invalidConfig(let detail): "配置无效：\(detail)"
        case .missingAPIKey: "未配置 API Key"
        case .auth(let code): "鉴权失败（HTTP \(code)），请检查 API Key"
        case .modelNotFound(let detail): "模型不存在或不可用：\(detail)"
        case .rateLimited: "请求被限流（429）"
        case .timeout: "请求超时"
        case .network(let detail): "网络错误：\(detail)"
        case .server(let code, let detail): "服务端错误（HTTP \(code)）：\(detail)"
        case .badResponse(let detail): "响应格式错误：\(detail)"
        case .emptyOutput: "模型返回了空内容"
        }
    }
}

// MARK: - Transport

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    /// Streams a (server-sent events) response line by line. A non-2xx response is returned with its body and `onLine` is not called.
    func sendStreaming(_ request: URLRequest, onLine: (String) -> Void) async throws -> (HTTPURLResponse, Data)
}

extension HTTPTransport {
    /// Fallback for transports that cannot stream: fetches the whole body, then replays it line by line.
    func sendStreaming(_ request: URLRequest, onLine: (String) -> Void) async throws -> (HTTPURLResponse, Data) {
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else { return (response, data) }
        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) { onLine(String(line)) }
        return (response, Data())
    }
}

/// Ephemeral session: no cookies / disk caches. TLS is validated by the system (no custom trust handling).
struct URLSessionTransport: HTTPTransport {
    let timeout: TimeInterval

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private func mapped(_ error: Error) -> Error {
        guard let error = error as? URLError else { return error }
        switch error.code {
        case .timedOut: return LLMError.timeout
        case .cancelled: return CancellationError()
        default: return LLMError.network(error.localizedDescription)
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.badResponse("非 HTTP 响应")
            }
            return (data, http)
        } catch {
            throw mapped(error)
        }
    }

    func sendStreaming(_ request: URLRequest, onLine: (String) -> Void) async throws -> (HTTPURLResponse, Data) {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.badResponse("非 HTTP 响应")
            }
            guard (200..<300).contains(http.statusCode) else {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count >= 64 * 1024 { break }
                }
                return (http, body)
            }
            for try await line in bytes.lines { onLine(line) }
            return (http, Data())
        } catch {
            throw mapped(error)
        }
    }
}

// MARK: - Request building (pure, unit-tested)

enum LLMRequestBuilder {
    static let anthropicVersion = "2023-06-01"
    static let anthropicMaxTokens = 4096
    static let webSearchToolName = "deepseek_web_search"

    /// Normalises a user supplied Base URL and appends the endpoint path exactly once.
    static func endpoint(format: LLMAPIFormat, baseURL: String) throws -> URL {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        for suffix in ["/chat/completions", "/responses", "/messages"] where base.lowercased().hasSuffix(suffix) {
            base.removeLast(suffix.count)
            while base.hasSuffix("/") { base.removeLast() }
            break
        }
        guard !base.isEmpty, let components = URLComponents(string: base),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else {
            throw LLMError.invalidConfig("Base URL 必须是有效的 https 地址")
        }
        guard components.user == nil, components.password == nil, components.query == nil else {
            throw LLMError.invalidConfig("Base URL 不能包含凭据或查询参数")
        }
        guard let url = URL(string: base + format.path) else {
            throw LLMError.invalidConfig("Base URL 无法解析")
        }
        return url
    }

    static func makeRequest(
        profile: LLMProfile,
        apiKey: String,
        transcript: String,
        systemPrompt: String,
        webSearch: WebSearchLevel? = nil
    ) throws -> URLRequest {
        guard !profile.modelID.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.invalidConfig("未填写 Model ID")
        }
        var request = URLRequest(url: try endpoint(format: profile.format, baseURL: profile.baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = profile.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userPrompt = TextProcessor.userPrompt(transcript: transcript)
        var body: [String: Any]
        switch profile.format {
        case .openAIResponses:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": profile.modelID,
                "instructions": systemPrompt,
                "input": userPrompt,
                "store": false
            ]
        case .openAIChatCompletions:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": profile.modelID,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ]
            ]
        case .anthropicMessages:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
            body = [
                "model": profile.modelID,
                "max_tokens": anthropicMaxTokens,
                "system": systemPrompt,
                "messages": [["role": "user", "content": userPrompt]]
            ]
        }
        if let effort = profile.effectiveReasoningEffort {
            switch profile.format {
            case .openAIResponses: body["reasoning"] = ["effort": effort]
            case .openAIChatCompletions: body["reasoning_effort"] = effort
            case .anthropicMessages: body["output_config"] = ["effort": effort]
            }
        }
        if let webSearch {
            // DeepSeek runs the search / page reading server-side: declaring the tool is all the client does.
            // Thinking mode turns on its multi-step "deep search" (search, open pages, find in page), which is far more
            // willing to actually search than the non-thinking mode; the conservative level stays in the quick mode.
            switch profile.format {
            case .openAIResponses:
                body["tools"] = [["type": webSearchToolName]]
                if webSearch.usesThinking, body["reasoning"] == nil { body["reasoning"] = ["effort": "high"] }
            case .openAIChatCompletions:
                body["tools"] = [["type": webSearchToolName]]
                if webSearch.usesThinking { body["thinking"] = ["type": "enabled"] }
                body["stream"] = true // progress events (`server_tool_event`) only exist in the stream
                body["stream_options"] = ["include_usage": true] // the final chunk then carries the token counts
            case .anthropicMessages:
                body["tools"] = [["type": webSearchToolName, "name": webSearchToolName]]
                if webSearch.usesThinking { body["thinking"] = ["type": "enabled"] }
            }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

// MARK: - Response parsing (pure, unit-tested)

enum LLMResponseParser {
    static func extractText(format: LLMAPIFormat, data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.badResponse("不是有效的 JSON 对象")
        }
        let text: String?
        switch format {
        case .openAIResponses:
            let output = root["output"] as? [[String: Any]] ?? []
            let parts = output
                .filter { ($0["type"] as? String) == "message" }
                .flatMap { $0["content"] as? [[String: Any]] ?? [] }
                .filter { ($0["type"] as? String) == "output_text" }
                .compactMap { $0["text"] as? String }
            text = parts.isEmpty ? nil : parts.joined()
        case .openAIChatCompletions:
            let message = (root["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
            if let content = message?["content"] as? String {
                text = content
            } else if let parts = message?["content"] as? [[String: Any]] {
                text = parts.compactMap { $0["text"] as? String }.joined()
            } else {
                text = nil
            }
        case .anthropicMessages:
            let parts = (root["content"] as? [[String: Any]] ?? [])
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
            text = parts.isEmpty ? nil : parts.joined()
        }
        guard let text else { throw LLMError.badResponse("未找到文本输出") }
        let cleaned = clean(text)
        guard !cleaned.isEmpty else { throw LLMError.emptyOutput }
        return cleaned
    }

    /// Token counts from a response body; zero when the API did not report them.
    static func extractUsage(format: LLMAPIFormat, data: Data) -> TokenUsage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .zero }
        return usage(format: format, root: root)
    }

    static func usage(format: LLMAPIFormat, root: [String: Any]) -> TokenUsage {
        guard let usage = root["usage"] as? [String: Any] else { return .zero }
        func int(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
        switch format {
        case .openAIChatCompletions:
            return TokenUsage(inputTokens: int("prompt_tokens"), outputTokens: int("completion_tokens"))
        case .openAIResponses:
            return TokenUsage(inputTokens: int("input_tokens"), outputTokens: int("output_tokens"))
        case .anthropicMessages:
            // Cached prompt tokens are reported separately from `input_tokens`; they are still input.
            return TokenUsage(
                inputTokens: int("input_tokens") + int("cache_creation_input_tokens") + int("cache_read_input_tokens"),
                outputTokens: int("output_tokens")
            )
        }
    }

    /// How many server-side tool calls (searches, page opens, link reads) the model made, per DeepSeek's response formats.
    static func serverToolCallCount(format: LLMAPIFormat, data: Data) -> Int {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        switch format {
        case .openAIChatCompletions:
            let message = (root["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
            let steps = message?["server_tool_calls"] as? [[String: Any]] ?? []
            return steps.reduce(0) { $0 + (($1["calls"] as? [Any])?.count ?? 0) }
        case .anthropicMessages:
            return (root["content"] as? [[String: Any]] ?? []).filter { ($0["type"] as? String) == "server_tool_use" }.count
        case .openAIResponses:
            return (root["output"] as? [[String: Any]] ?? []).filter { ($0["type"] as? String) == "web_search_call" }.count
        }
    }

    /// Trims whitespace and removes a wrapping Markdown code fence if the model added one anyway.
    static func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```"), result.hasSuffix("```"), result.count >= 6 {
            result.removeFirst(3)
            result.removeLast(3)
            if let newline = result.firstIndex(of: "\n"),
               result[result.startIndex..<newline].allSatisfy({ $0.isLetter || $0.isNumber }) {
                result = String(result[result.index(after: newline)...])
            }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    static func errorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = root["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let message = root["message"] as? String { return message }
        return nil
    }

    static func mapFailure(status: Int, data: Data, secrets: [String]) -> LLMError {
        let raw = errorMessage(from: data) ?? "无详细信息"
        let message = String(Diagnostics.redact(raw, secrets: secrets).prefix(200))
        switch status {
        case 401, 403: return .auth(status)
        case 404: return .modelNotFound(message)
        case 429: return .rateLimited
        default:
            if status == 400 || status == 422, message.lowercased().contains("model") {
                return .modelNotFound(message)
            }
            return .server(status, message)
        }
    }
}

// MARK: - Streaming (DeepSeek Chat Completions with web tools)

/// Reads DeepSeek's streamed chat completion: answer text from `delta.content`, tool progress from the choice-level
/// `server_tool_event`, and the final `server_tool_calls`. Also accepts a plain (non-streamed) JSON response.
struct ChatStreamAccumulator {
    private(set) var text = ""
    private(set) var progress = WebSearchProgress()
    private(set) var errorMessage: String?
    /// Total calls in the final `server_tool_calls`, if the response carried it.
    private(set) var finalCallCount: Int?
    /// From the last chunk that reported `usage` (requested through `stream_options.include_usage`).
    private(set) var usage = TokenUsage.zero

    /// Feeds one line; returns `true` when `progress` changed.
    mutating func consume(line raw: String) -> Bool {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("data:") {
            line = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        } else if !line.hasPrefix("{") {
            return false // blank lines, `: keep-alive` comments, `event:` names
        }
        guard !line.isEmpty, line != "[DONE]",
              let root = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else { return false }
        if let error = root["error"] as? [String: Any] {
            errorMessage = (error["message"] as? String) ?? "流式响应出错"
            return false
        }
        let reported = LLMResponseParser.usage(format: .openAIChatCompletions, root: root)
        if !reported.isEmpty { usage = reported }
        guard let choice = (root["choices"] as? [[String: Any]])?.first else { return false }
        if let message = choice["message"] as? [String: Any] { // not streamed
            if let content = message["content"] as? String { text = content }
            finalCallCount = Self.callCount(message["server_tool_calls"])
        }
        if let delta = choice["delta"] as? [String: Any] {
            if let content = delta["content"] as? String { text += content }
            if delta["server_tool_calls"] != nil { finalCallCount = Self.callCount(delta["server_tool_calls"]) }
        }
        if let event = choice["server_tool_event"] as? [String: Any] { return progress.apply(event: event) }
        return false
    }

    /// The tally once the stream is over. If no events could be read but the final `server_tool_calls` lists calls,
    /// fall back to that count so the user still sees that a search happened.
    var finalProgress: WebSearchProgress {
        var result = progress
        result.activity = nil
        if !result.madeAnyCall, let finalCallCount, finalCallCount > 0 { result.searches = finalCallCount }
        return result
    }

    private static func callCount(_ value: Any?) -> Int {
        (value as? [[String: Any]] ?? []).reduce(0) { $0 + (($1["calls"] as? [Any])?.count ?? 0) }
    }
}

// MARK: - Provider

/// One adapter type for all three protocols; behaviour is selected by `profile.format`.
/// Stateless single call: failed requests are never replayed automatically (they may be billed).
struct HTTPLLMProvider: LLMProvider {
    let profile: LLMProfile
    let apiKey: String
    let transport: any HTTPTransport

    init(profile: LLMProfile, apiKey: String, transport: (any HTTPTransport)? = nil) {
        self.profile = profile
        self.apiKey = apiKey
        self.transport = transport ?? URLSessionTransport(timeout: profile.timeout)
    }

    func process(transcript: String, systemPrompt: String) async throws -> String {
        try await send(transcript: transcript, systemPrompt: systemPrompt, webSearch: nil).text
    }

    func processWithUsage(transcript: String, systemPrompt: String) async throws -> LLMOutput {
        let output = try await send(transcript: transcript, systemPrompt: systemPrompt, webSearch: nil)
        return LLMOutput(text: output.text, usage: output.usage)
    }

    func processWithWebSearch(
        transcript: String,
        systemPrompt: String,
        level: WebSearchLevel,
        onProgress: @escaping @Sendable (WebSearchProgress) -> Void
    ) async throws -> WebSearchOutput {
        guard profile.format == .openAIChatCompletions else {
            return try await send(transcript: transcript, systemPrompt: systemPrompt, webSearch: level)
        }
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        let request = try LLMRequestBuilder.makeRequest(
            profile: profile, apiKey: apiKey, transcript: transcript, systemPrompt: systemPrompt, webSearch: level
        )
        var accumulator = ChatStreamAccumulator()
        onProgress(accumulator.progress)
        let (response, errorBody) = try await transport.sendStreaming(request) { line in
            if accumulator.consume(line: line) { onProgress(accumulator.progress) }
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LLMResponseParser.mapFailure(status: response.statusCode, data: errorBody, secrets: [apiKey])
        }
        if let message = accumulator.errorMessage {
            let safe = String(Diagnostics.redact(message, secrets: [apiKey]).prefix(200))
            throw LLMError.server(response.statusCode, safe)
        }
        let text = LLMResponseParser.clean(accumulator.text)
        guard !text.isEmpty else { throw LLMError.emptyOutput }
        let progress = accumulator.finalProgress
        Diagnostics.log("web search calls=\(progress.calls) results=\(progress.results) pages=\(progress.pages)")
        return WebSearchOutput(text: text, progress: progress, usage: accumulator.usage)
    }

    private func send(transcript: String, systemPrompt: String, webSearch: WebSearchLevel?) async throws -> WebSearchOutput {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        let request = try LLMRequestBuilder.makeRequest(
            profile: profile, apiKey: apiKey, transcript: transcript, systemPrompt: systemPrompt, webSearch: webSearch
        )
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw LLMResponseParser.mapFailure(status: response.statusCode, data: data, secrets: [apiKey])
        }
        let text = try LLMResponseParser.extractText(format: profile.format, data: data)
        let calls = webSearch != nil ? LLMResponseParser.serverToolCallCount(format: profile.format, data: data) : 0
        if webSearch != nil { Diagnostics.log("web search tool calls=\(calls)") }
        var progress = WebSearchProgress()
        progress.searches = calls
        return WebSearchOutput(
            text: text, progress: progress,
            usage: LLMResponseParser.extractUsage(format: profile.format, data: data)
        )
    }
}
