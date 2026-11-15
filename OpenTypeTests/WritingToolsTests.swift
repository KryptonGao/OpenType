import Foundation
import Testing
@testable import OpenType

// MARK: - Diff

struct TextDiffTests {
    @Test func identicalTextIsOneEqualSegment() {
        #expect(TextDiff.segments(old: "你好", new: "你好") == [.equal("你好")])
        #expect(TextDiff.segments(old: "", new: "") == [])
    }

    @Test func chineseChangesAreMarkedPerCharacter() {
        let segments = TextDiff.segments(old: "还有几个地方需要在做调整", new: "还有几个地方需要再做调整")
        #expect(segments == [.equal("还有几个地方需要"), .delete("在"), .insert("再"), .equal("做调整")])
        #expect(TextDiff.changeCount(segments) == 1)
        #expect(TextDiff.newText(segments) == "还有几个地方需要再做调整")
    }

    @Test func latinChangesAreMarkedPerWord() {
        let segments = TextDiff.segments(old: "hi there, ready by wednesday", new: "Hi there, ready by Wednesday")
        #expect(TextDiff.newText(segments) == "Hi there, ready by Wednesday")
        #expect(segments.first == .delete("hi"))
        #expect(segments.contains(.insert("Wednesday")))
        #expect(TextDiff.changeCount(segments) == 2)
    }

    @Test func pureInsertionAndDeletion() {
        #expect(TextDiff.segments(old: "我", new: "我。") == [.equal("我"), .insert("。")])
        #expect(TextDiff.segments(old: "我们，", new: "我们") == [.equal("我们"), .delete("，")])
    }

    @Test func newTextAlwaysReproducesTheNewString() {
        let pairs = [("abc def", "abd  def"), ("今天天气很好", "今天的天气真好"), ("a", "b"), ("", "新"), ("旧", "")]
        for (old, new) in pairs {
            #expect(TextDiff.newText(TextDiff.segments(old: old, new: new)) == new)
        }
    }

    @Test func hugeInputFallsBackToOneReplacement() {
        let old = String(repeating: "甲", count: 3000) + "X" + String(repeating: "乙", count: 3000)
        let new = String(repeating: "丙", count: 3000) + "Y" + String(repeating: "丁", count: 3000)
        let segments = TextDiff.segments(old: old, new: new)
        #expect(segments == [.delete(old), .insert(new)])
    }
}

// MARK: - Prompts, tables, results

struct WritingToolsPromptTests {
    @Test func userMessagesCarryTheMarkers() {
        let custom = WritingRequest(tool: .custom, source: "原文", instruction: "翻译成日语")
        #expect(WritingToolsPrompts.userMessage(for: custom) == "【修改要求】\n翻译成日语\n【原文】\n原文")
        let proof = WritingRequest(tool: .proofread, source: "原文")
        #expect(WritingToolsPrompts.userMessage(for: proof) == "【原文】\n原文")
        let compose = WritingRequest(tool: .compose, source: nil, instruction: "写请假邮件")
        #expect(WritingToolsPrompts.userMessage(for: compose) == "【写作需求】\n写请假邮件")
    }

    @Test func translationPromptNamesLanguageAndRegion() {
        var request = WritingRequest(tool: .translate, source: "你好")
        request.translationTarget = .traditionalChinese
        request.translationRegion = .taiwan
        let prompt = WritingToolsPrompts.systemPrompt(for: request)
        #expect(prompt.contains("Traditional Chinese"))
        #expect(prompt.contains("台湾"))
        // A region that does not belong to the language is ignored.
        request.translationTarget = .english
        #expect(!WritingToolsPrompts.systemPrompt(for: request).contains("巴西"))
    }

    @Test func composeOptionsTypedTextWinsOverTheChosenOption() {
        var options = ComposeOptions()
        options.kind = .post
        #expect(options.kindPrompt == ComposeOptions.Kind.post.promptName)
        options.customKind = "  周报 "
        #expect(options.kindPrompt == "周报")
        #expect(options.usesCustomKind)
        options.customKind = "   "
        #expect(options.kindPrompt == ComposeOptions.Kind.post.promptName)
        #expect(!options.usesCustomKind)

        var request = WritingRequest(tool: .compose, source: nil, instruction: "x")
        request.compose.customTone = "幽默"
        request.compose.customLength = "约 200 字"
        let prompt = WritingToolsPrompts.systemPrompt(for: request)
        #expect(prompt.contains("语气：幽默"))
        #expect(prompt.contains("篇幅：约 200 字"))
    }

    @Test func composeAsksForPlainTextOrMarkdown() {
        var request = WritingRequest(tool: .compose, source: nil, instruction: "写周报")
        let plain = WritingToolsPrompts.systemPrompt(for: request)
        #expect(plain.contains("纯文本"))
        #expect(!plain.contains("用 Markdown 语法排版"))
        request.markdown = true
        let markdown = WritingToolsPrompts.systemPrompt(for: request)
        #expect(markdown.contains("用 Markdown 语法排版"))
        #expect(!markdown.contains("纯文本"))
    }

    @Test func everyToolHasASystemPrompt() {
        for tool in WritingTool.allCases {
            let request = WritingRequest(tool: tool, source: "x", instruction: "y")
            #expect(!WritingToolsPrompts.systemPrompt(for: request).isEmpty)
        }
    }

    @Test func markdownTableParsesAndSkipsTheSeparatorRow() {
        let markdown = """
        | 项目 | 状态 |
        |---|:--:|
        | 设计稿 | 基本完成 |
        | 问题 | 随时联系 |
        """
        let rows = WritingTable.parse(markdown)
        #expect(rows == [["项目", "状态"], ["设计稿", "基本完成"], ["问题", "随时联系"]])
        #expect(WritingTable.tabSeparated(rows ?? []) == "项目\t状态\n设计稿\t基本完成\n问题\t随时联系")
    }

    @Test func nonTablesAreRejectedAndRaggedRowsPadded() {
        #expect(WritingTable.parse("只是一段话") == nil)
        #expect(WritingTable.parse("| a |\n|---|\n| b |") == nil) // one column
        #expect(WritingTable.parse("| a | b |\n|---|---|\n| c |") == [["a", "b"], ["c", ""]])
    }

    @Test func proofreadResultCarriesTheDiffAndKeepsOuterWhitespace() {
        let result = WritingToolsPrompts.makeResult(tool: .proofread, source: "我们在做调整\n", output: "我们再做调整")
        #expect(result.text == "我们再做调整\n")
        #expect(result.changeCount == 1)
        #expect(TextDiff.newText(result.diff ?? []) == "我们再做调整\n")
    }

    @Test func tableResultFallsBackToPlainTextWhenItIsNotATable() {
        let table = WritingToolsPrompts.makeResult(tool: .table, source: "x", output: "| a | b |\n|---|---|\n| 1 | 2 |")
        #expect(table.table == [["a", "b"], ["1", "2"]])
        #expect(table.text == "a\tb\n1\t2")
        let plain = WritingToolsPrompts.makeResult(tool: .table, source: "x", output: "没有表格")
        #expect(plain.table == nil)
        #expect(plain.text == "没有表格")
    }

    @Test func composeResultIsTheAnswerItself() {
        let result = WritingToolsPrompts.makeResult(tool: .compose, source: nil, output: "  主题：请假\n正文  ")
        #expect(result.text == "主题：请假\n正文")
        #expect(result.diff == nil)
    }
}

// MARK: - Multi-turn requests

struct LLMMessagesRequestTests {
    private func profile(_ format: LLMAPIFormat) -> LLMProfile {
        var p = LLMProfile.makeDefault()
        p.format = format
        p.baseURL = format.defaultBaseURL
        p.modelID = "m"
        return p
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private let turns: [LLMMessage] = [.user("原文"), .assistant("结果"), .user("再短一点")]

    @Test func chatCompletionsPutsTheSystemPromptFirstAndKeepsTurnsUnwrapped() throws {
        let request = try LLMRequestBuilder.makeRequest(profile: profile(.openAIChatCompletions), apiKey: "k", messages: turns, systemPrompt: "S")
        let messages = try #require(try body(request)["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user", "assistant", "user"])
        #expect(messages.map { $0["content"] } == ["S", "原文", "结果", "再短一点"])
    }

    @Test func anthropicUsesASeparateSystemFieldAndAlternatingTurns() throws {
        let request = try LLMRequestBuilder.makeRequest(profile: profile(.anthropicMessages), apiKey: "k", messages: turns, systemPrompt: "S")
        let json = try body(request)
        #expect(json["system"] as? String == "S")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["user", "assistant", "user"])
    }

    @Test func responsesSendsAPlainStringForOneTurnAndAnArrayForMore() throws {
        let single = try LLMRequestBuilder.makeRequest(profile: profile(.openAIResponses), apiKey: "k", messages: [.user("原文")], systemPrompt: "S")
        #expect(try body(single)["input"] as? String == "原文")
        let multi = try LLMRequestBuilder.makeRequest(profile: profile(.openAIResponses), apiKey: "k", messages: turns, systemPrompt: "S")
        let input = try #require(try body(multi)["input"] as? [[String: String]])
        #expect(input.count == 3)
        #expect(try body(multi)["instructions"] as? String == "S")
    }

    @Test func dictationRequestsStillWrapTheTranscript() throws {
        let request = try LLMRequestBuilder.makeRequest(profile: profile(.openAIChatCompletions), apiKey: "k", transcript: "嗯你好", systemPrompt: "S")
        let messages = try #require(try body(request)["messages"] as? [[String: String]])
        #expect(messages.last?["content"] == TextProcessor.userPrompt(transcript: "嗯你好"))
    }

    @Test func emptyConversationIsRejected() {
        #expect(throws: LLMError.self) {
            try LLMRequestBuilder.makeRequest(profile: profile(.openAIChatCompletions), apiKey: "k", messages: [], systemPrompt: "S")
        }
    }

    @Test func providerSendsTheTurnsAndReturnsTextAndUsage() async throws {
        let capture = MockTransportBox()
        let provider = HTTPLLMProvider(profile: profile(.openAIChatCompletions), apiKey: "k", transport: capture)
        let output = try await provider.complete(messages: turns, systemPrompt: "S")
        #expect(output.text == "好的结果")
        #expect(output.usage == TokenUsage(inputTokens: 10, outputTokens: 3))
        let sent = try #require(capture.request)
        #expect((try body(sent)["messages"] as? [[String: String]])?.count == 4)
    }
}

/// Answers with a server-sent-events body (the default `sendStreaming` replays it line by line).
private struct SSETransport: HTTPTransport {
    let body: String
    var status = 200

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private final class MockTransportBox: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?
    var request: URLRequest? { lock.withLock { stored } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { stored = request }
        let body = #"{"choices":[{"message":{"content":"好的结果"}}],"usage":{"prompt_tokens":10,"completion_tokens":3}}"#
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

// MARK: - Streaming answers

struct LLMStreamTests {
    private func json(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func run(_ format: LLMAPIFormat, _ lines: [String]) -> (pieces: [String], accumulator: LLMStreamAccumulator) {
        var accumulator = LLMStreamAccumulator(format: format)
        var pieces: [String] = []
        for line in lines { if let piece = accumulator.consume(line: line) { pieces.append(piece) } }
        return (pieces, accumulator)
    }

    @Test func chatCompletionsDeltasAndUsage() {
        let (pieces, acc) = run(.openAIChatCompletions, [
            #"data: {"choices":[{"delta":{"role":"assistant","content":""}}]}"#,
            #"data: {"choices":[{"delta":{"content":"你"}}]}"#,
            "",
            #"data: {"choices":[{"delta":{"content":"好"}}]}"#,
            #"data: {"choices":[],"usage":{"prompt_tokens":7,"completion_tokens":2}}"#,
            "data: [DONE]"
        ])
        #expect(pieces == ["你", "好"])
        #expect(acc.text == "你好")
        #expect(acc.usage == TokenUsage(inputTokens: 7, outputTokens: 2))
    }

    @Test func anthropicEventsAndUsage() {
        let (pieces, acc) = run(.anthropicMessages, [
            "event: message_start",
            #"data: {"type":"message_start","message":{"usage":{"input_tokens":11,"cache_read_input_tokens":4,"output_tokens":1}}}"#,
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}"#,
            #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}"#
        ])
        #expect(pieces == ["Hel", "lo"])
        #expect(acc.usage == TokenUsage(inputTokens: 15, outputTokens: 5))
    }

    @Test func responsesEventsAndUsage() {
        let (pieces, acc) = run(.openAIResponses, [
            #"data: {"type":"response.created","response":{}}"#,
            #"data: {"type":"response.output_text.delta","delta":"A"}"#,
            #"data: {"type":"response.output_text.delta","delta":"B"}"#,
            #"data: {"type":"response.completed","response":{"usage":{"input_tokens":3,"output_tokens":2}}}"#
        ])
        #expect(pieces == ["A", "B"])
        #expect(acc.usage == TokenUsage(inputTokens: 3, outputTokens: 2))
    }

    @Test func errorsInTheStreamAreReported() {
        #expect(run(.openAIChatCompletions, [#"data: {"error":{"message":"overloaded"}}"#]).accumulator.errorMessage == "overloaded")
        #expect(run(.anthropicMessages, [#"data: {"type":"error","error":{"message":"busy"}}"#]).accumulator.errorMessage == "busy")
        #expect(run(.openAIResponses, [#"data: {"type":"response.failed","response":{"error":{"message":"nope"}}}"#]).accumulator.errorMessage == "nope")
    }

    @Test func aNonStreamedJsonAnswerStillWorks() {
        let chat = run(.openAIChatCompletions, [#"{"choices":[{"message":{"content":"整段"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#])
        #expect(chat.accumulator.text == "整段")
        let anthropic = run(.anthropicMessages, [#"{"content":[{"type":"text","text":"整段"}],"usage":{"input_tokens":1,"output_tokens":1}}"#])
        #expect(anthropic.accumulator.text == "整段")
    }

    @Test func streamRequestsAskForStreaming() throws {
        for format in LLMAPIFormat.allCases {
            var profile = LLMProfile.makeDefault()
            profile.format = format
            profile.baseURL = format.defaultBaseURL
            profile.modelID = "m"
            let request = try LLMRequestBuilder.makeRequest(profile: profile, apiKey: "k", messages: [.user("x")], systemPrompt: "S", stream: true)
            let body = try json(request)
            #expect(body["stream"] as? Bool == true)
            #expect((body["stream_options"] != nil) == (format == .openAIChatCompletions))
            let plain = try LLMRequestBuilder.makeRequest(profile: profile, apiKey: "k", messages: [.user("x")], systemPrompt: "S")
            #expect(try json(plain)["stream"] == nil)
        }
    }

    @Test func providerStreamsPiecesAndReturnsTheFullText() async throws {
        var profile = LLMProfile.makeDefault()
        profile.modelID = "m"
        let sse = """
        data: {"choices":[{"delta":{"content":"你"}}]}

        data: {"choices":[{"delta":{"content":"好"}}]}

        data: {"choices":[],"usage":{"prompt_tokens":7,"completion_tokens":2}}

        data: [DONE]
        """
        let provider = HTTPLLMProvider(profile: profile, apiKey: "k", transport: SSETransport(body: sse))
        let received = PieceBox()
        let output = try await provider.completeStreaming(messages: [.user("x")], systemPrompt: "S") { received.add($0) }
        #expect(received.pieces == ["你", "好"])
        #expect(output.text == "你好")
        #expect(output.usage == TokenUsage(inputTokens: 7, outputTokens: 2))
    }

    @Test func providerMapsHttpAndStreamErrors() async {
        var profile = LLMProfile.makeDefault()
        profile.modelID = "m"
        let denied = HTTPLLMProvider(profile: profile, apiKey: "k", transport: SSETransport(body: "{}", status: 401))
        await #expect(throws: LLMError.auth(401)) {
            _ = try await denied.completeStreaming(messages: [.user("x")], systemPrompt: "S") { _ in }
        }
        let empty = HTTPLLMProvider(profile: profile, apiKey: "k", transport: SSETransport(body: "data: [DONE]"))
        await #expect(throws: LLMError.emptyOutput) {
            _ = try await empty.completeStreaming(messages: [.user("x")], systemPrompt: "S") { _ in }
        }
    }
}

private final class PieceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    var pieces: [String] { lock.withLock { stored } }
    func add(_ piece: String) { lock.withLock { stored.append(piece) } }
}

// MARK: - Settings

@MainActor
struct WritingToolsSettingsTests {
    private func store() -> SettingsStore { SettingsStore(defaults: UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")!) }

    @Test func defaults() {
        let settings = store()
        #expect(settings.writingToolsEnabled)
        #expect(settings.writingToolsHotkey == .defaultWritingTools)
        #expect(settings.writingToolsHotkey.displayName == "⌃⌥ W")
        #expect(settings.writingToolsProfileID == nil)
        #expect(settings.writingToolsModelID.isEmpty)
        #expect(settings.writingToolsReasoningEffort.isEmpty)
    }

    @Test func followsTheActiveProfileUnlessOneIsChosen() throws {
        let settings = store()
        let first = try #require(settings.activeProfile)
        #expect(settings.writingToolsProfile?.id == first.id)
        var other = LLMProfile.makeDefault()
        other.id = UUID(); other.name = "Other"; other.modelID = "other-model"
        settings.llmProfiles.append(other)
        settings.writingToolsProfileID = other.id
        #expect(settings.writingToolsProfile?.id == other.id)
        #expect(settings.activeProfile?.id == first.id) // dictation is unaffected
        settings.removeProfile(id: other.id)
        #expect(settings.writingToolsProfileID == nil)
        #expect(settings.writingToolsProfile?.id == first.id)
    }

    @Test func modelAndEffortOverridesApplyOnlyWhenNotBlank() throws {
        let settings = store()
        var base = try #require(settings.activeProfile)
        base.modelID = "big-model"
        base.reasoningEffort = "high"
        settings.updateProfile(base)
        #expect(settings.writingToolsProfile?.modelID == "big-model")
        #expect(settings.writingToolsProfile?.reasoningEffort == "high")
        settings.writingToolsModelID = " small-model "
        settings.writingToolsReasoningEffort = "low"
        #expect(settings.writingToolsProfile?.modelID == "small-model")
        #expect(settings.writingToolsProfile?.reasoningEffort == "low")
        #expect(settings.writingToolsProfile?.id == base.id) // the API key is still found under the profile's id
        #expect(settings.activeProfile?.modelID == "big-model") // the dictation profile is untouched
    }

    @Test func panelMaterialDefaultsToFrostedBlur() {
        #expect(store().writingToolsMaterial == .blur)
    }

    @Test func settingsPersist() {
        let suite = "opentype.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = SettingsStore(defaults: defaults)
        settings.writingToolsEnabled = false
        settings.writingToolsHotkey = HotkeyConfig(keyCode: 14, modifiers: [.maskCommand])
        settings.writingToolsModelID = "m"
        let reloaded = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        #expect(!reloaded.writingToolsEnabled)
        #expect(reloaded.writingToolsHotkey.keyCode == 14)
        #expect(reloaded.writingToolsModelID == "m")
    }
}

// MARK: - Controller

@MainActor
private final class WTInserter: TextInserting {
    var captured: InsertionTarget? = InsertionTarget(pid: 1, appName: "Test", element: nil, isSecure: false, selectedText: "我们在做调整")
    var outcome: InsertionOutcome = .insertedViaAccessibility
    private(set) var inserted: [String] = []
    private(set) var undone = 0
    func captureTarget() -> InsertionTarget? { captured }
    func insert(_ text: String, into target: InsertionTarget?) async -> InsertionOutcome {
        inserted.append(text)
        return outcome
    }
    func sendUndo(to target: InsertionTarget) -> Bool { undone += 1; return true }
}

@MainActor
private final class WTPresenter: WritingToolsPresenting {
    private(set) var shown = 0
    private(set) var hidden = 0
    private(set) var toasts: [String] = []
    private var undo: (() -> Void)?
    func show(controller: WritingToolsController) { shown += 1 }
    func hide() { hidden += 1 }
    func showToast(message: String, onUndo: @escaping () -> Void) { toasts.append(message); undo = onUndo }
    func tapUndo() { undo?() }
}

@MainActor
private final class WTNotifier: UserNotifying {
    private(set) var count = 0
    func notify(title: String, body: String) { count += 1 }
}

private final class WTCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [(messages: [LLMMessage], system: String, model: String)] = []
    var calls: [(messages: [LLMMessage], system: String, model: String)] { lock.withLock { stored } }
    func record(_ messages: [LLMMessage], _ system: String, _ model: String) { lock.withLock { stored.append((messages, system, model)) } }
}

private struct WTLLM: LLMProvider {
    var answers: [Result<String, LLMError>]
    var model: String
    var calls: WTCalls

    func process(transcript: String, systemPrompt: String) async throws -> String { "" }

    func complete(messages: [LLMMessage], systemPrompt: String) async throws -> LLMOutput {
        calls.record(messages, systemPrompt, model)
        let index = min(calls.calls.count - 1, answers.count - 1)
        return LLMOutput(text: try answers[index].get(), usage: TokenUsage(inputTokens: 5, outputTokens: 2))
    }
}

/// Delivers its answer in pieces and then waits for the test to let it finish.
private struct WTStreamingLLM: LLMProvider {
    var chunks: [String]
    var gate: AsyncStream<Void>
    var fails = false

    func process(transcript: String, systemPrompt: String) async throws -> String { "" }

    func completeStreaming(messages: [LLMMessage], systemPrompt: String, onDelta: @escaping @Sendable (String) -> Void) async throws -> LLMOutput {
        for chunk in chunks { onDelta(chunk) }
        for await _ in gate { break }
        if fails { throw LLMError.timeout }
        return LLMOutput(text: chunks.joined(), usage: TokenUsage(inputTokens: 4, outputTokens: 4))
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
}

/// The first answer arrives at once; the second one stops half way until the gate is released.
private struct WTTwoPhaseLLM: LLMProvider {
    var counter: CallCounter
    var gate: AsyncStream<Void>

    func process(transcript: String, systemPrompt: String) async throws -> String { "" }

    func completeStreaming(messages: [LLMMessage], systemPrompt: String, onDelta: @escaping @Sendable (String) -> Void) async throws -> LLMOutput {
        if counter.next() == 1 {
            onDelta("第一版")
            return LLMOutput(text: "第一版")
        }
        onDelta("半截")
        for await _ in gate { break }
        return LLMOutput(text: "第二版")
    }
}

@MainActor
private struct WTHarness {
    let controller: WritingToolsController
    let inserter = WTInserter()
    let presenter = WTPresenter()
    let notifier = WTNotifier()
    let history = HistoryStore()
    let settings: SettingsStore
    let calls = WTCalls()
    var copied: CopiedBox

    final class CopiedBox { var texts: [String] = [] }

    init(answers: [Result<String, LLMError>] = [.success("我们再做调整")], withKey: Bool = true, dictationBusy: Bool = false,
         provider: (@Sendable (LLMProfile) -> any LLMProvider)? = nil) {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")!)
        self.settings = settings
        let credentials = InMemoryCredentialStore()
        if withKey, let profile = settings.activeProfile { try? credentials.save("key", account: CredentialAccount.llmProfile(profile.id)) }
        let calls = self.calls
        let box = CopiedBox()
        self.copied = box
        self.controller = WritingToolsController(
            settingsStore: settings, credentialStore: credentials, inserter: inserter, historyStore: history, notifier: notifier,
            makeLLM: { profile, _ in provider?(profile) ?? WTLLM(answers: answers, model: profile.modelID, calls: calls) },
            copyToPasteboard: { box.texts.append($0) },
            isDictationBusy: { dictationBusy },
            applyDelay: .zero
        )
        controller.presenter = presenter
    }

    func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<300 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
struct WritingToolsControllerTests {
    @Test func opensTheMenuWhenTextIsSelected() async {
        let h = WTHarness()
        await h.controller.open()
        #expect(h.controller.isVisible)
        #expect(h.controller.hasSelection)
        #expect(h.controller.screen == .menu)
        #expect(h.presenter.shown == 1)
        #expect(!h.controller.showsBackButton)
    }

    @Test func opensComposeDirectlyWithoutASelection() async {
        let h = WTHarness()
        h.inserter.captured?.selectedText = nil
        await h.controller.open()
        #expect(!h.controller.hasSelection)
        #expect(h.controller.screen == .compose)
        #expect(!h.controller.showsBackButton)
        h.controller.openCompose() // not available without a selection
        #expect(h.controller.screen == .compose)
    }

    @Test func doesNotOpenForSecureFieldsDisabledFeatureOrBusyDictation() async {
        let secure = WTHarness()
        secure.inserter.captured?.selectedText = nil
        secure.inserter.captured = InsertionTarget(pid: 1, appName: "T", element: nil, isSecure: true)
        await secure.controller.open()
        #expect(!secure.controller.isVisible)

        let off = WTHarness()
        off.settings.writingToolsEnabled = false
        await off.controller.open()
        #expect(!off.controller.isVisible)

        let busy = WTHarness(dictationBusy: true)
        await busy.controller.open()
        #expect(!busy.controller.isVisible)

        let none = WTHarness()
        none.inserter.captured = nil
        await none.controller.open()
        #expect(!none.controller.isVisible)
    }

    @Test func toggleClosesAnOpenPanel() async {
        let h = WTHarness()
        await h.controller.toggle()
        #expect(h.controller.isVisible)
        await h.controller.toggle()
        #expect(!h.controller.isVisible)
        #expect(h.presenter.hidden == 1)
    }

    @Test func proofreadShowsTheDiffAndReplaceWritesBackAndRecordsHistory() async {
        let h = WTHarness()
        await h.controller.open()
        h.controller.run(.proofread)
        #expect(h.controller.screen == .loading)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.controller.result?.changeCount == 1)
        #expect(h.controller.replacesSelection)
        #expect(h.controller.resultTitle == WritingTool.proofread.resultTitle)
        #expect(h.calls.calls.first?.messages == [.user("【原文】\n我们在做调整")])

        await h.controller.apply()
        #expect(h.inserter.inserted == ["我们再做调整"])
        #expect(!h.controller.isVisible)
        #expect(h.presenter.toasts.count == 1)
        let record = h.history.records.first
        #expect(record?.kind == .writingTools)
        #expect(record?.rawText == "我们在做调整")
        #expect(record?.finalText == "我们再做调整")
        #expect(record?.delivery == .inserted)
        #expect(record?.usage == TokenUsage(inputTokens: 5, outputTokens: 2))
        #expect(record?.model == h.settings.activeProfile?.modelID)
    }

    @Test func undoToastSendsUndoToTheTargetApp() async {
        let h = WTHarness()
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        await h.controller.apply()
        h.presenter.tapUndo()
        #expect(h.inserter.undone == 1)
    }

    @Test func refineSendsTheConversationAndRegenerateRepeatsTheLastTurn() async {
        let h = WTHarness(answers: [.success("第一版"), .success("第二版"), .success("第三版")])
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.controller.result?.text == "第一版")

        h.controller.refineText = "再短一点"
        h.controller.submitRefine()
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming && h.controller.result?.text == "第二版" }
        let second = h.calls.calls[1].messages
        #expect(second.count == 3)
        #expect(second[1] == .assistant("第一版"))
        #expect(second[2].content.contains("再短一点"))
        #expect(h.controller.refineText.isEmpty)

        h.controller.regenerate() // same three turns again
        await h.wait { !h.controller.isStreaming && h.controller.result?.text == "第三版" }
        #expect(h.calls.calls[2].messages == second)
    }

    @Test func composeInsertsAtTheCaretWithoutASelection() async {
        let h = WTHarness(answers: [.success("主题：请假\n\n经理您好")])
        h.inserter.captured?.selectedText = nil
        await h.controller.open()
        h.controller.composePrompt = "写一封请假邮件"
        h.controller.compose.customTone = "诚恳"
        h.controller.submitCompose()
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(!h.controller.replacesSelection)
        #expect(h.calls.calls.first?.system.contains("语气：诚恳") == true)
        #expect(h.calls.calls.first?.messages == [.user("【写作需求】\n写一封请假邮件")])
        await h.controller.apply()
        #expect(h.inserter.inserted == ["主题：请假\n\n经理您好"])
        #expect(h.history.records.first?.rawText == "写一封请假邮件")
        #expect(h.presenter.toasts == [String(localized: "已插入")])
    }

    @Test func generateMarkdownSendsTheMarkdownPromptAndKeepsItWhenRefining() async {
        let h = WTHarness(answers: [.success("# 周报\n- 完成 A"), .success("# 周报\n- 完成 A、B")])
        h.inserter.captured?.selectedText = nil
        await h.controller.open()
        h.controller.composePrompt = "写周报"
        h.controller.submitCompose(markdown: true)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.calls.calls[0].system.contains("用 Markdown 语法排版"))
        #expect(h.controller.result?.text == "# 周报\n- 完成 A")
        h.controller.refineText = "再加一项"
        h.controller.submitRefine()
        await h.wait { !h.controller.isStreaming && h.controller.result?.text.contains("A、B") == true }
        #expect(h.calls.calls[1].system.contains("用 Markdown 语法排版")) // the format sticks
        await h.controller.apply()
        #expect(h.inserter.inserted == ["# 周报\n- 完成 A、B"])
    }

    @Test func plainGenerateStaysPlainText() async {
        let h = WTHarness()
        h.inserter.captured?.selectedText = nil
        await h.controller.open()
        h.controller.composePrompt = "写周报"
        h.controller.submitCompose()
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(!h.calls.calls[0].system.contains("用 Markdown 语法排版"))
    }

    @Test func translateUsesTheChosenLanguage() async {
        let h = WTHarness(answers: [.success("We are adjusting")])
        await h.controller.open()
        h.controller.translationTarget = .japanese
        h.controller.run(.translate)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.calls.calls.first?.system.contains("Japanese") == true)
        await h.controller.apply()
        #expect(h.history.records.first?.translationLabel == TranslationLanguage.japanese.displayName)
    }

    @Test func missingKeyShowsTheNoServicePage() async {
        let h = WTHarness(withKey: false)
        await h.controller.open()
        h.controller.run(.concise)
        await h.wait { h.controller.screen == .error }
        #expect(h.controller.failure == .noService)
        #expect(h.calls.calls.isEmpty)
    }

    @Test func modelFailureShowsTheReasonAndRetryWorks() async {
        let h = WTHarness(answers: [.failure(.rateLimited), .success("好了")])
        await h.controller.open()
        h.controller.run(.friendly)
        await h.wait { h.controller.screen == .error }
        #expect(h.controller.failure == .failed(LLMError.rateLimited.userMessage))
        h.controller.regenerate()
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.controller.result?.text == "好了")
        #expect(h.history.records.isEmpty) // nothing is recorded until the result is applied
    }

    @Test func writingToolsUsesItsOwnModelAndEffort() async {
        let h = WTHarness()
        h.settings.writingToolsModelID = "tiny-model"
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.calls.calls.first?.model == "tiny-model")
        #expect(h.settings.activeProfile?.modelID != "tiny-model")
    }

    @Test func backNavigation() async {
        let h = WTHarness(answers: [.success("好了")])
        await h.controller.open()
        h.controller.openCompose()
        #expect(h.controller.screen == .compose)
        #expect(h.controller.showsBackButton)
        h.controller.back()
        #expect(h.controller.screen == .menu)

        h.controller.run(.rewrite)
        h.controller.back() // cancel while loading
        #expect(h.controller.screen == .menu)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(h.controller.screen == .menu) // the dropped answer must not bring the result page back

        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        h.controller.back()
        #expect(h.controller.screen == .menu)
    }

    @Test func failedInsertionCopiesToTheClipboardAndNotifies() async {
        let h = WTHarness()
        h.inserter.outcome = .focusLost(reason: "焦点已离开")
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        await h.controller.apply()
        #expect(h.copied.texts == ["我们再做调整"])
        #expect(h.notifier.count == 1)
        #expect(h.presenter.toasts.isEmpty)
        #expect(h.history.records.first?.delivery == .manualCopy)
    }

    @Test func historyTextIsDroppedWhenSavingTextIsOff() async {
        let h = WTHarness()
        h.settings.saveHistoryText = false
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        await h.controller.apply()
        #expect(h.history.records.first?.rawText == nil)
        #expect(h.history.records.first?.finalText == nil)
        #expect(h.history.records.first?.kind == .writingTools)
    }

    @Test func copyPutsTheResultOnTheClipboard() async {
        let h = WTHarness()
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.screen == .result && !h.controller.isStreaming }
        h.controller.copyResult()
        #expect(h.copied.texts == ["我们再做调整"])
        #expect(h.controller.copied)
    }

    @Test func closeDropsAPendingAnswer() async {
        let h = WTHarness()
        await h.controller.open()
        h.controller.run(.rewrite)
        h.controller.close()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(h.controller.screen == .menu)
        #expect(h.controller.result == nil)
        #expect(!h.controller.isVisible)
        #expect(h.history.records.isEmpty)
    }

    @Test func theAnswerStreamsInAndOnlyTheFinishedResultCanBeApplied() async {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let h = WTHarness(provider: { _ in WTStreamingLLM(chunks: ["我们", "再做", "调整"], gate: gate) })
        await h.controller.open()
        h.controller.run(.proofread)
        await h.wait { h.controller.isStreaming && h.controller.result?.text == "我们再做调整" }
        #expect(h.controller.screen == .result)
        #expect(h.controller.isStreaming)
        #expect(h.controller.result?.diff == nil) // plain text while it arrives
        #expect(!h.controller.canApply)
        h.controller.copyResult()
        #expect(h.copied.texts.isEmpty)

        release.yield()
        await h.wait { !h.controller.isStreaming && h.controller.screen == .result && !h.controller.isStreaming }
        #expect(h.controller.result?.changeCount == 1) // the diff appears once it is complete
        #expect(h.controller.canApply)
        await h.controller.apply()
        #expect(h.inserter.inserted == ["我们再做调整"])
        #expect(h.history.records.first?.usage == TokenUsage(inputTokens: 4, outputTokens: 4))
    }

    @Test func stopDropsThePartialAnswerAndGoesBack() async {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let h = WTHarness(provider: { _ in WTStreamingLLM(chunks: ["半截"], gate: gate) })
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.isStreaming }
        h.controller.stopStreaming()
        release.yield()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(!h.controller.isStreaming)
        #expect(h.controller.screen == .menu)
        #expect(h.controller.result == nil)
        #expect(h.inserter.inserted.isEmpty)
    }

    @Test func stoppingARefinementRestoresThePreviousResult() async {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let counter = CallCounter()
        let h = WTHarness(provider: { _ in WTTwoPhaseLLM(counter: counter, gate: gate) })
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.result?.text == "第一版" && !h.controller.isStreaming }
        h.controller.refineText = "再短一点"
        h.controller.submitRefine()
        await h.wait { h.controller.isStreaming }
        #expect(h.controller.result?.text == "半截") // the second answer is growing over the first
        h.controller.back() // the back button stops it
        release.yield()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(!h.controller.isStreaming)
        #expect(h.controller.screen == .result)
        #expect(h.controller.result?.text == "第一版")
        #expect(h.controller.canApply)
    }

    @Test func aStreamThatBreaksOffShowsTheErrorAndKeepsNothingPartial() async {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let h = WTHarness(provider: { _ in WTStreamingLLM(chunks: ["半截"], gate: gate, fails: true) })
        await h.controller.open()
        h.controller.run(.rewrite)
        await h.wait { h.controller.isStreaming }
        release.yield()
        await h.wait { h.controller.screen == .error }
        #expect(!h.controller.isStreaming)
        #expect(h.controller.result == nil)
        #expect(h.controller.failure == .failed(LLMError.timeout.userMessage))
    }

    @Test func hotkeyIsDistinctFromTheOtherShortcutsByDefault() {
        #expect(HotkeyConfig.defaultWritingTools != HotkeyConfig.default)
        #expect(HotkeyConfig.defaultWritingTools != HotkeyConfig.defaultTranslation)
    }
}
