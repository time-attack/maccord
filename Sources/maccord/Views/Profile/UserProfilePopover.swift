import SwiftUI
import MaccordCore

/// The rich user profile card shown when a member/avatar/name is tapped. Fetches
/// the full `GET /users/{id}/profile` (badges, banner, bio, pronouns, connections,
/// mutual servers) and renders it Discord-style over the lightweight data we
/// already have, so the card is populated instantly and then enriched.
struct UserProfilePopover: View {
    let user: User
    var member: Member? = nil
    var presence: Presence? = nil

    @Environment(AppState.self) private var app
    @State private var profile: UserProfile?
    @State private var loading = true

    private let cardWidth: CGFloat = 320
    private let bannerHeight: CGFloat = 100
    private let avatarSize: CGFloat = 84

    // MARK: Resolved fields (profile overrides the lightweight fallback)

    private var resolvedUser: User { profile?.user ?? user }
    private var detail: ProfileDetail? { profile?.profile }
    private var isSelf: Bool { user.id == app.currentUser?.id }
    private var status: Status {
        if isSelf { return app.currentUserStatus }
        let live = app.presences.status(user.id)
        if live != .offline { return live }
        return presence?.status ?? .offline
    }
    private var customStatusText: String? {
        let s = app.presences.presence(user.id)?.customStatus?.state
        return (s?.isEmpty == false) ? s : nil
    }
    private var activityText: String? {
        guard let activity = app.presences.presence(user.id)?.activities.first(where: { $0.type != .custom }) else { return nil }
        switch activity.type {
        case .playing: return "Playing \(activity.name)"
        case .listening: return "Listening to \(activity.name)"
        case .watching: return "Watching \(activity.name)"
        case .streaming: return "Streaming \(activity.name)"
        case .competing: return "Competing in \(activity.name)"
        case .custom: return activity.name
        }
    }

    private var bio: String? {
        let value = detail?.bio ?? resolvedUser.bio
        return (value?.isEmpty == false) ? value : nil
    }
    private var pronouns: String? {
        let value = detail?.pronouns
        return (value?.isEmpty == false) ? value : nil
    }
    private var bannerHash: String? { detail?.banner ?? resolvedUser.banner }
    private var accentColor: Color {
        if let accent = detail?.accentColor ?? resolvedUser.accentColor,
           let color = Color(discordColor: accent) { return color }
        return DiscordColor.blurple
    }

    private var displayName: String {
        if let nick = member?.nick, !nick.isEmpty { return nick }
        return resolvedUser.displayName
    }

    private var resolvedMember: Member? { profile?.guildMember ?? member }

    private var badges: [ProfileBadgeKind] {
        ProfileBadgeKind.badges(
            publicFlags: resolvedUser.publicFlags,
            premiumType: resolvedUser.premiumType,
            premiumSince: profile?.premiumSince
        )
    }

    private var connections: [ConnectedAccount] { profile?.connectedAccounts ?? [] }
    private var mutualGuilds: [MutualGuild] { profile?.mutualGuilds ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: cardWidth)
        .frame(maxHeight: 560)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .task(id: user.id) {
            loading = true
            profile = await app.userProfile(for: user.id)
            loading = false
        }
    }

    // MARK: Banner + avatar

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let hash = bannerHash, let url = DiscordCDN.userBanner(userID: resolvedUser.id, hash: hash, size: 600) {
                    CachedAsyncImage(url: url, content: { $0.resizable().scaledToFill() },
                                     placeholder: { accentColor })
                } else {
                    accentColor
                }
            }
            .frame(height: bannerHeight)
            .frame(maxWidth: .infinity)
            .clipped()

            AvatarView(
                url: resolvedUser.avatarURL(size: 160),
                fallbackText: displayName,
                size: avatarSize,
                status: status,
                dotBorderColor: DiscordColor.bgFloating
            )
            .padding(6)
            .background(DiscordColor.bgFloating, in: .circle)
            .padding(.leading, 14)
            .offset(y: avatarSize / 2 + 6)
            .zIndex(1)
        }
    }

    // MARK: Body content

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name block + badges card.
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DiscordColor.headerPrimary)
                            .lineLimit(1)
                        Text(resolvedUser.handle)
                            .font(DiscordFont.panelUsername)
                            .foregroundStyle(DiscordColor.textNormal)
                            .lineLimit(1)
                        if let pronouns {
                            Text(pronouns)
                                .font(DiscordFont.panelSubtext)
                                .foregroundStyle(DiscordColor.textMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    if resolvedUser.isBot { BotTag() }
                }

                // Status line (+ a quick picker when viewing your own profile).
                HStack(spacing: 6) {
                    PresenceDotView(status: status, size: 10, borderColor: DiscordColor.bgSecondary)
                    Text(customStatusText ?? activityText ?? status.label)
                        .font(DiscordFont.panelSubtext)
                        .foregroundStyle(DiscordColor.textMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if isSelf {
                        Menu {
                            ForEach([Status.online, .idle, .dnd, .invisible], id: \.self) { s in
                                Button { app.setStatus(s) } label: { Label(s.label, systemImage: "circle.fill") }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(DiscordColor.interactiveNormal)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                if !badges.isEmpty {
                    ProfileBadgesRow(badges: badges)
                }

                if !isSelf && !resolvedUser.isBot {
                    Button {
                        Task { await app.openDM(with: resolvedUser.id) }
                    } label: {
                        Label("Message", systemImage: "bubble.left.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DiscordColor.blurple)

                    HStack(spacing: 8) {
                        Button { Clipboard.copy(app.profileLink(for: resolvedUser.id)) } label: {
                            Label("Copy Profile Link", systemImage: "link")
                        }
                        if app.isBlocked(resolvedUser.id) {
                            Button { Task { await app.unblockUser(resolvedUser.id) } } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) { Task { await app.blockUser(resolvedUser.id) } } label: {
                                Label("Block", systemImage: "hand.raised")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if !isSelf {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE").font(DiscordFont.sectionTitle).foregroundStyle(DiscordColor.headerSecondary)
                        TextField("Click to add a note", text: Binding(
                            get: { app.userNotes.note(for: resolvedUser.id.rawValue) },
                            set: { app.userNotes.set($0, for: resolvedUser.id.rawValue) }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 6))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondary, in: .rect(cornerRadius: 10, style: .continuous))

            // Detail card.
            VStack(alignment: .leading, spacing: 14) {
                if loading && profile == nil {
                    HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                }

                if let bio {
                    section(title: "About Me") {
                        Text(LocalizedStringKey(bio))
                            .font(DiscordFont.replyPreview)
                            .foregroundStyle(DiscordColor.textNormal)
                            .fixedSize(horizontal: false, vertical: true)
                            .tint(DiscordColor.linkBlue)
                    }
                }

                section(title: "Member Since") {
                    HStack(spacing: 16) {
                        memberSince("Discord", date: resolvedUser.id.createdAt)
                        if let joined = resolvedMember?.joinedAt {
                            memberSince(app.selectedGuildStore?.meta.name ?? "Server", date: joined)
                        }
                    }
                }

                if !connections.isEmpty {
                    section(title: "Connections") {
                        FlowLayout(spacing: 6) {
                            ForEach(connections) { conn in connectionChip(conn) }
                        }
                    }
                }

                if !mutualGuilds.isEmpty {
                    section(title: "\(mutualGuilds.count) Mutual Server\(mutualGuilds.count == 1 ? "" : "s")") {
                        mutualServerIcons
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondary, in: .rect(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .padding(.top, avatarSize / 2 + 6)
    }

    // MARK: Pieces

    private func memberSince(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DiscordColor.textMuted)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(DiscordFont.replyPreview)
                .foregroundStyle(DiscordColor.textNormal)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DiscordFont.sectionTitle)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(DiscordColor.headerSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func connectionChip(_ conn: ConnectedAccount) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(DiscordColor.textMuted)
            Text(conn.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DiscordColor.textNormal)
                .lineLimit(1)
            if conn.verified == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DiscordColor.textPositive)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DiscordColor.bgSecondaryAlt)
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
    }

    private var mutualServerIcons: some View {
        FlowLayout(spacing: 6) {
            ForEach(mutualGuilds.prefix(12)) { mutual in
                if let guild = app.guildStores[mutual.id]?.meta {
                    Group {
                        if let url = guild.iconURL(size: 48) {
                            CachedAsyncImage(url: url, content: { $0.resizable().scaledToFill() },
                                             placeholder: { DiscordColor.bgSecondaryAlt })
                        } else {
                            ZStack {
                                DiscordColor.bgSecondaryAlt
                                Text(guild.acronym.prefix(1))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DiscordColor.headerSecondary)
                            }
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    .help(guild.name)
                }
            }
        }
    }
}
