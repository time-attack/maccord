import SwiftUI
import MaccordCore

/// The SERVER member card (Discord's distinction: `member` = per-server profile
/// with nickname + roles, vs `user` = global profile with badges/banner/bio).
/// Tapping a member shows this; tapping the avatar here opens the user profile.
struct MemberProfilePopover: View {
    let member: Member
    var presence: Presence? = nil

    @Environment(AppState.self) private var app
    @State private var showUserProfile = false

    private var user: User { member.user ?? app.usersByID[member.id] ?? User(id: member.id, username: displayName) }
    private var resolvedMember: Member { app.selectedGuildStore?.member(member.id) ?? member }
    private var displayName: String {
        if let nick = member.nick, !nick.isEmpty { return nick }
        return member.user?.displayName ?? app.usersByID[member.id]?.displayName ?? "Unknown"
    }
    private var status: Status {
        let live = app.presences.status(member.id)
        return live != .offline ? live : (presence?.status ?? .offline)
    }
    private var colorRole: Role? { app.selectedGuildStore?.colorRole(for: resolvedMember) }
    private var accent: Color { colorRole.flatMap { Color(discordColor: $0.color) } ?? DiscordColor.blurple }

    private var roles: [Role] {
        guard let store = app.selectedGuildStore else { return [] }
        return resolvedMember.roles
            .filter { $0 != app.selectedGuildID }       // drop @everyone
            .compactMap { store.role($0) }
            .sorted { $0.position > $1.position }
    }

    private var subtitleText: String? {
        if let s = app.presences.presence(member.id)?.customStatus?.state, !s.isEmpty { return s }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                accent.frame(height: 60).frame(maxWidth: .infinity)
                // Avatar → global user profile (Discord's pfp-click behavior).
                Button { showUserProfile = true } label: {
                    AvatarView(url: member.avatarURL(guildID: app.selectedGuildID, size: 160),
                               fallbackText: displayName, size: 72, status: status,
                               dotBorderColor: DiscordColor.bgFloating)
                        .padding(5)
                        .background(DiscordColor.bgFloating, in: .circle)
                }
                .buttonStyle(.plain)
                .help("View Full Profile")
                .padding(.leading, 14)
                .offset(y: 36)
                .popover(isPresented: $showUserProfile, arrowEdge: .trailing) {
                    UserProfilePopover(user: user, member: member, presence: presence)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(displayName).font(.system(size: 19, weight: .bold))
                            .foregroundStyle(DiscordColor.headerPrimary).lineLimit(1)
                        if app.selectedGuildStore?.meta.ownerID == member.id {
                            Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(DiscordColor.statusIdle)
                        }
                        if user.isBot { BotTag() }
                    }
                    Text(user.handle).font(.system(size: 13)).foregroundStyle(DiscordColor.textNormal).lineLimit(1)
                    HStack(spacing: 6) {
                        PresenceDotView(status: status, size: 9, borderColor: DiscordColor.bgFloating)
                        Text(subtitleText ?? status.label)
                            .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted).lineLimit(1)
                    }
                }

                Divider().overlay(DiscordColor.divider)

                // Roles — the per-server data that belongs on the MEMBER profile.
                VStack(alignment: .leading, spacing: 6) {
                    Text(roles.count == 1 ? "ROLE" : "ROLES")
                        .font(.system(size: 11, weight: .bold)).tracking(0.4)
                        .foregroundStyle(DiscordColor.headerSecondary)
                    if roles.isEmpty {
                        Text("No roles").font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
                    } else {
                        FlowLayout(spacing: 6) { ForEach(roles) { roleChip($0) } }
                    }
                }

                if let joined = resolvedMember.joinedAt {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEMBER SINCE").font(.system(size: 11, weight: .bold)).tracking(0.4)
                            .foregroundStyle(DiscordColor.headerSecondary)
                        Text(joined.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13)).foregroundStyle(DiscordColor.textNormal)
                    }
                }

                Button { showUserProfile = true } label: {
                    Label("View Full Profile", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DiscordColor.blurple)
            }
            .padding(14)
            .padding(.top, 30)
        }
        .frame(width: 320)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private func roleChip(_ role: Role) -> some View {
        let color = Color(discordColor: role.color) ?? DiscordColor.interactiveMuted
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(role.name).font(.system(size: 12, weight: .medium))
                .foregroundStyle(DiscordColor.textNormal).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(DiscordColor.bgSecondaryAlt).clipShape(.capsule)
        .overlay { Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1) }
    }
}
