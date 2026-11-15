import SwiftUI

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(text: String, indent: Int)
    case numbered(number: String, text: String, indent: Int)
    case quote(String)
    case code(String)
    case rule
}

/// A small block-level Markdown parser (headings, lists, quotes, fenced code, rules, paragraphs).
/// Inline styling (bold, italics, code, links) is left to `AttributedString(markdown:)` at render time.
enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]?

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        func flushQuote() {
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: " "))) }
            quote = []
        }

        for raw in source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if code != nil {
                if raw.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    blocks.append(.code(code!.joined(separator: "\n")))
                    code = nil
                } else {
                    code!.append(raw)
                }
                continue
            }
            let line = raw.trimmingCharacters(in: .whitespaces)
            let indent = raw.prefix(while: { $0 == " " || $0 == "\t" }).count / 2

            if line.hasPrefix("```") { flushParagraph(); flushQuote(); code = []; continue }
            if line.isEmpty { flushParagraph(); flushQuote(); continue }
            if line.hasPrefix(">") {
                flushParagraph()
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            flushQuote()
            if let heading = headingMatch(line) {
                flushParagraph()
                blocks.append(heading)
            } else if line.count >= 3, line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }), Set(line).count == 1 {
                flushParagraph()
                blocks.append(.rule)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                flushParagraph()
                blocks.append(.bullet(text: String(line.dropFirst(2)), indent: indent))
            } else if let (number, text) = numberedMatch(line) {
                flushParagraph()
                blocks.append(.numbered(number: number, text: text, indent: indent))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        flushQuote()
        if let code { blocks.append(.code(code.joined(separator: "\n"))) }
        return blocks
    }

    private static func headingMatch(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return .heading(level: hashes, text: line.dropFirst(hashes).trimmingCharacters(in: .whitespaces))
    }

    private static func numberedMatch(_ line: String) -> (String, String)? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". ") else { return nil }
        return (String(digits), String(line.dropFirst(digits.count + 2)))
    }
}

/// Renders Markdown text with native SwiftUI views.
struct MarkdownView: View {
    let blocks: [MarkdownBlock]

    init(_ source: String) { blocks = MarkdownParser.parse(source) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level <= 1 ? .title3.bold() : level == 2 ? .headline : .subheadline.bold())
                .padding(.top, level <= 2 ? 4 : 0)
        case .paragraph(let text):
            inline(text)
        case .bullet(let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").foregroundStyle(.secondary)
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 14)
        case .numbered(let number, let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").foregroundStyle(.secondary).monospacedDigit()
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 14)
        case .quote(let text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5).fill(.tertiary).frame(width: 3)
                inline(text).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let text):
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        case .rule:
            Divider()
        }
    }

    private func inline(_ source: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: source, options: options) {
            return Text(attributed)
        }
        return Text(source)
    }
}
