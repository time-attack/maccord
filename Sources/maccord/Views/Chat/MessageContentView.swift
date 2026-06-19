import SwiftUI
import MaccordCore

/// Renders a message body. Splits out fenced code blocks (```lang … ```) and
/// blockquote lines ("> …") as block elements, and runs everything else through
/// the inline `DiscordMarkdown` renderer. Appends an "(edited)" marker.
struct MessageContentView: View {
    let message: Message
    let context: MarkdownContext

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: Block parsing

    struct ListItem {
        let text: String
        let ordered: Bool
        let number: Int
        let indent: Int
    }

    private enum Block {
        case code(language: String?, text: String)
        case quote(String)
        case header(level: Int, text: String)
        case subtext(String)
        case list([ListItem])
        case text(String)
    }

    private var blocks: [Block] {
        Self.parse(message.content)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .code(_, let text):
            codeBlock(text)
        case .quote(let text):
            quoteBlock(text)
        case .header(let level, let text):
            headerBlock(level: level, text)
        case .subtext(let text):
            subtextBlock(text)
        case .list(let items):
            listBlock(items)
        case .text(let text):
            inlineText(text, appendEdited: isLastTextBlock(text))
        }
    }

    // MARK: Renderers

    private func inlineText(_ text: String, appendEdited: Bool) -> some View {
        Group {
            if text.contains("||") {
                SpoilerText(content: text, context: context)
            } else {
                InlineRichText(content: text, context: context, showEdited: appendEdited && message.editedTimestamp != nil)
            }
        }
        .textSelection(.enabled)
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(DiscordFont.codeBlock)
            .foregroundStyle(DiscordColor.textNormal)
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.codeBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(DiscordColor.codeBorder, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 4, style: .continuous))
    }

    private func quoteBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DiscordColor.blockquoteBar)
                .frame(width: 4)
            Text(DiscordMarkdown.attributed(text, context: context))
                .font(DiscordFont.messageBody)
                .foregroundStyle(DiscordColor.textNormal)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Markdown headers (# / ## / ###). Inline markdown inside still resolves; we
    /// override the font size across the whole run for the header weight.
    private func headerBlock(level: Int, _ text: String) -> some View {
        var attr = DiscordMarkdown.attributed(text, context: context)
        attr.font = .system(size: level == 1 ? 24 : level == 2 ? 20 : 17, weight: .bold)
        return Text(attr)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    /// Subtext (-#) — smaller, muted helper text.
    private func subtextBlock(_ text: String) -> some View {
        var attr = DiscordMarkdown.attributed(text, context: context)
        attr.font = .system(size: 13)
        attr.foregroundColor = DiscordColor.textMuted
        return Text(attr)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ordered / unordered lists with indentation.
    private func listBlock(_ items: [ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Text(item.ordered ? "\(item.number)." : "•")
                        .font(DiscordFont.messageBody)
                        .foregroundStyle(DiscordColor.textMuted)
                        .frame(minWidth: 16, alignment: .trailing)
                    Text(DiscordMarkdown.attributed(item.text, context: context))
                        .font(DiscordFont.messageBody)
                        .foregroundStyle(DiscordColor.textNormal)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(item.indent) * 16)
            }
        }
    }

    // MARK: Helpers

    private static let orderedListRegex = try! NSRegularExpression(pattern: #"^(\d+)\.\s+(.*)$"#)

    /// `# `/`## `/`### ` → (1...3); `-# ` → 0 (subtext). nil otherwise.
    private static func headerPrefix(_ line: String) -> (Int, String)? {
        if line.hasPrefix("### ") { return (3, String(line.dropFirst(4))) }
        if line.hasPrefix("## ") { return (2, String(line.dropFirst(3))) }
        if line.hasPrefix("# ") { return (1, String(line.dropFirst(2))) }
        if line.hasPrefix("-# ") { return (0, String(line.dropFirst(3))) }
        return nil
    }

    private static func parseListItem(_ line: String) -> ListItem? {
        let leading = line.prefix { $0 == " " }.count
        let trimmed = String(line.drop { $0 == " " })
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return ListItem(text: String(trimmed.dropFirst(2)), ordered: false, number: 0, indent: leading / 2)
        }
        let ns = trimmed as NSString
        if let m = orderedListRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
            let num = Int(ns.substring(with: m.range(at: 1))) ?? 1
            return ListItem(text: ns.substring(with: m.range(at: 2)), ordered: true, number: num, indent: leading / 2)
        }
        return nil
    }

    private func isLastTextBlock(_ text: String) -> Bool {
        guard case .text(let last)? = blocks.last(where: { if case .text = $0 { return true } else { return false } }) else {
            return false
        }
        return last == text
    }

    /// Split content into ordered blocks. Fenced code blocks take priority; the
    /// remainder is grouped into runs of blockquote ("> ") lines vs plain text.
    private static func parse(_ content: String) -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0
        var textBuffer: [String] = []
        var quoteBuffer: [String] = []
        var listBuffer: [ListItem] = []

        func flushText() {
            if !textBuffer.isEmpty {
                blocks.append(.text(textBuffer.joined(separator: "\n")))
                textBuffer.removeAll()
            }
        }
        func flushQuote() {
            if !quoteBuffer.isEmpty {
                blocks.append(.quote(quoteBuffer.joined(separator: "\n")))
                quoteBuffer.removeAll()
            }
        }
        func flushList() {
            if !listBuffer.isEmpty {
                blocks.append(.list(listBuffer))
                listBuffer.removeAll()
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block start.
            if trimmed.hasPrefix("```") {
                flushText()
                flushQuote()
                flushList()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                var closed = false
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces) == "```" {
                        closed = true
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                let body = codeLines.joined(separator: "\n")
                if closed || !body.isEmpty {
                    blocks.append(.code(language: language.isEmpty ? nil : language, text: body))
                } else {
                    // Unterminated fence with no body — treat as text.
                    textBuffer.append(line)
                }
                continue
            }

            // Headers (#, ##, ###) and subtext (-#) — single-line block elements.
            if let (level, rest) = Self.headerPrefix(line) {
                flushText(); flushQuote(); flushList()
                blocks.append(level == 0 ? .subtext(rest) : .header(level: level, text: rest))
                i += 1
                continue
            }

            // List items (-, *, or "1.") — grouped into one list block.
            if let item = Self.parseListItem(line) {
                flushText(); flushQuote()
                listBuffer.append(item)
                i += 1
                continue
            }

            // Blockquote line.
            if line.hasPrefix("> ") || line == ">" {
                flushText()
                flushList()
                let stripped = line.hasPrefix("> ") ? String(line.dropFirst(2)) : ""
                quoteBuffer.append(stripped)
                i += 1
                continue
            }

            flushQuote()
            flushList()
            textBuffer.append(line)
            i += 1
        }
        flushText()
        flushQuote()
        flushList()

        if blocks.isEmpty { blocks.append(.text(content)) }
        return blocks
    }
}
