import SwiftUI
import MaccordCore

/// Click-to-reveal spoiler spans (`||like this||`).
struct SpoilerText: View {
    let content: String
    let context: MarkdownContext

    @State private var revealed = false

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: 3) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .plain(let text):
                    Text(DiscordMarkdown.attributed(text, context: context))
                        .font(DiscordFont.messageBody)
                case .spoiler(let text):
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) { revealed = true }
                    } label: {
                        Text(revealed ? text : String(repeating: "•", count: max(4, min(text.count, 24))))
                            .font(DiscordFont.messageBody)
                            .foregroundStyle(revealed ? DiscordColor.textNormal : DiscordColor.spoiler)
                            .padding(.horizontal, revealed ? 0 : 4)
                            .padding(.vertical, revealed ? 0 : 1)
                            .background(revealed ? Color.clear : DiscordColor.spoiler)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(revealed)
                }
            }
        }
    }

    private enum Segment {
        case plain(String)
        case spoiler(String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var i = content.startIndex
        while i < content.endIndex {
            if content[i...].hasPrefix("||"),
               let close = content[i...].dropFirst(2).range(of: "||") {
                let inner = String(content[i..<close.lowerBound].dropFirst(2))
                result.append(.spoiler(inner))
                i = close.upperBound
            } else {
                var j = i
                while j < content.endIndex, !content[j...].hasPrefix("||") {
                    j = content.index(after: j)
                }
                result.append(.plain(String(content[i..<j])))
                i = j
            }
        }
        return result
    }
}
