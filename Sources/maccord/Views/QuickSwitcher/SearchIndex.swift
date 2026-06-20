import SwiftUI
import MaccordCore

/// The ⌘K search index: every server, every channel you can view (with its
/// `Server › Category` context), every DM / group DM, and every friend — each
/// carrying an icon and a `navigate` closure. Built once when the switcher opens
/// (and refreshed as servers finish loading), then matched with a simple, fast
/// substring test. No fuzzy scoring, no caching layers, no scopes.
struct SearchResult: Identifiable {
    enum Kind { case server, channel, voice, dm, group, user }

    let id: String
    let kind: Kind
    let title: String
    let lowercasedTitle: String
    /// `lowercasedTitle` reduced to letters/digits — so "gamedev" matches a
    /// server actually named "Game Dev" (spaces/dashes/emoji ignored).
    let compactTitle: String
    let subtitle: String?
    let icon: ResultIcon
    let status: Status?
    /// Extra lowercased match text (server + category for channels, @handle for
    /// people) so a channel is findable by its server, a person by their handle.
    let keywords: String
    /// Lower = more recently visited (0 = most recent); `.max` if never visited.
    let recencyRank: Int
    let navigate: () -> Void

    init(id: String, kind: Kind, title: String, subtitle: String?, icon: ResultIcon,
         status: Status?, keywords: String, recencyRank: Int, navigate: @escaping () -> Void) {
        self.id = id
        self.kind = kind
        self.title = title
        let lower = title.lowercased()
        self.lowercasedTitle = lower
        self.compactTitle = lower.filter { $0.isLetter || $0.isNumber }
        self.subtitle = subtitle
        self.icon = icon
        self.status = status
        self.keywords = keywords
        self.recencyRank = recencyRank
        self.navigate = navigate
    }

    var kindLabel: String {
        switch kind {
        case .server: "Server"
        case .channel: "Channel"
        case .voice: "Voice"
        case .dm: "DM"
        case .group: "Group"
        case .user: "Person"
        }
    }

    /// Fast match: nil = no match, lower = better. Title beats keyword; exact
    /// beats prefix beats substring. The final tier ignores spaces/punctuation so
    /// "gamedev" matches "Game Dev". `q` is expected lowercased.
    func matchScore(_ q: String) -> Int? {
        if lowercasedTitle == q { return 0 }
        if lowercasedTitle.hasPrefix(q) { return 1 }
        if lowercasedTitle.contains(q) { return 2 }
        if keywords.contains(q) { return 3 }
        let qc = q.filter { $0.isLetter || $0.isNumber }
        if !qc.isEmpty, compactTitle.contains(qc) { return 4 }
        return nil
    }
}

enum ResultIcon {
    case image(url: URL?, monogram: String, shape: IconShape)
    case glyph(symbol: String, tint: Color)
}

enum IconShape { case circle, roundedSquare }

@MainActor
struct SearchIndex {
    let app: AppState

    private var currentUserID: Snowflake? { app.currentUser?.id }

    /// The whole index: servers + viewable channels + DMs/groups + friends.
    func containers() -> [SearchResult] {
        let recents = recencyMap()
        return servers() + channels(recents: recents) + conversations(recents: recents) + friends()
    }

    // MARK: Servers

    private func servers() -> [SearchResult] {
        app.orderedGuilds.map { guild in
            SearchResult(
                id: "g-\(guild.id.rawValue)",
                kind: .server,
                title: guild.name,
                subtitle: "Server",
                icon: .image(url: guild.iconURL(size: 64), monogram: guild.acronym, shape: .roundedSquare),
                status: nil,
                keywords: guild.name.lowercased(),
                recencyRank: .max,
                navigate: { [app] in app.selectGuild(guild.id) }
            )
        }
    }

    // MARK: Channels (every loaded channel you can view)

    private func channels(recents: [Snowflake: Int]) -> [SearchResult] {
        var out: [SearchResult] = []
        for channel in app.channelsByID.values {
            guard let guildID = channel.guildID else { continue }   // DMs handled separately
            guard channel.type.isTextLike || channel.type.isVoice else { continue }
            let store = app.guildStores[guildID]
            if let store, !canView(channel, in: store) { continue }
            let guildName = store?.meta.name ?? "Server"
            let parent = channel.parentID.flatMap { store?.channels[$0] ?? app.channelsByID[$0] }
            let name = channel.name ?? "channel"
            out.append(SearchResult(
                id: "ch-\(channel.id.rawValue)",
                kind: channel.type.isVoice ? .voice : .channel,
                title: name,
                subtitle: channelContext(channel, parent: parent, guildName: guildName),
                icon: .glyph(symbol: channelGlyph(channel.type), tint: DiscordColor.channelIcon),
                status: nil,
                keywords: "\(guildName.lowercased()) \((parent?.name ?? "").lowercased())",
                recencyRank: recents[channel.id] ?? .max,
                navigate: { [app] in
                    app.selectedGuildID = guildID
                    Task { await app.selectChannel(channel.id) }
                }
            ))
        }
        return out
    }

    /// VIEW_CHANNEL check mirroring the sidebar; fails open until member roles load
    /// (so accessible channels are never hidden on incomplete data).
    private func canView(_ channel: Channel, in store: GuildStore) -> Bool {
        guard let me = currentUserID, let roleIDs = app.myRoleIDs(in: store.id) else { return true }
        return store.canViewChannel(channel, myRoleIDs: roleIDs, myUserID: me)
    }

    private func channelContext(_ channel: Channel, parent: Channel?, guildName: String) -> String {
        if channel.type.isThread {
            if let parent, let pname = parent.name { return "\(guildName) › #\(pname)" }
            return "\(guildName) · Thread"
        }
        if let parent, parent.type == .category, let cname = parent.name {
            return "\(guildName) › \(cname)"
        }
        return guildName
    }

    private func channelGlyph(_ type: ChannelType) -> String {
        switch type {
        case .announcement, .announcementThread: "megaphone.fill"
        case .forum: "list.bullet.rectangle"
        case .media: "photo.on.rectangle"
        case .voice: "speaker.wave.2.fill"
        case .stageVoice: "person.wave.2.fill"
        case .publicThread, .privateThread: "text.bubble"
        default: "number"
        }
    }

    // MARK: Conversations (DMs + group DMs)

    private func conversations(recents: [Snowflake: Int]) -> [SearchResult] {
        app.dms.map { dm in
            let isGroup = dm.type == .groupDM
            let title = dm.displayName(currentUserID: currentUserID)
            let other = dm.otherRecipient(currentUserID: currentUserID)
            let subtitle = isGroup
                ? "Group · \(dm.recipients?.count ?? 0) members"
                : (other.map { "@\($0.handle)" } ?? "Direct Message")
            return SearchResult(
                id: "dm-\(dm.id.rawValue)",
                kind: isGroup ? .group : .dm,
                title: title,
                subtitle: subtitle,
                icon: .image(url: dm.iconURL(currentUserID: currentUserID, size: 64),
                             monogram: String(title.prefix(1)).uppercased(), shape: .circle),
                status: isGroup ? nil : other.map { app.presences.status($0.id) },
                keywords: "\((other?.handle ?? "").lowercased())",
                recencyRank: recents[dm.id] ?? .max,
                navigate: { [app] in
                    app.selectGuild(nil)
                    Task { await app.selectChannel(dm.id) }
                }
            )
        }
    }

    // MARK: Friends

    private func friends() -> [SearchResult] {
        var seen = Set<Snowflake>()
        for dm in app.dms where dm.type == .dm {
            if let id = dm.otherRecipient(currentUserID: currentUserID)?.id { seen.insert(id) }
        }
        var out: [SearchResult] = []
        for rel in app.friends {
            guard let u = rel.user, u.id != currentUserID, seen.insert(u.id).inserted else { continue }
            out.append(SearchResult(
                id: "u-\(u.id.rawValue)",
                kind: .user,
                title: u.displayName,
                subtitle: "@\(u.handle)",
                icon: .image(url: u.avatarURL(size: 64),
                             monogram: String(u.displayName.prefix(1)).uppercased(), shape: .circle),
                status: app.presences.status(u.id),
                keywords: "\(u.username.lowercased()) \(u.handle.lowercased())",
                recencyRank: .max,
                navigate: { [app] in Task { await app.openDM(with: u.id) } }
            ))
        }
        return out
    }

    // MARK: Recency

    private func recencyMap() -> [Snowflake: Int] {
        var m: [Snowflake: Int] = [:]
        for (i, id) in app.recentChannels.enumerated() { m[id] = i }
        return m
    }
}
