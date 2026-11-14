import SwiftUI

/// Settings tab of the main window: a segmented switcher over the individual settings pages.
struct SettingsView: View {
    let coordinator: DictationSessionCoordinator
    let updater: AppUpdater
    @State private var page: Page = .general

    private enum Page: String, CaseIterable, Identifiable {
        case general, speech, ai, translation, helpMeSay, privacy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: String(localized: "通用")
            case .speech: String(localized: "语音识别")
            case .ai: String(localized: "AI 处理")
            case .translation: String(localized: "翻译")
            case .helpMeSay: String(localized: "帮我说")
            case .privacy: String(localized: "隐私与权限")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("设置分类", selection: $page) {
                ForEach(Page.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Group {
                switch page {
                case .general: GeneralSettingsTab(coordinator: coordinator, updater: updater)
                case .speech: SpeechRecognitionSettingsTab(coordinator: coordinator)
                case .ai: AIProcessingSettingsTab(coordinator: coordinator)
                case .translation: TranslationSettingsTab(coordinator: coordinator)
                case .helpMeSay: HelpMeSaySettingsTab(coordinator: coordinator)
                case .privacy: PrivacyPermissionsSettingsTab(coordinator: coordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    let updater: AppUpdater
    private var settingsStore: SettingsStore { coordinator.settingsStore }
    @State private var launchAtLogin = false
    @State private var launchError: String?
    /// The language picked now vs. the one the running process was launched with.
    @State private var language = AppLanguage.stored()

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("启动与显示") {
                Toggle("开机启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        do {
                            try settingsStore.setLaunchAtLogin(newValue)
                            launchError = nil
                        } catch {
                            launchError = String(localized: "设置开机启动失败：\(error.localizedDescription)")
                        }
                        launchAtLogin = settingsStore.launchAtLogin
                    }
                ))
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
                Toggle("在 Dock 中显示图标", isOn: $settingsStore.showDockIcon)
            }
            UpdateSettingsSection(updater: updater, settingsStore: settingsStore)
            Section("界面语言") {
                Picker("界面语言", selection: Binding(
                    get: { language },
                    set: { newValue in
                        language = newValue
                        AppLanguage.store(newValue)
                    }
                )) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                if language != AppLanguage.atLaunch {
                    HStack {
                        Text("更改语言后需重启 OpenType 才会生效。").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("重启 OpenType") { coordinator.permissions.relaunch() }
                    }
                }
            }
            Section("快捷键（按一下开始，再按一下结束）") {
                HotkeyRecorderRow(
                    title: "全局快捷键",
                    hotkey: Binding(get: { settingsStore.hotkey }, set: { settingsStore.hotkey = $0 ?? .default }),
                    defaultHotkey: .default,
                    conflict: { $0 == settingsStore.translationHotkey ? String(localized: "与翻译快捷键相同，请换一个") : nil },
                    coordinator: coordinator
                )
                Toggle("暂停全局快捷键", isOn: $settingsStore.hotkeysPaused)
                Text("短按快捷键开始说话，再短按一次结束，随后自动整理并插入；长按快捷键则是「帮我说」（见「帮我说」标签页）；说话过程中按 Esc 可取消。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("悬浮窗与反馈") {
                Picker("悬浮窗位置", selection: $settingsStore.overlayPosition) {
                    ForEach(OverlayPosition.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("悬浮窗材质", selection: $settingsStore.overlayMaterial) {
                    ForEach(OverlayMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("极简悬浮窗", isOn: $settingsStore.overlayMinimalMode)
                Picker("极简胶囊材质", selection: $settingsStore.overlayMinimalMaterial) {
                    ForEach(OverlayMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Text("只显示一个带小音波的胶囊，不显示识别文字和结果；翻译时上方多一个选择语言的胶囊，联网搜索 / 读取网页时再多一个显示进度的长胶囊。出错或需要手动复制时仍会展开完整窗口。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("声音反馈", isOn: $settingsStore.soundFeedbackEnabled)
                Text("开启后，开始录音、结束录音、转写完成及出错时会播放提示音（默认关闭）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("文本插入") {
                Toggle("转写后自动插入文本", isOn: $settingsStore.autoInsertEnabled)
                Text("关闭后，结果会显示在悬浮窗中供手动复制。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = settingsStore.launchAtLogin }
    }
}

// MARK: - Speech recognition

private struct SpeechRecognitionSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    @State private var testResult: TestResult = .idle

    private var settingsStore: SettingsStore { coordinator.settingsStore }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("服务商") {
                Picker("语音识别服务", selection: $settingsStore.asrProvider) {
                    ForEach(ASRProvider.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: settingsStore.asrProvider) { _, _ in testResult = .idle }
            }
            switch settingsStore.asrProvider {
            case .bailian:
                bailianSections(settingsStore: settingsStore)
            case .deepseek:
                deepseekSections()
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func bailianSections(settingsStore: SettingsStore) -> some View {
        @Bindable var settingsStore = settingsStore
        Section("阿里云百炼") {
            Picker("识别模型", selection: $settingsStore.asrModel) {
                ForEach(ASRModel.allCases) { Text($0.displayName).tag($0) }
            }
            .onChange(of: settingsStore.asrModel) { _, _ in testResult = .idle }
            Picker("区域", selection: $settingsStore.asrRegion) {
                ForEach(ASRRegion.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Workspace ID", text: $settingsStore.asrWorkspaceID)
            SecretField(
                title: "API Key",
                account: CredentialAccount.bailianAPIKey,
                credentials: coordinator.credentialStore
            )
            DisclosureGroup("高级：自定义 WebSocket 地址") {
                TextField("wss://…（留空则使用上方区域与 Workspace ID）", text: $settingsStore.asrCustomURL)
                Text("自定义地址须与所选识别模型的协议一致（qwen-audio 为 /api-ws/v1/inference，qwen3 为 /api-ws/v1/realtime?model=…）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("测试连接") { test() }
                    .disabled(testResult == .running)
                TestResultView(result: testResult)
            }
        }
        Section("识别") {
            Picker("默认识别语言", selection: $settingsStore.asrLanguage) {
                ForEach(ASRLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            Text("指定后只按该语言识别，能减少混语与误判；不确定时保持「自动识别」。")
                .font(.caption).foregroundStyle(.secondary)
            if settingsStore.asrModel == .qwenAudio31Message {
                Text("该模型的语种提示支持 30 种语言；粤语会保留粤语写法，乌克兰语、土耳其语、冰岛语没有对应提示，将自动识别。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("识别端润色：去除语气词与重复语", isOn: $settingsStore.asrDisfluencyRemoval)
                Text("由语音识别模型直接过滤「嗯、呃」等语气词与重复内容并润色（disfluency_removal_enabled）。已启用 AI 文本后处理时通常无需开启，关闭可保留原话。录音时的实时中间结果始终开启。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("断句模式", selection: $settingsStore.asrTurnDetection) {
                    ForEach(ASRTurnDetection.allCases) { Text($0.displayName).tag($0) }
                }
            }
            if settingsStore.asrModel == .qwenAudio31Message || settingsStore.asrTurnDetection == .serverVAD {
                HStack {
                    Text("VAD 阈值")
                    Slider(value: $settingsStore.asrVADThreshold, in: -1...1, step: 0.1)
                    Text(settingsStore.asrVADThreshold, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit().frame(width: 36)
                }
                Stepper("静音时长：\(settingsStore.asrSilenceDurationMS) ms",
                        value: $settingsStore.asrSilenceDurationMS, in: 200...2000, step: 100)
            } else {
                Text("手动模式在结束录音时发送 commit，建议单次录音不超过 60 秒。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            Text("录音会实时发送到阿里云百炼进行识别；默认不在本地保存音频与识别记录。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func deepseekSections() -> some View {
        Section("DeepSeek 语音识别") {
            SecretField(
                title: "API Key",
                account: CredentialAccount.deepseekASRAPIKey,
                credentials: coordinator.credentialStore
            )
            HStack {
                Button("测试连接") { test() }
                    .disabled(testResult == .running)
                TestResultView(result: testResult)
            }
            Text("DeepSeek 没有语种参数，只能根据音频自动识别（支持中文、粤语、英语、日语、韩语等 21 种语言），因此「默认识别语言」对它不生效；如需指定语言，请改用阿里云百炼。")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Text("DeepSeek 不支持流式识别：录音期间不会显示实时文字，结束录音后才会上传整段音频并返回结果。单次请求最长 120 秒，更长的录音会自动分段识别。测试连接会发送一段 0.5 秒的静音，按 1 秒计费。")
                .font(.caption).foregroundStyle(.secondary)
            Text("录音结束后会以 WAV 文件整段发送到 DeepSeek（api.deepseek.com）进行识别；默认不在本地保存音频与识别记录。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func test() {
        testResult = .running
        Task {
            do {
                try await coordinator.testASRConnection()
                testResult = .success(String(localized: "连接成功"))
            } catch let error as ASRError {
                testResult = .failure(error.userMessage)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
        }
    }
}

// MARK: - AI processing

private struct AIProcessingSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    @State private var testResult: TestResult = .idle

    private var settingsStore: SettingsStore { coordinator.settingsStore }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        let profile = Binding<LLMProfile>(
            get: { settingsStore.activeProfile ?? LLMProfile.makeDefault() },
            set: { settingsStore.updateProfile($0) }
        )
        Form {
            Section("处理") {
                Toggle("启用 AI 文本后处理", isOn: $settingsStore.llmEnabled)
                Picker("处理等级", selection: $settingsStore.processingLevel) {
                    ForEach(ProcessingLevel.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("AI 失败或超时时回退使用 ASR 原文", isOn: $settingsStore.fallbackToRawOnLLMFailure)
            }

            Section("配置（Profile）") {
                HStack {
                    Picker("当前配置", selection: $settingsStore.activeProfileID) {
                        ForEach(settingsStore.llmProfiles) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Button { settingsStore.addProfile() } label: { Image(systemName: "plus") }
                        .help("新建配置")
                    Button { settingsStore.addProfile(from: profile.wrappedValue) } label: { Image(systemName: "plus.square.on.square") }
                        .help("复制当前配置")
                    Button {
                        let id = profile.wrappedValue.id
                        if settingsStore.removeProfile(id: id) != nil {
                            try? coordinator.credentialStore.delete(account: CredentialAccount.llmProfile(id))
                        }
                    } label: { Image(systemName: "minus") }
                        .help("删除当前配置")
                        .disabled(settingsStore.llmProfiles.count <= 1)
                }
                TextField("名称", text: profile.name)
                Picker("API 格式", selection: profile.format) {
                    ForEach(LLMAPIFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: profile.wrappedValue.format) { old, new in
                    // Switching format swaps the default Base URL, but never overwrites a custom one.
                    if profile.wrappedValue.baseURL == old.defaultBaseURL {
                        profile.wrappedValue.baseURL = new.defaultBaseURL
                    }
                }
                TextField("Base URL", text: profile.baseURL)
                    .autocorrectionDisabled()
                Text("将请求：\(endpointPreview(profile.wrappedValue))")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                TextField("Model ID", text: profile.modelID)
                    .autocorrectionDisabled()
                TextField("推理强度（effort）", text: profile.reasoningEffort, prompt: Text("留空则不发送，如 low / medium / high"))
                    .autocorrectionDisabled()
                Text("原样发送，各家模型支持的取值不同，请按所用模型的文档填写；留空时不发送该参数。填写了模型不支持的值可能返回错误。")
                    .font(.caption).foregroundStyle(.secondary)
                SecretField(
                    title: "API Key",
                    account: CredentialAccount.llmProfile(profile.wrappedValue.id),
                    credentials: coordinator.credentialStore
                )
                Stepper("超时：\(Int(profile.wrappedValue.timeout)) 秒", value: profile.timeout, in: 3...120, step: 1)
                HStack {
                    Button("测试连接") { test(profile.wrappedValue) }
                        .disabled(testResult == .running)
                    TestResultView(result: testResult)
                }
            }

            Section("System Prompt") {
                TextEditor(text: profile.systemPrompt)
                    .font(.callout)
                    .frame(height: 120)
                Button("恢复默认 Prompt") {
                    profile.wrappedValue.systemPrompt = TextProcessor.defaultSystemPrompt
                }
            }

            Section {
                Text("转写文本会发送到上方配置的 LLM 服务；API Key 以明文 JSON 保存在 ~/.opentype。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settingsStore.activeProfileID) { _, _ in testResult = .idle }
    }

    private func endpointPreview(_ profile: LLMProfile) -> String {
        (try? LLMRequestBuilder.endpoint(format: profile.format, baseURL: profile.baseURL).absoluteString)
            ?? String(localized: "（Base URL 无效，必须为 https）")
    }

    private func test(_ profile: LLMProfile) {
        testResult = .running
        Task {
            do {
                let output = try await coordinator.testLLMConnection(profile: profile)
                testResult = .success(String(localized: "连接成功，示例输出：\(output)"))
            } catch let error as LLMError {
                testResult = .failure(error.userMessage)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
        }
    }
}

// MARK: - Translation

private struct TranslationSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    private var settingsStore: SettingsStore { coordinator.settingsStore }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("默认翻译语言") {
                Picker("翻译为", selection: $settingsStore.translationTargetLanguage) {
                    ForEach(TranslationLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Text("开始翻译时，悬浮窗会预先选中这里的语言；你可以在悬浮窗里临时切换成其他语言（仅对当次生效，不会改动这里的默认值）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("地区用语") {
                Picker("葡萄牙语", selection: Binding(
                    get: { settingsStore.translationRegion(for: .portuguese) ?? .brazil },
                    set: { settingsStore.setTranslationRegion($0, for: .portuguese) }
                )) {
                    ForEach(TranslationLanguage.portuguese.regions) { Text($0.displayName).tag($0) }
                }
                Picker("繁體中文", selection: Binding(
                    get: { settingsStore.translationRegion(for: .traditionalChinese) ?? .taiwan },
                    set: { settingsStore.setTranslationRegion($0, for: .traditionalChinese) }
                )) {
                    ForEach(TranslationLanguage.traditionalChinese.regions) { Text($0.displayName).tag($0) }
                }
                Text("巴西与葡萄牙的葡萄牙语、台湾与港澳的繁体中文，用词和写法并不相同。翻译成这两种语言时，会明确要求模型使用这里选的地区用语；悬浮窗里也可以临时切换。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("翻译快捷键（按一下开始，再按一下结束；长按为「翻译帮我说」）") {
                HotkeyRecorderRow(
                    title: "翻译快捷键",
                    hotkey: $settingsStore.translationHotkey,
                    defaultHotkey: .defaultTranslation,
                    allowsClear: true,
                    conflict: { $0 == settingsStore.hotkey ? String(localized: "与听写快捷键相同，请换一个") : nil },
                    coordinator: coordinator
                )
                Text("说出一段话，结束后会先整理再翻译成目标语言并插入。长按这个快捷键则是「翻译帮我说」（见「帮我说」标签页）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("翻译由「AI 处理」中当前选中的 Profile 完成，需要已填写 API Key；即使关闭了 AI 文本后处理或选择了原始模式，翻译仍会调用该模型。翻译失败时不会插入未翻译的文字，识别原文会保留在悬浮窗中供复制。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Help me say

private struct HelpMeSaySettingsTab: View {
    let coordinator: DictationSessionCoordinator
    @State private var testResult: TestResult = .idle
    private var settingsStore: SettingsStore { coordinator.settingsStore }

    private var eagernessLabel: String {
        let value = settingsStore.helpMeSayWebSearchEagerness
        guard let level = WebSearchLevel(eagerness: value) else { return String(localized: "\(value)%（不搜索）") }
        return "\(value)%（\(level.displayName)）"
    }

    private func testWebSearch() {
        testResult = .running
        Task {
            do {
                let output = try await coordinator.testWebSearchConnection()
                testResult = .success(String(localized: "连接成功，示例输出：\(output)"))
            } catch let error as LLMError {
                testResult = .failure(error.userMessage)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
        }
    }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("帮我说") {
                Toggle("长按快捷键触发「帮我说」/「翻译帮我说」", isOn: $settingsStore.helpMeSayEnabled)
                Text("按住「通用」里设置的听写快捷键不放，直到悬浮窗显示「帮我说」后开始说话，松开即结束。识别完成后，模型不只是整理文字，还会弄清你想表达的意思，把它细化、补全、理顺，写成可以直接发出的成品，再自动插入。轻按一下快捷键仍是普通听写。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("翻译帮我说：长按「翻译」标签页里设置的翻译快捷键，做同样的事，但成品直接用翻译目标语言写出（悬浮窗里可临时切换语言与地区用语）。例：按住翻译快捷键说「跟房东说下个月水管漏水要修，问他什么时候方便」，得到一段完整、得体的目标语言消息。它与「帮我说」共用下面的联网搜索（搜索与读取网页）和 System Prompt 设置；模型调用失败时不会插入未翻译的文字，识别原文会保留在悬浮窗中供复制。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("例：说「跟老师说我明天发烧了想请一天假」，会得到一段完整、礼貌的请假消息；说「帮我问下这个报错怎么解决」，会被整理成问题明确、条件完整的提问。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("联网搜索（DeepSeek）") {
                Toggle("允许模型联网搜索并读取网页", isOn: $settingsStore.helpMeSayWebSearchEnabled)
                Text("开启后，「帮我说」与「翻译帮我说」改由 DeepSeek（api.deepseek.com，模型 deepseek-flash，均为固定值）完成：模型在需要查证或较新信息时自行搜索网络，并把查到的资料融入成品。搜索与网页读取由 DeepSeek 服务端完成，是否搜索由模型决定，会明显增加耗时（开启思考模式以便多步搜索，超时 180 秒）；搜索时悬浮窗会实时显示正在搜索的内容和已搜到的结果数，完成后提示是否真的搜索过，并按 DeepSeek 联网工具的价格另外计费。此时不使用「AI 处理」里选中的 Profile；普通听写与普通翻译不受影响。")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("搜索积极度")
                        Spacer()
                        Text(eagernessLabel).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.helpMeSayWebSearchEagerness) },
                            set: { settingsStore.helpMeSayWebSearchEagerness = Int($0.rounded()) }
                        ),
                        in: 0...100, step: 5
                    )
                    .disabled(!settingsStore.helpMeSayWebSearchEnabled)
                }
                Text("0%：不搜索（等同关闭，仍用「AI 处理」的 Profile）；1–33% 保守：只在你明确要求查证时搜索，用快速模式；34–66% 适中：遇到拿不准的具体事实才搜索；67–100% 积极：凡涉及可查证的事实都会先搜索核实。保守档不开思考模式，更快更省；适中和积极档用多步深度搜索，更耗时。")
                    .font(.caption).foregroundStyle(.secondary)
                SecretField(
                    title: "DeepSeek API Key",
                    account: CredentialAccount.deepseekWebSearchAPIKey,
                    credentials: coordinator.credentialStore
                )
                HStack {
                    Button("测试连接") { testWebSearch() }
                        .disabled(testResult == .running)
                    TestResultView(result: testResult)
                }
                Text("此 Key 单独保存，与语音识别、AI 处理的 Key 互不影响。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("System Prompt") {
                TextEditor(text: $settingsStore.helpMeSayPrompt)
                    .font(.callout)
                    .frame(height: 200)
                Button("恢复默认 Prompt") {
                    settingsStore.helpMeSayPrompt = TextProcessor.defaultHelpMeSayPrompt
                }
                .disabled(settingsStore.helpMeSayPrompt == TextProcessor.defaultHelpMeSayPrompt)
                Text("留空时使用默认 Prompt。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("「帮我说」与「翻译帮我说」由「AI 处理」中当前选中的 Profile 完成（开启上面的联网搜索时改用 DeepSeek），需要已填写 API Key；即使关闭了 AI 文本后处理或选择了原始模式，它仍会调用该模型。生成内容较长，如经常超时，可在 Profile 中调大超时时间。模型调用失败时，是否改用识别原文取决于「AI 失败或超时时回退使用 ASR 原文」。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy & permissions

private struct PrivacyPermissionsSettingsTab: View {
    let coordinator: DictationSessionCoordinator

    private var permissions: PermissionManager { coordinator.permissions }

    var body: some View {
        @Bindable var settingsStore = coordinator.settingsStore
        Form {
            Section("权限") {
                permissionRow(
                    "麦克风", "采集语音并发送到语音识别服务。",
                    status: permissions.microphone,
                    request: { Task { _ = await permissions.ensureMicrophone() } },
                    pane: .microphone
                )
                permissionRow(
                    "辅助功能", "向其他应用的输入框写入文本、模拟粘贴。",
                    status: permissions.accessibility,
                    request: { permissions.requestAccessibility() },
                    pane: .accessibility
                )
                permissionRow(
                    "按键监听（输入监控）", "监听全局快捷键。",
                    status: permissions.inputMonitoring,
                    request: { permissions.requestInputMonitoring() },
                    pane: .inputMonitoring
                )
                if !coordinator.hotkeyActive {
                    Text("全局快捷键尚未生效。授权后会自动生效；如果系统设置里已经打开开关但这里仍显示 ✗，请点「重启 OpenType」；若仍无效，在系统设置的列表里选中 OpenType，点「−」删除后用「+」重新添加。")
                        .font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("重新检查") { permissions.refresh() }
                    Button("重启 OpenType") { permissions.relaunch() }
                }
                Text("当前运行位置：\(Bundle.main.bundleURL.path)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Section("隐私") {
                Text("不会保存原始音频。识别和整理后的文字默认保存在本机「历史」中（不上传），可在历史页关闭或清空；统计只记录次数、字数、时长和 Token 数。")
                Text("语音发送至所选的语音识别服务（阿里云百炼或 DeepSeek）；转写文本发送至所配置的 LLM 服务。API Key 以明文 JSON 保存在 ~/.opentype。")
                    .foregroundStyle(.secondary)
                Toggle("启用诊断日志（仅记录阶段耗时，不含语音与文字内容）", isOn: $settingsStore.diagnosticsEnabled)
                Button("清除临时数据") { coordinator.clearTemporaryData() }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private func permissionRow(
        _ title: LocalizedStringKey, _ detail: LocalizedStringKey, status: PermissionStatus,
        request: @escaping () -> Void, pane: PermissionManager.Pane
    ) -> some View {
        HStack {
            Image(systemName: status.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status.isGranted ? .green : .red)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !status.isGranted {
                Button("授权", action: request)
                Button("打开系统设置") { permissions.openSystemSettings(pane) }
            }
        }
    }
}

// MARK: - Shared

private enum TestResult: Equatable {
    case idle, running, success(String), failure(String)
}

private struct TestResultView: View {
    let result: TestResult

    var body: some View {
        switch result {
        case .idle: EmptyView()
        case .running: ProgressView().controlSize(.small)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green).lineLimit(3).font(.caption)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill").foregroundStyle(.red).lineLimit(3).font(.caption)
        }
    }
}

// MARK: - Software update

private struct UpdateSettingsSection: View {
    let updater: AppUpdater
    let settingsStore: SettingsStore

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Section("软件更新") {
            LabeledContent("当前版本", value: updater.currentVersion.description)
            statusRow
            if let notes = updater.release?.notes, updater.updateAvailable, !notes.isEmpty {
                DisclosureGroup("更新内容") {
                    ScrollView {
                        Text(notes).font(.caption).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                }
            }
            Toggle("自动检查更新", isOn: $settingsStore.autoCheckUpdates)
            Toggle("自动下载并安装更新", isOn: $settingsStore.autoInstallUpdates)
            Text("开启后，发现新版本会在后台下载并校验，待当前没有听写任务时自动安装并重启 OpenType。更新来自 GitHub Releases。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle, .upToDate:
            HStack {
                Text(updater.state == .upToDate ? "已是最新版本" : "尚未检查更新")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("检查更新") { Task { await updater.checkForUpdates() } }
            }
        case .checking:
            HStack { ProgressView().controlSize(.small); Text("正在检查更新…").foregroundStyle(.secondary) }
        case .available:
            HStack {
                Text("发现新版本 \(updater.release?.version.description ?? "")").foregroundStyle(.green)
                Spacer()
                Button("更新并重启") { updater.installUpdate() }.buttonStyle(.borderedProminent)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("正在下载更新… \(Int(progress * 100))%").foregroundStyle(.secondary)
                ProgressView(value: progress)
            }
        case .readyToInstall:
            HStack { ProgressView().controlSize(.small); Text("更新已就绪，即将重启…").foregroundStyle(.secondary) }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.caption).foregroundStyle(.red)
                HStack {
                    if updater.release != nil { Button("重试") { updater.installUpdate() } }
                    Button("检查更新") { Task { await updater.checkForUpdates() } }
                    Button("手动下载") { updater.openReleasePage() }
                }
            }
        }
    }
}
