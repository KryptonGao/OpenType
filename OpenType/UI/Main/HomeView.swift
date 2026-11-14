import Charts
import SwiftUI

private enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: String(localized: "近 7 天")
        case .month: String(localized: "近 30 天")
        case .quarter: String(localized: "近 90 天")
        }
    }
}

private enum ChartMetric: String, CaseIterable, Identifiable {
    case tokens = "Token"
    case words = "字数"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tokens: "Token"
        case .words: "字数"
        }
    }
}

/// Input statistics and LLM token usage.
struct HomeView: View {
    let coordinator: DictationSessionCoordinator
    let router: MainWindowRouter
    @State private var range: StatsRange = .week
    @State private var metric: ChartMetric = .tokens

    private var history: HistoryStore { coordinator.historyStore }

    var body: some View {
        let stats = UsageStats.summarize(history.records, days: range.rawValue)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusCard

                section("输入统计") {
                    StatGroup {
                        StatCard(title: "输入次数", value: stats.range.sessions.formatted(),
                                 caption: "今日 \(stats.today.sessions) · 累计 \(stats.allTime.sessions.formatted())")
                        StatCard(title: "输入字数", value: StatsFormat.compact(stats.range.words),
                                 caption: "今日 \(StatsFormat.compact(stats.today.words)) · 累计 \(StatsFormat.compact(stats.allTime.words))")
                        StatCard(title: "录音时长", value: StatsFormat.duration(stats.range.recordingSeconds),
                                 caption: "累计 \(StatsFormat.duration(stats.allTime.recordingSeconds))")
                        StatCard(title: "平均语速",
                                 value: stats.range.wordsPerMinute.map { String(localized: "\(Int($0.rounded())) 字/分") } ?? "—",
                                 caption: "累计 \(stats.allTime.wordsPerMinute.map { String(localized: "\(Int($0.rounded())) 字/分") } ?? "—")")
                    }
                }

                section("Token 使用量") {
                    StatGroup {
                        StatCard(title: "总 Token", value: StatsFormat.compact(stats.range.usage.total),
                                 caption: "今日 \(StatsFormat.compact(stats.today.usage.total)) · 累计 \(StatsFormat.compact(stats.allTime.usage.total))")
                        StatCard(title: "输入 Token", value: StatsFormat.compact(stats.range.usage.inputTokens),
                                 caption: "累计 \(StatsFormat.compact(stats.allTime.usage.inputTokens))")
                        StatCard(title: "输出 Token", value: StatsFormat.compact(stats.range.usage.outputTokens),
                                 caption: "累计 \(StatsFormat.compact(stats.allTime.usage.outputTokens))")
                        StatCard(title: "AI 调用", value: stats.range.llmCalls.formatted(),
                                 caption: "累计 \(stats.allTime.llmCalls.formatted()) 次")
                    }
                }

                chartCard(stats)
                if !stats.models.isEmpty { modelsCard(stats) }

                Text("Token 为各 AI 服务返回的用量；未返回用量的服务不计入。语音识别按时长计费，不计 Token。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("首页")
        .toolbar {
            ToolbarItem {
                Picker("统计范围", selection: $range) {
                    ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: Pieces

    /// Hotkey status (and the way to fix it when the hotkey is not active).
    private var statusCard: some View {
        let settings = coordinator.settingsStore
        return HStack(spacing: 14) {
            Image(systemName: coordinator.hotkeyActive ? "mic.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(coordinator.hotkeyActive ? Color.accentColor : .orange, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(coordinator.hotkeyStatusText).font(.headline)
                if coordinator.hotkeyActive {
                    HStack(spacing: 14) {
                        Text("听写：\(settings.hotkey.displayName)")
                        if let translationHotkey = settings.translationHotkey {
                            Text("翻译：\(translationHotkey.displayName)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text("全局快捷键未启用，需要「辅助功能」和「输入监控」权限。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if !coordinator.hotkeyActive {
                Button("前往授权") { router.tab = .settings(.privacy) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func chartCard(_ stats: UsageStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日趋势").font(.headline)
                Spacer()
                Picker("指标", selection: $metric) {
                    ForEach(ChartMetric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }
            Chart {
                ForEach(stats.days) { day in
                    switch metric {
                    case .tokens:
                        BarMark(x: .value("日期", day.date, unit: .day), y: .value("Token", day.totals.usage.inputTokens))
                            .foregroundStyle(by: .value("类型", String(localized: "输入")))
                        BarMark(x: .value("日期", day.date, unit: .day), y: .value("Token", day.totals.usage.outputTokens))
                            .foregroundStyle(by: .value("类型", String(localized: "输出")))
                    case .words:
                        BarMark(x: .value("日期", day.date, unit: .day), y: .value("字数", day.totals.words))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : (range == .month ? 5 : 15))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                }
            }
            .chartForegroundStyleScale([String(localized: "输入"): Color.accentColor, String(localized: "输出"): Color.orange])
            .chartLegend(metric == .tokens ? .visible : .hidden)
            .frame(height: 200)
            .overlay {
                if (metric == .tokens ? stats.range.usage.total : stats.range.words) == 0 {
                    Text("这段时间还没有数据").foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func modelsCard(_ stats: UsageStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按模型").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("模型"); Text("调用").gridColumnAlignment(.trailing)
                    Text("输入").gridColumnAlignment(.trailing); Text("输出").gridColumnAlignment(.trailing)
                    Text("合计").gridColumnAlignment(.trailing)
                }
                .font(.caption).foregroundStyle(.secondary)
                Divider()
                ForEach(stats.models) { row in
                    GridRow {
                        Text(row.model).lineLimit(1).truncationMode(.middle)
                        Text(row.calls.formatted()).monospacedDigit()
                        Text(row.usage.inputTokens.formatted()).monospacedDigit()
                        Text(row.usage.outputTokens.formatted()).monospacedDigit()
                        Text(row.usage.total.formatted()).monospacedDigit().bold()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// One framed row of statistics, separated by hairlines (like a grouped Form row of cells).
private struct StatGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id { Divider().padding(.vertical, 10) }
                    subview
                }
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let caption: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}
