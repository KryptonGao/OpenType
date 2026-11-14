import AppKit
import SwiftUI

/// Local history of finished sessions: list on the left, full text on the right.
struct HistoryView: View {
    let coordinator: DictationSessionCoordinator
    @State private var selection: UUID?
    @State private var search = ""
    @State private var kindFilter: SessionKind?
    @State private var confirmClear = false

    private var history: HistoryStore { coordinator.historyStore }
    private var settings: SettingsStore { coordinator.settingsStore }

    private var filtered: [SessionRecord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return history.records.filter { record in
            if let kindFilter, record.kind != kindFilter { return false }
            guard !query.isEmpty else { return true }
            return [record.finalText, record.rawText, record.model, record.translationLabel]
                .contains { $0?.localizedCaseInsensitiveContains(query) == true }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if history.records.isEmpty {
                ContentUnavailableView {
                    Label("还没有历史记录", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(settings.saveHistoryText
                         ? "完成一次语音输入后，会出现在这里。"
                         : "当前未保存识别文字，开启上方的「保存文字」后，新的输入会出现在这里。")
                }
            } else {
                // Plain HStack: HSplitView mis-sizes a List vertically (content sinks to the bottom).
                HStack(spacing: 0) {
                    list.frame(width: 320).frame(maxHeight: .infinity)
                    Divider()
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .confirmationDialog("清空历史记录？", isPresented: $confirmClear) {
            Button("仅清除文字（保留统计）", role: .destructive) { history.clearTexts() }
            Button("清除全部记录与统计", role: .destructive) { history.clearAll(); selection = nil }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。")
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("搜索", text: $search, prompt: Text("搜索文字或模型"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            Picker("类型", selection: $kindFilter) {
                Text("全部").tag(SessionKind?.none)
                ForEach(SessionKind.allCases) { Text($0.displayName).tag(SessionKind?.some($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            Spacer()
            Toggle("保存文字", isOn: Bindable(settings).saveHistoryText)
                .toggleStyle(.switch)
                .help("关闭后只记录次数、字数、Token 等统计，不再保存识别和整理后的文字")
            Button("清空…", systemImage: "trash") { confirmClear = true }
                .disabled(history.records.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: List

    private var list: some View {
        List(selection: $selection) {
            ForEach(groupedByDay, id: \.day) { group in
                Section(Self.dayTitle(group.day)) {
                    ForEach(group.records) { record in
                        HistoryRow(record: record)
                            .tag(record.id)
                            .contextMenu {
                                Button("复制", systemImage: "doc.on.doc") { copy(record) }
                                    .disabled(record.finalText == nil)
                                Button("删除", systemImage: "trash", role: .destructive) { remove(record) }
                            }
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if filtered.isEmpty { ContentUnavailableView.search }
        }
        .onDeleteCommand {
            if let selection, let record = history.records.first(where: { $0.id == selection }) { remove(record) }
        }
    }

    private var groupedByDay: [(day: Date, records: [SessionRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "今天") }
        if calendar.isDateInYesterday(day) { return String(localized: "昨天") }
        return day.formatted(.dateTime.year().month().day())
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let selection, let record = history.records.first(where: { $0.id == selection }) {
            HistoryDetail(record: record, copy: { copy(record) }, delete: { remove(record) })
        } else {
            ContentUnavailableView("选择一条记录", systemImage: "text.alignleft")
        }
    }

    private func copy(_ record: SessionRecord) {
        guard let text = record.finalText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func remove(_ record: SessionRecord) {
        if selection == record.id { selection = nil }
        history.delete(ids: [record.id])
    }
}

private struct HistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.kind.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.finalText ?? String(localized: "（未保存文字）"))
                    .lineLimit(2)
                    .foregroundStyle(record.finalText == nil ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(record.date.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    Text("\(record.wordCount) 字")
                    if record.delivery == .manualCopy { Text("· 未自动插入") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct HistoryDetail: View {
    let record: SessionRecord
    let copy: () -> Void
    let delete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(kindTitle, systemImage: record.kind.symbolName).font(.headline)
                    Spacer()
                    Button("复制", systemImage: "doc.on.doc", action: copy).disabled(record.finalText == nil)
                    Button("删除", systemImage: "trash", role: .destructive, action: delete)
                }

                if let final = record.finalText {
                    block("结果", final)
                    if let raw = record.rawText, raw != final { block("识别原文", raw, secondary: true) }
                } else {
                    Text("这条记录没有保存文字（保存文字开关关闭时产生）。").foregroundStyle(.secondary)
                }

                Divider()
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    meta("时间", record.date.formatted(date: .abbreviated, time: .standard))
                    meta("字数", "\(record.wordCount)")
                    meta("录音时长", StatsFormat.duration(record.recordingSeconds))
                    meta("去向", record.delivery == .inserted ? String(localized: "已插入光标处") : String(localized: "需手动复制"))
                    if let model = record.model { meta("模型", model) }
                    if !record.usage.isEmpty {
                        meta("Token", String(localized: "输入 \(record.usage.inputTokens.formatted()) · 输出 \(record.usage.outputTokens.formatted()) · 合计 \(record.usage.total.formatted())"))
                    }
                }
                .font(.callout)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var kindTitle: String {
        if let label = record.translationLabel { return "\(record.kind.displayName) → \(label)" }
        return record.kind.displayName
    }

    private func block(_ title: LocalizedStringKey, _ text: String, secondary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(text)
                .textSelection(.enabled)
                .foregroundStyle(secondary ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func meta(_ name: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}
