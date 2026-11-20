import AppKit
import Testing
@testable import OpenType

@MainActor
struct ScreenAskSettingsTests {
    @Test func defaultsFollowVoiceAIAndOverridesKeepCredentialIdentity() throws {
        let name = "opentype.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.screenAskEnabled)
        #expect(settings.screenAskHotkey == HotkeyConfig(keyCode: 22, modifiers: [.maskCommand, .maskShift]))
        var base = try #require(settings.activeProfile)
        base.modelID = "vision-base"
        base.reasoningEffort = "medium"
        settings.updateProfile(base)
        #expect(settings.screenAskProfile == base)
        settings.screenAskModelID = " vision-custom \n"
        settings.screenAskReasoningEffort = " high "
        #expect(settings.screenAskProfile?.id == base.id)
        #expect(settings.screenAskProfile?.modelID == "vision-custom")
        #expect(settings.screenAskProfile?.reasoningEffort == "high")
        #expect(settings.activeProfile == base)
        let restored = SettingsStore(defaults: defaults)
        #expect(restored.screenAskProfile == settings.screenAskProfile)
        settings.screenAskModelID = "  "
        settings.screenAskReasoningEffort = "\n"
        #expect(settings.screenAskProfile == base)
    }

    @Test func defaultShortcutFiresOnceAndSwallowsTheChord() {
        let manager = HotkeyManager()
        manager.hotkey = .defaultScreenAsk
        var presses = 0
        manager.onPress = { presses += 1 }
        #expect(manager.handle(type: .keyDown, keyCode: 22, flags: [.maskCommand, .maskShift], isAutoRepeat: false))
        #expect(manager.handle(type: .keyDown, keyCode: 22, flags: [.maskCommand, .maskShift], isAutoRepeat: true))
        #expect(presses == 1)
        #expect(manager.handle(type: .keyUp, keyCode: 22, flags: [.maskCommand, .maskShift], isAutoRepeat: false))
        #expect(!manager.handle(type: .keyDown, keyCode: 22, flags: [.maskCommand], isAutoRepeat: false))
    }

    @Test func deletedProfileFallsBackAndInvalidHotkeyUsesDefault() throws {
        let name = "opentype.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.setCodable(HotkeyConfig(keyCode: 53, modifiers: []), forKey: "opentype.screenAskHotkey")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.screenAskHotkey == .defaultScreenAsk)
        let original = try #require(settings.activeProfile)
        let added = settings.addProfile()
        settings.screenAskProfileID = added.id
        settings.removeProfile(id: added.id)
        #expect(settings.screenAskProfileID == nil)
        #expect(settings.screenAskProfile?.id == original.id)
    }
}

struct ScreenAskImageRequestTests {
    @Test(arguments: LLMAPIFormat.allCases)
    func imagesUseTheSelectedProtocolAndKeepFollowups(_ format: LLMAPIFormat) throws {
        var profile = LLMProfile.makeDefault()
        profile.format = format
        profile.baseURL = format.defaultBaseURL
        profile.reasoningEffort = "high"
        let image = Data([1, 2, 3])
        var turn = LLMMessage.user("What is this?")
        turn.imageJPEG = image
        for turns in [[turn], [turn, .assistant("A flower"), .user("Which color?")]] {
            let request = try LLMRequestBuilder.makeRequest(profile: profile, apiKey: "test", messages: turns, systemPrompt: "S", stream: true)
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let key = format == .openAIResponses ? "input" : "messages"
            let messages = try #require(body[key] as? [[String: Any]])
            let first = messages[format == .openAIChatCompletions ? 1 : 0]
            let content = try #require(first["content"] as? [[String: Any]])
            #expect(content.count == 2)
            #expect(content[1]["text"] as? String == "What is this?")
            switch format {
            case .openAIResponses:
                #expect(content[0]["type"] as? String == "input_image")
                #expect(content[0]["image_url"] as? String == "data:image/jpeg;base64,AQID")
                #expect((body["reasoning"] as? [String: String])?["effort"] == "high")
                #expect(body["store"] as? Bool == false)
            case .openAIChatCompletions:
                #expect(content[0]["type"] as? String == "image_url")
                #expect((content[0]["image_url"] as? [String: String])?["url"] == "data:image/jpeg;base64,AQID")
                #expect(body["reasoning_effort"] as? String == "high")
            case .anthropicMessages:
                #expect(content[0]["type"] as? String == "image")
                #expect((content[0]["source"] as? [String: String]) == ["type": "base64", "media_type": "image/jpeg", "data": "AQID"])
                #expect((body["output_config"] as? [String: String])?["effort"] == "high")
            }
            if turns.count > 1 { #expect(messages.last?["content"] as? String == "Which color?") }
        }
    }

    @Test func retinaCropFlipsYClampsAndSupportsReverseDrags() {
        let rect = ScreenRegion.pixelRect(selection: CGRect(x: 100, y: 50, width: 200, height: 100),
                                          viewSize: CGSize(width: 800, height: 600), imageSize: CGSize(width: 1600, height: 1200))
        #expect(rect == CGRect(x: 200, y: 900, width: 400, height: 200))
        #expect(ScreenRegion.pixelRect(selection: CGRect(x: -10, y: 550, width: 50, height: 100),
                                       viewSize: CGSize(width: 800, height: 600), imageSize: CGSize(width: 1600, height: 1200)) == CGRect(x: 0, y: 0, width: 80, height: 100))
        #expect(ScreenRegion.pixelRect(selection: CGRect(x: 300, y: 150, width: -200, height: -100),
                                       viewSize: CGSize(width: 800, height: 600), imageSize: CGSize(width: 1600, height: 1200)) == rect)
    }
}

private actor ScreenAskCalls {
    var messages: [[LLMMessage]] = []
    func record(_ messages: [LLMMessage]) { self.messages.append(messages) }
}

private struct ScreenAskLLM: LLMProvider {
    let calls: ScreenAskCalls
    var failure = false
    var delay = false
    func process(transcript: String, systemPrompt: String) async throws -> String { "Answer" }
    func complete(messages: [LLMMessage], systemPrompt: String) async throws -> LLMOutput {
        await calls.record(messages)
        if delay { try? await Task.sleep(for: .milliseconds(80)) } // deliberately return even after cancellation
        if failure { throw LLMError.rateLimited }
        return LLMOutput(text: "Answer")
    }
}

@MainActor
private final class ScreenAskHarness {
    let calls = ScreenAskCalls()
    let settings: SettingsStore
    let controller: ScreenAskController
    init(withKey: Bool = true, failure: Bool = false, delay: Bool = false) throws {
        settings = SettingsStore(defaults: UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")!)
        let credentials = InMemoryCredentialStore()
        if withKey, let profile = settings.activeProfile { try credentials.save("test", account: CredentialAccount.llmProfile(profile.id)) }
        let calls = calls
        controller = ScreenAskController(settings: settings, credentials: credentials,
                                         makeLLM: { _, _ in ScreenAskLLM(calls: calls, failure: failure, delay: delay) }, notify: { _ in })
        let context = try #require(CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try #require(context.makeImage())
        controller.selected(ScreenRegion(image: image, frame: CGRect(x: 100, y: 100, width: 100, height: 100)))
    }
    func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }
}

@MainActor
struct ScreenAskControllerTests {
    @Test func followupRetainsImageAndTheAnsweredTurns() async throws {
        let h = try ScreenAskHarness()
        defer { h.controller.close() }
        h.controller.question = "First"
        h.controller.submit()
        await h.waitUntil { !h.controller.isLoading }
        #expect(h.controller.answer == "Answer")
        h.controller.question = "Follow up"
        h.controller.submit()
        await h.waitUntil { !h.controller.isLoading }
        let calls = await h.calls.messages
        #expect(calls.count == 2)
        #expect(calls.last?.map(\.content) == ["First", "Answer", "Follow up"])
        #expect(calls.last?.first?.imageJPEG != nil)
        #expect(calls.last?.last?.imageJPEG == nil)
    }

    @Test func missingKeyAndRequestFailureKeepTheQuestionForRetry() async throws {
        let missing = try ScreenAskHarness(withKey: false)
        missing.controller.question = "Question"
        missing.controller.submit()
        #expect(missing.controller.error == LLMError.missingAPIKey.userMessage)
        #expect(missing.controller.question == "Question")
        missing.controller.close()
        let failed = try ScreenAskHarness(failure: true)
        failed.controller.question = "Retry me"
        failed.controller.submit()
        await failed.waitUntil { !failed.controller.isLoading }
        #expect(failed.controller.question == "Retry me")
        #expect(failed.controller.error == LLMError.rateLimited.userMessage)
        failed.controller.close()
    }

    @Test func closingDropsLateAnswersAndStoppingPreservesTheQuestion() async throws {
        let h = try ScreenAskHarness(delay: true)
        h.controller.question = "Question"
        h.controller.submit()
        for _ in 0..<200 {
            if await h.calls.messages.count == 1 { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(await h.calls.messages.count == 1)
        h.controller.stop()
        #expect(h.controller.question == "Question")
        h.controller.submit()
        h.controller.close()
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!h.controller.isVisible)
        #expect(!h.controller.isLoading)
        #expect(h.controller.answer.isEmpty)
        #expect(h.controller.question.isEmpty)
    }

    @Test func panelStaysOnNegativeOriginDisplaysAndAvoidsRightEdge() {
        let screen = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let rect = ScreenAskPanelController.placement(size: CGSize(width: 412, height: 480),
                                                     selection: CGRect(x: -200, y: 300, width: 180, height: 100), screen: screen)
        #expect(screen.insetBy(dx: 8, dy: 8).contains(rect))
        #expect(rect.maxX <= -200)
    }

    @Test func imageSearchUsesTheSelectedEngineAndClearsTheSession() throws {
        let suite = "opentype.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        var engines: [ImageSearchEngine] = []
        var searchedWidth = 0
        let controller = ScreenAskController(settings: settings, credentials: InMemoryCredentialStore(), imageSearch: { image, engine in
            searchedWidth = image.width
            engines.append(engine)
        }, notify: { _ in })
        let context = try #require(CGContext(data: nil, width: 20, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let region = ScreenRegion(image: try #require(context.makeImage()), frame: .zero)
        controller.selected(region)
        controller.searchImage()
        #expect(engines == [.google])
        #expect(searchedWidth == 20)
        #expect(!controller.isVisible)

        controller.selected(region)
        settings.screenAskImageSearchEngine = .bing
        #expect(engines == [.google])
        controller.searchImage()
        #expect(engines == [.google, .bing])
        #expect(!controller.isVisible)
        #expect(SettingsStore(defaults: defaults).screenAskImageSearchEngine == .bing)
    }

    @Test func imageSearchFormsSubmitTheImageInEachEnginesFormat() {
        let data = Data([1, 2, 3])
        let google = ImageSearchEngine.google.html(imageData: data)
        #expect(google.contains("https://lens.google.com/v3/upload"))
        #expect(google.contains("encoded_image"))
        #expect(google.contains("atob('AQID')"))
        let bing = ImageSearchEngine.bing.html(imageData: data)
        #expect(bing.contains("https://www.bing.com/images/detail/search?iss=sbiupload&amp;FORM=ANCMS1#enterInsights"))
        #expect(bing.contains(#"name="imageBin" value="AQID""#))
    }
}

struct ImageSearchCleanupTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        return folder
    }

    private func writeForm(in folder: URL, engine: ImageSearchEngine = .google, age: TimeInterval = 121,
                           name: String = UUID().uuidString + ".html") throws -> URL {
        let file = folder.appendingPathComponent(name)
        try engine.html(imageData: Data([1, 2, 3])).write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: file.path)
        return file
    }

    @Test func removesExpiredFormsButKeepsRecentAndLockedForms() throws {
        let folder = try makeFolder()
        let manager = FileManager.default
        defer { try? manager.removeItem(at: folder) }
        let google = try writeForm(in: folder)
        let bing = try writeForm(in: folder, engine: .bing)
        let recent = try writeForm(in: folder, age: 120)
        let future = try writeForm(in: folder, age: -60)
        let active = try writeForm(in: folder)
        let file = try FileHandle(forWritingTo: active)
        defer { try? file.close() }
        try #require(flock(file.fileDescriptor, LOCK_EX | LOCK_NB) == 0)

        ImageSearchEngine.removeExpiredFiles(in: folder, now: now)

        #expect(!manager.fileExists(atPath: google.path))
        #expect(!manager.fileExists(atPath: bing.path))
        #expect(manager.fileExists(atPath: recent.path))
        #expect(manager.fileExists(atPath: future.path))
        #expect(manager.fileExists(atPath: active.path))

        try #require(flock(file.fileDescriptor, LOCK_UN) == 0)
        ImageSearchEngine.removeExpiredFiles(in: folder, now: now)
        #expect(!manager.fileExists(atPath: active.path))

        ImageSearchEngine.removeExpiredFiles(in: folder, now: now.addingTimeInterval(1))
        #expect(!manager.fileExists(atPath: recent.path))
        #expect(manager.fileExists(atPath: future.path))
    }

    @Test func leavesUnrelatedEntriesAndLinkedFilesAlone() throws {
        let folder = try makeFolder()
        let outside = try makeFolder()
        let manager = FileManager.default
        defer {
            try? manager.removeItem(at: folder)
            try? manager.removeItem(at: outside)
        }
        let target = try writeForm(in: outside)
        let symlink = folder.appendingPathComponent(UUID().uuidString + ".html")
        try manager.createSymbolicLink(at: symlink, withDestinationURL: target)
        let hardLink = folder.appendingPathComponent(UUID().uuidString + ".html")
        try manager.linkItem(at: target, to: hardLink)
        let directory = folder.appendingPathComponent(UUID().uuidString + ".html", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        let nestedForm = try writeForm(in: directory)
        let wrongName = try writeForm(in: folder, name: "other.html")
        let wrongExtension = try writeForm(in: folder, name: UUID().uuidString + ".txt")
        let unrelated = try writeForm(in: folder)
        try Data("unrelated".utf8).write(to: unrelated)
        try manager.setAttributes([.modificationDate: now.addingTimeInterval(-121)], ofItemAtPath: unrelated.path)

        ImageSearchEngine.removeExpiredFiles(in: folder, now: now)

        for entry in [target, symlink, hardLink, nestedForm, wrongName, wrongExtension, unrelated] {
            #expect(manager.fileExists(atPath: entry.path))
        }
    }

    @Test func skipsMissingLinkedAndNonPrivateFolders() throws {
        let folder = try makeFolder()
        let manager = FileManager.default
        defer { try? manager.removeItem(at: folder) }
        let privateFolder = folder.appendingPathComponent("private", isDirectory: true)
        try manager.createDirectory(at: privateFolder, withIntermediateDirectories: false,
                                    attributes: [.posixPermissions: 0o700])
        let expired = try writeForm(in: privateFolder)
        let linked = folder.appendingPathComponent("linked", isDirectory: true)
        try manager.createSymbolicLink(at: linked, withDestinationURL: privateFolder)
        let missing = folder.appendingPathComponent("missing", isDirectory: true)

        ImageSearchEngine.removeExpiredFiles(in: missing, now: now)
        ImageSearchEngine.removeExpiredFiles(in: linked, now: now)
        #expect(!manager.fileExists(atPath: missing.path))
        #expect(manager.fileExists(atPath: expired.path))

        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: privateFolder.path)
        ImageSearchEngine.removeExpiredFiles(in: privateFolder, now: now)
        #expect(manager.fileExists(atPath: expired.path))
    }
}

@MainActor
struct ScreenAskWebSearchTests {
    private func makeSettings() throws -> SettingsStore {
        let name = "opentype.tests.\(UUID().uuidString)"
        return SettingsStore(defaults: try #require(UserDefaults(suiteName: name)))
    }

    @Test func followsTheSharedSettingUnlessOverridden() throws {
        let settings = try makeSettings()
        #expect(settings.screenAskWebSearchLevel == nil) // shared switch is off by default
        settings.webSearchEnabled = true
        #expect(settings.screenAskWebSearchLevel == .aggressive) // inherits the shared 80 %
        settings.webSearchEagerness = 40
        #expect(settings.screenAskWebSearchLevel == .balanced)
        settings.screenAskWebSearchEagerness = 10
        #expect(settings.screenAskWebSearchLevel == .conservative)
        #expect(settings.webSearchLevel == .balanced) // the override never touches the shared value
        settings.screenAskWebSearchMode = .off
        #expect(settings.screenAskWebSearchLevel == nil)
        settings.webSearchEnabled = false
        settings.screenAskWebSearchMode = .on
        #expect(settings.screenAskWebSearchLevel == .conservative)
        settings.screenAskWebSearchEagerness = 0
        #expect(settings.screenAskWebSearchLevel == nil)
        settings.screenAskWebSearchEagerness = nil
        #expect(settings.screenAskWebSearchLevel == .balanced)
    }

    @Test func helpMeSayHasItsOwnEagerness() throws {
        let settings = try makeSettings()
        settings.webSearchEnabled = true
        settings.webSearchEagerness = 80
        #expect(settings.helpMeSayWebSearchLevel == .aggressive)
        settings.helpMeSayWebSearchEagerness = 20
        #expect(settings.helpMeSayWebSearchLevel == .conservative)
        #expect(settings.screenAskWebSearchLevel == .aggressive) // independent of Screen Ask
        settings.screenAskWebSearchEagerness = 50
        #expect(settings.screenAskWebSearchLevel == .balanced && settings.helpMeSayWebSearchLevel == .conservative)
        settings.helpMeSayWebSearchEagerness = 0
        #expect(settings.helpMeSayWebSearchLevel == nil)
        settings.helpMeSayWebSearchEagerness = nil
        #expect(settings.helpMeSayWebSearchLevel == .aggressive)
        settings.webSearchEnabled = false
        settings.helpMeSayWebSearchEagerness = 90
        #expect(settings.helpMeSayWebSearchLevel == nil) // the shared switch still decides
    }

    @Test func overridesPersistAndSharedKeysKeepTheirOldNames() throws {
        let name = "opentype.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "opentype.helpMeSayWebSearchEnabled") // written by a build before the move
        defaults.set(55, forKey: "opentype.helpMeSayWebSearchEagerness")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.webSearchEnabled && settings.webSearchEagerness == 55)
        settings.screenAskWebSearchMode = .on
        settings.screenAskWebSearchEagerness = 120
        #expect(settings.screenAskWebSearchEagerness == 100)
        let restored = SettingsStore(defaults: defaults)
        #expect(restored.screenAskWebSearchMode == .on && restored.screenAskWebSearchEagerness == 100)
        restored.screenAskWebSearchEagerness = nil
        #expect(SettingsStore(defaults: defaults).screenAskWebSearchEagerness == nil)
    }

    @Test func webSearchRequestGoesToDeepSeekWithItsOwnKey() async throws {
        let settings = try makeSettings()
        settings.screenAskWebSearchMode = .on
        let credentials = InMemoryCredentialStore() // no key for the Ask profile: not needed
        let seen = ScreenAskSeen()
        let controller = ScreenAskController(settings: settings, credentials: credentials,
                                             makeLLM: { profile, key in ScreenAskWebLLM(seen: seen, profile: profile, key: key) }, notify: { _ in })
        let context = try #require(CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        controller.selected(ScreenRegion(image: try #require(context.makeImage()), frame: CGRect(x: 0, y: 0, width: 10, height: 10)))
        defer { controller.close() }

        controller.question = "What song is this?"
        controller.submit()
        #expect(controller.error == LLMError.invalidConfig(String(localized: "未填写联网搜索的 DeepSeek API Key")).userMessage)
        #expect(controller.question == "What song is this?")

        try credentials.save("ds-key", account: CredentialAccount.deepseekWebSearchAPIKey)
        controller.submit()
        for _ in 0..<200 where controller.isLoading || controller.answer.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(controller.answer == "Found it")
        #expect(controller.webSearchNote?.isEmpty == false)
        #expect(controller.webSearchStatus == nil)
        let call = try #require(await seen.calls.first)
        #expect(call.model == LLMProfile.deepSeekWebSearchModel && call.key == "ds-key")
        #expect(call.level == .aggressive)
        #expect(call.prompt.contains("search the web"))
    }
}

private actor ScreenAskSeen {
    struct Call { var model: String; var key: String; var level: WebSearchLevel; var prompt: String }
    var calls: [Call] = []
    func record(_ call: Call) { calls.append(call) }
}

private struct ScreenAskWebLLM: LLMProvider {
    let seen: ScreenAskSeen
    let profile: LLMProfile
    let key: String
    func process(transcript: String, systemPrompt: String) async throws -> String { "plain" }
    func completeStreamingWithWebSearch(
        messages: [LLMMessage], systemPrompt: String, level: WebSearchLevel,
        onDelta: @escaping @Sendable (String) -> Void, onProgress: @escaping @Sendable (WebSearchProgress) -> Void
    ) async throws -> WebSearchOutput {
        await seen.record(.init(model: profile.modelID, key: key, level: level, prompt: systemPrompt))
        var progress = WebSearchProgress()
        progress.searches = 1
        progress.results = 5
        onProgress(progress)
        onDelta("Found it")
        return WebSearchOutput(text: "Found it", progress: progress)
    }
}

@MainActor
struct ScreenAskHistoryTests {
    private func makeController(history: HistoryStore, settings: SettingsStore) throws -> ScreenAskController {
        let credentials = InMemoryCredentialStore()
        if let profile = settings.activeProfile { try credentials.save("k", account: CredentialAccount.llmProfile(profile.id)) }
        let calls = ScreenAskCalls()
        let controller = ScreenAskController(settings: settings, credentials: credentials, history: history,
                                             makeLLM: { _, _ in ScreenAskLLM(calls: calls) }, notify: { _ in })
        let context = try #require(CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        controller.selected(ScreenRegion(image: try #require(context.makeImage()), frame: CGRect(x: 0, y: 0, width: 10, height: 10)))
        return controller
    }

    @Test func everyAnsweredQuestionIsRecordedAsTextOnly() async throws {
        let settings = SettingsStore(defaults: try #require(UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")))
        let history = HistoryStore()
        let controller = try makeController(history: history, settings: settings)
        defer { controller.close() }
        for question in ["First", "Second"] {
            controller.question = question
            controller.submit()
            for _ in 0..<200 where controller.isLoading || controller.answer.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
            for _ in 0..<200 where controller.isLoading { try? await Task.sleep(for: .milliseconds(5)) }
        }
        #expect(history.records.count == 2)
        let newest = try #require(history.records.first)
        #expect(newest.kind == .screenAsk && newest.delivery == .displayed)
        #expect(newest.rawText == "Second" && newest.finalText == "Answer")
        #expect(newest.model == settings.screenAskProfile?.modelID)
        #expect(history.records.last?.rawText == "First")
    }

    @Test func textStaysOutOfHistoryWhenSavingIsOff() async throws {
        let settings = SettingsStore(defaults: try #require(UserDefaults(suiteName: "opentype.tests.\(UUID().uuidString)")))
        settings.saveHistoryText = false
        let history = HistoryStore()
        let controller = try makeController(history: history, settings: settings)
        defer { controller.close() }
        controller.question = "Private"
        controller.submit()
        for _ in 0..<200 where history.records.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        let record = try #require(history.records.first)
        #expect(record.kind == .screenAsk && record.rawText == nil && record.finalText == nil)
        #expect(record.wordCount > 0) // statistics survive
    }
}

struct SelectionGeometryTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let box = CGRect(x: 100, y: 200, width: 300, height: 200) // maxX 400, maxY 400

    @Test func cornersEdgeMidpointsAndEdgesAreGrips() {
        #expect(SelectionGeometry.hit(CGPoint(x: 100, y: 400), in: box) == .topLeft)
        #expect(SelectionGeometry.hit(CGPoint(x: 250, y: 402), in: box) == .top)
        #expect(SelectionGeometry.hit(CGPoint(x: 400, y: 300), in: box) == .right)
        #expect(SelectionGeometry.hit(CGPoint(x: 398, y: 200), in: box) == .bottomRight)
        #expect(SelectionGeometry.hit(CGPoint(x: 170, y: 200), in: box) == .bottom) // along the edge, not at its dot
        #expect(SelectionGeometry.hit(CGPoint(x: 100, y: 340), in: box) == .left)
        #expect(SelectionGeometry.hit(CGPoint(x: 250, y: 300), in: box) == nil) // inside: that moves the box
        #expect(SelectionGeometry.hit(CGPoint(x: 600, y: 600), in: box) == nil)
        #expect(SelectionGeometry.hit(.zero, in: .zero) == nil)
    }

    @Test func eachGripMovesOnlyItsOwnSides() {
        #expect(SelectionGeometry.resize(box, handle: .right, to: CGPoint(x: 500, y: 999), within: bounds) == CGRect(x: 100, y: 200, width: 400, height: 200))
        #expect(SelectionGeometry.resize(box, handle: .top, to: CGPoint(x: 0, y: 500), within: bounds) == CGRect(x: 100, y: 200, width: 300, height: 300))
        #expect(SelectionGeometry.resize(box, handle: .topLeft, to: CGPoint(x: 50, y: 450), within: bounds) == CGRect(x: 50, y: 200, width: 350, height: 250))
        #expect(SelectionGeometry.resize(box, handle: .bottomRight, to: CGPoint(x: 450, y: 150), within: bounds) == CGRect(x: 100, y: 150, width: 350, height: 250))
        #expect(SelectionGeometry.resize(box, handle: .left, to: CGPoint(x: 150, y: 0), within: bounds) == CGRect(x: 150, y: 200, width: 250, height: 200))
    }

    @Test func resizingPastTheOppositeSideFlipsAndStaysInBounds() {
        #expect(SelectionGeometry.resize(box, handle: .left, to: CGPoint(x: 700, y: 300), within: bounds) == CGRect(x: 400, y: 200, width: 300, height: 200))
        #expect(SelectionGeometry.resize(box, handle: .bottom, to: CGPoint(x: 0, y: 600), within: bounds) == CGRect(x: 100, y: 400, width: 300, height: 200))
        #expect(SelectionGeometry.resize(box, handle: .topRight, to: CGPoint(x: 5000, y: 5000), within: bounds) == CGRect(x: 100, y: 200, width: 900, height: 600))
    }

    @Test func movingKeepsSizeAndStopsAtTheEdges() {
        #expect(SelectionGeometry.move(box, by: CGSize(width: 50, height: -20), within: bounds) == CGRect(x: 150, y: 180, width: 300, height: 200))
        #expect(SelectionGeometry.move(box, by: CGSize(width: -500, height: -500), within: bounds) == CGRect(x: 0, y: 0, width: 300, height: 200))
        #expect(SelectionGeometry.move(box, by: CGSize(width: 5000, height: 5000), within: bounds) == CGRect(x: 700, y: 600, width: 300, height: 200))
    }

    @Test func newBoxesClipToTheScreen() {
        #expect(SelectionGeometry.rect(from: CGPoint(x: 900, y: 700), to: CGPoint(x: 1200, y: 900), within: bounds) == CGRect(x: 900, y: 700, width: 100, height: 100))
    }
}

@MainActor
struct ScreenAskReselectionTests {
    @Test func adjustingTheBoxResetsTheConversationButKeepsTheTypedQuestion() async throws {
        let h = try ScreenAskHarness()
        defer { h.controller.close() }
        h.controller.question = "First"
        h.controller.submit()
        await h.waitUntil { !h.controller.isLoading }
        #expect(h.controller.answer == "Answer")
        h.controller.question = "Typed meanwhile"
        let context = try #require(CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        h.controller.selected(ScreenRegion(image: try #require(context.makeImage()), frame: CGRect(x: 10, y: 10, width: 40, height: 40)))
        #expect(h.controller.answer.isEmpty && h.controller.isVisible)
        #expect(h.controller.question == "Typed meanwhile")
        h.controller.submit()
        await h.waitUntil { !h.controller.isLoading }
        let calls = await h.calls.messages
        #expect(calls.last?.map(\.content) == ["Typed meanwhile"]) // the earlier turns belonged to the old region
        #expect(calls.last?.first?.imageJPEG != nil)
    }
}
