import Foundation

/// A guild member. https://discord.com/developers/docs/resources/guild#guild-member-object
public struct Member: Codable, Hashable, Sendable, Identifiable {
    /// The underlying user. Optional because some gateway member payloads omit it
    /// when the user is delivered separately.
    public let user: User?
    public let nick: String?
    public let avatar: String?
    public let roles: [Snowflake]
    public let joinedAt: Date?
    public let premiumSince: Date?
    public let deaf: Bool?
    public let mute: Bool?
    public let pending: Bool?
    public let communicationDisabledUntil: Date?
    public let flags: Int?

    enum CodingKeys: String, CodingKey {
        case user, nick, avatar, roles, deaf, mute, pending, flags
        case joinedAt = "joined_at"
        case premiumSince = "premium_since"
        case communicationDisabledUntil = "communication_disabled_until"
    }

    public var id: Snowflake { user?.id ?? Snowflake(0) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try? c.decodeIfPresent(User.self, forKey: .user)
        nick = try? c.decodeIfPresent(String.self, forKey: .nick)
        avatar = try? c.decodeIfPresent(String.self, forKey: .avatar)
        roles = (try? c.decode([Snowflake].self, forKey: .roles)) ?? []
        joinedAt = try? c.decodeIfPresent(Date.self, forKey: .joinedAt)
        premiumSince = try? c.decodeIfPresent(Date.self, forKey: .premiumSince)
        deaf = try? c.decodeIfPresent(Bool.self, forKey: .deaf)
        mute = try? c.decodeIfPresent(Bool.self, forKey: .mute)
        pending = try? c.decodeIfPresent(Bool.self, forKey: .pending)
        communicationDisabledUntil = try? c.decodeIfPresent(Date.self, forKey: .communicationDisabledUntil)
        flags = try? c.decodeIfPresent(Int.self, forKey: .flags)
    }

    public init(
        user: User?, nick: String? = nil, avatar: String? = nil, roles: [Snowflake] = [],
        joinedAt: Date? = nil, premiumSince: Date? = nil, deaf: Bool? = nil,
        mute: Bool? = nil, pending: Bool? = nil, communicationDisabledUntil: Date? = nil,
        flags: Int? = nil
    ) {
        self.user = user; self.nick = nick; self.avatar = avatar; self.roles = roles
        self.joinedAt = joinedAt; self.premiumSince = premiumSince; self.deaf = deaf
        self.mute = mute; self.pending = pending
        self.communicationDisabledUntil = communicationDisabledUntil; self.flags = flags
    }

    /// Name to render: server nick > global name > username.
    public var displayName: String {
        if let nick, !nick.isEmpty { return nick }
        return user?.displayName ?? "Unknown"
    }

    /// Member-specific avatar overrides the user avatar within the guild.
    public func avatarURL(guildID: Snowflake?, size: Int = 128) -> URL? {
        if let avatar, let guildID, let userID = user?.id {
            return DiscordCDN.guildMemberAvatar(guildID: guildID, userID: userID, hash: avatar, size: size)
        }
        return user?.avatarURL(size: size)
    }

    public var isTimedOut: Bool {
        guard let until = communicationDisabledUntil else { return false }
        return until > Date()
    }
}
