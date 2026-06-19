import Foundation

/// A guild (server). https://discord.com/developers/docs/resources/guild
///
/// In the READY payload guilds arrive fully hydrated with their channels,
/// members, presences, voice states and threads; in `GET /users/@me/guilds`
/// only the lightweight fields are present.
public struct Guild: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let name: String
    public let icon: String?
    public let banner: String?
    public let splash: String?
    public let ownerID: Snowflake?
    public let description: String?
    public let roles: [Role]
    public let emojis: [Emoji]
    public let features: [String]
    public let premiumTier: Int?
    public let premiumSubscriptionCount: Int?
    public let approximateMemberCount: Int?
    public let approximatePresenceCount: Int?
    public let memberCount: Int?
    public let unavailable: Bool?

    // READY-hydrated collections (empty for the lightweight guild list).
    public let channels: [Channel]
    public let threads: [Channel]
    public let members: [Member]
    public let presences: [Presence]
    public let voiceStates: [VoiceState]

    enum CodingKeys: String, CodingKey {
        case id, name, icon, banner, splash, description, roles, emojis, features
        case channels, threads, members, presences, unavailable
        case ownerID = "owner_id"
        case premiumTier = "premium_tier"
        case premiumSubscriptionCount = "premium_subscription_count"
        case approximateMemberCount = "approximate_member_count"
        case approximatePresenceCount = "approximate_presence_count"
        case memberCount = "member_count"
        case voiceStates = "voice_states"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown Server"
        icon = try? c.decodeIfPresent(String.self, forKey: .icon)
        banner = try? c.decodeIfPresent(String.self, forKey: .banner)
        splash = try? c.decodeIfPresent(String.self, forKey: .splash)
        ownerID = try? c.decodeIfPresent(Snowflake.self, forKey: .ownerID)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        roles = (try? c.decode([Role].self, forKey: .roles)) ?? []
        emojis = (try? c.decode([Emoji].self, forKey: .emojis)) ?? []
        features = (try? c.decode([String].self, forKey: .features)) ?? []
        premiumTier = try? c.decodeIfPresent(Int.self, forKey: .premiumTier)
        premiumSubscriptionCount = try? c.decodeIfPresent(Int.self, forKey: .premiumSubscriptionCount)
        approximateMemberCount = try? c.decodeIfPresent(Int.self, forKey: .approximateMemberCount)
        approximatePresenceCount = try? c.decodeIfPresent(Int.self, forKey: .approximatePresenceCount)
        memberCount = try? c.decodeIfPresent(Int.self, forKey: .memberCount)
        unavailable = try? c.decodeIfPresent(Bool.self, forKey: .unavailable)
        channels = (try? c.decode([Channel].self, forKey: .channels)) ?? []
        threads = (try? c.decode([Channel].self, forKey: .threads)) ?? []
        members = (try? c.decode([Member].self, forKey: .members)) ?? []
        presences = (try? c.decode([Presence].self, forKey: .presences)) ?? []
        voiceStates = (try? c.decode([VoiceState].self, forKey: .voiceStates)) ?? []
    }

    public init(
        id: Snowflake, name: String, icon: String? = nil, banner: String? = nil,
        splash: String? = nil, ownerID: Snowflake? = nil, description: String? = nil,
        roles: [Role] = [], emojis: [Emoji] = [], features: [String] = [],
        premiumTier: Int? = nil, premiumSubscriptionCount: Int? = nil,
        approximateMemberCount: Int? = nil, approximatePresenceCount: Int? = nil,
        memberCount: Int? = nil, unavailable: Bool? = nil, channels: [Channel] = [],
        threads: [Channel] = [], members: [Member] = [], presences: [Presence] = [],
        voiceStates: [VoiceState] = []
    ) {
        self.id = id; self.name = name; self.icon = icon; self.banner = banner
        self.splash = splash; self.ownerID = ownerID; self.description = description
        self.roles = roles; self.emojis = emojis; self.features = features
        self.premiumTier = premiumTier; self.premiumSubscriptionCount = premiumSubscriptionCount
        self.approximateMemberCount = approximateMemberCount
        self.approximatePresenceCount = approximatePresenceCount
        self.memberCount = memberCount; self.unavailable = unavailable
        self.channels = channels; self.threads = threads; self.members = members
        self.presences = presences; self.voiceStates = voiceStates
    }

    public func iconURL(size: Int = 128) -> URL? {
        guard let icon else { return nil }
        return DiscordCDN.guildIcon(guildID: id, hash: icon, size: size)
    }

    public func bannerURL(size: Int = 512) -> URL? {
        guard let banner else { return nil }
        return DiscordCDN.guildBanner(guildID: id, hash: banner, size: size)
    }

    /// Initials used for the fallback icon tile ("My Cool Server" → "MCS").
    public var acronym: String {
        name.split(separator: " ").compactMap(\.first).prefix(3).map(String.init).joined()
    }
}

/// A minimal unavailable-guild stub (GUILD_DELETE / outage).
public struct UnavailableGuild: Codable, Hashable, Sendable, Identifiable {
    public let id: Snowflake
    public let unavailable: Bool?
}
