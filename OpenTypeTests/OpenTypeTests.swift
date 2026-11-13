import CoreGraphics
import Foundation
import Testing
@testable import OpenType

// MARK: - TranscriptAggregator

struct TranscriptAggregatorTests {
    @Test func previewReplacesSnapshotInsteadOfAppending() {
        var agg = TranscriptAggregator()
        agg.updatePreview(itemID: "a", text: "今天", stash: "天气")
        agg.updatePreview(itemID: "a", text: "今天天气", stash: "不错")
        #expect(agg.solidText == "今天天气")
        #expect(agg.stashText == "不错")
        #expect(agg.finalText.isEmpty)
    }

    @Test func completedReplacesTemporaryContentAndIgnoresStash() {
        var agg = TranscriptAggregator()
        agg.updatePreview(itemID: "a", text: "今天天气", stash: "不错啊")
        agg.complete(itemID: "a", transcript: "今天天气不错。")
        #expect(agg.finalText == "今天天气不错。")
        #expect(agg.stashText.isEmpty)
        // A late preview must not resurrect temporary content.
        agg.updatePreview(itemID: "a", text: "垃圾", stash: "数据")
        #expect(agg.finalText == "今天天气不错。")
        #expect(agg.solidText == "今天天气不错。")
    }

    @Test func utterancesKeepArrivalOrder() {
        var agg = TranscriptAggregator()
        agg.updatePreview(itemID: "a", text: "一", stash: "")
        agg.updatePreview(itemID: "b", text: "二", stash: "")
        agg.complete(itemID: "b", transcript: "第二句。")
        agg.complete(itemID: "a", transcript: "第一句。")
        #expect(agg.finalText == "第一句。第二句。")
    }

    @Test func bestEffortKeepsUnfinishedText() {
        var agg = TranscriptAggregator()
        agg.complete(itemID: "a", transcript: "已确认。")
        agg.updatePreview(itemID: "b", text: "未完", stash: "成")
        #expect(agg.finalText == "已确认。")
        #expect(agg.bestEffortText == "已确认。未完成")
    }

    @Test func joinAddsSpacesOnlyBetweenLatinWords() {
        #expect(TranscriptAggregator.join(["Hello", "world"]) == "Hello world")
        #expect(TranscriptAggregator.join(["你好。", "world"]) == "你好。world")
        #expect(TranscriptAggregator.join(["你好", " ", "世界"]) == "你好世界")
    }
}

// MARK: - DeepSeek ASR

struct DeepSeekASRTests {
    @Test func wavHeaderDescribesMono16BitPCM() {
        let pcm = Data(count: 3200)
        let wav = DeepSeekASR.wav(pcm: pcm)
        #expect(wav.count == 44 + 3200)
        #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
        func u32(_ offset: Int) -> UInt32 {
            wav.subdata(in: offset..<offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        }
        func u16(_ offset: Int) -> UInt16 {
            wav.subdata(in: offset..<offset + 2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        }
        #expect(u32(4) == 36 + 3200)
        #expect(u16(20) == 1)       // PCM
        #expect(u16(22) == 1)       // mono
        #expect(u32(24) == 16000)   // sample rate
        #expect(u32(28) == 32000)   // byte rate
        #expect(u16(34) == 16)      // bits
        #expect(u32(40) == 3200)    // data size
    }

    @Test func requestIsMultipartWithBearerHeaderAndNoKeyInURL() throws {
        let request = DeepSeekASR.makeRequest(url: DeepSeekASR.endpoint, apiKey: "sk-secret", pcm: Data(count: 64), boundary: "B")
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.deepseek.com/v1/tools/asr")
        #expect(request.url?.absoluteString.contains("sk-secret") == false)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=B")
        let body = try #require(request.httpBody)
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.hasPrefix("--B\r\nContent-Disposition: form-data; name=\"file\"; filename=\"speech.wav\""))
        #expect(text.hasSuffix("\r\n--B--\r\n"))
    }

    @Test func splitsLongRecordingsOnSampleBoundaries() {
        let pcm = Data(count: 1001)
        let parts = DeepSeekASR.segments(of: pcm, maxBytes: 400)
        #expect(parts.map(\.count) == [400, 400, 201])
        #expect(DeepSeekASR.segments(of: Data(count: 100), maxBytes: 400).count == 1)
        #expect(DeepSeekASR.maxSegmentBytes <= 8 * 1024 * 1024)
        #expect(DeepSeekASR.maxSegmentSeconds < 120)
    }

    @Test func parsesTranscriptAndMapsErrors() throws {
        let json = Data(#"{"request_id":"r","text":"上海今天天气怎么样？","duration_ms":3200}"#.utf8)
        #expect(try DeepSeekASR.parseTranscript(json) == "上海今天天气怎么样？")
        #expect(throws: ASRError.self) { try DeepSeekASR.parseTranscript(Data("nope".utf8)) }
        #expect(DeepSeekASR.error(forStatus: 401) == .auth(401))
        #expect(DeepSeekASR.error(forStatus: 429) == .rateLimited)
        #expect(DeepSeekASR.error(forStatus: 504) == .timeout)
        #expect(DeepSeekASR.error(forStatus: 408) == .timeout)
    }

    @Test func buffersAudioAndEmitsNothingBeforeFinish() async throws {
        let asr = DeepSeekASR(config: ASRConfig(url: DeepSeekASR.endpoint, apiKey: "k", language: nil, turnDetection: .manual, provider: .deepseek))
        try await asr.connect()
        try await asr.sendAudio(Data(count: 3200))
        await asr.close()
        var received: [ASREvent] = []
        for await event in asr.events { received.append(event) }
        #expect(received.isEmpty)
        await #expect(throws: ASRError.self) { try await asr.sendAudio(Data(count: 2)) }
    }

    @Test func rejectsNonHTTPSEndpoint() async {
        let asr = DeepSeekASR(config: ASRConfig(url: URL(string: "http://example.com")!, apiKey: "k", language: nil, turnDetection: .manual, provider: .deepseek))
        await #expect(throws: ASRError.self) { try await asr.connect() }
    }
}

// MARK: - ASR config / payload

struct ASRConfigTests {
    @Test func buildsRegionalEndpointWithoutCredentials() throws {
        let beijing = try ASRConfig.endpoint(region: .beijing, workspaceID: "ws-123", customURL: "")
        #expect(beijing.absoluteString == "wss://ws-123.cn-beijing.maas.aliyuncs.com/api-ws/v1/realtime?model=qwen3-asr-flash-realtime")
        let sg = try ASRConfig.endpoint(region: .singapore, workspaceID: "ws-123", customURL: "")
        #expect(sg.host == "ws-123.ap-southeast-1.maas.aliyuncs.com")
    }

    @Test func rejectsHostInjectionAndNonWSS() {
        #expect(throws: ASRError.self) { try ASRConfig.endpoint(region: .beijing, workspaceID: "evil.com/x", customURL: "") }
        #expect(throws: ASRError.self) { try ASRConfig.endpoint(region: .beijing, workspaceID: "", customURL: "") }
        #expect(throws: ASRError.self) { try ASRConfig.endpoint(region: .beijing, workspaceID: "a", customURL: "ws://example.com") }
        #expect(throws: ASRError.self) { try ASRConfig.endpoint(region: .beijing, workspaceID: "a", customURL: "https://example.com") }
    }

    @Test func customURLOverridesWorkspace() throws {
        let url = try ASRConfig.endpoint(region: .beijing, workspaceID: "", customURL: " wss://proxy.example.com/ws ")
        #expect(url.absoluteString == "wss://proxy.example.com/ws")
    }

    @Test func sessionUpdateServerVAD() throws {
        let config = ASRConfig(
            url: URL(string: "wss://x.example.com")!, apiKey: "k", language: "zh",
            turnDetection: .serverVAD(threshold: 0.0, silenceDurationMS: 400)
        )
        let payload = BailianRealtimeASR.sessionUpdatePayload(config: config)
        #expect(payload["type"] as? String == "session.update")
        let session = try #require(payload["session"] as? [String: Any])
        #expect(session["input_audio_format"] as? String == "pcm")
        #expect(session["sample_rate"] as? Int == 16000)
        let transcription = try #require(session["input_audio_transcription"] as? [String: Any])
        #expect(transcription["language"] as? String == "zh")
        let vad = try #require(session["turn_detection"] as? [String: Any])
        #expect(vad["type"] as? String == "server_vad")
        #expect(vad["silence_duration_ms"] as? Int == 400)
    }

    @Test func sessionUpdateManualAndAutoLanguage() throws {
        let config = ASRConfig(url: URL(string: "wss://x.example.com")!, apiKey: "k", language: nil, turnDetection: .manual)
        let session = try #require(BailianRealtimeASR.sessionUpdatePayload(config: config)["session"] as? [String: Any])
        #expect(session["turn_detection"] is NSNull)
        let transcription = try #require(session["input_audio_transcription"] as? [String: Any])
        #expect(transcription["language"] == nil)
    }
}

// MARK: - LLM adapters

private struct MockTransport: HTTPTransport {
    let status: Int
    let body: String
    var capture: CaptureBox?

    final class CaptureBox: @unchecked Sendable { var request: URLRequest? }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capture?.request = request
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

struct LLMAdapterTests {
    private func profile(_ format: LLMAPIFormat, base: String? = nil) -> LLMProfile {
        var p = LLMProfile.makeDefault()
        p.format = format
        p.baseURL = base ?? format.defaultBaseURL
        p.modelID = "test-model"
        return p
    }

    @Test(arguments: [
        ("https://api.openai.com/v1", LLMAPIFormat.openAIChatCompletions, "https://api.openai.com/v1/chat/completions"),
        ("https://api.openai.com/v1/", .openAIResponses, "https://api.openai.com/v1/responses"),
        ("https://api.openai.com/v1/chat/completions", .openAIChatCompletions, "https://api.openai.com/v1/chat/completions"),
        ("  https://api.anthropic.com/v1//  ", .anthropicMessages, "https://api.anthropic.com/v1/messages"),
        ("https://api.anthropic.com/v1/messages", .anthropicMessages, "https://api.anthropic.com/v1/messages"),
        ("https://proxy.example.com", .openAIChatCompletions, "https://proxy.example.com/chat/completions"),
    ])
    func normalisesBaseURL(base: String, format: LLMAPIFormat, expected: String) throws {
        #expect(try LLMRequestBuilder.endpoint(format: format, baseURL: base).absoluteString == expected)
    }

    @Test func rejectsNonHTTPSBaseURL() {
        #expect(throws: LLMError.self) { try LLMRequestBuilder.endpoint(format: .openAIResponses, baseURL: "http://api.openai.com/v1") }
        #expect(throws: LLMError.self) { try LLMRequestBuilder.endpoint(format: .openAIResponses, baseURL: "") }
        #expect(throws: LLMError.self) { try LLMRequestBuilder.endpoint(format: .openAIResponses, baseURL: "https://user:pw@api.openai.com/v1") }
    }

    @Test func reasoningEffortIsOmittedByDefault() throws {
        for format in LLMAPIFormat.allCases {
            let request = try LLMRequestBuilder.makeRequest(profile: profile(format), apiKey: "k", transcript: "t", systemPrompt: "S")
            let json = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
            #expect(json["reasoning"] == nil && json["reasoning_effort"] == nil && json["output_config"] == nil)
        }
    }

    @Test func reasoningEffortMapsPerFormat() throws {
        func json(_ format: LLMAPIFormat, _ effort: String) throws -> [String: Any] {
            var p = profile(format)
            p.reasoningEffort = effort
            let request = try LLMRequestBuilder.makeRequest(profile: p, apiKey: "k", transcript: "t", systemPrompt: "S")
            return try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        }
        #expect((try json(.openAIResponses, " low ")["reasoning"] as? [String: String]) == ["effort": "low"])
        #expect(try json(.openAIChatCompletions, "xhigh")["reasoning_effort"] as? String == "xhigh")
        #expect((try json(.anthropicMessages, "medium")["output_config"] as? [String: String]) == ["effort": "medium"])
        #expect(try json(.openAIChatCompletions, "  ")["reasoning_effort"] == nil)
    }

    @Test func webSearchDeclaresDeepSeekToolPerFormat() throws {
        func json(_ p: LLMProfile, search: Bool = true) throws -> (URLRequest, [String: Any]) {
            let request = try LLMRequestBuilder.makeRequest(profile: p, apiKey: "k", transcript: "t", systemPrompt: "S", webSearch: search)
            return (request, try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any]))
        }
        // The dedicated profile is fixed: DeepSeek host, deepseek-flash, 60 s.
        let fixed = LLMProfile.makeDeepSeekWebSearch()
        let (request, chat) = try json(fixed)
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(chat["model"] as? String == "deepseek-flash")
        #expect((chat["tools"] as? [[String: String]]) == [["type": "deepseek_web_search"]])
        #expect(request.timeoutInterval == 180)
        #expect(chat["stream"] as? Bool == true)
        #expect((chat["thinking"] as? [String: String]) == ["type": "enabled"]) // thinking => multi-step deep search
        // Other wire formats declare the tool the way DeepSeek documents it.
        let (_, responses) = try json(profile(.openAIResponses))
        #expect((responses["tools"] as? [[String: String]]) == [["type": "deepseek_web_search"]])
        let (_, anthropic) = try json(profile(.anthropicMessages))
        #expect((anthropic["tools"] as? [[String: String]]) == [["type": "deepseek_web_search", "name": "deepseek_web_search"]])
        // Off: no tools.
        let plain = try json(fixed, search: false).1
        #expect(plain["tools"] == nil && plain["thinking"] == nil)
    }

    @Test func webSearchResponseParsingIgnoresToolBlocks() throws {
        let anthropic = #"{"content":[{"type":"thinking","thinking":"x"},{"type":"server_tool_use","id":"srvtoolu_1","name":"deepseek_web_search","input":{}},{"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[]},{"type":"text","text":"成品。","citations":[]}]}"#
        #expect(try LLMResponseParser.extractText(format: .anthropicMessages, data: Data(anthropic.utf8)) == "成品。")
        let chat = #"{"choices":[{"message":{"content":"成品。","server_tool_calls":[{"index":0,"calls":[]}]}}]}"#
        #expect(try LLMResponseParser.extractText(format: .openAIChatCompletions, data: Data(chat.utf8)) == "成品。")
    }

    @Test func streamedWebSearchReportsProgressAndText() async throws {
        let sse = """
        : keep-alive
        data: {"choices":[{"delta":{"reasoning_content":"先查一下"},"server_tool_event":{"type":"step_reasoning_done","step":0}}]}

        data: {"choices":[{"delta":{},"server_tool_event":{"type":"call_started","step":0,"call":{"index":0,"type":"deepseek_web_search","kind":"deep_search","action":{"type":"search","queries":["英伟达 CEO","黄仁勋 离职"]}}}}]}

        data: {"choices":[{"delta":{},"server_tool_event":{"type":"call_completed","step":0,"call":{"index":0,"status":"completed","sources":[{"url":"https://a.com"},{"url":"https://b.com"},{"url":"https://c.com"}]}}}]}

        data: {"choices":[{"delta":{},"server_tool_event":{"type":"call_started","step":1,"call":{"index":0,"action":{"type":"open_page","url":"https://news.example.com/x"}}}}]}

        data: {"choices":[{"delta":{},"server_tool_event":{"type":"call_completed","step":1,"call":{"index":0,"status":"completed","page":{"url":"https://news.example.com/x"}}}}]}

        data: {"choices":[{"delta":{"content":"黄仁勋仍是"}}]}

        data: {"choices":[{"delta":{"content":"英伟达 CEO。","server_tool_calls":[{"index":0,"calls":[{"id":"a"}]},{"index":1,"calls":[{"id":"b"}]}]},"finish_reason":"stop"}]}

        data: [DONE]
        """
        final class Seen: @unchecked Sendable { var statuses: [String] = [] }
        let seen = Seen()
        let box = MockTransport.CaptureBox()
        let provider = HTTPLLMProvider(profile: LLMProfile.makeDeepSeekWebSearch(), apiKey: "k",
                                       transport: MockTransport(status: 200, body: sse, capture: box))
        let output = try await provider.processWithWebSearch(transcript: "t", systemPrompt: "S") { seen.statuses.append($0.statusText) }
        #expect(output.text == "黄仁勋仍是英伟达 CEO。")
        #expect(output.progress.searches == 1 && output.progress.results == 3 && output.progress.pages == 1)
        #expect(output.progress.summary == "搜索 1 次，共 3 条结果，读取 1 个网页")
        #expect(seen.statuses.contains("正在搜索「英伟达 CEO、黄仁勋 离职」"))
        #expect(seen.statuses.contains("正在读取网页 news.example.com · 已搜到 3 条结果"))
        #expect(seen.statuses.last == "搜索 1 次 · 已搜到 3 条结果 · 已读取 1 个网页 · 正在整理…")
        #expect(seen.statuses.first == "已开启联网搜索，模型思考中…")
    }

    @Test func streamedWebSearchFallsBackToFinalCallCountAndMapsErrors() async throws {
        // Event shape not recognised, but the final server_tool_calls still tells us the model searched.
        let odd = #"data: {"choices":[{"delta":{"content":"好。","server_tool_calls":[{"index":0,"calls":[{},{}]}]},"finish_reason":"stop"}]}"#
        let provider = HTTPLLMProvider(profile: LLMProfile.makeDeepSeekWebSearch(), apiKey: "k", transport: MockTransport(status: 200, body: odd))
        let output = try await provider.processWithWebSearch(transcript: "t", systemPrompt: "S") { _ in }
        #expect(output.text == "好。" && output.progress.madeAnyCall && output.progress.searches == 2)

        let none = HTTPLLMProvider(profile: LLMProfile.makeDeepSeekWebSearch(), apiKey: "k",
                                   transport: MockTransport(status: 200, body: #"data: {"choices":[{"delta":{"content":"没搜。"}}]}"#))
        let plain = try await none.processWithWebSearch(transcript: "t", systemPrompt: "S") { _ in }
        #expect(!plain.progress.madeAnyCall)

        let failing = HTTPLLMProvider(profile: LLMProfile.makeDeepSeekWebSearch(), apiKey: "k",
                                      transport: MockTransport(status: 401, body: #"{"error":{"message":"bad"}}"#))
        await #expect(throws: LLMError.auth(401)) { try await failing.processWithWebSearch(transcript: "t", systemPrompt: "S") { _ in } }
        let midStream = HTTPLLMProvider(profile: LLMProfile.makeDeepSeekWebSearch(), apiKey: "k",
                                        transport: MockTransport(status: 200, body: #"data: {"error":{"message":"boom"}}"#))
        await #expect(throws: LLMError.server(200, "boom")) { try await midStream.processWithWebSearch(transcript: "t", systemPrompt: "S") { _ in } }
    }

    @Test func countsServerToolCalls() {
        let chat = #"{"choices":[{"message":{"content":"x","server_tool_calls":[{"index":0,"calls":[{"id":"a"},{"id":"b"}]},{"index":1,"calls":[{"id":"c"}]}]}}]}"#
        #expect(LLMResponseParser.serverToolCallCount(format: .openAIChatCompletions, data: Data(chat.utf8)) == 3)
        #expect(LLMResponseParser.serverToolCallCount(format: .openAIChatCompletions, data: Data(#"{"choices":[{"message":{"content":"x"}}]}"#.utf8)) == 0)
        let anthropic = #"{"content":[{"type":"server_tool_use"},{"type":"web_search_tool_result"},{"type":"text","text":"x"}]}"#
        #expect(LLMResponseParser.serverToolCallCount(format: .anthropicMessages, data: Data(anthropic.utf8)) == 1)
        let responses = #"{"output":[{"type":"web_search_call"},{"type":"web_search_call"},{"type":"message","content":[]}]}"#
        #expect(LLMResponseParser.serverToolCallCount(format: .openAIResponses, data: Data(responses.utf8)) == 2)
    }

    @Test func legacyProfileWithoutEffortDecodes() throws {
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(LLMProfile.makeDefault())) as? [String: Any])
        legacy.removeValue(forKey: "reasoningEffort")
        let decoded = try JSONDecoder().decode(LLMProfile.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.reasoningEffort == "")
    }

    @Test func openAIResponsesRequestAndParsing() async throws {
        let box = MockTransport.CaptureBox()
        let body = #"{"output":[{"type":"reasoning","summary":[]},{"type":"message","content":[{"type":"output_text","text":"你好，世界。"}]}]}"#
        let provider = HTTPLLMProvider(profile: profile(.openAIResponses), apiKey: "sk-test",
                                       transport: MockTransport(status: 200, body: body, capture: box))
        let output = try await provider.process(transcript: "嗯你好世界", systemPrompt: "SYS")
        #expect(output == "你好，世界。")

        let request = try #require(box.request)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        let json = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        #expect(json["model"] as? String == "test-model")
        #expect(json["instructions"] as? String == "SYS")
        #expect((json["input"] as? String)?.contains("嗯你好世界") == true)
    }

    @Test func chatCompletionsRequestAndParsing() async throws {
        let box = MockTransport.CaptureBox()
        let body = #"{"choices":[{"message":{"role":"assistant","content":"```\n整理后的文字。\n```"}}]}"#
        let provider = HTTPLLMProvider(profile: profile(.openAIChatCompletions), apiKey: "sk-test",
                                       transport: MockTransport(status: 200, body: body, capture: box))
        let output = try await provider.process(transcript: "原文", systemPrompt: "SYS")
        #expect(output == "整理后的文字。") // code fence stripped

        let json = try #require(JSONSerialization.jsonObject(with: box.request!.httpBody!) as? [String: Any])
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.first?["role"] == "system")
        #expect(messages.first?["content"] == "SYS")
        #expect(messages.last?["role"] == "user")
        #expect(box.request?.url?.path == "/v1/chat/completions")
    }

    @Test func anthropicRequestAndParsing() async throws {
        let box = MockTransport.CaptureBox()
        let body = #"{"content":[{"type":"text","text":"整理"},{"type":"text","text":"完成。"}]}"#
        let provider = HTTPLLMProvider(profile: profile(.anthropicMessages), apiKey: "ak-test",
                                       transport: MockTransport(status: 200, body: body, capture: box))
        let output = try await provider.process(transcript: "原文", systemPrompt: "SYS")
        #expect(output == "整理完成。")

        let request = try #require(box.request)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "ak-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let json = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        #expect(json["system"] as? String == "SYS")
        #expect(json["max_tokens"] as? Int == 4096)
        #expect((json["messages"] as? [[String: Any]])?.count == 1)
    }

    @Test func mapsErrorStatuses() async {
        func run(_ status: Int, _ body: String) async -> LLMError? {
            let provider = HTTPLLMProvider(profile: profile(.openAIChatCompletions), apiKey: "sk-secret-key",
                                           transport: MockTransport(status: status, body: body))
            do { _ = try await provider.process(transcript: "x", systemPrompt: "s"); return nil }
            catch { return error as? LLMError }
        }
        #expect(await run(401, #"{"error":{"message":"bad key"}}"#) == .auth(401))
        #expect(await run(403, "{}") == .auth(403))
        #expect(await run(429, "{}") == .rateLimited)
        if case .modelNotFound = await run(404, #"{"error":{"message":"The model `x` does not exist"}}"#) {} else { Issue.record("404 should be modelNotFound") }
        if case .modelNotFound = await run(400, #"{"error":{"message":"Invalid model"}}"#) {} else { Issue.record("400 model should be modelNotFound") }
        if case .server(500, let detail) = await run(500, #"{"error":{"message":"oops sk-secret-key"}}"#) {
            #expect(!detail.contains("sk-secret-key")) // key redacted from error text
        } else { Issue.record("500 should be server error") }
    }

    @Test func badAndEmptyResponses() async {
        func run(_ body: String) async -> LLMError? {
            let provider = HTTPLLMProvider(profile: profile(.openAIChatCompletions), apiKey: "k",
                                           transport: MockTransport(status: 200, body: body))
            do { _ = try await provider.process(transcript: "x", systemPrompt: "s"); return nil }
            catch { return error as? LLMError }
        }
        if case .badResponse = await run("not json") {} else { Issue.record("expected badResponse") }
        if case .badResponse = await run(#"{"choices":[]}"#) {} else { Issue.record("expected badResponse") }
        #expect(await run(#"{"choices":[{"message":{"content":"  "}}]}"#) == .emptyOutput)
    }

    @Test func missingKeyAndModel() async {
        let noKey = HTTPLLMProvider(profile: profile(.openAIResponses), apiKey: "", transport: MockTransport(status: 200, body: "{}"))
        await #expect(throws: LLMError.missingAPIKey) { try await noKey.process(transcript: "x", systemPrompt: "s") }
        var p = profile(.openAIResponses); p.modelID = " "
        let noModel = HTTPLLMProvider(profile: p, apiKey: "k", transport: MockTransport(status: 200, body: "{}"))
        await #expect(throws: LLMError.self) { try await noModel.process(transcript: "x", systemPrompt: "s") }
    }

    @Test func rawLevelSkipsProvider() async throws {
        struct Failing: LLMProvider {
            func process(transcript: String, systemPrompt: String) async throws -> String { throw LLMError.timeout }
        }
        let output = try await TextProcessor().process(transcript: "原文", level: .raw, basePrompt: "", provider: Failing())
        #expect(output == "原文")
    }

    @Test func deepLevelAddsInstruction() {
        let standard = TextProcessor.systemPrompt(base: "", level: .standard)
        let deep = TextProcessor.systemPrompt(base: "", level: .deep)
        #expect(standard == TextProcessor.defaultSystemPrompt)
        #expect(deep.hasPrefix(standard) && deep.count > standard.count)
    }

    @Test func userPromptContainsTranscriptInFence() {
        let prompt = TextProcessor.userPrompt(transcript: "你好")
        #expect(prompt == "请整理以下语音识别文本：\n\n```\n你好\n```")
    }
}

// MARK: - Coordinator end-to-end with fakes

private final class FakeAudio: AudioCapturing, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Data>.Continuation?
    private(set) var stopCount = 0
    var chunksToEmitOnStart = 0

    func start(onLevel: @escaping @Sendable (Float) -> Void,
               onInterruption: @escaping @Sendable (AudioCaptureError) -> Void) throws -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        lock.withLock { self.continuation = continuation }
        for _ in 0..<chunksToEmitOnStart { continuation.yield(Data(count: AudioPipeline.chunkSize)) }
        return stream
    }

    func stop() {
        lock.withLock {
            stopCount += 1
            continuation?.finish()
            continuation = nil
        }
    }
}

private actor FakeASR: ASRService {
    nonisolated let events: AsyncStream<ASREvent>
    private let continuation: AsyncStream<ASREvent>.Continuation
    private(set) var sentChunks = 0
    private(set) var finishCalled = false
    private(set) var closed = false
    var failOnConnect: ASRError?
    var scriptOnFinish: [ASREvent] = []
    var failAfterChunks: Int?

    init(failOnConnect: ASRError? = nil, scriptOnFinish: [ASREvent] = [], failAfterChunks: Int? = nil) {
        (events, continuation) = AsyncStream.makeStream(of: ASREvent.self)
        self.failOnConnect = failOnConnect
        self.scriptOnFinish = scriptOnFinish
        self.failAfterChunks = failAfterChunks
    }

    func connect() async throws { if let failOnConnect { throw failOnConnect } }
    func sendAudio(_ pcm: Data) async throws {
        sentChunks += 1
        if sentChunks == 1 { continuation.yield(.preview(itemID: "i1", text: "你好", stash: "世界")) }
        if let failAfterChunks, sentChunks >= failAfterChunks {
            continuation.yield(.failed(.disconnected("test")))
            continuation.finish()
        }
    }
    func commit() async throws {}
    func finish() async throws {
        finishCalled = true
        for event in scriptOnFinish { continuation.yield(event) }
        continuation.yield(.finished)
        continuation.finish()
    }
    func close() async { closed = true; continuation.finish() }
}

@MainActor
private final class FakeInserter: TextInserting {
    var outcome: InsertionOutcome = .insertedViaAccessibility
    private(set) var inserted: [String] = []
    func captureTarget() -> InsertionTarget? { InsertionTarget(pid: 1, appName: "Test", element: nil, isSecure: false) }
    func insert(_ text: String, into target: InsertionTarget?) async -> InsertionOutcome {
        inserted.append(text)
        return outcome
    }
}

@MainActor
private final class FakePermissions: PermissionChecking {
    var granted = true
    func ensureMicrophone() async -> Bool { granted }
}

private final class PromptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [(transcript: String, prompt: String)] = []
    var calls: [(transcript: String, prompt: String)] { lock.withLock { storage } }
    private var searchStorage: [Bool] = []
    var webSearchFlags: [Bool] { lock.withLock { searchStorage } }
    func record(_ transcript: String, _ prompt: String, webSearch: Bool = false) {
        lock.withLock { storage.append((transcript, prompt)); searchStorage.append(webSearch) }
    }
}

private struct FakeLLM: LLMProvider {
    var result: Result<String, LLMError>
    var recorder: PromptRecorder?
    func process(transcript: String, systemPrompt: String) async throws -> String {
        recorder?.record(transcript, systemPrompt)
        return try result.get()
    }
    func processWithWebSearch(
        transcript: String, systemPrompt: String, onProgress: @escaping @Sendable (WebSearchProgress) -> Void
    ) async throws -> WebSearchOutput {
        recorder?.record(transcript, systemPrompt, webSearch: true)
        let progress = WebSearchProgress(searches: 2, results: 9, pages: 1)
        onProgress(progress)
        return WebSearchOutput(text: try result.get(), progress: progress)
    }
}

@MainActor
private struct Harness {
    let coordinator: DictationSessionCoordinator
    let audio: FakeAudio
    let inserter: FakeInserter
    let permissions: FakePermissions
    let settings: SettingsStore
    let credentials = InMemoryCredentialStore()

    init(asr: @escaping @Sendable () -> FakeASR, llm: Result<String, LLMError> = .success("整理后的文字。"),
         recorder: PromptRecorder? = nil, configure: (SettingsStore) -> Void = { _ in }) {
        let suite = "opentype.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = SettingsStore(defaults: defaults)
        settings.asrWorkspaceID = "ws-test"
        settings.soundFeedbackEnabled = false
        configure(settings)
        let audio = FakeAudio()
        audio.chunksToEmitOnStart = 5
        let inserter = FakeInserter()
        let permissions = FakePermissions()
        let credentials = self.credentials
        try? credentials.save("asr-key", account: CredentialAccount.bailianAPIKey)
        if let profile = settings.activeProfile { try? credentials.save("llm-key", account: CredentialAccount.llmProfile(profile.id)) }
        self.coordinator = DictationSessionCoordinator(
            settingsStore: settings, credentialStore: credentials, permissions: PermissionManager(),
            audio: audio, permissionChecker: permissions,
            makeASR: { _ in asr() }, makeLLM: { _, _ in FakeLLM(result: llm, recorder: recorder) },
            inserter: inserter, overlay: nil, playsSounds: false
        )
        self.audio = audio; self.inserter = inserter; self.permissions = permissions; self.settings = settings
    }

    /// Waits until the predicate holds (max ~3 s).
    func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<300 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
struct CoordinatorTests {
    @Test func initialStateIsIdle() {
        let harness = Harness(asr: { FakeASR() })
        #expect(harness.coordinator.state == .idle)
        #expect(harness.coordinator.currentSessionID == nil)
    }

    @Test func happyPathInsertsProcessedText() async {
        let harness = Harness(asr: {
            FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "嗯你好世界")])
        })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        #expect(c.state == .connecting)
        #expect(c.currentSessionID != nil)

        await harness.wait { c.state == .recording }
        #expect(c.state == .recording)
        await harness.wait { !c.solidText.isEmpty }
        #expect(c.solidText == "你好")
        #expect(c.stashText == "世界")

        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["整理后的文字。"])
        await harness.wait { if case .success = c.state { true } else { false } }
        if case .success(let note) = c.state { #expect(note == nil) } else { Issue.record("expected success, got \(c.state)") }
        #expect(c.currentSessionID == nil)
    }

    @Test func hotkeyPressTogglesRecording() async {
        let harness = Harness(asr: {
            FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好")])
        })
        let c = harness.coordinator
        c.handleHotkeyPress() // first press starts
        #expect(c.state == .connecting)
        await harness.wait { c.state == .recording }
        #expect(c.state == .recording)
        c.handleHotkeyPress() // second press stops and inserts
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted.count == 1)
    }

    @Test func llmFailureFallsBackToRawText() async {
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原始文本")]) },
            llm: .failure(.timeout)
        )
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["原始文本"])
        await harness.wait { if case .success(let n) = c.state { n != nil } else { false } }
        if case .success(let note) = c.state { #expect(note?.contains("已使用原文") == true) } else { Issue.record("expected success with note") }
    }

    @Test func llmFailureWithoutFallbackKeepsTextForCopy() async {
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原始文本")]) },
            llm: .failure(.rateLimited),
            configure: { $0.fallbackToRawOnLLMFailure = false }
        )
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(c.pendingText == "原始文本")
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func rawModeSkipsLLM() async {
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原始文本")]) },
            llm: .failure(.timeout), // would fail if called
            configure: { $0.processingLevel = .raw }
        )
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["原始文本"])
        if case .success(let note) = c.state { #expect(note == nil) }
    }

    @Test func noSpeechInsertsNothing() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: []) })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { c.state == .idle }
        #expect(c.state == .idle)
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func manualCopyWhenInsertionRefused() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) })
        harness.inserter.outcome = .requiresManualCopy(reason: "目标是密码框")
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { if case .manualCopy = c.state { true } else { false } }
        guard case .manualCopy(let reason) = c.state else { Issue.record("expected manualCopy, got \(c.state)"); return }
        #expect(reason.contains("密码框"))
        #expect(c.pendingText == "整理后的文字。")
        c.cancelSession()
        #expect(c.state == .idle)
        #expect(c.pendingText.isEmpty)
    }

    @Test func autoInsertDisabledShowsManualCopy() async {
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) },
            configure: { $0.autoInsertEnabled = false }
        )
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { if case .manualCopy = c.state { true } else { false } }
        guard case .manualCopy = c.state else { Issue.record("expected manualCopy, got \(c.state)"); return }
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func escapeCancelsWithoutInserting() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.cancelSession()
        #expect(c.state == .idle)
        #expect(c.currentSessionID == nil)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(c.state == .idle)
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func busyStateRejectsNewSession() async {
        let harness = Harness(asr: { FakeASR() })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        let first = c.currentSessionID
        c.beginSession(mode: .hold)
        #expect(c.currentSessionID == first)
        c.cancelSession()
    }

    @Test func connectFailureShowsErrorAndStopsAudio() async {
        let harness = Harness(asr: { FakeASR(failOnConnect: .auth(401)) })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error(let message) = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(message.contains("401"))
        #expect(harness.audio.stopCount >= 1)
        #expect(!c.state.isBusy)
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func asrDisconnectKeepsRecognisedText() async {
        let harness = Harness(asr: { FakeASR(failAfterChunks: 2) })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(c.pendingText == "你好世界") // confirmed text + stash kept for copy, nothing guessed
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func missingConfigurationFailsBeforeRecording() async {
        let harness = Harness(asr: { FakeASR() }, configure: { $0.asrWorkspaceID = "" })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error(let message) = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(message.contains("Workspace ID"))
        #expect(!c.state.isBusy)
    }

    @Test func deepSeekProviderRequiresItsOwnKey() async {
        let harness = Harness(asr: { FakeASR() }, configure: { $0.asrProvider = .deepseek })
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error(let message) = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(message.contains("DeepSeek"))
    }

    @Test func deepSeekConfigUsesDeepSeekEndpointAndKey() throws {
        let harness = Harness(asr: { FakeASR() }, configure: { $0.asrProvider = .deepseek })
        try harness.credentials.save("ds-key", account: CredentialAccount.deepseekASRAPIKey)
        let config = try harness.coordinator.asrConfig()
        #expect(config.provider == .deepseek)
        #expect(config.url == DeepSeekASR.endpoint)
        #expect(config.apiKey == "ds-key")
    }

    @Test func deniedMicrophoneFailsCleanly() async {
        let harness = Harness(asr: { FakeASR() })
        harness.permissions.granted = false
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error(let message) = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(message.contains("麦克风"))
    }

    @Test func translationSessionTranslatesToDefaultLanguage() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好世界")]) },
            llm: .success("Hello world"), recorder: recorder,
            configure: { $0.translationTargetLanguage = .japanese }
        )
        let c = harness.coordinator
        c.beginSession(mode: .toggle, translating: true)
        #expect(c.translationTarget == .japanese) // pre-selected from Settings
        await harness.wait { c.state == .recording }
        #expect(c.canChangeTranslationTarget)
        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["Hello world"])
        let call = try? #require(recorder.calls.first)
        #expect(call?.transcript == "你好世界")
        #expect(call?.prompt == TextProcessor.translationSystemPrompt(target: .japanese))
        #expect(harness.settings.translationTargetLanguage == .japanese)
    }

    @Test func translationLanguageCanBeSwitchedInPopup() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好")]) },
            recorder: recorder
        )
        let c = harness.coordinator
        c.beginSession(mode: .toggle, translating: true)
        await harness.wait { c.state == .recording }
        c.setTranslationTarget(.french)
        #expect(c.translationTarget == .french)
        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(recorder.calls.first?.prompt == TextProcessor.translationSystemPrompt(target: .french))
        #expect(harness.settings.translationTargetLanguage == .english) // default stays untouched
        c.setTranslationTarget(.german) // locked after processing
        #expect(c.translationTarget == .french)
    }

    @Test func regionFollowsSettingsAndPopupChoice() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好")]) },
            llm: .success("Olá"), recorder: recorder,
            configure: {
                $0.translationTargetLanguage = .portuguese
                $0.setTranslationRegion(.portugal, for: .portuguese)
            }
        )
        let c = harness.coordinator
        c.beginSession(mode: .toggle, translating: true)
        #expect(c.translationRegion == .portugal) // from Settings
        await harness.wait { c.state == .recording }
        c.setTranslationRegion(.brazil) // popup override
        c.setTranslationRegion(.taiwan) // not a Portuguese variant: ignored
        #expect(c.translationRegion == .brazil)
        c.setTranslationTarget(.traditionalChinese) // switching language picks that language's configured region
        #expect(c.translationRegion == .taiwan)
        c.setTranslationTarget(.portuguese)
        #expect(c.translationRegion == .portugal)
        c.setTranslationRegion(.brazil)
        c.stopRecording()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(recorder.calls.first?.prompt == TextProcessor.translationSystemPrompt(target: .portuguese, region: .brazil))
        #expect(harness.settings.translationRegion(for: .portuguese) == .portugal) // Settings untouched
    }

    @Test func translationIgnoresRawModeAndLLMSwitch() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好")]) },
            llm: .success("Hello"), recorder: recorder,
            configure: { $0.processingLevel = .raw; $0.llmEnabled = false }
        )
        let c = harness.coordinator
        c.handleTranslationHotkeyPress()
        await harness.wait { c.state == .recording }
        c.handleTranslationHotkeyPress() // second press ends recording
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["Hello"])
        #expect(recorder.calls.count == 1)
    }

    @Test func translationFailureNeverInsertsUntranslatedText() async {
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原始文本")]) },
            llm: .failure(.timeout)
        )
        let c = harness.coordinator
        c.beginSession(mode: .toggle, translating: true)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { if case .error = c.state { true } else { false } }
        guard case .error(let message) = c.state else { Issue.record("expected error, got \(c.state)"); return }
        #expect(message.contains("翻译失败"))
        #expect(c.pendingText == "原始文本")
        #expect(harness.inserter.inserted.isEmpty)
    }

    @Test func dictationSessionHasNoTranslationTarget() async {
        let harness = Harness(asr: { FakeASR() })
        let c = harness.coordinator
        c.beginSession(mode: .toggle)
        #expect(c.translationTarget == nil)
        c.setTranslationTarget(.french) // ignored for plain dictation
        #expect(c.translationTarget == nil)
        c.cancelSession()
    }

    // MARK: Help me say

    @Test func holdingHotkeyUpgradesToHelpMeSayAndReleaseEndsRecording() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "跟老师说我明天请假")]) },
            llm: .success("老师您好，我明天需要请假一天。"), recorder: recorder,
            configure: { $0.processingLevel = .raw; $0.llmEnabled = false }
        )
        let c = harness.coordinator
        c.handleHotkeyPress() // key down: starts a normal session
        #expect(!c.isHelpMeSay)
        #expect(c.handleHotkeyLongPress() == true) // still held past the threshold
        #expect(c.isHelpMeSay)
        #expect(c.sessionMode == .hold)
        await harness.wait { c.state == .recording }
        c.handleHotkeyRelease() // key up ends the recording
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["老师您好，我明天需要请假一天。"])
        #expect(recorder.calls.first?.transcript == "跟老师说我明天请假")
        #expect(recorder.calls.first?.prompt == TextProcessor.defaultHelpMeSayPrompt)
    }

    @Test func shortTapStaysPlainDictation() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) })
        let c = harness.coordinator
        c.handleHotkeyPress()
        c.handleHotkeyRelease() // released before the threshold
        #expect(!c.isHelpMeSay)
        #expect(c.sessionMode == .toggle)
        await harness.wait { c.state == .recording }
        #expect(c.state == .recording) // keeps recording until the next press
        c.handleHotkeyPress()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(!harness.inserter.inserted.isEmpty)
    }

    @Test func longPressWhileEndingARecordingDoesNothing() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) })
        let c = harness.coordinator
        c.handleHotkeyPress()
        c.handleHotkeyRelease()
        await harness.wait { c.state == .recording }
        c.handleHotkeyPress() // this press only stops the recording
        #expect(c.handleHotkeyLongPress() == false)
        #expect(!c.isHelpMeSay)
        await harness.wait { harness.inserter.inserted.count == 1 }
    }

    @Test func modifierOnlyLongPressStartsHelpMeSayItself() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "问下这个报错")]) },
            llm: .success("请问……"), recorder: recorder
        )
        let c = harness.coordinator
        #expect(c.handleHotkeyLongPress() == true) // idle: the long press begins the session
        #expect(c.isHelpMeSay && c.state == .connecting)
        await harness.wait { c.state == .recording }
        c.handleHotkeyRelease()
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["请问……"])
    }

    @Test func helpMeSayDisabledIgnoresLongPress() async {
        let harness = Harness(asr: { FakeASR() }, configure: { $0.helpMeSayEnabled = false })
        let c = harness.coordinator
        c.handleHotkeyPress()
        #expect(c.handleHotkeyLongPress() == false)
        #expect(!c.isHelpMeSay)
        #expect(c.sessionMode == .toggle)
        c.cancelSession()
        #expect(c.handleHotkeyLongPress() == false)
        #expect(c.state == .idle)
    }

    @Test func helpMeSayUsesCustomPromptAndIgnoresCleanupSwitches() async {
        let recorder = PromptRecorder()
        let harness = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "你好")]) },
            llm: .success("成品"), recorder: recorder,
            configure: { $0.processingLevel = .raw; $0.llmEnabled = false; $0.helpMeSayPrompt = "自定义提示" }
        )
        let c = harness.coordinator
        c.toggleHelpMeSayFromMenu()
        #expect(c.isHelpMeSay && c.sessionMode == .toggle)
        await harness.wait { c.state == .recording }
        c.toggleHelpMeSayFromMenu() // second tap ends it
        await harness.wait { harness.inserter.inserted.count == 1 }
        #expect(harness.inserter.inserted == ["成品"])
        #expect(recorder.calls.first?.prompt == "自定义提示")
    }

    @Test func helpMeSayWebSearchUsesFixedDeepSeekProfileAndOwnKey() async {
        final class Seen: @unchecked Sendable { var profiles: [LLMProfile] = []; var keys: [String] = [] }
        func run(enabled: Bool, withKey: Bool) async -> (flags: [Bool], prompt: String?, seen: Seen, state: DictationState) {
            let recorder = PromptRecorder()
            let seen = Seen()
            let suite = "opentype.tests.\(UUID().uuidString)"
            let settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
            settings.asrWorkspaceID = "ws-test"
            settings.soundFeedbackEnabled = false
            settings.helpMeSayWebSearchEnabled = enabled
            settings.fallbackToRawOnLLMFailure = false
            let credentials = InMemoryCredentialStore()
            try? credentials.save("asr-key", account: CredentialAccount.bailianAPIKey)
            if let p = settings.activeProfile { try? credentials.save("profile-key", account: CredentialAccount.llmProfile(p.id)) }
            if withKey { try? credentials.save("search-key", account: CredentialAccount.deepseekWebSearchAPIKey) }
            let audio = FakeAudio(); audio.chunksToEmitOnStart = 5
            let inserter = FakeInserter()
            let c = DictationSessionCoordinator(
                settingsStore: settings, credentialStore: credentials, permissions: PermissionManager(),
                audio: audio, permissionChecker: FakePermissions(),
                makeASR: { _ in FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原话")]) },
                makeLLM: { profile, key in
                    seen.profiles.append(profile); seen.keys.append(key)
                    return FakeLLM(result: .success("成品"), recorder: recorder)
                },
                inserter: inserter, overlay: nil, playsSounds: false
            )
            c.toggleHelpMeSayFromMenu()
            for _ in 0..<100 where c.state != .recording { try? await Task.sleep(for: .milliseconds(30)) }
            c.toggleHelpMeSayFromMenu()
            for _ in 0..<100 {
                if inserter.inserted.count == 1 { break }
                if case .error = c.state { break }
                try? await Task.sleep(for: .milliseconds(30))
            }
            return (recorder.webSearchFlags, recorder.calls.first?.prompt, seen, c.state)
        }
        let on = await run(enabled: true, withKey: true)
        #expect(on.flags == [true])
        #expect(on.prompt?.contains(TextProcessor.webSearchAddendum) == true)
        #expect(on.seen.keys == ["search-key"]) // not the active profile's key
        #expect(on.seen.profiles.first?.baseURL == "https://api.deepseek.com")
        #expect(on.seen.profiles.first?.modelID == "deepseek-flash")
        let off = await run(enabled: false, withKey: true)
        #expect(off.flags == [false] && off.prompt == TextProcessor.defaultHelpMeSayPrompt)
        #expect(off.seen.keys == ["profile-key"])
        // Enabled without a key: fails (no silent fallback to another model) and nothing is sent.
        let noKey = await run(enabled: true, withKey: false)
        #expect(noKey.flags.isEmpty)
        if case .error(let message) = noKey.state { #expect(message.contains("联网搜索")) } else { Issue.record("expected error") }
    }

    @Test func helpMeSayFailureFallsBackOrKeepsRawText() async {
        let fallback = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原话")]) },
            llm: .failure(.timeout)
        )
        let a = fallback.coordinator
        a.toggleHelpMeSayFromMenu()
        await fallback.wait { a.state == .recording }
        a.toggleHelpMeSayFromMenu()
        await fallback.wait { fallback.inserter.inserted.count == 1 }
        #expect(fallback.inserter.inserted == ["原话"]) // fallbackToRawOnLLMFailure defaults to on

        let strict = Harness(
            asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "原话")]) },
            llm: .failure(.timeout), configure: { $0.fallbackToRawOnLLMFailure = false }
        )
        let b = strict.coordinator
        b.toggleHelpMeSayFromMenu()
        await strict.wait { b.state == .recording }
        b.toggleHelpMeSayFromMenu()
        await strict.wait { if case .error = b.state { true } else { false } }
        guard case .error(let message) = b.state else { Issue.record("expected error, got \(b.state)"); return }
        #expect(message.contains("帮我说失败"))
        #expect(b.pendingText == "原话")
        #expect(strict.inserter.inserted.isEmpty)
    }

    @Test func newSessionAfterResultIsAllowed() async {
        let harness = Harness(asr: { FakeASR(scriptOnFinish: [.completed(itemID: "i1", transcript: "文本")]) })
        harness.inserter.outcome = .requiresManualCopy(reason: "x")
        let c = harness.coordinator
        c.beginSession(mode: .hold)
        await harness.wait { c.state == .recording }
        c.stopRecording()
        await harness.wait { if case .manualCopy = c.state { true } else { false } }
        c.beginSession(mode: .hold)
        #expect(c.state == .connecting)
        #expect(c.pendingText.isEmpty)
        c.cancelSession()
    }
}

// MARK: - Hotkey state machine

@MainActor
struct HotkeyTests {
    private func makeManager() -> (HotkeyManager, Counter) {
        let manager = HotkeyManager()
        let counter = Counter()
        manager.onPress = { counter.press += 1 }
        manager.onRelease = { counter.release += 1 }
        manager.onCancel = { counter.cancel += 1 }
        return (manager, counter)
    }

    final class Counter { var press = 0, release = 0, cancel = 0 }

    private let chord: CGEventFlags = [.maskControl, .maskAlternate]

    @Test func pressAndReleaseOnKeyUp() {
        let (m, c) = makeManager()
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false) == true)
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: true) == true) // repeat swallowed
        #expect(c.press == 1)
        #expect(m.handle(type: .keyUp, keyCode: 49, flags: chord, isAutoRepeat: false) == true)
        #expect(c.release == 1)
    }

    @Test func releasingModifierEarlyEndsSession() {
        let (m, c) = makeManager()
        _ = m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false)
        _ = m.handle(type: .flagsChanged, keyCode: 58, flags: [.maskControl], isAutoRepeat: false) // option released
        #expect(c.release == 1)
        // later key-up must not release twice, but is still swallowed
        #expect(m.handle(type: .keyUp, keyCode: 49, flags: [], isAutoRepeat: false) == true)
        #expect(c.release == 1)
    }

    @Test func otherKeysAndWrongModifiersPassThrough() {
        let (m, c) = makeManager()
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: [], isAutoRepeat: false) == false)
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: [.maskControl], isAutoRepeat: false) == false)
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: [.maskControl, .maskAlternate, .maskShift], isAutoRepeat: false) == false)
        #expect(m.handle(type: .keyDown, keyCode: 0, flags: chord, isAutoRepeat: false) == false)
        #expect(c.press == 0)
    }

    @Test func pausedHotkeyDoesNothing() {
        let (m, c) = makeManager()
        m.isEnabled = { false }
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false) == false)
        #expect(c.press == 0)
    }

    @Test func escapeOnlyInterceptedWhenSessionVisible() {
        let (m, c) = makeManager()
        #expect(m.handle(type: .keyDown, keyCode: 53, flags: [], isAutoRepeat: false) == false)
        m.shouldInterceptEscape = { true }
        #expect(m.handle(type: .keyDown, keyCode: 53, flags: [], isAutoRepeat: false) == true)
        #expect(c.cancel == 1)
    }

    @Test func tapDisabledReleasesStuckSession() {
        let (m, c) = makeManager()
        _ = m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false)
        _ = m.handle(type: .tapDisabledByTimeout, keyCode: 0, flags: [], isAutoRepeat: false)
        #expect(c.release == 1)
    }
}

@MainActor
struct HotkeyLongPressTests {
    private let chord: CGEventFlags = [.maskControl, .maskAlternate]

    @Test func chordHoldFiresLongPressThenReleases() {
        let m = HotkeyManager()
        var press = 0, release = 0, long = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }
        m.onLongPress = { long += 1; return true }
        _ = m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false)
        #expect(press == 1)
        m.fireLongPress()
        #expect(long == 1 && release == 0)
        _ = m.handle(type: .keyUp, keyCode: 49, flags: chord, isAutoRepeat: false)
        #expect(release == 1)
        m.fireLongPress() // late timer after release: ignored
        #expect(long == 1)
    }

    @Test func modifierOnlyHoldReplacesTapWhenClaimed() {
        let m = HotkeyManager()
        var press = 0, release = 0, long = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }
        m.onLongPress = { long += 1; return true }
        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn)
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn, isAutoRepeat: false)
        m.fireLongPress()
        #expect(long == 1 && press == 0)
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: [], isAutoRepeat: false)
        #expect(press == 0 && release == 1) // no tap on release, only the end of the hold
    }

    @Test func unclaimedLongPressStillCountsAsTap() {
        let m = HotkeyManager()
        var press = 0, release = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }
        m.onLongPress = { false }
        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn)
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn, isAutoRepeat: false)
        m.fireLongPress()
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: [], isAutoRepeat: false)
        #expect(press == 1 && release == 1)
    }

    @Test func otherKeyDuringClaimedHoldEndsIt() {
        let m = HotkeyManager()
        var release = 0
        m.onRelease = { release += 1 }
        m.onLongPress = { true }
        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn)
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn, isAutoRepeat: false)
        m.fireLongPress()
        _ = m.handle(type: .keyDown, keyCode: 123, flags: .maskSecondaryFn, isAutoRepeat: false)
        #expect(release == 1)
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: [], isAutoRepeat: false)
        #expect(release == 1) // not reported twice
    }

    @Test func shortHoldNeverFiresLongPress() async {
        let m = HotkeyManager()
        var long = 0
        m.onLongPress = { long += 1; return true }
        m.longPressDelay = .milliseconds(30)
        _ = m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false)
        _ = m.handle(type: .keyUp, keyCode: 49, flags: chord, isAutoRepeat: false)
        try? await Task.sleep(for: .milliseconds(120))
        #expect(long == 0)
    }

    @Test func timerFiresWhileStillHeld() async {
        let m = HotkeyManager()
        var long = 0
        m.onLongPress = { long += 1; return true }
        m.longPressDelay = .milliseconds(30)
        _ = m.handle(type: .keyDown, keyCode: 49, flags: chord, isAutoRepeat: false)
        try? await Task.sleep(for: .milliseconds(150))
        #expect(long == 1)
        _ = m.handle(type: .keyUp, keyCode: 49, flags: chord, isAutoRepeat: false)
    }
}

struct HotkeyConfigTests {
    @Test func validation() {
        #expect(HotkeyConfig.default.validation == .ok)
        #expect(HotkeyConfig(keyCode: 122, modifiers: []).validation == .ok)                       // F1 alone
        #expect(HotkeyConfig(keyCode: 0, modifiers: []).validation == .ok)                          // plain A is allowed
        #expect(HotkeyConfig(keyCode: 0, modifiers: .maskShift).validation == .ok)
        #expect(HotkeyConfig(keyCode: 53, modifiers: .maskCommand).validation != .ok)               // Esc reserved
        #expect(HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn).validation == .ok)          // fn alone
        #expect(HotkeyConfig(keyCode: nil, modifiers: .maskCommand, modifierKeyCode: 54).validation == .ok) // right ⌘ alone
        #expect(HotkeyConfig(keyCode: nil, modifiers: []).validation != .ok)
    }

    @Test func cautions() {
        #expect(HotkeyConfig.default.caution == nil)
        #expect(HotkeyConfig(keyCode: 122, modifiers: []).caution == nil)
        #expect(HotkeyConfig(keyCode: 0, modifiers: []).caution != nil)
        #expect(HotkeyConfig(keyCode: nil, modifiers: .maskAlternate, modifierKeyCode: 61).caution != nil)
    }

    @Test func displayNames() {
        #expect(HotkeyConfig.default.displayName == "⌃⌥ Space")
        #expect(HotkeyConfig(keyCode: 122, modifiers: []).displayName == "F1")
        #expect(HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn).displayName == "fn（仅修饰键）")
        #expect(HotkeyConfig(keyCode: nil, modifiers: .maskAlternate, modifierKeyCode: 61).displayName == "右 ⌥ 键（单独按下）")
    }

    @Test func codableRoundTrip() throws {
        let config = HotkeyConfig(keyCode: 2, modifiers: [.maskCommand, .maskShift])
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
    }
}

@MainActor
struct CustomHotkeyTests {
    @Test func customChordAndFnModifierOnly() {
        let m = HotkeyManager()
        var press = 0, release = 0, cancel = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }; m.onCancel = { cancel += 1 }

        m.hotkey = HotkeyConfig(keyCode: 2, modifiers: [.maskCommand, .maskShift]) // ⇧⌘D
        #expect(m.handle(type: .keyDown, keyCode: 2, flags: [.maskCommand, .maskShift], isAutoRepeat: false))
        _ = m.handle(type: .keyUp, keyCode: 2, flags: [.maskCommand, .maskShift], isAutoRepeat: false)
        #expect(press == 1 && release == 1)

        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskSecondaryFn) // tap fn
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn, isAutoRepeat: false)
        #expect(press == 1) // still only the chord's press: fn going down alone triggers nothing yet
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: [], isAutoRepeat: false)
        #expect(press == 2 && release == 2)

        // fn + another key (e.g. fn+F1 / arrow) is a different gesture: no tap
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn, isAutoRepeat: false)
        #expect(!m.handle(type: .keyDown, keyCode: 123, flags: .maskSecondaryFn, isAutoRepeat: false))
        _ = m.handle(type: .flagsChanged, keyCode: 63, flags: [], isAutoRepeat: false)
        #expect(press == 2 && release == 2 && cancel == 0)
    }

    @Test func singleSidedModifierOnlyReactsToThatKey() {
        let m = HotkeyManager()
        var press = 0, release = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }
        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskAlternate, modifierKeyCode: 61) // right ⌥
        let leftDown = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20)
        let rightDown = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40)

        _ = m.handle(type: .flagsChanged, keyCode: 58, flags: leftDown, isAutoRepeat: false) // left ⌥: ignored
        #expect(press == 0)
        _ = m.handle(type: .flagsChanged, keyCode: 58, flags: [], isAutoRepeat: false)
        _ = m.handle(type: .flagsChanged, keyCode: 61, flags: rightDown, isAutoRepeat: false)
        #expect(press == 0) // fires on release, as one tap
        _ = m.handle(type: .flagsChanged, keyCode: 61, flags: [], isAutoRepeat: false)
        #expect(press == 1 && release == 1)
    }

    @Test func plainSingleKeyShortcut() {
        let m = HotkeyManager()
        var press = 0, release = 0
        m.onPress = { press += 1 }; m.onRelease = { release += 1 }
        m.hotkey = HotkeyConfig(keyCode: 122, modifiers: []) // F1
        #expect(m.handle(type: .keyDown, keyCode: 122, flags: [.maskSecondaryFn], isAutoRepeat: false))
        _ = m.handle(type: .keyUp, keyCode: 122, flags: [.maskSecondaryFn], isAutoRepeat: false)
        #expect(press == 1 && release == 1)
    }

    @Test func modifierOnlyTapIgnoresOrdinaryChordsAndClicks() {
        let m = HotkeyManager()
        var press = 0
        m.onPress = { press += 1 }
        m.hotkey = HotkeyConfig(keyCode: nil, modifiers: .maskCommand)
        // ⌘C: another key arrives while ⌘ is down → not a tap
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: .maskCommand, isAutoRepeat: false)
        _ = m.handle(type: .keyDown, keyCode: 8, flags: .maskCommand, isAutoRepeat: false)
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: [], isAutoRepeat: false)
        #expect(press == 0)
        // ⌘-click
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: .maskCommand, isAutoRepeat: false)
        _ = m.handle(type: .leftMouseDown, keyCode: 0, flags: .maskCommand, isAutoRepeat: false)
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: [], isAutoRepeat: false)
        #expect(press == 0)
        // a plain tap, however brief, fires once on release
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: .maskCommand, isAutoRepeat: false)
        #expect(press == 0)
        _ = m.handle(type: .flagsChanged, keyCode: 55, flags: [], isAutoRepeat: false)
        #expect(press == 1)
    }

    @Test func fnFlagOnArrowKeysDoesNotBreakNormalChord() {
        let m = HotkeyManager()
        var press = 0
        m.onPress = { press += 1 }
        m.hotkey = HotkeyConfig(keyCode: 49, modifiers: .maskControl) // ⌃Space, fn not required
        #expect(m.handle(type: .keyDown, keyCode: 49, flags: [.maskControl, .maskSecondaryFn], isAutoRepeat: false))
        #expect(press == 1)
    }
}

// MARK: - Settings

@MainActor
struct SettingsStoreTests {
    private func makeStore() -> (SettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")!
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func defaultsMatchPRD() {
        let (s, _) = makeStore()
        #expect(s.hotkey == .default)
        #expect(s.asrTurnDetection == .serverVAD)
        #expect(s.asrVADThreshold == 0.0)
        #expect(s.asrSilenceDurationMS == 400)
        #expect(s.asrLanguage == .auto)
        #expect(s.processingLevel == .standard)
        #expect(s.fallbackToRawOnLLMFailure)
        #expect(!s.soundFeedbackEnabled)
        #expect(s.llmProfiles.count == 1)
        #expect(s.activeProfile != nil)
    }

    @Test func translationSettingsDefaultAndPersist() {
        let (s, defaults) = makeStore()
        #expect(s.translationTargetLanguage == .english)
        #expect(s.translationHotkey == .defaultTranslation)
        s.translationTargetLanguage = .korean
        s.translationHotkey = nil // explicitly cleared must stay cleared
        var reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.translationTargetLanguage == .korean)
        #expect(reloaded.translationHotkey == nil)
        let custom = HotkeyConfig(keyCode: 2, modifiers: [.maskCommand, .maskShift])
        s.translationHotkey = custom
        reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.translationHotkey == custom)
    }

    @Test func regionalVariantsAreOnlyOfferedWhereTheyMatter() {
        #expect(TranslationLanguage.portuguese.regions == [.brazil, .portugal])
        #expect(TranslationLanguage.traditionalChinese.regions == [.taiwan, .hongKongMacau])
        #expect(TranslationLanguage.english.regions.isEmpty)
        #expect(TranslationLanguage.simplifiedChinese.regions.isEmpty)
    }

    @Test func regionDefaultsAndPersists() {
        let (s, defaults) = makeStore()
        #expect(s.translationRegion(for: .portuguese) == .brazil)
        #expect(s.translationRegion(for: .traditionalChinese) == .taiwan)
        #expect(s.translationRegion(for: .japanese) == nil)
        s.setTranslationRegion(.portugal, for: .portuguese)
        s.setTranslationRegion(.hongKongMacau, for: .traditionalChinese)
        s.setTranslationRegion(.taiwan, for: .portuguese) // not a Portuguese variant: ignored
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.translationRegion(for: .portuguese) == .portugal)
        #expect(reloaded.translationRegion(for: .traditionalChinese) == .hongKongMacau)
        reloaded.translationTargetLanguage = .traditionalChinese
        #expect(reloaded.translationLabel == "繁體中文（港澳）")
    }

    @Test func promptNamesTheRegionalVariant() {
        let br = TextProcessor.translationSystemPrompt(target: .portuguese, region: .brazil)
        let pt = TextProcessor.translationSystemPrompt(target: .portuguese, region: .portugal)
        let tw = TextProcessor.translationSystemPrompt(target: .traditionalChinese, region: .taiwan)
        let hk = TextProcessor.translationSystemPrompt(target: .traditionalChinese, region: .hongKongMacau)
        #expect(br.contains("Brazilian Portuguese") && !br.contains("European Portuguese"))
        #expect(pt.contains("European Portuguese") && !pt.contains("Brazilian Portuguese"))
        #expect(tw.contains("Taiwan") && !tw.contains("Hong Kong"))
        #expect(hk.contains("Hong Kong") && !hk.contains("in Taiwan"))
        // A region belonging to another language is ignored.
        #expect(TextProcessor.translationSystemPrompt(target: .french, region: .brazil)
                == TextProcessor.translationSystemPrompt(target: .french))
    }

    @Test func helpMeSaySettingsDefaultAndPersist() {
        let suite = "opentype.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let s = SettingsStore(defaults: defaults)
        #expect(s.helpMeSayEnabled)
        #expect(!s.helpMeSayWebSearchEnabled) // opt-in
        #expect(s.helpMeSayPrompt == TextProcessor.defaultHelpMeSayPrompt)
        s.helpMeSayEnabled = false
        s.helpMeSayWebSearchEnabled = true
        s.helpMeSayPrompt = "自定义"
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.helpMeSayWebSearchEnabled)
        #expect(!reloaded.helpMeSayEnabled)
        #expect(reloaded.helpMeSayPrompt == "自定义")
        #expect(TextProcessor.helpMeSaySystemPrompt(custom: "  \n ") == TextProcessor.defaultHelpMeSayPrompt)
        #expect(TextProcessor.helpMeSaySystemPrompt(custom: " 自定义 ") == "自定义")
    }

    @Test func translationPromptNamesTargetLanguage() {
        for language in TranslationLanguage.allCases {
            #expect(TextProcessor.translationSystemPrompt(target: language).contains(language.promptName))
        }
    }

    @Test func profilesPersistWithoutSecrets() throws {
        let (s, defaults) = makeStore()
        var p = s.activeProfile!
        p.name = "My"
        p.modelID = "m1"
        s.updateProfile(p)
        let added = s.addProfile(from: p)
        #expect(s.activeProfileID == added.id)

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.llmProfiles.count == 2)
        #expect(reloaded.activeProfileID == added.id)
        let raw = try #require(defaults.data(forKey: "opentype.llmProfiles"))
        let text = String(decoding: raw, as: UTF8.self)
        #expect(!text.lowercased().contains("apikey"))
    }

    @Test func lastProfileCannotBeRemoved() {
        let (s, _) = makeStore()
        #expect(s.removeProfile(id: s.activeProfile!.id) == nil)
        let added = s.addProfile()
        #expect(s.removeProfile(id: added.id) == added.id)
        #expect(s.llmProfiles.count == 1)
    }
}

// MARK: - Credentials / diagnostics

struct SecurityTests {
    @Test func inMemoryCredentialRoundTrip() throws {
        let store = InMemoryCredentialStore()
        try store.save("secret", account: "a")
        #expect(try store.load(account: "a") == "secret")
        #expect(store.hasValue(account: "a"))
        try store.delete(account: "a")
        #expect(try store.load(account: "a") == nil)
    }

    @Test func redactionRemovesSecrets() {
        #expect(Diagnostics.redact("Bearer sk-abcdef123 failed", secrets: ["sk-abcdef123"]) == "Bearer *** failed")
    }
}
