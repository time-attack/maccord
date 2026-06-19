import SwiftUI
import MaccordCore

/// The Home sidebar: a Friends nav row + the user's DM list.
public struct DMListView: View {
    @Environment(AppState.self) private var app
    @State private var searchText = ""
    @State private var showNewGroup = false

    public init() {}

    private var friendsSelected: Bool {
        app.selectedGuildID == nil && app.selectedChannelID == nil
    }

    private var filteredDMs: [Channel] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return app.dms }
        return app.dms.filter {
            $0.displayName(currentUserID: app.currentUser?.id).lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchField

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

                    ForEach(filteredDMs) { dm in
                        DMRowView(
                            channel: dm,
                            isSelected: app.selectedChannelID == dm.id && app.selectedGuildID == nil
                        ) {
                            select(dm)
                        }
                    }

                    if filteredDMs.isEmpty {
                        Text(searchText.isEmpty ? "No direct messages yet" : "No matches")
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
        .sheet(isPresented: $showNewGroup) { GroupDMCreateView() }
    }

    private var header: some View {
        HStack {
            Text("Home")
                .font(DiscordFont.categoryHeader)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(DiscordColor.channelDefault)
            Spacer()
            Button { showNewGroup = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DiscordColor.interactiveNormal)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Create Group DM")
        }
        .padding(.horizontal, 18)
        .frame(height: 40, alignment: .bottom)
        .padding(.bottom, 6)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DiscordColor.textMuted)
            TextField("Find or start a conversation", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(DiscordColor.textNormal)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 5, style: .continuous))
        .padding(.horizontal, 10)
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
