import SwiftUI
import MaccordCore

/// The scrollable list of categories and channels for the selected guild.
/// Categories are collapsible (local state); rows reflect selection, unread and
/// mention state from `AppState`.
struct ChannelListView: View {
    let store: GuildStore

    @Environment(AppState.self) private var app
    @State private var collapsed: Set<Snowflake> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(store.channelTree(myRoleIDs: app.myRoleIDs(in: store.id),
                                          myUserID: app.currentUser?.id)) { node in
                    section(node)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)   // Discord-style: no chunky scrollbar in the list
    }

    @ViewBuilder
    private func section(_ node: ChannelTreeNode) -> some View {
        if let category = node.category {
            CategoryHeaderView(
                name: category.name ?? "",
                isCollapsed: collapsed.contains(category.id),
                toggle: { toggle(category.id) }
            )
            if !collapsed.contains(category.id) {
                ForEach(node.channels) { channel in
                    row(channel)
                }
            }
        } else {
            ForEach(node.channels) { channel in
                row(channel)
            }
        }
    }

    @ViewBuilder
    private func row(_ channel: Channel) -> some View {
        if channel.type.isVoice {
            VoiceChannelRowView(
                channel: channel,
                isSelected: app.selectedChannelID == channel.id,
                action: { select(channel.id) }
            )
        } else {
            ChannelRowView(
                channel: channel,
                isSelected: app.selectedChannelID == channel.id,
                isUnread: app.readState.isUnread(channel.id),
                mentionCount: app.readState.mentionCount(channel.id),
                action: { select(channel.id) }
            )
        }
    }

    private func toggle(_ id: Snowflake) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }

    private func select(_ id: Snowflake) {
        Task { await app.selectChannel(id) }
    }
}
