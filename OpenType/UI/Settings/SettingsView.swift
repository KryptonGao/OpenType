import SwiftUI

struct SettingsView: View {
    let coordinator: DictationSessionCoordinator

    var body: some View {
        TabView {
            GeneralSettingsTab(coordinator: coordinator)
                .tabItem { Label("通用", systemImage: "gearshape") }

            SpeechRecognitionSettingsTab(coordinator: coordinator)
                .tabItem { Label("语音识别", systemImage: "waveform") }

            AIProcessingSettingsTab(coordinator: coordinator)
                .tabItem { Label("AI 处理", systemImage: "sparkles") }

            PrivacyPermissionsSettingsTab(coordinator: coordinator)
                .tabItem { Label("隐私与权限", systemImage: "hand.raised") }
        }
        .frame(width: 600, height: 560)
        .padding()
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    let coordinator: DictationSessionCoordinator
    private var settingsStore: SettingsStore { coordinator.settingsStore }
    @State private var launchAtLogin = false
    @State private var launchError: String?

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
                            launchError = "设置开机启动失败：\(error.localizedDescription)"
                        }
                        launchAtLogin = settingsStore.launchAtLogin
                    }
                ))
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
                Toggle("在 Dock 中显示图标", isOn: $settingsStore.showDockIcon)
            }
            Section("快捷键（按一下开始，再按一下结束）") {
                HotkeyRecorderRow(settingsStore: settingsStore, coordinator: coordinator)
                Toggle("暂停全局快捷键", isOn: $settingsStore.hotkeysPaused)
                Text("短按快捷键开始说话，再短按一次结束，随后自动整理并插入；说话过程中按 Esc 可取消。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("悬浮窗与反馈") {
                Picker("悬浮窗位置", selection: $settingsStore.overlayPosition) {
                    ForEach(OverlayPosition.allCases) { Text($0.displayName).tag($0) }
                }
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
            Section("阿里云百炼（qwen3-asr-flash-realtime）") {
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
                }
                HStack {
                    Button("测试连接") { test() }
                        .disabled(testResult == .running)
                    TestResultView(result: testResult)
                }
            }
            Section("识别") {
                Picker("识别语言", selection: $settingsStore.asrLanguage) {
                    ForEach(ASRLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("断句模式", selection: $settingsStore.asrTurnDetection) {
                    ForEach(ASRTurnDetection.allCases) { Text($0.displayName).tag($0) }
                }
                if settingsStore.asrTurnDetection == .serverVAD {
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
        .formStyle(.grouped)
    }

    private func test() {
        testResult = .running
        Task {
            do {
                try await coordinator.testASRConnection()
                testResult = .success("连接成功")
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
                Picker("推理强度（effort）", selection: profile.reasoningEffort) {
                    ForEach(ReasoningEffort.allCases) { Text($0.displayName).tag($0) }
                }
                Text("仅对支持推理参数的模型有效；选「默认」时不发送该参数。不支持该参数的模型可能返回错误，请改回「默认」。Anthropic 格式下「最低」按 low 发送。")
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
                Text("转写文本会发送到上方配置的 LLM 服务；API Key 仅保存在 macOS Keychain。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settingsStore.activeProfileID) { _, _ in testResult = .idle }
    }

    private func endpointPreview(_ profile: LLMProfile) -> String {
        (try? LLMRequestBuilder.endpoint(format: profile.format, baseURL: profile.baseURL).absoluteString)
            ?? "（Base URL 无效，必须为 https）"
    }

    private func test(_ profile: LLMProfile) {
        testResult = .running
        Task {
            do {
                let output = try await coordinator.testLLMConnection(profile: profile)
                testResult = .success("连接成功，示例输出：\(output)")
            } catch let error as LLMError {
                testResult = .failure(error.userMessage)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
        }
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
                Text("默认不将原始音频或识别记录写入磁盘；临时内容随会话结束释放。")
                Text("语音流发送至阿里云百炼；转写文本发送至所配置的 LLM 服务。API Key 仅存于 Keychain。")
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
        _ title: String, _ detail: String, status: PermissionStatus,
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
