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
}

/// Ephemeral session: no cookies / disk caches. TLS is validated by the system (no custom trust handling).
struct URLSessionTransport: HTTPTransport {
    let timeout: TimeInterval

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.badResponse("非 HTTP 响应")
            }
            return (data, http)
        } catch let error as LLMError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw LLMError.timeout
            case .cancelled: throw CancellationError()
            default: throw LLMError.network(error.localizedDescription)
            }
        }
    }
}

// MARK: - Request building (pure, unit-tested)

enum LLMRequestBuilder {
    static let anthropicVersion = "2023-06-01"
    static let anthropicMaxTokens = 4096

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
        systemPrompt: String
    ) throws -> URLRequest {
        guard !profile.modelID.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.invalidConfig("未填写 Model ID")
        }
        var request = URLRequest(url: try endpoint(format: profile.format, baseURL: profile.baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = profile.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userPrompt = TextProcessor.userPrompt(transcript: transcript)
        let body: [String: Any]
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
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        let request = try LLMRequestBuilder.makeRequest(
            profile: profile, apiKey: apiKey, transcript: transcript, systemPrompt: systemPrompt
        )
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw LLMResponseParser.mapFailure(status: response.statusCode, data: data, secrets: [apiKey])
        }
        return try LLMResponseParser.extractText(format: profile.format, data: data)
    }
}
