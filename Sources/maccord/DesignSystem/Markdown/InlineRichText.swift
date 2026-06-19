import SwiftUI
import MaccordCore

/// Inline message body that renders custom Discord emoji (`<:name:id>`) as real
/// CDN images mixed with markdown-formatted text.
struct InlineRichText: View {
    let content: String
    let context: MarkdownContext
    var showEdited = false

    private static let emojiRegex = try! NSRegularExpression(pattern: "<(a)?:(\\w+):(\\d+)>")

    enum Segment: Identifiable {
        case text(String)
        case emoji(Emoji)

        var id: String {
            switch self {
            case .text(let s): "t-\(s.hashValue)"
            case .emoji(let e): "e-\(e.reactionKey)"
            }
        }
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: 3) {
            ForEach(segments) { segment in
                switch segment {
                case .text(let text):
                    textView(text)
                case .emoji(let emoji):
                    emojiView(emoji)
                }
            }
            if showEdited {
                Text(" (edited)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DiscordColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textView(_ text: String) -> some View {
        Text(DiscordMarkdown.attributed(text, context: context))
            .font(DiscordFont.messageBody)
            .foregroundStyle(DiscordColor.textNormal)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func emojiView(_ emoji: Emoji) -> some View {
        Group {
            if let url = emoji.imageURL(size: 48) {
                CachedAsyncImage(
                    url: url,
                    content: { $0.resizable().scaledToFit() },
                    placeholder: { Text(":\(emoji.name ?? "emoji"):").font(.system(size: 14)) }
                )
                .frame(width: 22, height: 22)
            } else {
                Text(":\(emoji.name ?? "emoji"):")
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 1)
        .help(emoji.name ?? "")
    }

    private var segments: [Segment] {
        Self.parse(content)
    }

    static func parse(_ content: String) -> [Segment] {
        let ns = content as NSString
        var result: [Segment] = []
        var last = 0
        for match in emojiRegex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > last {
                result.append(.text(ns.substring(with: NSRange(location: last, length: match.range.location - last))))
            }
            let animated = match.range(at: 1).location != NSNotFound
            let name = ns.substring(with: match.range(at: 2))
            let idStr = ns.substring(with: match.range(at: 3))
            if let id = Snowflake(string: idStr) {
                result.append(.emoji(Emoji(id: id, name: name, animated: animated)))
            }
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            result.append(.text(ns.substring(with: NSRange(location: last, length: ns.length - last))))
        }
        if result.isEmpty { result.append(.text(content)) }
        return result
    }
}
