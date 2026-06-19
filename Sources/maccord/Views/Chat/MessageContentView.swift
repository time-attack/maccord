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

    private enum Block {
        case code(language: String?, text: String)
        case quote(String)
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

    // MARK: Helpers

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

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block start.
            if trimmed.hasPrefix("```") {
                flushText()
                flushQuote()
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

            // Blockquote line.
            if line.hasPrefix("> ") || line == ">" {
                flushText()
                let stripped = line.hasPrefix("> ") ? String(line.dropFirst(2)) : ""
                quoteBuffer.append(stripped)
                i += 1
                continue
            }

            flushQuote()
            textBuffer.append(line)
            i += 1
        }
        flushText()
        flushQuote()

        if blocks.isEmpty { blocks.append(.text(content)) }
        return blocks
    }
}
