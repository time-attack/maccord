import Foundation

/// A guild ban entry. https://discord.com/developers/docs/resources/guild#ban-object
public struct GuildBan: Codable, Identifiable, Sendable, Hashable {
    public let reason: String?
    public let user: User

    public var id: Snowflake { user.id }
}
