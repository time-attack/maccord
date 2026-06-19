import SwiftUI
import MaccordCore

/// A text-like channel row (#text, announcement, forum). Renders the leading
/// type glyph, the channel name, hover/selected backgrounds, an unread "dot"
/// pill on the left edge, and a trailing mention badge.
struct ChannelRowView: View {
    let channel: Channel
    let isSelected: Bool
    let isUnread: Bool
    let mentionCount: Int
    let action: () -> Void

    @State private var isHovering = false

    /// The selected channel is, by definition, read — never style it as unread.
    private var effectiveUnread: Bool { isUnread && !isSelected }

    private var iconName: String {
        switch channel.type {
        case .announcement, .announcementThread: "megaphone.fill"
        case .forum, .media: "doc.text"
        default: "number"
        }
    }

    /// Selected, unread, or hovered rows brighten the channel name; otherwise muted.
    private var nameColor: Color {
        if isSelected { return DiscordColor.interactiveActive }
        if effectiveUnread { return DiscordColor.interactiveActive }
        if isHovering { return DiscordColor.interactiveHover }
        return DiscordColor.channelDefault
    }

    private var nameWeight: Font.Weight {
        (isSelected || effectiveUnread) ? .medium : .regular
    }

    private var rowBackground: Color {
        if isSelected { return DiscordColor.channelSelected }
        if isHovering { return DiscordColor.channelHover }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isSelected || effectiveUnread ? DiscordColor.interactiveActive : DiscordColor.channelIcon)
                    .frame(width: 20, alignment: .center)
                Text(channel.name ?? channel.displayName(currentUserID: nil))
                    .font(.system(size: 15, weight: nameWeight))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if mentionCount > 0 {
                    UnreadBadge(count: mentionCount)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: Layout.channelRowHeight)
            .background(rowBackground)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .opacity(app.isChannelMuted(channel.id) && !isSelected ? 0.45 : 1)
        .contextMenu {
            Button { Task { await app.markChannelRead(channel.id) } } label: {
                Label("Mark As Read", systemImage: "envelope.open")
            }
            Button { app.markChannelUnread(channel.id) } label: {
                Label("Mark As Unread", systemImage: "envelope.badge")
            }
            Menu {
                Button { app.muteChannel(channel.id, duration: 3600) } label: { Label("For 1 Hour", systemImage: "clock") }
                Button { app.muteChannel(channel.id, duration: 28800) } label: { Label("For 8 Hours", systemImage: "clock") }
                Button { app.muteChannel(channel.id, duration: nil) } label: { Label("Until I Turn It Back On", systemImage: "bell.slash") }
            } label: {
                Label("Mute Channel", systemImage: "bell.slash")
            }
            if app.isChannelMuted(channel.id) {
                Button { app.unmuteChannel(channel.id) } label: { Label("Unmute Channel", systemImage: "bell") }
            }
            if let gid = channel.guildID {
                Button { app.notificationSettingsGuildID = gid } label: {
                    Label("Notification Settings", systemImage: "bell.badge")
                }
                Button {
                    Task { if let url = await app.createChannelInvite(channel.id) { Clipboard.copy(url) } }
                } label: {
                    Label("Invite People", systemImage: "person.crop.circle.badge.plus")
                }
            }
            Divider()
            Button { Clipboard.copy(app.channelLink(channel)) } label: { Label("Copy Link", systemImage: "link") }
            Button { Clipboard.copy(channel.id.description) } label: { Label("Copy Channel ID", systemImage: "number") }
        }
        .help(channel.topic ?? "")
    }

    @Environment(AppState.self) private var app
}
