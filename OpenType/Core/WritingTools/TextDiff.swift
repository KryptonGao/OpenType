import Foundation

enum DiffSegment: Equatable, Sendable {
    case equal(String)
    case delete(String)
    case insert(String)
}

/// Token-level diff used to show proofreading as inline changes (red deletion, green insertion).
enum TextDiff {
    /// Above this many cells the exact diff is skipped and the differing middle is shown as one replacement.
    static let maxCells = 4_000_000

    static func segments(old: String, new: String) -> [DiffSegment] {
        if old == new { return old.isEmpty ? [] : [.equal(old)] }
        let a = tokens(old)
        let b = tokens(new)

        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }

        var result: [DiffSegment] = []
        func append(_ segment: DiffSegment) {
            switch (result.last, segment) {
            case (.equal(let x)?, .equal(let y)): result[result.count - 1] = .equal(x + y)
            case (.delete(let x)?, .delete(let y)): result[result.count - 1] = .delete(x + y)
            case (.insert(let x)?, .insert(let y)): result[result.count - 1] = .insert(x + y)
            default: result.append(segment)
            }
        }
        if prefix > 0 { append(.equal(a[..<prefix].joined())) }
        let midA = Array(a[prefix..<(a.count - suffix)])
        let midB = Array(b[prefix..<(b.count - suffix)])
        let suffixText = a.suffix(suffix).joined()
        for segment in diffMiddle(midA, midB) { append(segment) }
        if suffix > 0 { append(.equal(suffixText)) }
        return normalised(result)
    }

    /// Number of separate changes (a deletion directly followed by an insertion is one).
    static func changeCount(_ segments: [DiffSegment]) -> Int {
        var count = 0
        var inChange = false
        for segment in segments {
            switch segment {
            case .equal: inChange = false
            case .delete, .insert:
                if !inChange { count += 1 }
                inChange = true
            }
        }
        return count
    }

    /// The text with every change accepted.
    static func newText(_ segments: [DiffSegment]) -> String {
        segments.reduce(into: "") { text, segment in
            switch segment {
            case .equal(let s), .insert(let s): text += s
            case .delete: break
            }
        }
    }

    // MARK: Internals

    /// Within a change, the deletion is listed before the insertion.
    private static func normalised(_ segments: [DiffSegment]) -> [DiffSegment] {
        var result: [DiffSegment] = []
        var deletes = "", inserts = ""
        func flush() {
            if !deletes.isEmpty { result.append(.delete(deletes)) }
            if !inserts.isEmpty { result.append(.insert(inserts)) }
            deletes = ""; inserts = ""
        }
        for segment in segments {
            switch segment {
            case .delete(let s): deletes += s
            case .insert(let s): inserts += s
            case .equal: flush(); result.append(segment)
            }
        }
        flush()
        return result
    }

    private static func diffMiddle(_ a: [String], _ b: [String]) -> [DiffSegment] {
        if a.isEmpty && b.isEmpty { return [] }
        if a.isEmpty { return [.insert(b.joined())] }
        if b.isEmpty { return [.delete(a.joined())] }
        guard a.count * b.count <= maxCells else { return [.delete(a.joined()), .insert(b.joined())] }

        // Longest common subsequence table, filled from the end so the walk below goes forwards.
        let columns = b.count + 1
        var table = [Int32](repeating: 0, count: (a.count + 1) * columns)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i * columns + j] = a[i] == b[j]
                    ? table[(i + 1) * columns + j + 1] + 1
                    : max(table[(i + 1) * columns + j], table[i * columns + j + 1])
            }
        }
        var result: [DiffSegment] = []
        var i = 0, j = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] {
                result.append(.equal(a[i])); i += 1; j += 1
            } else if table[(i + 1) * columns + j] >= table[i * columns + j + 1] {
                result.append(.delete(a[i])); i += 1
            } else {
                result.append(.insert(b[j])); j += 1
            }
        }
        while i < a.count { result.append(.delete(a[i])); i += 1 }
        while j < b.count { result.append(.insert(b[j])); j += 1 }
        return result
    }

    private enum Kind { case ideographic, word, space, other }

    private static func kind(of scalar: Unicode.Scalar) -> Kind {
        if TextMetrics.isIdeographic(scalar) { return .ideographic }
        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return .space }
        if CharacterSet.alphanumerics.contains(scalar) || scalar == "'" || scalar == "’" { return .word }
        return .other
    }

    /// One token per CJK / kana / hangul character, one per run of letters or digits, one per run of whitespace,
    /// one per punctuation mark.
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var currentKind: Kind?
        for scalar in text.unicodeScalars {
            let k = kind(of: scalar)
            if let currentKind, currentKind == k, k == .word || k == .space {
                current.unicodeScalars.append(scalar)
            } else {
                if !current.isEmpty { result.append(current) }
                current = String(scalar)
                currentKind = k
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
