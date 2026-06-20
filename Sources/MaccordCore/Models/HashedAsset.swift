import Foundation

/// Discord CDN base + helpers for building avatar / icon / emoji / banner URLs
/// from the hashes returned in API objects.
///
/// See https://discord.com/developers/docs/reference#image-formatting
public enum DiscordCDN {
    public static let base = "https://cdn.discordapp.com"

    /// Valid power-of-two sizes Discord accepts via `?size=`.
    public static func clampSize(_ requested: Int) -> Int {
        let allowed = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
        return allowed.min(by: { abs($0 - requested) < abs($1 - requested) }) ?? 128
    }

    /// `a_`-prefixed hashes are animated → `.gif`, otherwise `.png`.
    static func ext(for hash: String, preferGIF: Bool = true) -> String {
        (preferGIF && hash.hasPrefix("a_")) ? "gif" : "png"
    }

    // MARK: User / member

    public static func userAvatar(userID: Snowflake, hash: String, size: Int = 128) -> URL? {
        url("/avatars/\(userID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    /// Default avatar for a user with no custom avatar. New-username system uses
    /// `(id >> 22) % 6`; legacy discriminator users use `discriminator % 5`.
    public static func defaultAvatar(userID: Snowflake, discriminator: String) -> URL? {
        let index: UInt64
        if discriminator == "0" || discriminator.isEmpty {
            index = (userID.rawValue >> 22) % 6
        } else {
            index = UInt64(discriminator.suffix(4)).map { $0 % 5 } ?? 0
        }
        return URL(string: "\(base)/embed/avatars/\(index).png")
    }

    public static func guildMemberAvatar(guildID: Snowflake, userID: Snowflake, hash: String, size: Int = 128) -> URL? {
        url("/guilds/\(guildID.rawValue)/users/\(userID.rawValue)/avatars/\(hash).\(ext(for: hash))", size: size)
    }

    public static func userBanner(userID: Snowflake, hash: String, size: Int = 512) -> URL? {
        url("/banners/\(userID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    // MARK: Guild

    public static func guildIcon(guildID: Snowflake, hash: String, size: Int = 128) -> URL? {
        url("/icons/\(guildID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    public static func guildBanner(guildID: Snowflake, hash: String, size: Int = 512) -> URL? {
        url("/banners/\(guildID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    /// Group-DM icon (`channel.icon` hash) — `/channel-icons/{id}/{hash}.png`.
    public static func channelIcon(channelID: Snowflake, hash: String, size: Int = 64) -> URL? {
        url("/channel-icons/\(channelID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    // MARK: Emoji / sticker

    public static func emoji(id: Snowflake, animated: Bool, size: Int = 64) -> URL? {
        url("/emojis/\(id.rawValue).\(animated ? "gif" : "png")", size: size)
    }

    public static func roleIcon(roleID: Snowflake, hash: String, size: Int = 64) -> URL? {
        url("/role-icons/\(roleID.rawValue)/\(hash).\(ext(for: hash))", size: size)
    }

    public static func sticker(id: Snowflake, lottie: Bool = false) -> URL? {
        URL(string: "\(base)/stickers/\(id.rawValue).\(lottie ? "json" : "png")")
    }

    private static func url(_ path: String, size: Int) -> URL? {
        URL(string: "\(base)\(path)?size=\(clampSize(size))")
    }
}
