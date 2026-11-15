import AppKit
import SwiftUI

/// The presets tab: prompt presets (edited on the right) and the per-app rules that pick one automatically.
struct PresetsView: View {
    @Bindable var store: PresetStore
    let dictionaryStore: DictionaryStore
    @State private var page: Page = .presets
    @State private var selection: String?
    @State private var pendingDelete: PromptPreset?

    private enum Page: Hashable { case presets, rules }

    private var selectedPreset: PromptPreset? { store.preset(id: selection) ?? store.presets.first }

    var body: some View {
        Group {
            switch page {
            case .presets: presetsPage
            case .rules: AppRulesPage(store: store)
            }
        }
        .navigationTitle("预设")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $page) {
                    Text("预设").tag(Page.presets)
                    Text("应用规则").tag(Page.rules)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if page == .presets {
                ToolbarItem {
                    Menu("新建预设", systemImage: "plus") {
                        ForEach(PresetKind.allCases) { kind in
                            Button(kind.displayName, systemImage: kind.defaultSymbolName) {
                                selection = store.addPreset(kind: kind).id
                            }
                        }
                    }
                }
                ToolbarItem {
                    Button("恢复内置预设", systemImage: "arrow.counterclockwise") { store.restoreBuiltIns() }
                        .help("找回被删除的内置预设；已有的预设不会被改动")
                }
            }
        }
        .confirmationDialog(
            "删除预设“\(pendingDelete?.displayName ?? "")”？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { preset in
            Button("删除", role: .destructive) { store.delete(id: preset.id) }
        } message: { _ in
            Text("指向它的应用规则会一并删除。")
        }
    }

    // MARK: Presets

    private var presetsPage: some View {
        HStack(spacing: 0) {
            presetList.frame(width: 260).frame(maxHeight: .infinity)
            Divider()
            if let preset = selectedPreset {
                PresetEditor(
                    preset: preset, dictionaryStore: dictionaryStore,
                    isDefault: store.defaultPresetID == preset.id,
                    onChange: { store.update($0) },
                    onMakeDefault: { store.setDefaultPreset(preset.id) },
                    onDelete: { pendingDelete = preset },
                    canDelete: store.presets.count > 1
                )
                .id(preset.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var presetList: some View {
        List(selection: Binding(get: { selectedPreset?.id }, set: { selection = $0 })) {
            Section {
                ForEach(store.presets) { preset in
                    HStack {
                        Label {
                            Text(preset.displayName).lineLimit(1)
                        } icon: {
                            Image(systemName: preset.symbolName)
                        }
                        Spacer(minLength: 4)
                        if store.defaultPresetID == preset.id {
                            Text("默认")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .tag(preset.id)
                    .contextMenu {
                        Button("设为默认预设", systemImage: "checkmark.circle") { store.setDefaultPreset(preset.id) }
                        Button("复制", systemImage: "plus.square.on.square") { selection = store.duplicate(preset.id)?.id }
                        Divider()
                        Button("删除", systemImage: "trash", role: .destructive) { pendingDelete = preset }
                            .disabled(store.presets.count <= 1)
                    }
                }
            } footer: {
                Text("默认预设用于没有匹配应用规则的场景，也可以在菜单栏切换。录音时还能在悬浮窗里临时换一个。")
                    .padding(.top, 6)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Preset editor

private struct PresetEditor: View {
    let preset: PromptPreset
    let dictionaryStore: DictionaryStore
    let isDefault: Bool
    let onChange: (PromptPreset) -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    private func binding<Value>(_ keyPath: WritableKeyPath<PromptPreset, Value>) -> Binding<Value> {
        Binding(
            get: { preset[keyPath: keyPath] },
            set: { newValue in
                var copy = preset
                copy[keyPath: keyPath] = newValue
                onChange(copy)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("名称", text: binding(\.name), prompt: Text(preset.displayName))
                Picker("类型", selection: binding(\.kind)) {
                    ForEach(PresetKind.allCases) { Text($0.displayName).tag($0) }
                }
                if let summary = BuiltInPresets.summary(for: preset.id) {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
                kindNote
            } header: {
                HStack {
                    Text("预设")
                    Spacer()
                    if isDefault {
                        Text("当前默认预设").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("设为默认预设", action: onMakeDefault).controlSize(.small)
                    }
                }
            }

            Section {
                promptEditor
            } header: {
                Text("提示词")
            } footer: {
                HStack {
                    Button("填入默认提示词") { fillDefaultPrompt() }
                        .disabled(preset.effectivePrompt == nil || !preset.prompt.isEmpty)
                    Button("恢复默认") {
                        var copy = preset
                        copy.prompt = ""
                        onChange(copy)
                    }
                    .disabled(preset.prompt.isEmpty)
                }
                .controlSize(.small)
                .padding(.top, 4)
            }

            if preset.kind == .cleanup {
                Section("标点") {
                    Toggle("去掉末尾的句号", isOn: binding(\.stripTrailingPeriod))
                    Text("这一项在 AI 处理之后直接改写结果，所以在原始模式或 AI 失败时同样生效。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(dictionaryStore.packs) { pack in
                    Toggle(isOn: Binding(
                        get: { preset.dictionaryPackIDs.contains(pack.id) },
                        set: { isOn in
                            var copy = preset
                            copy.dictionaryPackIDs.removeAll { $0 == pack.id }
                            if isOn { copy.dictionaryPackIDs.append(pack.id) }
                            onChange(copy)
                        }
                    )) {
                        Label(pack.displayName, systemImage: pack.symbolName)
                    }
                }
            } header: {
                Text("启用词库")
            } footer: {
                Text("使用这个预设时，勾选的内置词库即使在词典页里关闭了也会生效。")
            }

            Section {
                Button("删除预设", role: .destructive, action: onDelete).disabled(!canDelete)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var kindNote: some View {
        switch preset.kind {
        case .cleanup:
            EmptyView()
        case .helpMeSay:
            Text("把口述写成完整的成品文字。需要 AI，不受“AI 整理”开关影响；联网搜索沿用「帮我说」设置。")
                .font(.caption).foregroundStyle(.secondary)
        case .shellCommand:
            Text("把需求转成一条命令，写成单行并只插入、不回车，你检查后自己按回车。需要 AI。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var promptEditor: some View {
        TextEditor(text: binding(\.prompt))
            .font(.body.monospaced())
            .frame(minHeight: 150)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if preset.prompt.isEmpty {
                    Text(preset.promptPlaceholder)
                        .font(.body.monospaced())
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }

    private func fillDefaultPrompt() {
        guard let effective = preset.effectivePrompt else { return }
        var copy = preset
        copy.prompt = effective
        onChange(copy)
    }
}

// MARK: - App rules

private struct AppRulesPage: View {
    @Bindable var store: PresetStore
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("按应用自动匹配预设", isOn: $store.autoMatchEnabled)
                Text("开始录音时，OpenType 会看当前所在的应用，并使用它对应的预设；没有规则的应用使用默认预设。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()

            List {
                Section("应用规则") {
                    if store.rules.isEmpty {
                        Text("还没有应用规则。点击右上角的“添加应用”，从“应用程序”文件夹里选择 App，再为它挑一个预设。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(store.rules.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }) { rule in
                        RuleRow(rule: rule, store: store)
                    }
                }
            }
            .listStyle(.inset)
            .opacity(store.autoMatchEnabled ? 1 : 0.5)
        }
        .toolbar {
            ToolbarItem {
                Button("添加应用", systemImage: "plus") { chooseApps() }
                    .help("从“应用程序”文件夹里选择要添加的 App，可一次选多个")
            }
            ToolbarItem {
                Button("移除全部", systemImage: "trash") { confirmClear = true }
                    .disabled(store.rules.isEmpty)
            }
        }
        .confirmationDialog("移除全部应用规则？", isPresented: $confirmClear) {
            Button("移除全部", role: .destructive) { store.removeAllRules() }
        } message: {
            Text("之后所有应用都会使用默认预设，直到你重新添加。")
        }
    }

    /// Lets the user pick any number of apps (the panel opens in /Applications) and gives each a rule.
    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "添加")
        guard panel.runModal() == .OK else { return }
        // Start from a preset that actually changes something: the first one that is not the default.
        let preset = store.presets.first { $0.id != store.defaultPresetID } ?? store.defaultPreset
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier, store.rule(for: id) == nil else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            store.setRule(bundleID: id, appName: name, presetID: preset.id)
        }
    }
}

private struct RuleRow: View {
    let rule: AppRule
    @Bindable var store: PresetStore

    private var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.appName)
                HStack(spacing: 6) {
                    Text(rule.bundleID).lineLimit(1)
                    if icon == nil { Text("未安装") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("预设", selection: Binding(
                get: { rule.presetID },
                set: { store.setRule(bundleID: rule.bundleID, appName: rule.appName, presetID: $0) }
            )) {
                ForEach(store.presets) { Text($0.displayName).tag($0.id) }
            }
            .labelsHidden()
            .fixedSize()
            Button("删除", systemImage: "trash", role: .destructive) { store.removeRule(bundleID: rule.bundleID) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }
}
