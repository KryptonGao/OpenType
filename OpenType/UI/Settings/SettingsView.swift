import SwiftUI

/// One settings page of the main window; the sidebar picks which one (see `SettingsPage`).
struct SettingsView: View {
    let page: SettingsPage
    let coordinator: DictationSessionCoordinator
    let updater: AppUpdater

    var body: some View {
        Group {
            switch page {
            case .general: GeneralSettingsTab(coordinator: coordinator, updater: updater)
            case .speech: SpeechRecognitionSettingsTab(coordinator: coordinator)
            case .ai: AIProcessingSettingsTab(coordinator: coordinator)
            case .translation: TranslationSettingsTab(coordinator: coordinator)
            case .helpMeSay: HelpMeSaySettingsTab(coordinator: coordinator)
            case .writingTools: WritingToolsSettingsTab(coordinator: coordinator)
            case .screenAsk: ScreenAskSettingsTab(coordinator: coordinator)
            case .privacy: PrivacyPermissionsSettingsTab(coordinator: coordinator)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(page.title)
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
                    conflict: {
                        if $0 == settingsStore.screenAskHotkey { return String(localized: "与屏幕提问快捷键相同，请换一个") }
                        if $0 == settingsStore.translationHotkey { return String(localized: "与翻译快捷键相同，请换一个") }
                        return $0 == settingsStore.writingToolsHotkey ? String(localized: "与书写工具快捷键相同，请换一个") : nil
                    },
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
    private var audioInputMonitor: AudioInputMonitor { coordinator.audioInputMonitor }

    private var audioInputSelection: Binding<String?> {
        Binding(
            get: { settingsStore.audioInputDeviceUID },
            set: { newUID in
                guard let newUID else {
                    settingsStore.selectAudioInputDevice(nil)
                    return
                }
                if let device = audioInputMonitor.devices.first(where: { $0.uid == newUID }) {
                    settingsStore.selectAudioInputDevice(device)
                }
            }
        )
    }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        let missing = audioInputMonitor.disconnectedLockedDevice(
            uid: settingsStore.audioInputDeviceUID,
            cachedName: settingsStore.audioInputDeviceName
        )
        let isBluetooth = audioInputMonitor.activeTransport(lockedUID: settingsStore.audioInputDeviceUID) == .bluetooth
        Form {
            Section("麦克风") {
                Picker("输入设备", selection: audioInputSelection) {
                    Text(audioInputMonitor.systemDefaultLabel()).tag(String?.none)
                    if !audioInputMonitor.devices.isEmpty {
                        Divider()
                        ForEach(audioInputMonitor.devices) { device in
                            Text(device.displayName).tag(Optional(device.uid))
                        }
                    }
                    if let missing {
                        Divider()
                        Text(String(localized: "\(missing.name)（未连接）")).tag(Optional(missing.uid))
                    }
                }
                if isBluetooth {
                    Label("当前将使用蓝牙麦克风，录音期间蓝牙耳机可能会切换到低音质通话模式；建议改选内置或外接麦克风。", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("锁定为内置或外接麦克风后，即使戴着 AirPods 等蓝牙耳机听歌或开会，触发听写也不会把蓝牙切到低音质通话模式。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        .onAppear { audioInputMonitor.refresh() }
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
            ProviderSiteLink(site: .bailian)
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
            ProviderSiteLink(site: .deepseek)
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

    @State private var webSearchTestResult: TestResult = .idle
    private var settingsStore: SettingsStore { coordinator.settingsStore }


    private var eagernessLabel: String {
        let value = settingsStore.webSearchEagerness
        guard let level = WebSearchLevel(eagerness: value) else { return String(localized: "\(value)%（不搜索）") }
        return "\(value)%（\(level.displayName)）"
    }

    private func testWebSearch() {
        webSearchTestResult = .running
        Task {
            do {
                let output = try await coordinator.testWebSearchConnection()
                webSearchTestResult = .success(String(localized: "连接成功，示例输出：\(output)"))
            } catch let error as LLMError {
                webSearchTestResult = .failure(error.userMessage)
            } catch {
                webSearchTestResult = .failure(error.localizedDescription)
            }
        }
    }

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

            Section("联网搜索（DeepSeek）") {
                Toggle("允许模型联网搜索并读取网页", isOn: $settingsStore.webSearchEnabled)
                Text("开启后，「帮我说」、「翻译帮我说」与「屏幕提问」（可在其设置中单独开关）改由 DeepSeek（api.deepseek.com，模型 deepseek-flash，均为固定值）完成：模型在需要查证或较新信息时自行搜索网络，并把查到的资料融入成品。搜索与网页读取由 DeepSeek 服务端完成，是否搜索由模型决定，会明显增加耗时（开启思考模式以便多步搜索，超时 180 秒）；搜索时悬浮窗会实时显示正在搜索的内容和已搜到的结果数，完成后提示是否真的搜索过，并按 DeepSeek 联网工具的价格另外计费。此时这些功能不使用上方选中的 Profile；普通听写与普通翻译不受影响。")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("默认搜索积极度")
                        Spacer()
                        Text(eagernessLabel).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.webSearchEagerness) },
                            set: { settingsStore.webSearchEagerness = Int($0.rounded()) }
                        ),
                        in: 0...100, step: 5
                    )
                    .disabled(!settingsStore.webSearchEnabled)
                }
                Text("0%：不搜索（等同关闭，仍用「AI 处理」的 Profile）；1–33% 保守：只在你明确要求查证时搜索，用快速模式；34–66% 适中：遇到拿不准的具体事实才搜索；67–100% 积极：凡涉及可查证的事实都会先搜索核实。保守档不开思考模式，更快更省；适中和积极档用多步深度搜索，更耗时。这里是默认值，「帮我说」与「屏幕提问」未单独设置时沿用；它们各自的积极度请分别在「帮我说」「屏幕提问」设置页里选择。")
                    .font(.caption).foregroundStyle(.secondary)
                SecretField(
                    title: "DeepSeek API Key",
                    account: CredentialAccount.deepseekWebSearchAPIKey,
                    credentials: coordinator.credentialStore
                )
                ProviderSiteLink(site: .deepseek)
                HStack {
                    Button("测试连接") { testWebSearch() }
                        .disabled(webSearchTestResult == .running)
                    TestResultView(result: webSearchTestResult)
                }
                Text("此 Key 单独保存，与语音识别、AI 处理的 Key 互不影响。")
                    .font(.caption).foregroundStyle(.secondary)
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
            Section("预设") {
                Toggle("翻译时套用当前应用的预设", isOn: $settingsStore.translationUsesPreset)
                Text("开启后，翻译会使用当前应用对应的预设（见「预设」页）：译文遵循该预设的语气与风格，启用它的专有名词词库，并按它的设置去掉句末句号。「Terminal 命令生成」这类命令预设不会用于翻译。关闭时翻译只使用自己的提示词。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("翻译快捷键（按一下开始，再按一下结束；长按为「翻译帮我说」）") {
                HotkeyRecorderRow(
                    title: "翻译快捷键",
                    hotkey: $settingsStore.translationHotkey,
                    defaultHotkey: .defaultTranslation,
                    allowsClear: true,
                    conflict: {
                        if $0 == settingsStore.screenAskHotkey { return String(localized: "与屏幕提问快捷键相同，请换一个") }
                        if $0 == settingsStore.hotkey { return String(localized: "与听写快捷键相同，请换一个") }
                        return $0 == settingsStore.writingToolsHotkey ? String(localized: "与书写工具快捷键相同，请换一个") : nil
                    },
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

// MARK: - Writing Tools

private struct WritingToolsSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    private var settingsStore: SettingsStore { coordinator.settingsStore }

    /// Model ID of the chosen profile (what a blank field falls back to).
    private var profileModelID: String {
        let profile = settingsStore.llmProfiles.first { $0.id == settingsStore.writingToolsProfileID } ?? settingsStore.activeProfile
        return profile?.modelID ?? ""
    }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("书写工具") {
                Toggle("启用书写工具", isOn: $settingsStore.writingToolsEnabled)
                Text("在任意应用里选中文字，按快捷键，在选区旁弹出面板：纠错、改写、调整语气、摘要、要点、列表、表格、翻译，或用一句话（打字或语音）描述想要的修改。没有选中文字时直接打开「创作」，用一句话生成邮件、贴文或消息，插入到光标处。结果页可以继续调整，替换后在原应用里按 ⌘Z 即可还原。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("快捷键") {
                HotkeyRecorderRow(
                    title: "书写工具快捷键",
                    hotkey: Binding(get: { settingsStore.writingToolsHotkey }, set: { settingsStore.writingToolsHotkey = $0 ?? .defaultWritingTools }),
                    defaultHotkey: .defaultWritingTools,
                    conflict: {
                        if $0 == settingsStore.screenAskHotkey { return String(localized: "与屏幕提问快捷键相同，请换一个") }
                        if $0 == settingsStore.hotkey { return String(localized: "与听写快捷键相同，请换一个") }
                        return $0 == settingsStore.translationHotkey ? String(localized: "与翻译快捷键相同，请换一个") : nil
                    },
                    coordinator: coordinator
                )
                Picker("面板材质", selection: $settingsStore.writingToolsMaterial) {
                    ForEach(OverlayMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Text("面板出现在鼠标指针旁，可以拖动。再按一次快捷键或按 Esc 可关闭面板。面板不会抢走原应用的焦点，选区保持不变。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("AI 模型") {
                Picker("配置（Profile）", selection: $settingsStore.writingToolsProfileID) {
                    Text("跟随「AI 处理」当前配置").tag(UUID?.none)
                    Divider()
                    ForEach(settingsStore.llmProfiles) { Text($0.name).tag(Optional($0.id)) }
                }
                TextField("Model ID", text: $settingsStore.writingToolsModelID,
                          prompt: Text("留空则使用配置里的：\(profileModelID)"))
                    .autocorrectionDisabled()
                TextField("推理强度（effort）", text: $settingsStore.writingToolsReasoningEffort,
                          prompt: Text("留空则使用配置里的设置，如 low / medium / high"))
                    .autocorrectionDisabled()
                Text("书写工具可以使用与听写不同的模型和推理强度（例如更快的小模型）。API Key、Base URL 和 API 格式取自上面选中的配置；两个栏位留空时完全沿用该配置。推理强度原样发送，请按所用模型的文档填写。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("选中的文字（或「创作」的需求）会发送到上方配置的 LLM 服务。个别应用不向系统公开所选文字时，OpenType 会模拟一次 ⌘C 来读取，并随后还原剪贴板。需要辅助功能权限。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Help me say

private struct HelpMeSaySettingsTab: View {
    let coordinator: DictationSessionCoordinator
    private var settingsStore: SettingsStore { coordinator.settingsStore }

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Section("语音改写") {
                Toggle("选中文字后用语音改写它", isOn: $settingsStore.voiceRewriteEnabled)
                Text("在任意应用里先选中一段文字，再按听写快捷键（或长按），说出修改要求，例如「语气委婉一点」「翻译成日语」「总结成三条要点」「把这段 JSON 转成 Swift struct」。OpenType 会把选中的原文和你的语音指令一起交给「AI 处理」中当前选中的 Profile，并用结果直接替换选中的内容；悬浮窗会显示「语音改写」。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("没有选中文字，或应用不向系统公开所选文字（需要辅助功能权限）时，仍是普通听写。翻译快捷键与终端命令预设不受影响。改写失败时不会改动选中的文字；如果录音期间选区变了，结果会复制到剪贴板而不是写入。每次改写都会把选中的文字发送给该 Profile 的模型。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("帮我说") {
                Toggle("长按快捷键触发「帮我说」/「翻译帮我说」", isOn: $settingsStore.helpMeSayEnabled)
                Text("按住「通用」里设置的听写快捷键不放，直到悬浮窗显示「帮我说」后开始说话，松开即结束。识别完成后，模型不只是整理文字，还会弄清你想表达的意思，把它细化、补全、理顺，写成可以直接发出的成品，再自动插入。轻按一下快捷键仍是普通听写。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("翻译帮我说：长按「翻译」标签页里设置的翻译快捷键，做同样的事，但成品直接用翻译目标语言写出（悬浮窗里可临时切换语言与地区用语）。例：按住翻译快捷键说「跟房东说下个月水管漏水要修，问他什么时候方便」，得到一段完整、得体的目标语言消息。它与「帮我说」共用「AI 处理」里的联网搜索（搜索与读取网页）和下面的 System Prompt 设置；模型调用失败时不会插入未翻译的文字，识别原文会保留在悬浮窗中供复制。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("例：说「跟老师说我明天发烧了想请一天假」，会得到一段完整、礼貌的请假消息；说「帮我问下这个报错怎么解决」，会被整理成问题明确、条件完整的提问。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("联网搜索") {
                WebSearchEagernessOverrideRow(override: $settingsStore.helpMeSayWebSearchEagerness, shared: settingsStore.webSearchEagerness)
                    .disabled(!settingsStore.webSearchEnabled)
                Text(settingsStore.webSearchEnabled
                     ? "联网搜索已在「AI 处理」中开启。这里单独选择「帮我说」与「翻译帮我说」的搜索积极度；未单独设置时沿用「AI 处理」里的值。"
                     : "联网搜索在「AI 处理」中开启后才会生效（含 DeepSeek API Key）。开启后可在这里单独选择「帮我说」与「翻译帮我说」的搜索积极度；未单独设置时沿用「AI 处理」里的值。")
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
                Text("「帮我说」与「翻译帮我说」由「AI 处理」中当前选中的 Profile 完成（开启「AI 处理」里的联网搜索时改用 DeepSeek），需要已填写 API Key；即使关闭了 AI 文本后处理或选择了原始模式，它仍会调用该模型。生成内容较长，如经常超时，可在 Profile 中调大超时时间。模型调用失败时，是否改用识别原文取决于「AI 失败或超时时回退使用 ASR 原文」。")
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
                Button("检查更新") { Task { await AppContainer.updateWindows.checkAndPresent() } }
            }
        case .checking:
            HStack { ProgressView().controlSize(.small); Text("正在检查更新…").foregroundStyle(.secondary) }
        case .available:
            HStack {
                Text("发现新版本 \(updater.release?.version.description ?? "")").foregroundStyle(.green)
                Spacer()
                Button("查看更新") { AppContainer.updateWindows.present() }.buttonStyle(.borderedProminent)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("正在下载更新… \(Int(progress * 100))%").foregroundStyle(.secondary)
                ProgressView(value: progress)
            }
            .onTapGesture { AppContainer.updateWindows.present() }
        case .readyToInstall:
            HStack { ProgressView().controlSize(.small); Text("更新已就绪，即将重启…").foregroundStyle(.secondary) }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.caption).foregroundStyle(.red)
                HStack {
                    if updater.release != nil { Button("重试") { updater.installUpdate(); AppContainer.updateWindows.present() } }
                    Button("检查更新") { Task { await AppContainer.updateWindows.checkAndPresent() } }
                    Button("手动下载") { updater.openReleasePage() }
                }
            }
        }
    }
}

// MARK: - Per-feature web search eagerness

/// Slider for a feature's own web search eagerness. Untouched, it shows (and follows) the shared value from "AI 处理";
/// moving it sets the feature's own value, and "跟随" returns to following.
private struct WebSearchEagernessOverrideRow: View {
    @Binding var override: Int?
    let shared: Int

    private var value: Int { override ?? shared }
    private var label: String {
        guard let level = WebSearchLevel(eagerness: value) else { return String(localized: "\(value)%（不搜索）") }
        return "\(value)%（\(level.displayName)）"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("搜索积极度")
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)
                if override != nil {
                    Button("恢复为默认 \(shared)%") { override = nil }.buttonStyle(.borderless)
                } else {
                    Text("跟随默认").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Slider(
                value: Binding(get: { Double(value) }, set: { override = Int($0.rounded()) }),
                in: 0...100, step: 5
            )
        }
    }
}

// MARK: - Screen Ask

private struct ScreenAskSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    private var settings: SettingsStore { coordinator.settingsStore }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("屏幕提问") {
                Toggle("启用屏幕提问", isOn: $settings.screenAskEnabled)
                Text("按快捷键后拖动选取屏幕区域，在选区旁输入问题或用语音提问；也可以在默认浏览器中用 Google 或 Bing 搜索所选图片。按 Esc 或再次按快捷键关闭。")
                    .font(.caption).foregroundStyle(.secondary)
                HotkeyRecorderRow(
                    title: "屏幕提问快捷键",
                    hotkey: Binding(get: { settings.screenAskHotkey }, set: { settings.screenAskHotkey = $0 ?? .defaultScreenAsk }),
                    defaultHotkey: .defaultScreenAsk,
                    conflict: {
                        if $0 == settings.hotkey { return String(localized: "与听写快捷键相同，请换一个") }
                        if $0 == settings.translationHotkey { return String(localized: "与翻译快捷键相同，请换一个") }
                        return $0 == settings.writingToolsHotkey ? String(localized: "与书写工具快捷键相同，请换一个") : nil
                    }, coordinator: coordinator
                )
                Picker("图片搜索引擎", selection: $settings.screenAskImageSearchEngine) {
                    ForEach(ImageSearchEngine.allCases, id: \.self) { engine in
                        Text(verbatim: engine.rawValue).tag(engine)
                    }
                }
            }
            Section("AI 模型") {
                Picker("配置（Profile）", selection: $settings.screenAskProfileID) {
                    Text("跟随「AI 处理」当前配置").tag(UUID?.none)
                    ForEach(settings.llmProfiles) { Text($0.name).tag(Optional($0.id)) }
                }
                TextField("Model ID", text: $settings.screenAskModelID,
                          prompt: Text("留空则使用配置里的设置"))
                    .autocorrectionDisabled()
                TextField("推理强度（effort）", text: $settings.screenAskReasoningEffort,
                          prompt: Text("留空则使用配置里的设置，如 low / medium / high"))
                    .autocorrectionDisabled()
                Text("Ask 默认跟随语音「AI 处理」的配置，也可以单独选择配置、模型和 effort。请使用支持图片输入的模型；API Key、Base URL 和 API 格式取自所选配置。语音输入沿用「语音识别」设置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("联网搜索") {
                Picker("联网搜索", selection: $settings.screenAskWebSearchMode) {
                    Text(settings.webSearchEnabled ? "跟随「AI 处理」（当前开启）" : "跟随「AI 处理」（当前关闭）").tag(FeatureOverride.inherit)
                    Text("开启").tag(FeatureOverride.on)
                    Text("关闭").tag(FeatureOverride.off)
                }
                if settings.screenAskWebSearchMode != .off {
                    WebSearchEagernessOverrideRow(override: $settings.screenAskWebSearchEagerness, shared: settings.webSearchEagerness)
                }
                Text("未单独设置时，沿用「AI 处理」里的联网搜索开关和积极度、DeepSeek API Key。联网搜索开启时，屏幕提问改由 DeepSeek（固定模型 deepseek-flash）回答，不使用上面选中的配置；请确认该模型能读取图片，否则选区图片无法被理解。搜索与读取网页由 DeepSeek 服务端完成，会增加耗时并按其联网工具价格另外计费，回答时会显示搜索进度。积极度 0% 等同不搜索。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("隐私与权限") {
                Text("需要屏幕录制权限。选取区域后，只有发送问题时才会将选区图片发送给所选 AI 服务；点击「图片搜索」会将选区图片上传到所选搜索引擎。截图不会保存；问题与回答的文字会记入「历史」（在历史页关闭「保存文字」后只记录统计）。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("打开屏幕录制设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
