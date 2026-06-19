import SwiftUI
import MaccordCore

/// A single 48×48 guild icon in the server rail. Shows the guild's CDN icon (or
/// an acronym fallback tile), morphs from squircle to circle on hover/selection,
/// carries a leading selection pill, and overlays a mention badge / unread dot.
struct GuildIconView: View {
    let guild: Guild

    @Environment(AppState.self) private var app
    @State private var isHovering = false

    private var isSelected: Bool { app.selectedGuildID == guild.id }
    private var isActive: Bool { isSelected || isHovering }

    /// The guild's channels, drawn from the live store when hydrated, otherwise
    /// the normalized cache filtered by guild.
    private var guildChannels: [Channel] {
        if let store = app.guildStores[guild.id] {
            return Array(store.channels.values)
        }
        return app.channelsByID.values.filter { $0.guildID == guild.id }
    }

    private var mentionCount: Int {
        app.readState.guildMentionCount(guild, channels: guildChannels)
    }

    private var hasUnread: Bool {
        app.readState.guildHasUnread(guild, channels: guildChannels, excluding: app.selectedChannelID)
    }

    private var pillState: SelectionPill.PillState {
        if isSelected { return .selected }
        if isHovering { return .hovered }
        if hasUnread { return .unread }
        return .hidden
    }

    var body: some View {
        HStack(spacing: 0) {
            SelectionPill(state: pillState)
                .frame(width: Layout.pillWidth)

            Spacer(minLength: 0)

            Button {
                app.selectGuild(guild.id)
            } label: {
                tile
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            .discordTooltip(guild.name)
            .contextMenu { serverContextMenu }

            Spacer(minLength: 0)
        }
        .frame(width: Layout.guildRailWidth, height: Layout.serverIconSize)
    }

    @ViewBuilder
    private var serverContextMenu: some View {
        Button { Task { await app.markGuildRead(guild.id) } } label: {
            Label("Mark As Read", systemImage: "envelope.open")
        }
        Button { Task { if let url = await app.createInvite(forGuild: guild.id) { Clipboard.copy(url) } } } label: {
            Label("Invite People", systemImage: "person.crop.circle.badge.plus")
        }
        Divider()
        Button { app.notificationSettingsGuildID = guild.id } label: {
            Label("Notification Settings", systemImage: "bell.fill")
        }
        Button { app.toggleGuildMute(guild.id) } label: {
            Label(app.mutedGuilds.contains(guild.id) ? "Unmute Server" : "Mute Server",
                  systemImage: app.mutedGuilds.contains(guild.id) ? "bell" : "bell.slash")
        }
        if app.canManageGuild(guild.id) {
            Divider()
            Button { app.serverSettingsGuildID = guild.id } label: {
                Label("Server Settings", systemImage: "gearshape")
            }
        }
        Button { Clipboard.copy(guild.id.description) } label: {
            Label("Copy Server ID", systemImage: "number")
        }
        if guild.ownerID != app.currentUser?.id {
            Divider()
            Button(role: .destructive) { Task { await app.leaveGuild(guild.id) } } label: {
                Label("Leave Server", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var tile: some View {
        let shape = RoundedRectangle(
            cornerRadius: isActive ? Layout.iconCornerActive : Layout.iconRadiusIdle,
            style: .continuous
        )
        return iconContent
            .frame(width: Layout.serverIconSize, height: Layout.serverIconSize)
            .clipShape(shape)
            .opacity(app.mutedGuilds.contains(guild.id) && !isSelected ? 0.4 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
            .overlay(alignment: .bottomTrailing) {
                if mentionCount > 0 {
                    UnreadBadge(count: mentionCount)
                        .offset(x: 2, y: 2)
                }
            }
    }

    @ViewBuilder
    private var iconContent: some View {
        if let url = guild.iconURL(size: 96) {
            CachedAsyncImage(
                url: url,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: { fallbackTile }
            )
        } else {
            fallbackTile
        }
    }

    private var fallbackTile: some View {
        ZStack {
            (isActive ? DiscordColor.blurple : DiscordColor.bgSecondary)
            Text(guild.acronym)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? .white : DiscordColor.headerSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(4)
        }
    }
}
