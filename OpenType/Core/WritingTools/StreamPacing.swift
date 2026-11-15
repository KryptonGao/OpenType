import Foundation

/// One piece of a streamed answer as it appeared on screen (it fades in from `revealedAt`).
struct StreamChunk: Identifiable, Equatable, Sendable {
    let id: Int
    var text: String
    var revealedAt: Date
}

/// How a streamed answer is paced on screen. A slow stream is shown as it arrives; when text arrives faster than it
/// can be read comfortably it is released a sentence or a line at a time, never character by character.
enum StreamPacing {
    /// Up to this many characters waiting to be shown are released at once (the stream is slow enough).
    static let slowLimit = 30
    /// Without a sentence end in sight, a backlog longer than this is cut at a clause or a space.
    static let maxWait = 80
    /// A chunk is at least this long, so one-word sentences do not flicker by.
    static let minChunk = 8
    /// How long a revealed chunk takes to fade in.
    static let fadeDuration: TimeInterval = 0.45

    private static let sentenceEnds: Set<Character> = ["\n", "。", "！", "？", "；", "!", "?", ";"]
    private static let clauseEnds: Set<Character> = ["，", "、", "：", ",", ":", " "]

    /// The next piece of `pending` (text received but not shown yet) to show, or `nil` to wait for more text.
    /// `finished`: the stream is over, so whatever is left may be shown.
    static func nextChunk(pending: String, finished: Bool) -> String? {
        guard !pending.isEmpty else { return nil }
        if pending.count <= slowLimit { return pending }

        let characters = Array(pending)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let isEnd = sentenceEnds.contains(character) || (character == "." && isSentenceDot(characters, at: index))
            if isEnd, index + 1 >= minChunk {
                var end = index + 1
                while end < characters.count, characters[end].isWhitespace { end += 1 } // keep the line break with its sentence
                return String(characters[..<end])
            }
            index += 1
        }
        if characters.count > maxWait { // a long run without punctuation
            let limit = min(maxWait, characters.count)
            if let cut = characters[minChunk..<limit].lastIndex(where: { clauseEnds.contains($0) }) {
                return String(characters[...cut])
            }
            return String(characters[..<limit])
        }
        return finished ? pending : nil
    }

    /// Pause before the next release, shorter the more is waiting.
    static func delay(backlog: Int) -> Duration {
        if backlog <= slowLimit { return .milliseconds(30) }
        return backlog > 300 ? .milliseconds(60) : .milliseconds(110)
    }

    /// Opacity of a chunk `age` seconds after it appeared (eased out).
    static func opacity(age: TimeInterval) -> Double {
        let t = min(max(age / fadeDuration, 0), 1)
        return 1 - (1 - t) * (1 - t)
    }

    /// A "." ends a sentence unless it sits inside a number, an abbreviation or a domain ("3.5", "e.g.", "a.com").
    private static func isSentenceDot(_ characters: [Character], at index: Int) -> Bool {
        guard index + 1 < characters.count else { return true }
        return characters[index + 1].isWhitespace
    }
}
