import SwiftUI
import MaccordCore

/// The 240pt channel sidebar: a server/DM header, the scrollable channel list,
/// and the pinned user panel at the bottom.
public struct ChannelSidebarView: View {
    @Environment(AppState.self) private var app

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if let store = app.selectedGuildStore {
                ServerHeaderView(guild: store.meta)
                ChannelListView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                dmHeader
                // The DM list is provided by another area; placeholder for now.
                VStack {
                    Text("Direct Messages")
                        .font(DiscordFont.channelName)
                        .foregroundStyle(DiscordColor.channelDefault)
                        .padding(.top, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            UserPanelView()
        }
        .frame(width: Layout.channelSidebarWidth)
        .background(DiscordColor.panelSidebar)
    }

    private var dmHeader: some View {
        HStack {
            Text("Direct Messages")
                .font(DiscordFont.serverName)
                .foregroundStyle(DiscordColor.headerPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: Layout.headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DiscordColor.bgTertiary)
                .frame(height: 1)
        }
    }
}
