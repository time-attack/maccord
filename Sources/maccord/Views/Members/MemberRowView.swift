import SwiftUI
import MaccordCore

/// A single member-list row: avatar with presence dot, the member's display name
/// in their highest colored role, and an optional custom-status line. Tapping the
/// row opens the user profile popover.
struct MemberRowView: View {
    let entry: MemberListEntry

    @Environment(AppState.self) private var app
    @State private var isHovering = false
    @State private var showProfile = false

    // Prefer the live presence store (kept current by PRESENCE_UPDATE) over the
    // op14 snapshot, so the dot reflects the member's real status.
    private var status: Status {
        let live = app.presences.status(entry.member.id)
        if live != .offline { return live }
        return entry.presence?.status ?? .offline
    }

    private var isOffline: Bool {
        status == .offline || status == .invisible
    }

    private var displayName: String {
        if let nick = entry.member.nick, !nick.isEmpty { return nick }
        return entry.member.user?.displayName
            ?? app.usersByID[entry.member.id]?.displayName
            ?? "Unknown"
    }

    private var nameColor: Color {
        if let role = app.selectedGuildStore?.colorRole(for: entry.member),
           let color = Color(discordColor: role.color) {
            return color
        }
        return DiscordColor.interactiveNormal
    }

    private var customStatus: String? {
        guard let state = entry.presence?.customStatus?.state, !state.isEmpty else { return nil }
        return state
    }

    private var avatarURL: URL? {
        entry.member.avatarURL(guildID: app.selectedGuildID, size: 64)
            ?? app.usersByID[entry.member.id]?.avatarURL(size: 64)
    }

    private var isOwner: Bool {
        app.selectedGuildStore?.meta.ownerID == entry.member.id
    }

    /// "Playing X" / "Listening to …" activity for the subtitle (live presence).
    private var activityText: String? {
        let presence = app.presences.presence(entry.member.id) ?? entry.presence
        guard let activity = presence?.activities.first(where: { $0.type != .custom }) else { return nil }
        switch activity.type {
        case .playing: return "Playing \(activity.name)"
        case .listening: return "Listening to \(activity.name)"
        case .watching: return "Watching \(activity.name)"
        case .streaming: return "Streaming \(activity.name)"
        case .competing: return "Competing in \(activity.name)"
        case .custom: return activity.name
        }
    }

    var body: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    url: avatarURL,
                    fallbackText: displayName,
                    size: Layout.listAvatar,
                    status: status,
                    dotBorderColor: isHovering ? DiscordColor.bgModifierHover : DiscordColor.bgSecondary
                )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(displayName)
                            .font(DiscordFont.memberName)
                            .foregroundStyle(nameColor)
                            .lineLimit(1)
                        if isOwner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DiscordColor.statusIdle)
                        }
                        if entry.member.user?.isBot == true { BotTag() }
                    }

                    if let subtitle = customStatus ?? activityText {
                        Text(subtitle)
                            .font(DiscordFont.panelSubtext)
                            .foregroundStyle(DiscordColor.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Layout.channelRowInset)
            .frame(height: Layout.memberRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? DiscordColor.bgModifierHover : Color.clear)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(.rect)
            .opacity(isOffline ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .padding(.horizontal, Layout.channelRowInset)
        .popover(isPresented: $showProfile, arrowEdge: .leading) {
            MemberProfilePopover(member: entry.member, presence: entry.presence)
        }
        .contextMenu {
            Button { showProfile = true } label: { Label("View Profile", systemImage: "person.crop.circle") }
            if !isSelf {
                Button { Task { await app.openDM(with: entry.member.id) } } label: { Label("Message", systemImage: "bubble.left") }
            }
            Button { Clipboard.copy("<@\(entry.member.id.rawValue)>") } label: { Label("Copy Mention", systemImage: "at") }
            if let gid = app.selectedGuildID, !isSelf { moderationMenu(gid) }
            Divider()
            if !isSelf {
                if app.isBlocked(entry.member.id) {
                    Button { Task { await app.unblockUser(entry.member.id) } } label: { Label("Unblock", systemImage: "hand.raised.slash") }
                } else {
                    Button(role: .destructive) { Task { await app.blockUser(entry.member.id) } } label: { Label("Block", systemImage: "hand.raised") }
                }
            }
            Button { Clipboard.copy(entry.member.id.description) } label: { Label("Copy User ID", systemImage: "number") }
        }
    }

    private var isSelf: Bool { entry.member.id == app.currentUser?.id }

    /// Kick / Ban / Timeout actions, shown only when the user has the permission.
    @ViewBuilder
    private func moderationMenu(_ guildID: Snowflake) -> some View {
        let uid = entry.member.id
        if app.canTimeout(in: guildID) || app.canKick(in: guildID) || app.canBan(in: guildID) {
            Divider()
            if app.canTimeout(in: guildID) {
                Menu {
                    Button("60 seconds") { Task { await app.timeoutMember(uid, in: guildID, minutes: 1) } }
                    Button("5 minutes") { Task { await app.timeoutMember(uid, in: guildID, minutes: 5) } }
                    Button("1 hour") { Task { await app.timeoutMember(uid, in: guildID, minutes: 60) } }
                    Button("1 day") { Task { await app.timeoutMember(uid, in: guildID, minutes: 1_440) } }
                    Divider()
                    Button("Remove Timeout") { Task { await app.timeoutMember(uid, in: guildID, minutes: 0) } }
                } label: { Label("Timeout", systemImage: "clock.badge.exclamationmark") }
            }
            if app.canKick(in: guildID) {
                Button(role: .destructive) { Task { await app.kickMember(uid, in: guildID) } } label: {
                    Label("Kick", systemImage: "door.left.hand.open")
                }
            }
            if app.canBan(in: guildID) {
                Button(role: .destructive) { Task { await app.banMember(uid, in: guildID) } } label: {
                    Label("Ban", systemImage: "hammer")
                }
            }
        }
    }

    /// Build the best `User` we can for the profile popover.
    private var resolvedUser: User {
        if let user = entry.member.user { return user }
        if let user = app.usersByID[entry.member.id] { return user }
        return User(id: entry.member.id, username: displayName)
    }
}
