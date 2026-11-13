import Foundation

/// Aggregates Bailian realtime transcription events in utterance order.
///
/// - `...transcription.text` events carry a *snapshot* (`text` + `stash`) for an `item_id`; they replace
///   the previous snapshot instead of being appended.
/// - `...transcription.completed` carries the final `transcript` and replaces the temporary content.
/// - The last `stash` is never treated as a final result.
struct TranscriptAggregator: Equatable, Sendable {
    private struct Item: Equatable, Sendable {
        let id: String
        var text = ""
        var stash = ""
        var completed: String?
    }

    private var items: [Item] = []

    var isEmpty: Bool { items.isEmpty }

    mutating func updatePreview(itemID: String, text: String, stash: String) {
        let index = indexOfItem(itemID)
        guard items[index].completed == nil else { return } // late preview after completion
        items[index].text = text
        items[index].stash = stash
    }

    mutating func complete(itemID: String, transcript: String) {
        let index = indexOfItem(itemID)
        items[index].completed = transcript
        items[index].text = ""
        items[index].stash = ""
    }

    /// Text shown in normal weight: completed utterances + the confirmed `text` part of in-flight ones.
    var solidText: String {
        Self.join(items.map { $0.completed ?? $0.text })
    }

    /// Text shown in light weight: the unstable `stash` of the latest in-flight utterance.
    var stashText: String {
        guard let last = items.last, last.completed == nil else { return "" }
        return last.stash
    }

    /// Final result: only utterances confirmed by `completed` events.
    var finalText: String {
        Self.join(items.compactMap(\.completed))
    }

    /// Fallback used when the session did not finish cleanly: never lose what was already recognised.
    var bestEffortText: String {
        Self.join(items.map { $0.completed ?? ($0.text + $0.stash) })
    }

    private mutating func indexOfItem(_ id: String) -> Int {
        if let index = items.firstIndex(where: { $0.id == id }) { return index }
        items.append(Item(id: id))
        return items.count - 1
    }

    /// Joins utterances; inserts a space only between two latin word characters.
    static func join(_ parts: [String]) -> String {
        var result = ""
        for raw in parts {
            let part = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            if let last = result.unicodeScalars.last, let first = part.unicodeScalars.first,
               needsSpace(between: last, and: first) {
                result += " "
            }
            result += part
        }
        return result
    }

    private static func needsSpace(between a: Unicode.Scalar, and b: Unicode.Scalar) -> Bool {
        func isLatinWordish(_ s: Unicode.Scalar) -> Bool {
            s.isASCII && (CharacterSet.alphanumerics.contains(s) || ".,!?;:".unicodeScalars.contains(s))
        }
        return isLatinWordish(a) && isLatinWordish(b) && CharacterSet.alphanumerics.contains(b)
    }
}
