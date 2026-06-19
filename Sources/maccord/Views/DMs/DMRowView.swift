import SwiftUI
import MaccordCore

/// A single Direct Message row: the conversation's icon (1:1 recipient avatar or
/// group-DM icon) and its computed display name. Highlights on hover/selection.
struct DMRowView: View {
    let channel: Channel
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppState.self) private var app
    @State private var isHovering = false

    private var currentUserID: Snowflake? { app.currentUser?.id }

    private var title: String {
        channel.displayName(currentUserID: currentUserID)
    }

    /// Avatar for the row: the channel icon if present, otherwise the first
    /// recipient's avatar resolved through the user cache.
    private var iconURL: URL? {
        if let url = channel.iconURL(currentUserID: currentUserID, size: 64) {
            return url
        }
        let other = channel.recipients?.first(where: { $0.id != currentUserID })
            ?? channel.recipients?.first
        if let other { return other.avatarURL(size: 64) }
        return nil
    }

    private var subtitle: String? {
        guard channel.type == .groupDM else { return nil }
        let count = channel.recipients?.count ?? 0
        guard count > 0 else { return nil }
        return "\(count) Member\(count == 1 ? "" : "s")"
    }

    private var otherRecipient: User? {
        channel.recipients?.first(where: { $0.id != currentUserID })
    }

    private var background: Color {
        if isSelected { return DiscordColor.channelSelected }
        if isHovering { return DiscordColor.channelHover }
        return .clear
    }

    private var textColor: Color {
        if isSelected { return DiscordColor.interactiveActive }
        if app.readState.isUnread(channel.id) { return DiscordColor.interactiveActive }
        return isHovering ? DiscordColor.interactiveHover : DiscordColor.channelDefault
    }

    private var nameWeight: Font.Weight {
        (isSelected || app.readState.isUnread(channel.id)) ? .semibold : .regular
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AvatarView(
                    url: iconURL,
                    fallbackText: title,
                    size: Layout.listAvatar,
                    dotBorderColor: DiscordColor.bgSecondary
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DiscordFont.channelName.weight(nameWeight))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(DiscordFont.panelSubtext)
                            .foregroundStyle(DiscordColor.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if app.readState.mentionCount(channel.id) > 0 {
                    UnreadBadge(count: app.readState.mentionCount(channel.id))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: Layout.memberRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .overlay(alignment: .trailing) {
            if isHovering {
                Button { Task { await app.closeDM(channel.id) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DiscordColor.interactiveNormal)
                        .padding(6)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(channel.type == .groupDM ? "Leave Group" : "Close DM")
                .padding(.trailing, 12)
            }
        }
        .contextMenu {
            Button { Task { await app.markChannelRead(channel.id) } } label: {
                Label("Mark As Read", systemImage: "envelope.open")
            }
            if channel.type == .dm, let other = otherRecipient {
                Divider()
                if app.isBlocked(other.id) {
                    Button { Task { await app.unblockUser(other.id) } } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                } else {
                    Button(role: .destructive) { Task { await app.blockUser(other.id) } } label: { Label("Block", systemImage: "hand.raised") }
                }
            }
            Divider()
            Button { Clipboard.copy(channel.id.description) } label: { Label("Copy Channel ID", systemImage: "number") }
            Button(role: .destructive) { Task { await app.closeDM(channel.id) } } label: {
                Label(channel.type == .groupDM ? "Leave Group" : "Close DM", systemImage: "xmark")
            }
        }
        .padding(.horizontal, 8)
    }
}
