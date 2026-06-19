import SwiftUI
import MaccordCore

/// A server-rail folder: a tinted rounded container holding several guild icons,
/// collapsible to a 2×2 preview tile (Discord's folder behaviour).
struct GuildFolderView: View {
    let folder: AppState.GuildFolder

    @Environment(AppState.self) private var app
    @State private var collapsed = true

    private var guilds: [Guild] {
        folder.guildIDs.compactMap { app.guildStores[$0]?.meta }
    }

    private var folderColor: Color {
        folder.color.flatMap { Color(discordColor: $0) } ?? DiscordColor.blurple
    }

    /// Aggregate mention count across the folder's guilds.
    private var mentionCount: Int {
        guilds.reduce(0) { sum, guild in
            let channels = app.guildStores[guild.id].map { Array($0.channels.values) } ?? []
            return sum + app.readState.guildMentionCount(guild, channels: channels)
        }
    }

    /// Whether any contained guild has unread messages.
    private var hasUnread: Bool {
        guilds.contains { guild in
            let channels = app.guildStores[guild.id].map { Array($0.channels.values) } ?? []
            return app.readState.guildHasUnread(guild, channels: channels, excluding: app.selectedChannelID)
        }
    }

    var body: some View {
        VStack(spacing: Layout.serverIconGap) {
            if collapsed {
                collapsedTile
            } else {
                expandedFolder
            }
        }
        .frame(width: Layout.guildRailWidth)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: collapsed)
    }

    // MARK: Collapsed — a 2×2 preview of the folder's guilds

    private var collapsedTile: some View {
        Button {
            collapsed = false
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.iconRadiusIdle, style: .continuous)
                    .fill(folderColor.opacity(0.4))
                LazyVGrid(columns: [GridItem(.fixed(18), spacing: 3), GridItem(.fixed(18), spacing: 3)], spacing: 3) {
                    ForEach(Array(guilds.prefix(4))) { guild in
                        miniIcon(guild)
                    }
                }
            }
            .frame(width: Layout.serverIconSize, height: Layout.serverIconSize)
            .overlay(alignment: .bottomTrailing) {
                if mentionCount > 0 {
                    UnreadBadge(count: mentionCount).offset(x: 2, y: 2)
                } else if hasUnread {
                    UnreadBadge.Dot().offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .help(folder.name ?? "Folder")
    }

    private func miniIcon(_ guild: Guild) -> some View {
        Group {
            if let url = guild.iconURL(size: 48) {
                CachedAsyncImage(url: url, content: { $0.resizable().scaledToFill() },
                                 placeholder: { DiscordColor.bgSecondary })
            } else {
                ZStack {
                    DiscordColor.bgSecondary
                    Text(guild.acronym.prefix(1))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerSecondary)
                }
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(.rect(cornerRadius: 5, style: .continuous))
    }

    // MARK: Expanded — folder header + nested guild icons in a tinted column

    private var expandedFolder: some View {
        VStack(spacing: Layout.serverIconGap) {
            Button {
                collapsed = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Layout.iconCornerActive, style: .continuous)
                        .fill(folderColor.opacity(0.4))
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(folderColor)
                }
                .frame(width: Layout.serverIconSize, height: Layout.serverIconSize)
            }
            .buttonStyle(.plain)
            .help(folder.name ?? "Folder")

            ForEach(guilds) { guild in
                GuildIconView(guild: guild)
            }
        }
        .padding(.vertical, 8)
        .background(
            folderColor.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
