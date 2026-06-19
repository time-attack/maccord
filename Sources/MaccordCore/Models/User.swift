import Foundation

/// A Discord user. https://discord.com/developers/docs/resources/user
public struct User: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let username: String
    /// The new "display name"; falls back to `username` when nil.
    public let globalName: String?
    /// "0" for migrated (pomelo) usernames.
    public let discriminator: String
    public let avatar: String?
    public let bot: Bool?
    public let system: Bool?
    public let banner: String?
    public let accentColor: Int?
    public let bio: String?
    public let publicFlags: Int?
    public let premiumType: Int?

    public init(
        id: Snowflake,
        username: String,
        globalName: String? = nil,
        discriminator: String = "0",
        avatar: String? = nil,
        bot: Bool? = nil,
        system: Bool? = nil,
        banner: String? = nil,
        accentColor: Int? = nil,
        bio: String? = nil,
        publicFlags: Int? = nil,
        premiumType: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.globalName = globalName
        self.discriminator = discriminator
        self.avatar = avatar
        self.bot = bot
        self.system = system
        self.banner = banner
        self.accentColor = accentColor
        self.bio = bio
        self.publicFlags = publicFlags
        self.premiumType = premiumType
    }

    enum CodingKeys: String, CodingKey {
        case id, username, discriminator, avatar, bot, system, banner, bio
        case globalName = "global_name"
        case accentColor = "accent_color"
        case publicFlags = "public_flags"
        case premiumType = "premium_type"
    }

    /// The name to render in the UI: global name when present, else username.
    public var displayName: String {
        if let globalName, !globalName.isEmpty { return globalName }
        return username
    }

    /// `@username` style handle (no discriminator for migrated accounts).
    public var handle: String {
        if discriminator == "0" || discriminator.isEmpty { return username }
        return "\(username)#\(discriminator)"
    }

    public func avatarURL(size: Int = 128) -> URL? {
        if let avatar {
            return DiscordCDN.userAvatar(userID: id, hash: avatar, size: size)
        }
        return DiscordCDN.defaultAvatar(userID: id, discriminator: discriminator)
    }

    public func bannerURL(size: Int = 512) -> URL? {
        guard let banner else { return nil }
        return DiscordCDN.userBanner(userID: id, hash: banner, size: size)
    }

    public var isBot: Bool { bot ?? false }
}

/// The authenticated account (`GET /users/@me`) — superset of `User`.
public struct CurrentUser: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let username: String
    public let globalName: String?
    public let discriminator: String
    public let avatar: String?
    public let banner: String?
    public let accentColor: Int?
    public let bio: String?
    public let email: String?
    public let phone: String?
    public let verified: Bool?
    public let mfaEnabled: Bool?
    public let locale: String?
    public let nsfwAllowed: Bool?
    public let premiumType: Int?
    public let publicFlags: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, discriminator, avatar, banner, bio, email, phone, verified, locale
        case globalName = "global_name"
        case accentColor = "accent_color"
        case mfaEnabled = "mfa_enabled"
        case nsfwAllowed = "nsfw_allowed"
        case premiumType = "premium_type"
        case publicFlags = "public_flags"
    }

    public var displayName: String {
        if let globalName, !globalName.isEmpty { return globalName }
        return username
    }

    public func avatarURL(size: Int = 128) -> URL? {
        if let avatar {
            return DiscordCDN.userAvatar(userID: id, hash: avatar, size: size)
        }
        return DiscordCDN.defaultAvatar(userID: id, discriminator: discriminator)
    }

    /// Projection into the lightweight `User` used throughout the UI.
    public var asUser: User {
        User(
            id: id, username: username, globalName: globalName, discriminator: discriminator,
            avatar: avatar, banner: banner, accentColor: accentColor, bio: bio,
            publicFlags: publicFlags, premiumType: premiumType
        )
    }
}
