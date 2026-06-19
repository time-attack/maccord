import SwiftUI
import MaccordCore

/// Reaction pills under a message. No "+" affordance on the message itself —
/// add reactions via the hover toolbar or right-click menu only (Discord desktop).
struct ReactionBarView: View {
    @Environment(AppState.self) private var app

    let message: Message

    var body: some View {
        if !message.reactions.isEmpty {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(message.reactions) { reaction in
                    ReactionPill(reaction: reaction) {
                        Task { await app.toggleReaction(messageID: message.id, emoji: reaction.emoji) }
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}

/// The "add a reaction" pill — used only from hover toolbar popover, not inline.
struct AddReactionPill: View {
    let onEmoji: (Emoji) -> Void
    @State private var hovering = false
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 14))
                .foregroundStyle(hovering ? DiscordColor.interactiveHover : DiscordColor.interactiveNormal)
                .padding(.horizontal, 8)
                .frame(height: Layout.reactionPillHeight)
                .background(hovering ? DiscordColor.surfaceHigher : DiscordColor.bgSecondary.opacity(0.6))
                .clipShape(.capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add Reaction")
        .popover(isPresented: $showPicker, arrowEdge: .top) {
            EmojiPickerView { emoji in onEmoji(emoji); showPicker = false }
        }
    }
}

private struct ReactionPill: View {
    let reaction: Reaction
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                emoji
                Text("\(reaction.count)")
                    .font(DiscordFont.reactionCount)
                    .foregroundStyle(reaction.me ? DiscordColor.interactiveActive : DiscordColor.headerSecondary)
            }
            .padding(.horizontal, 7)
            .frame(height: Layout.reactionPillHeight)
            .background(background)
            .overlay {
                Capsule()
                    .strokeBorder(reaction.me ? DiscordColor.blurple : .clear, lineWidth: 1)
            }
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(reaction.emoji.name ?? reaction.emoji.reactionKey)
    }

    @ViewBuilder
    private var emoji: some View {
        if reaction.emoji.isCustom, let url = reaction.emoji.imageURL(size: 32) {
            CachedAsyncImage(
                url: url,
                content: { $0.resizable().scaledToFit() },
                placeholder: { Color.clear }
            )
            .frame(width: 16, height: 16)
        } else {
            Text(reaction.emoji.name ?? "")
                .font(.system(size: 14))
        }
    }

    private var background: Color {
        if reaction.me {
            return DiscordColor.blurple.opacity(0.16)
        }
        return hovering ? DiscordColor.surfaceHigher : DiscordColor.bgSecondary.opacity(0.6)
    }
}
