import Foundation

/// `GET /users/{id}/profile` — the rich profile shown in popovers.
public struct UserProfile: Codable, Sendable, Hashable {
    public let user: User
    public let profile: ProfileDetail?
    public let guildMember: Member?
    public let mutualGuilds: [MutualGuild]?
    public let connectedAccounts: [ConnectedAccount]?
    public let premiumSince: Date?
    public let badges: [ProfileBadge]?

    enum CodingKeys: String, CodingKey {
        case user, badges
        case profile = "user_profile"
        case guildMember = "guild_member"
        case mutualGuilds = "mutual_guilds"
        case connectedAccounts = "connected_accounts"
        case premiumSince = "premium_since"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(User.self, forKey: .user)
        profile = try? c.decodeIfPresent(ProfileDetail.self, forKey: .profile)
        guildMember = try? c.decodeIfPresent(Member.self, forKey: .guildMember)
        mutualGuilds = try? c.decodeIfPresent([MutualGuild].self, forKey: .mutualGuilds)
        connectedAccounts = try? c.decodeIfPresent([ConnectedAccount].self, forKey: .connectedAccounts)
        premiumSince = try? c.decodeIfPresent(Date.self, forKey: .premiumSince)
        badges = try? c.decodeIfPresent([ProfileBadge].self, forKey: .badges)
    }
}

public struct ProfileDetail: Codable, Sendable, Hashable {
    public let bio: String?
    public let pronouns: String?
    public let banner: String?
    public let accentColor: Int?

    enum CodingKeys: String, CodingKey {
        case bio, pronouns, banner
        case accentColor = "accent_color"
    }
}

public struct MutualGuild: Codable, Sendable, Hashable, Identifiable {
    public let id: Snowflake
    public let nick: String?
}

public struct ConnectedAccount: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let type: String
    public let name: String
    public let verified: Bool?
}

public struct ProfileBadge: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let description: String?
    public let icon: String?
}
