import SwiftUI
import MaccordCore

/// The leftmost 72pt column: the Discord server rail. A scrollable stack of the
/// Home/DM button, a divider, and one icon per guild on the tertiary background.
public struct GuildRailView: View {
    @Environment(AppState.self) private var app
    @State private var showJoin = false

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Layout.serverIconGap) {
                HomeButton(isSelected: app.selectedGuildID == nil) {
                    app.selectGuild(nil)
                }

                divider

                if app.guildFolders.isEmpty {
                    ForEach(app.orderedGuilds) { guild in
                        GuildIconView(guild: guild)
                    }
                } else {
                    ForEach(app.guildFolders) { folder in
                        if folder.isRealFolder {
                            GuildFolderView(folder: folder)
                        } else if let id = folder.guildIDs.first,
                                  let guild = app.guildStores[id]?.meta {
                            GuildIconView(guild: guild)
                        }
                    }
                }

                addServerButton
            }
            // Top inset clears the traffic-light controls (the window uses a hidden
            // title bar for an immersive, Discord-like look).
            .padding(.top, 30)
            .padding(.bottom, 12)
        }
        .frame(width: Layout.guildRailWidth)
        .frame(maxHeight: .infinity)
        .background(DiscordColor.panelRail)
        .sheet(isPresented: $showJoin) { JoinServerView() }
    }

    private var addServerButton: some View {
        Button { showJoin = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DiscordColor.green)
                .frame(width: Layout.serverIconSize, height: Layout.serverIconSize)
                .background(DiscordColor.bgSecondaryAlt, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Add a Server")
        .padding(.top, 4)
    }

    private var divider: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(DiscordColor.divider)
            .frame(width: 32, height: 2)
            .padding(.vertical, 4)
    }
}
