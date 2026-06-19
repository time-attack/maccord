import SwiftUI
import MaccordCore

/// The thin "reply spine" rendered above a replying message: a curved L-shape
/// connector running up from the avatar gutter into a mini-avatar, author name
/// and a truncated quote of the referenced message.
struct ReplyPreviewView: View {
    let reply: Message?
    var onJump: ((Snowflake) -> Void)? = nil

    var body: some View {
        Button {
            if let id = reply?.id { onJump?(id) }
        } label: {
            HStack(alignment: .bottom, spacing: 4) {
            // The spine occupies the avatar gutter so the reply content lines up
            // exactly with the message body below, and the connector starts over
            // the avatar's centre.
            ZStack(alignment: .bottomTrailing) {
                Color.clear.frame(width: Layout.messageLeftGutter, height: 12)
                ReplySpineShape()
                    .stroke(DiscordColor.interactiveMuted, lineWidth: 1.5)
                    .frame(width: Layout.messageLeftGutter - Layout.messageAvatar / 2 - 16, height: 10)
            }
            content
            Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, Layout.messageHGutter)
            .padding(.bottom, 1)
        }
        .buttonStyle(.plain)
        .disabled(reply == nil || onJump == nil)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let reply {
            HStack(spacing: 6) {
                AvatarView(
                    url: reply.author.avatarURL(size: 32),
                    fallbackText: reply.author.displayName,
                    size: 16
                )
                Text(reply.author.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DiscordColor.headerSecondary)
                    .lineLimit(1)
                Text(quote(reply))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DiscordColor.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DiscordColor.textFaint)
                Text("Original message was deleted")
                    .font(.system(size: 13, weight: .regular))
                    .italic()
                    .foregroundStyle(DiscordColor.textFaint)
                    .lineLimit(1)
            }
        }
    }

    private func quote(_ message: Message) -> String {
        if !message.content.isEmpty {
            return message.content.replacingOccurrences(of: "\n", with: " ")
        }
        if !message.attachments.isEmpty { return "Click to see attachment" }
        if !message.embeds.isEmpty { return "Click to see embed" }
        return "Click to jump to message"
    }
}

/// An L-shaped connector: up from bottom-left, rounding into a rightward run.
private struct ReplySpineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius: CGFloat = 8
        let startX = rect.minX
        p.move(to: CGPoint(x: startX, y: rect.maxY))
        p.addLine(to: CGPoint(x: startX, y: rect.minY + radius))
        p.addQuadCurve(
            to: CGPoint(x: startX + radius, y: rect.minY),
            control: CGPoint(x: startX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}
