import Foundation

/// Pure matching logic of the dictionary: which entries a transcript mentions, and the deterministic replacement.
/// Built once per set of entries (it precompiles the regular expressions).
struct DictionaryMatcher {
    static let maxHints = 40
    /// Longest spoken form (in words) that is matched across separators, e.g. "c plus plus".
    private static let maxRun = 5

    private struct Candidate {
        let entry: DictionaryEntry
        /// Squashed ASCII spellings, compared with runs of consecutive transcript words ("open ai" == "openai").
        let asciiForms: Set<String>
        /// Squashed non-ASCII spellings (e.g. Chinese mis-hearings), compared as substrings.
        let substringForms: [String]
    }

    private struct Rule {
        let regex: NSRegularExpression
        let replacement: String
    }

    private let candidates: [Candidate]
    private let rules: [Rule]

    init(entries: [DictionaryEntry]) {
        var candidates: [Candidate] = []
        var rules: [Rule] = []
        var seenRules = Set<String>()
        for entry in entries {
            let term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { continue }
            let spellings = ([term] + entry.aliases).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            var ascii = Set<String>()
            var substrings: [String] = []
            for spelling in spellings {
                let squashed = Self.squash(spelling)
                guard squashed.count >= 2 else { continue }
                if spelling.allSatisfy(\.isASCII) { ascii.insert(squashed) } else { substrings.append(squashed) }
            }
            candidates.append(Candidate(entry: entry, asciiForms: ascii, substringForms: substrings))

            guard entry.autoReplace else { continue }
            for spelling in spellings {
                let key = spelling.lowercased()
                guard seenRules.insert(key).inserted, let regex = Self.makeRegex(for: spelling) else { continue }
                rules.append(Rule(regex: regex, replacement: term))
            }
        }
        self.candidates = candidates
        self.rules = rules
    }

    var isEmpty: Bool { candidates.isEmpty }

    // MARK: Hints for the LLM

    /// Entries the transcript seems to mention (in dictionary order, at most `limit`).
    func hints(for transcript: String, limit: Int = DictionaryMatcher.maxHints) -> [DictionaryEntry] {
        guard !candidates.isEmpty else { return [] }
        let runs = Self.wordRuns(of: transcript)
        let squashedTranscript = Self.squash(transcript)
        var result: [DictionaryEntry] = []
        for candidate in candidates {
            let matched = !candidate.asciiForms.isDisjoint(with: runs)
                || candidate.substringForms.contains { squashedTranscript.contains($0) }
            if matched {
                result.append(candidate.entry)
                if result.count >= limit { break }
            }
        }
        return result
    }

    // MARK: Deterministic replacement

    /// Replaces the term and aliases of every `autoReplace` entry. All matches are found on the original text and
    /// the longest match wins where they overlap, so a replacement is never rewritten again by another rule.
    func correct(_ text: String) -> String {
        guard !rules.isEmpty, !text.isEmpty else { return text }
        let source = text as NSString
        let full = NSRange(location: 0, length: source.length)
        var hits: [(range: NSRange, replacement: String)] = []
        for rule in rules {
            for match in rule.regex.matches(in: text, range: full) where match.range.length > 0 {
                hits.append((match.range, rule.replacement))
            }
        }
        guard !hits.isEmpty else { return text }
        hits.sort { $0.range.location != $1.range.location ? $0.range.location < $1.range.location : $0.range.length > $1.range.length }
        var chosen: [(range: NSRange, replacement: String)] = []
        var end = 0
        for hit in hits where hit.range.location >= end {
            chosen.append(hit)
            end = hit.range.location + hit.range.length
        }
        let result = NSMutableString(string: text)
        for hit in chosen.reversed() {
            result.replaceCharacters(in: hit.range, with: hit.replacement)
        }
        return result as String
    }

    // MARK: Helpers

    /// Lowercased, keeping only letters, digits and the "+" / "#" of names like "C++" and "C#".
    static func squash(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "#" })
    }

    /// Squashed concatenations of up to `maxRun` consecutive ASCII words of the transcript.
    private static func wordRuns(of text: String) -> Set<String> {
        var words: [String] = []
        var current = ""
        for character in text.lowercased() {
            if character.isASCII, character.isLetter || character.isNumber || character == "+" || character == "#" {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        var runs = Set<String>()
        for start in words.indices {
            var joined = ""
            for word in words[start..<min(words.count, start + maxRun)] {
                joined += word
                runs.insert(joined)
            }
        }
        return runs
    }

    /// Case-insensitive pattern for a spelling. Spaces, "-" and "_" match any mix of those (so "open ai" also finds
    /// "OpenAI" and "open-ai"). Pure ASCII spellings must stand alone (no letters or digits right next to them);
    /// non-ASCII spellings are matched as plain text.
    private static func makeRegex(for spelling: String) -> NSRegularExpression? {
        var pattern = ""
        var lastWasSeparator = false
        for character in spelling {
            if character == " " || character == "-" || character == "_" {
                if !lastWasSeparator { pattern += "[\\s\\-_]*" }
                lastWasSeparator = true
            } else {
                pattern += NSRegularExpression.escapedPattern(for: String(character))
                lastWasSeparator = false
            }
        }
        if spelling.allSatisfy(\.isASCII) {
            pattern = "(?<![A-Za-z0-9])" + pattern + "(?![A-Za-z0-9])"
        }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
