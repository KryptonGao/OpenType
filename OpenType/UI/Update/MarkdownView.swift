import AppKit
import SwiftStreamingMarkdown
import SwiftUI

/// Renders Markdown with Microsoft's SwiftStreamingMarkdown (swift-markdown / cmark-gfm underneath): headings, lists,
/// quotes, code with syntax highlighting, tables, and LaTeX (`\( … \)` inline, `$$ … $$` and `\[ … \]` as blocks).
/// Used for the release notes and for everything a model answers.
struct MarkdownContent: View {
    let source: String
    var fontSize: CGFloat = 13
    /// While a reply is still arriving: newly added text fades in.
    var animatesNewText = false

    init(_ source: String, fontSize: CGFloat = 13, animatesNewText: Bool = false) {
        self.source = source
        self.fontSize = fontSize
        self.animatesNewText = animatesNewText
    }

    var body: some View {
        SwiftStreamingMarkdown.MarkdownView(
            text: source,
            config: .openType(fontSize: fontSize, animatesText: animatesNewText)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MarkdownRenderConfig {
    /// Compact panel styling: system fonts at `fontSize`, tight block spacing, hairline table borders, no "select more
    /// text" menu entry.
    static func openType(fontSize: CGFloat, animatesText: Bool) -> MarkdownRenderConfig {
        let label = Color(nsColor: .labelColor)
        let secondary = Color(nsColor: .secondaryLabelColor)
        let hairline = label.opacity(0.18)
        let tint = label.opacity(0.07)

        func fonts(_ size: CGFloat, weight: NSFont.Weight = .regular) -> TextFonts {
            let normal = NSFont.systemFont(ofSize: size, weight: weight)
            let bold = NSFont.systemFont(ofSize: size, weight: .bold)
            let manager = NSFontManager.shared
            return TextFonts(
                normal: normal,
                italic: manager.convert(normal, toHaveTrait: .italicFontMask),
                bold: bold,
                boldItalic: manager.convert(bold, toHaveTrait: .italicFontMask),
                preferredLetterSpacing: 0,
                preferredLineHeight: (size * 1.55).rounded()
            )
        }

        let body = fonts(fontSize)
        let mono = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
        return MarkdownRenderConfig(
            shouldAnimateText: animatesText,
            blockQuoteStyle: .init(textFonts: body, textColor: secondary),
            headingStyle: .init(
                h1Font: fonts(fontSize + 4, weight: .bold),
                h2Font: fonts(fontSize + 2, weight: .bold),
                h3Font: fonts(fontSize, weight: .bold),
                h4Font: fonts(fontSize, weight: .semibold),
                h5Font: fonts(fontSize, weight: .semibold),
                h6Font: fonts(fontSize, weight: .semibold),
                textColor: label
            ),
            orderedListStyle: .init(textFonts: body, textColor: label),
            paragraphStyle: .init(textFonts: body, textColor: label),
            tableStyle: .init(
                textFonts: fonts(fontSize - 1),
                headerTextColor: label,
                regularTextColor: label,
                headerBackgroundColor: tint,
                borderColor: hairline,
                actionButtonColor: secondary
            ),
            inlineStyle: .init(
                boldTextColor: label,
                linkTextFont: body.normal,
                linkTextColor: .accentColor,
                codeTextFont: mono,
                codeTextColor: label,
                codeBackgroundColor: tint,
                codeUnderlineColor: .clear
            ),
            codeBlockConfig: .init(theme: .github, backgroundColor: tint, foregroundColor: secondary),
            blockSpacing: 8,
            textSelectionConfig: .init(isEnabled: false),
            thematicBreakColor: hairline
        )
    }
}
