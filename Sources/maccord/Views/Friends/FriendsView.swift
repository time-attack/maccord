import SwiftUI
import MaccordCore

/// Discord's Home → Friends panel: Online / All / Pending / Add Friend tabs with
/// accept/decline/remove and DM shortcuts.
struct FriendsView: View {
    @Environment(AppState.self) private var app
    @State private var tab: Tab = .online
    @State private var addUsername = ""
    @State private var addError: String?
    @State private var isAdding = false

    enum Tab: String, CaseIterable, Identifiable {
        case online = "Online", all = "All", pending = "Pending", blocked = "Blocked", add = "Add Friend"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DiscordColor.divider)
            tabBar
            Divider().overlay(DiscordColor.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch tab {
                    case .online: friendList(app.onlineFriends, empty: "No friends online")
                    case .all: friendList(app.friends, empty: "You don't have any friends yet")
                    case .pending: pendingList
                    case .blocked: blockedList
                    case .add: addFriendForm
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DiscordColor.panelChat)
        .task { await app.refreshRelationships() }
    }

    private var header: some View {
        HStack {
            Text("Friends")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DiscordColor.headerPrimary)
            Spacer()
            if app.incomingFriendRequests.count > 0 {
                Text("\(app.incomingFriendRequests.count) pending")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiscordColor.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 16) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.system(size: 14, weight: tab == t ? .semibold : .medium))
                        .foregroundStyle(tab == t ? DiscordColor.interactiveActive : DiscordColor.interactiveNormal)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if tab == t {
                                Capsule().fill(DiscordColor.interactiveActive).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func friendList(_ list: [Relationship], empty: String) -> some View {
        if list.isEmpty {
            Text(empty).font(.system(size: 14)).foregroundStyle(DiscordColor.textMuted).padding(.top, 8)
        } else {
            ForEach(list) { rel in
                if let user = rel.user { friendRow(user: user, relationship: rel) }
            }
        }
    }

    private var pendingList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !app.incomingFriendRequests.isEmpty {
                sectionTitle("Incoming — \(app.incomingFriendRequests.count)")
                ForEach(app.incomingFriendRequests) { rel in
                    if let user = rel.user { pendingRow(user: user, incoming: true) }
                }
            }
            if !app.outgoingFriendRequests.isEmpty {
                sectionTitle("Outgoing — \(app.outgoingFriendRequests.count)")
                ForEach(app.outgoingFriendRequests) { rel in
                    if let user = rel.user { pendingRow(user: user, incoming: false) }
                }
            }
            if app.incomingFriendRequests.isEmpty && app.outgoingFriendRequests.isEmpty {
                Text("No pending friend requests").font(.system(size: 14)).foregroundStyle(DiscordColor.textMuted)
            }
        }
    }

    @ViewBuilder
    private var blockedList: some View {
        if app.blockedUsers.isEmpty {
            Text("You haven't blocked anyone")
                .font(.system(size: 14)).foregroundStyle(DiscordColor.textMuted).padding(.top, 8)
        } else {
            ForEach(app.blockedUsers) { rel in
                if let user = rel.user {
                    HStack(spacing: 12) {
                        AvatarView(url: user.avatarURL(size: 80), fallbackText: user.displayName, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName).font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DiscordColor.headerPrimary)
                            Text(user.handle).font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
                        }
                        Spacer()
                        Button("Unblock") { Task { await app.unblockUser(user.id) } }
                            .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    private var addFriendForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You can add friends by username.")
                .font(.system(size: 14)).foregroundStyle(DiscordColor.textMuted)
            HStack(spacing: 10) {
                TextField("Username", text: $addUsername)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(10)
                    .background(DiscordColor.surfaceRaised, in: .rect(cornerRadius: 8))
                Button {
                    Task { await submitAddFriend() }
                } label: {
                    Text(isAdding ? "Sending…" : "Send Request")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(DiscordColor.blurple)
                .disabled(addUsername.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
            if let addError {
                Text(addError).font(.system(size: 13)).foregroundStyle(DiscordColor.dangerRed)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func friendRow(user: User, relationship: Relationship) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarURL(size: 80), fallbackText: user.displayName,
                       size: 36, status: app.presences.status(user.id))
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                Text(app.presences.presence(user.id)?.customStatus?.state ?? app.presences.status(user.id).label)
                    .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted).lineLimit(1)
            }
            Spacer()
            Button { Task { await app.openDM(with: user.id) } } label: {
                Image(systemName: "bubble.left.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .tint(DiscordColor.blurple)
            .help("Message")
            Menu {
                Button(role: .destructive) { Task { await app.removeFriend(user.id) } } label: {
                    Label("Remove Friend", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(10)
        .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8))
    }

    private func pendingRow(user: User, incoming: Bool) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarURL(size: 80), fallbackText: user.displayName, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName).font(.system(size: 15, weight: .semibold))
                Text(user.handle).font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
            }
            Spacer()
            if incoming {
                Button { Task { await app.acceptFriendRequest(user.id) } } label: {
                    Image(systemName: "checkmark").frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent).tint(DiscordColor.textPositive)
                Button { Task { await app.removeFriend(user.id) } } label: {
                    Image(systemName: "xmark").frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered).tint(DiscordColor.dangerRed)
            } else {
                Button("Cancel") { Task { await app.removeFriend(user.id) } }
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold)).tracking(0.4)
            .foregroundStyle(DiscordColor.headerSecondary)
    }

    private func submitAddFriend() async {
        isAdding = true
        addError = nil
        defer { isAdding = false }
        do {
            try await app.sendFriendRequest(username: addUsername)
            addUsername = ""
            tab = .pending
        } catch {
            addError = "Couldn't send request — check the username and try again."
        }
    }
}
