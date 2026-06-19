import SwiftUI
import MaccordCore

/// A scoped, Apple-styled Server Settings sheet: a glass section rail on the left
/// and a detail pane (Overview, Roles, Emoji, Members) on the right.
struct ServerSettingsView: View {
    let guildID: Snowflake

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .overview
    @State private var invites: [GuildInvite] = []
    @State private var bans: [GuildBan] = []
    @State private var inviteMaxAge = 86_400
    @State private var inviteMaxUses = 0
    @State private var loadingInvites = false
    @State private var loadingBans = false

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", roles = "Roles", emoji = "Emoji",
             members = "Members", invites = "Invites", bans = "Bans"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: "gearshape.fill"
            case .roles: "at"
            case .emoji: "face.smiling.inverse"
            case .members: "person.2.fill"
            case .invites: "link"
            case .bans: "hammer.fill"
            }
        }
    }

    private var guild: Guild? { app.guildStores[guildID]?.meta }
    private var store: GuildStore? { app.guildStores[guildID] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(DiscordColor.divider)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DiscordColor.bgPrimary)
        }
        .frame(width: 760, height: 520)
        .background(DiscordColor.bgSecondary)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text((guild?.name ?? "Server").uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(DiscordColor.headerSecondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 8) {
                        Image(systemName: t.icon).frame(width: 18)
                        Text(t.rawValue).font(.system(size: 14, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tab == t ? DiscordColor.interactiveActive : DiscordColor.interactiveNormal)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(tab == t ? DiscordColor.channelSelected : Color.clear,
                               in: .rect(cornerRadius: 6, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(role: .destructive) { dismiss() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").frame(width: 18)
                    Text("Close").font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(DiscordColor.dangerRed)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .frame(width: 200)
        .glassEffect(.regular.tint(DiscordColor.bgTertiary.opacity(0.5)), in: .rect(cornerRadius: 0))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(tab.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                switch tab {
                case .overview: overview
                case .roles: roles
                case .emoji: emoji
                case .members: members
                case .invites: invitesView
                case .bans: bansView
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var overview: some View {
        if let guild {
            HStack(spacing: 16) {
                AvatarView(url: guild.iconURL(size: 160), fallbackText: guild.acronym, size: 80)
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(guild.name).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                    if let desc = guild.description, !desc.isEmpty {
                        Text(desc).font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
                    }
                }
                Spacer()
            }
            infoCard {
                infoRow("Server ID", guild.id.description)
                infoRow("Created", guild.id.createdAt.formatted(date: .abbreviated, time: .omitted))
                if let owner = guild.ownerID { infoRow("Owner", app.usersByID[owner]?.displayName ?? owner.description) }
                infoRow("Members", "\(guild.approximateMemberCount ?? store?.channels.count ?? 0)")
                infoRow("Roles", "\(store?.roles.count ?? guild.roles.count)")
                infoRow("Boost Tier", "Level \(guild.premiumTier ?? 0)")
                if !guild.features.isEmpty { infoRow("Features", "\(guild.features.count)") }
            }

            if guild.ownerID != app.currentUser?.id {
                Button(role: .destructive) {
                    Task { await app.leaveGuild(guild.id); dismiss() }
                } label: {
                    Label("Leave Server", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DiscordColor.dangerRed)
                .controlSize(.large)
            }
        }
    }

    private var roles: some View {
        let list = store?.roleList ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(list) { role in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Circle().fill(Color(discordColor: role.color) ?? DiscordColor.interactiveMuted)
                            .frame(width: 12, height: 12)
                        Text(role.name).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DiscordColor.textNormal)
                        Spacer()
                        if role.hoist { tag("Hoisted") }
                        if role.permissions.isAdministrator { tag("Admin") }
                        if role.managed { tag("Managed") }
                    }
                    if !role.permissions.labeledFlags.isEmpty {
                        Text(role.permissions.labeledFlags.prefix(6).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(DiscordColor.textMuted)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8, style: .continuous))
            }
            if list.isEmpty { empty("No roles") }
        }
    }

    private var emoji: some View {
        let emojis = guild?.emojis ?? []
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 8), count: 8), spacing: 8) {
            ForEach(emojis) { e in
                CachedAsyncImage(url: e.imageURL(size: 64), content: { $0.resizable().scaledToFit() },
                                 placeholder: { DiscordColor.bgSecondaryAlt })
                    .frame(width: 40, height: 40)
                    .help(e.name ?? "")
            }
        }
        .overlay { if emojis.isEmpty { empty("No custom emoji") } }
    }

    private var members: some View {
        infoCard {
            infoRow("Approx. members", "\(guild?.approximateMemberCount ?? 0)")
            infoRow("Online (approx.)", "\(guild?.approximatePresenceCount ?? 0)")
            Text("Open the member list (⌘U) to browse members by role.")
                .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
        }
    }

    // MARK: Invites

    private var invitesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoCard {
                Text("Create Invite")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                HStack {
                    Text("Expire after").font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
                    Spacer()
                    Picker("", selection: $inviteMaxAge) {
                        Text("30 minutes").tag(1_800)
                        Text("1 hour").tag(3_600)
                        Text("6 hours").tag(21_600)
                        Text("1 day").tag(86_400)
                        Text("7 days").tag(604_800)
                        Text("Never").tag(0)
                    }.labelsHidden().frame(width: 130)
                }
                HStack {
                    Text("Max uses").font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
                    Spacer()
                    Picker("", selection: $inviteMaxUses) {
                        Text("No limit").tag(0)
                        Text("1 use").tag(1)
                        Text("5 uses").tag(5)
                        Text("10 uses").tag(10)
                        Text("25 uses").tag(25)
                        Text("50 uses").tag(50)
                    }.labelsHidden().frame(width: 130)
                }
                Button {
                    Task {
                        let channel = store?.defaultChannel
                            ?? store?.channels.values.first(where: { $0.type.isTextLike })
                        if let channel,
                           let invite = await app.createInvite(channelID: channel.id,
                                                               maxAgeSeconds: inviteMaxAge,
                                                               maxUses: inviteMaxUses, temporary: false) {
                            Clipboard.copy(invite.url)
                            await loadInvites()
                        }
                    }
                } label: {
                    Label("Create & Copy Invite", systemImage: "link.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(DiscordColor.blurple)
            }

            if loadingInvites {
                ProgressView().controlSize(.small)
            } else if invites.isEmpty {
                empty("No active invites")
            } else {
                ForEach(invites) { invite in inviteRow(invite) }
            }
        }
        .task { await loadInvites() }
    }

    private func inviteRow(_ invite: GuildInvite) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.url).font(.system(size: 13, weight: .medium)).foregroundStyle(DiscordColor.linkBlue)
                Text(inviteSubtitle(invite)).font(.system(size: 11)).foregroundStyle(DiscordColor.textMuted)
            }
            Spacer()
            Button { Clipboard.copy(invite.url) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.plain).help("Copy")
            Button(role: .destructive) {
                Task { await app.deleteInvite(invite.code); await loadInvites() }
            } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).help("Revoke")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8))
    }

    private func inviteSubtitle(_ i: GuildInvite) -> String {
        var parts: [String] = []
        if let inviter = i.inviter { parts.append("by \(inviter.displayName)") }
        let uses = i.uses ?? 0
        if let max = i.maxUses, max > 0 { parts.append("\(uses)/\(max) uses") } else { parts.append("\(uses) uses") }
        if let exp = i.expiresAt { parts.append("expires \(exp.formatted(date: .abbreviated, time: .shortened))") }
        else { parts.append("never expires") }
        return parts.joined(separator: " · ")
    }

    private func loadInvites() async {
        loadingInvites = true
        invites = await app.guildInvites(guildID)
        loadingInvites = false
    }

    // MARK: Bans

    private var bansView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if loadingBans {
                ProgressView().controlSize(.small)
            } else if bans.isEmpty {
                empty("No bans")
            } else {
                ForEach(bans) { ban in
                    HStack(spacing: 10) {
                        AvatarView(url: ban.user.avatarURL(size: 48), fallbackText: ban.user.displayName, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ban.user.displayName).font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DiscordColor.textNormal)
                            Text(ban.reason ?? "No reason given").font(.system(size: 11))
                                .foregroundStyle(DiscordColor.textMuted).lineLimit(1)
                        }
                        Spacer()
                        Button("Unban") {
                            Task { await app.unbanMember(ban.user.id, in: guildID); await loadBans() }
                        }.buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 8))
                }
            }
        }
        .task { await loadBans() }
    }

    private func loadBans() async {
        loadingBans = true
        bans = await app.bans(in: guildID)
        loadingBans = false
    }

    // MARK: Bits

    private func infoCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 10, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(DiscordColor.textNormal)
                .textSelection(.enabled)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DiscordColor.headerSecondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(DiscordColor.bgTertiary, in: .capsule)
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
    }
}
