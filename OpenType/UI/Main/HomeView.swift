import Charts
import SwiftUI

private enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: "近 7 天"
        case .month: "近 30 天"
        case .quarter: "近 90 天"
        }
    }
}

private enum ChartMetric: String, CaseIterable, Identifiable {
    case tokens = "Token"
    case words = "字数"

    var id: String { rawValue }
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
                header
                if !coordinator.hotkeyActive { permissionBanner }

                section("输入统计") {
                    LazyVGrid(columns: Self.columns, spacing: 12) {
                        StatCard(title: "输入次数", value: stats.range.sessions.formatted(),
                                 caption: "今日 \(stats.today.sessions) · 累计 \(stats.allTime.sessions.formatted())")
                        StatCard(title: "输入字数", value: StatsFormat.compact(stats.range.words),
                                 caption: "今日 \(StatsFormat.compact(stats.today.words)) · 累计 \(StatsFormat.compact(stats.allTime.words))")
                        StatCard(title: "录音时长", value: StatsFormat.duration(stats.range.recordingSeconds),
                                 caption: "累计 \(StatsFormat.duration(stats.allTime.recordingSeconds))")
                        StatCard(title: "平均语速",
                                 value: stats.range.wordsPerMinute.map { "\(Int($0.rounded())) 字/分" } ?? "—",
                                 caption: "累计 " + (stats.allTime.wordsPerMinute.map { "\(Int($0.rounded())) 字/分" } ?? "—"))
                    }
                }

                section("Token 使用量") {
                    LazyVGrid(columns: Self.columns, spacing: 12) {
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
    }

    private static let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenType").font(.largeTitle.bold())
                Text(statusLine).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("统计范围", selection: $range) {
                ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    private var statusLine: String {
        if coordinator.settingsStore.hotkeysPaused { return "全局快捷键已暂停" }
        guard coordinator.hotkeyActive else { return "全局快捷键未启用" }
        return "按 \(coordinator.settingsStore.hotkey.displayName) 开始语音输入"
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("全局快捷键未启用，需要「辅助功能」和「输入监控」权限。")
            Spacer()
            Button("前往授权") { router.tab = .settings }
        }
        .padding(12)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
                    ForEach(ChartMetric.allCases) { Text($0.rawValue).tag($0) }
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
                            .foregroundStyle(by: .value("类型", "输入"))
                        BarMark(x: .value("日期", day.date, unit: .day), y: .value("Token", day.totals.usage.outputTokens))
                            .foregroundStyle(by: .value("类型", "输出"))
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
            .chartForegroundStyleScale(["输入": Color.accentColor, "输出": Color.orange])
            .chartLegend(metric == .tokens ? .visible : .hidden)
            .frame(height: 200)
            .overlay {
                if (metric == .tokens ? stats.range.usage.total : stats.range.words) == 0 {
                    Text("这段时间还没有数据").foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
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
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
