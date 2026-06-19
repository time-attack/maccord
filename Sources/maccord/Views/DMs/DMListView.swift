import SwiftUI
import MaccordCore

/// The Home sidebar: a Friends nav row + the user's DM list.
public struct DMListView: View {
    @Environment(AppState.self) private var app

    public init() {}

    private var friendsSelected: Bool {
        app.selectedGuildID == nil && app.selectedChannelID == nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    friendsRow

                    if app.incomingFriendRequests.count > 0 {
                        HStack(spacing: 6) {
                            Text("Friend Requests")
                                .font(.system(size: 11, weight: .bold)).tracking(0.3)
                                .foregroundStyle(DiscordColor.headerSecondary)
                            UnreadBadge(count: app.incomingFriendRequests.count)
                        }
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                    }

                    Text("Direct Messages")
                        .font(.system(size: 11, weight: .bold)).tracking(0.3)
                        .foregroundStyle(DiscordColor.headerSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(app.dms) { dm in
                        DMRowView(
                            channel: dm,
                            isSelected: app.selectedChannelID == dm.id && app.selectedGuildID == nil
                        ) {
                            select(dm)
                        }
                    }

                    if app.dms.isEmpty {
                        Text("No direct messages yet")
                            .font(DiscordFont.replyPreview)
                            .foregroundStyle(DiscordColor.textFaint)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(width: Layout.channelSidebarWidth)
        .frame(maxHeight: .infinity)
        .background(DiscordColor.panelSidebar)
    }

    private var header: some View {
        HStack {
            Text("Home")
                .font(DiscordFont.categoryHeader)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(DiscordColor.channelDefault)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 40, alignment: .bottom)
        .padding(.bottom, 6)
    }

    private var friendsRow: some View {
        Button {
            app.showFriendsHome()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(friendsSelected ? DiscordColor.interactiveActive : DiscordColor.channelIcon)
                    .frame(width: Layout.listAvatar, height: Layout.listAvatar)
                    .background(friendsSelected ? DiscordColor.channelSelected : DiscordColor.bgSecondaryAlt,
                               in: .circle)
                Text("Friends")
                    .font(DiscordFont.channelName.weight(friendsSelected ? .semibold : .regular))
                    .foregroundStyle(friendsSelected ? DiscordColor.interactiveActive : DiscordColor.channelDefault)
                Spacer()
                if app.incomingFriendRequests.count > 0 {
                    UnreadBadge(count: app.incomingFriendRequests.count)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: Layout.memberRowHeight)
            .background(friendsSelected ? DiscordColor.channelSelected : .clear)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func select(_ dm: Channel) {
        app.selectGuild(nil)
        Task { await app.selectChannel(dm.id) }
    }
}
