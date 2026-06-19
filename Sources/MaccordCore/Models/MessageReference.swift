import Foundation

/// A reference to another message (reply or forward).
/// https://discord.com/developers/docs/resources/channel#message-reference-object
public struct MessageReference: Codable, Hashable, Sendable {
    /// 0 = default (reply), 1 = forward.
    public let type: Int?
    public let messageID: Snowflake?
    public let channelID: Snowflake?
    public let guildID: Snowflake?
    public let failIfNotExists: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case messageID = "message_id"
        case channelID = "channel_id"
        case guildID = "guild_id"
        case failIfNotExists = "fail_if_not_exists"
    }

    public init(
        type: Int? = 0, messageID: Snowflake?, channelID: Snowflake? = nil,
        guildID: Snowflake? = nil, failIfNotExists: Bool? = false
    ) {
        self.type = type; self.messageID = messageID; self.channelID = channelID
        self.guildID = guildID; self.failIfNotExists = failIfNotExists
    }

    public static func reply(to messageID: Snowflake, in channelID: Snowflake,
                             guildID: Snowflake? = nil, failIfNotExists: Bool = false) -> MessageReference {
        MessageReference(type: 0, messageID: messageID, channelID: channelID,
                         guildID: guildID, failIfNotExists: failIfNotExists)
    }

    /// A forward reference (type 1) — the target channel posts a snapshot of the
    /// source message.
    public static func forward(messageID: Snowflake, channelID: Snowflake,
                               guildID: Snowflake? = nil) -> MessageReference {
        MessageReference(type: 1, messageID: messageID, channelID: channelID,
                         guildID: guildID, failIfNotExists: false)
    }
}

/// Controls which mentions in a message actually ping.
/// https://discord.com/developers/docs/resources/channel#allowed-mentions-object
public struct AllowedMentions: Codable, Hashable, Sendable {
    public let parse: [String]
    public let roles: [Snowflake]?
    public let users: [Snowflake]?
    public let repliedUser: Bool?

    enum CodingKeys: String, CodingKey {
        case parse, roles, users
        case repliedUser = "replied_user"
    }

    public init(parse: [String] = ["users", "roles", "everyone"], roles: [Snowflake]? = nil,
                users: [Snowflake]? = nil, repliedUser: Bool? = true) {
        self.parse = parse; self.roles = roles; self.users = users; self.repliedUser = repliedUser
    }

    /// Mirror Discord's default: ping everything parsed, ping the replied user.
    public static let `default` = AllowedMentions()
    /// Suppress the @reply ping (used when replying without mentioning).
    public static let silentReply = AllowedMentions(repliedUser: false)
}
