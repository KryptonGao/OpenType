import Foundation

/// Aggregated numbers for the home page. Pure function of the records, so it is unit-tested.
struct UsageStats: Equatable, Sendable {
    struct Totals: Equatable, Sendable {
        var sessions = 0
        var words = 0
        var recordingSeconds = 0.0
        var usage = TokenUsage.zero
        /// Sessions that actually called an LLM.
        var llmCalls = 0

        /// Words per minute of recording; nil until there is something to divide.
        var wordsPerMinute: Double? {
            recordingSeconds >= 1 ? Double(words) / (recordingSeconds / 60) : nil
        }

        fileprivate mutating func add(_ record: SessionRecord) {
            sessions += 1
            words += record.wordCount
            recordingSeconds += record.recordingSeconds
            usage += record.usage
            if !record.usage.isEmpty { llmCalls += 1 }
        }
    }

    struct Day: Equatable, Identifiable, Sendable {
        var date: Date
        var totals = Totals()
        var id: Date { date }
    }

    struct ModelRow: Equatable, Identifiable, Sendable {
        var model: String
        var calls: Int
        var usage: TokenUsage
        var id: String { model }
    }

    /// Records inside the selected range.
    var range = Totals()
    /// Everything ever recorded.
    var allTime = Totals()
    var today = Totals()
    /// One entry per calendar day of the range (oldest first), including days without activity.
    var days: [Day] = []
    /// Token usage per model within the range, most used first.
    var models: [ModelRow] = []

    /// `days`: how many trailing calendar days (including today) the range covers.
    static func summarize(_ records: [SessionRecord], days dayCount: Int, now: Date = .now, calendar: Calendar = .current) -> UsageStats {
        var stats = UsageStats()
        let startOfToday = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -(max(dayCount, 1) - 1), to: startOfToday) ?? startOfToday
        stats.days = (0..<max(dayCount, 1)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: first).map { Day(date: $0) }
        }
        var models: [String: ModelRow] = [:]

        for record in records {
            stats.allTime.add(record)
            let day = calendar.startOfDay(for: record.date)
            if day == startOfToday { stats.today.add(record) }
            guard day >= first, day <= startOfToday else { continue }
            stats.range.add(record)
            if let index = stats.days.firstIndex(where: { $0.date == day }) { stats.days[index].totals.add(record) }
            if let model = record.model, !record.usage.isEmpty {
                var row = models[model] ?? ModelRow(model: model, calls: 0, usage: .zero)
                row.calls += 1
                row.usage += record.usage
                models[model] = row
            }
        }
        stats.models = models.values.sorted { $0.usage.total > $1.usage.total }
        return stats
    }
}

enum StatsFormat {
    /// 1 234 → "1,234"; 12 345 → "1.2 万"; 123 456 789 → "1.2 亿".
    static func compact(_ value: Int) -> String {
        switch value {
        case ..<10_000: value.formatted(.number)
        case ..<100_000_000: (Double(value) / 10_000).formatted(.number.precision(.fractionLength(0...1))) + " 万"
        default: (Double(value) / 100_000_000).formatted(.number.precision(.fractionLength(0...2))) + " 亿"
        }
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) 秒" }
        let minutes = total / 60
        if minutes < 60 { return "\(minutes) 分 \(total % 60) 秒" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }
}
