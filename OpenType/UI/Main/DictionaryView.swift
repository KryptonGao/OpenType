import SwiftUI

/// The dictionary tab: master switch, built-in packs, custom entries and a searchable list of everything in effect.
struct DictionaryView: View {
    @Bindable var store: DictionaryStore
    @State private var search = ""
    @State private var editor: EditorTarget?

    fileprivate enum EditorTarget: Identifiable {
        case new
        case edit(DictionaryEntry)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let entry): entry.id.uuidString
            }
        }
    }

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ entry: DictionaryEntry) -> Bool {
        guard !query.isEmpty else { return true }
        return entry.term.localizedCaseInsensitiveContains(query)
            || entry.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: 0) {
            packList.frame(width: 290).frame(maxHeight: .infinity)
            Divider()
            entryList.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("词典")
        .searchable(text: $search, prompt: "搜索词条或别名")
        .toolbar { toolbarContent }
        .sheet(item: $editor) { target in
            EntryEditor(target: target.entry) { term, aliases, autoReplace in
                switch target {
                case .new: store.addCustom(term: term, aliases: aliases, autoReplace: autoReplace)
                case .edit(let entry): store.updateCustom(id: entry.id, term: term, aliases: aliases, autoReplace: autoReplace)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Text("生效 \(store.activeEntryCount) 条")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        ToolbarItem {
            Toggle("启用词典", isOn: $store.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("词典会让 AI 按正确写法输出专业术语，并自动替换已设置的常见误识别")
        }
        ToolbarItem {
            Button("添加词条", systemImage: "plus") { editor = .new }
        }
    }

    // MARK: Packs

    private var packList: some View {
        Form {
            Section {
                ForEach(store.packs) { pack in
                    Toggle(isOn: Binding(
                        get: { store.isPackEnabled(pack.id) },
                        set: { store.setPack(pack.id, enabled: $0) }
                    )) {
                        Label {
                            HStack {
                                Text(pack.displayName)
                                Spacer()
                                Text("\(pack.entries.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: pack.symbolName).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("内置词库")
            } footer: {
                Text("只在语音里提到相关词汇时才会提示 AI，不会拖慢或加长每次请求。")
            }
        }
        .formStyle(.grouped)
        .disabled(!store.isEnabled)
    }

    // MARK: Entries

    private var entryList: some View {
        let custom = store.customEntries.filter(matches)
        let packs = store.packs.compactMap { pack -> (DictionaryPack, [DictionaryEntry])? in
            let entries = pack.entries.filter(matches)
            return entries.isEmpty ? nil : (pack, entries)
        }
        return List {
            Section("自定义词条") {
                if store.customEntries.isEmpty {
                    Text("还没有自定义词条。点击「添加词条」，写下正确写法和常被听错的说法，例如 GitHub ← gee hub。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(custom) { entry in
                        EntryRow(entry: entry, showsReplaceBadge: true)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editor = .edit(entry) }
                            .contextMenu {
                                Button("编辑", systemImage: "pencil") { editor = .edit(entry) }
                                Button("删除", systemImage: "trash", role: .destructive) { store.deleteCustom(ids: [entry.id]) }
                            }
                    }
                    .onDelete { offsets in
                        store.deleteCustom(ids: Set(offsets.map { custom[$0].id }))
                    }
                }
            }
            ForEach(packs, id: \.0.id) { pack, entries in
                Section {
                    ForEach(entries) { EntryRow(entry: $0, showsReplaceBadge: false) }
                } header: {
                    HStack {
                        Text(pack.displayName)
                        if !store.isPackEnabled(pack.id) {
                            Text("已关闭").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if !query.isEmpty, custom.isEmpty, packs.isEmpty { ContentUnavailableView.search }
        }
        .opacity(store.isEnabled ? 1 : 0.5)
    }
}

private extension DictionaryView.EditorTarget {
    var entry: DictionaryEntry? {
        if case .edit(let entry) = self { entry } else { nil }
    }
}

private struct EntryRow: View {
    let entry: DictionaryEntry
    let showsReplaceBadge: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.term).font(.body.monospaced())
            if !entry.aliases.isEmpty {
                Text("← " + entry.aliases.joined(separator: "、"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if showsReplaceBadge, entry.autoReplace {
                Text("自动替换")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

private struct EntryEditor: View {
    let target: DictionaryEntry?
    let onSave: (String, [String], Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var aliases = ""
    @State private var autoReplace = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(target == nil ? LocalizedStringKey("添加词条") : LocalizedStringKey("编辑词条")).font(.headline)
            Form {
                TextField("正确写法", text: $term, prompt: Text("例如 GitHub"))
                TextField("常被听成", text: $aliases, prompt: Text("用逗号分隔，例如 gee hub、吉特哈布"))
                Toggle("自动替换", isOn: $autoReplace)
            }
            .formStyle(.columns)
            Text("开启自动替换后，识别结果里出现这些说法时会直接改成正确写法；关闭则只提示 AI 参考。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave(term, DictionaryStore.parseAliases(aliases), autoReplace)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let target {
                term = target.term
                aliases = target.aliases.joined(separator: "、")
                autoReplace = target.autoReplace
            }
        }
    }
}
