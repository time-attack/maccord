import SwiftUI
import MaccordCore

/// Lists the users who reacted to a message with a particular emoji
/// (`GET /channels/{id}/messages/{mid}/reactions/{emoji}`). Shown from a
/// reaction pill's right-click → "View Reactions".
struct ReactionDetailsPopover: View {
    let channelID: Snowflake
    let messageID: Snowflake
    let emoji: Emoji

    @Environment(AppState.self) private var app
    @State private var users: [User] = []
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                emojiGlyph
                Text("\(users.count) reacted")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
            }
            .padding(10)
            Divider().overlay(DiscordColor.bgTertiary)

            if loading {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                    .frame(height: 80)
            } else if users.isEmpty {
                Text("No one yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(DiscordColor.textMuted)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(users) { user in
                            HStack(spacing: 8) {
                                AvatarView(url: user.avatarURL(size: 32),
                                           fallbackText: user.displayName, size: 24)
                                Text(user.displayName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(DiscordColor.textNormal)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 240, height: 300)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 10, style: .continuous))
        .task {
            users = await app.reactionUsers(channelID: channelID, messageID: messageID, emoji: emoji)
            loading = false
        }
    }

    @ViewBuilder
    private var emojiGlyph: some View {
        if emoji.isCustom, let url = emoji.imageURL(size: 32) {
            CachedAsyncImage(url: url, content: { $0.resizable().scaledToFit() },
                             placeholder: { Color.clear })
                .frame(width: 18, height: 18)
        } else {
            Text(emoji.name ?? "").font(.system(size: 16))
        }
    }
}
