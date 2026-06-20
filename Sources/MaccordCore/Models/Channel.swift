import Foundation

public enum ChannelType: Int, Codable, Sendable, Hashable {
    case text = 0
    case dm = 1
    case voice = 2
    case groupDM = 3
    case category = 4
    case announcement = 5
    case announcementThread = 10
    case publicThread = 11
    case privateThread = 12
    case stageVoice = 13
    case directory = 14
    case forum = 15
    case media = 16

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = ChannelType(rawValue: raw) ?? .text
    }

    public var isVoice: Bool { self == .voice || self == .stageVoice }
    public var isThread: Bool { self == .publicThread || self == .privateThread || self == .announcementThread }
    public var isTextLike: Bool { self == .text || self == .announcement || self == .forum || self == .media || isThread }
    public var isDM: Bool { self == .dm || self == .groupDM }
}

/// A permission overwrite on a channel. `type` 0=role, 1=member.
public struct PermissionOverwrite: Codable, Hashable, Sendable, Identifiable {
    public let id: Snowflake
    public let type: Int
    public let allow: Permissions
    public let deny: Permissions
}

/// A channel — guild text/voice/category/thread, or a DM/group DM.
/// https://discord.com/developers/docs/resources/channel
public struct Channel: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let type: ChannelType
    public let guildID: Snowflake?
    public let position: Int?
    public let name: String?
    public let topic: String?
    public let nsfw: Bool?
    public let lastMessageID: Snowflake?
    public let bitrate: Int?
    public let userLimit: Int?
    public let rateLimitPerUser: Int?
    public let recipients: [User]?
    public let icon: String?
    public let ownerID: Snowflake?
    public let parentID: Snowflake?
    public let permissionOverwrites: [PermissionOverwrite]?
    public let lastPinTimestamp: Date?
    public let memberCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, position, name, topic, nsfw, bitrate, recipients, icon
        case guildID = "guild_id"
        case lastMessageID = "last_message_id"
        case userLimit = "user_limit"
        case rateLimitPerUser = "rate_limit_per_user"
        case ownerID = "owner_id"
        case parentID = "parent_id"
        case permissionOverwrites = "permission_overwrites"
        case lastPinTimestamp = "last_pin_timestamp"
        case memberCount = "member_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        type = (try? c.decode(ChannelType.self, forKey: .type)) ?? .text
        guildID = try? c.decodeIfPresent(Snowflake.self, forKey: .guildID)
        position = try? c.decodeIfPresent(Int.self, forKey: .position)
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        topic = try? c.decodeIfPresent(String.self, forKey: .topic)
        nsfw = try? c.decodeIfPresent(Bool.self, forKey: .nsfw)
        lastMessageID = try? c.decodeIfPresent(Snowflake.self, forKey: .lastMessageID)
        bitrate = try? c.decodeIfPresent(Int.self, forKey: .bitrate)
        userLimit = try? c.decodeIfPresent(Int.self, forKey: .userLimit)
        rateLimitPerUser = try? c.decodeIfPresent(Int.self, forKey: .rateLimitPerUser)
        recipients = try? c.decodeIfPresent([User].self, forKey: .recipients)
        icon = try? c.decodeIfPresent(String.self, forKey: .icon)
        ownerID = try? c.decodeIfPresent(Snowflake.self, forKey: .ownerID)
        parentID = try? c.decodeIfPresent(Snowflake.self, forKey: .parentID)
        permissionOverwrites = try? c.decodeIfPresent([PermissionOverwrite].self, forKey: .permissionOverwrites)
        lastPinTimestamp = try? c.decodeIfPresent(Date.self, forKey: .lastPinTimestamp)
        memberCount = try? c.decodeIfPresent(Int.self, forKey: .memberCount)
    }

    public init(
        id: Snowflake, type: ChannelType, guildID: Snowflake? = nil, position: Int? = nil,
        name: String? = nil, topic: String? = nil, nsfw: Bool? = nil,
        lastMessageID: Snowflake? = nil, bitrate: Int? = nil, userLimit: Int? = nil,
        rateLimitPerUser: Int? = nil, recipients: [User]? = nil, icon: String? = nil,
        ownerID: Snowflake? = nil, parentID: Snowflake? = nil,
        permissionOverwrites: [PermissionOverwrite]? = nil, lastPinTimestamp: Date? = nil,
        memberCount: Int? = nil
    ) {
        self.id = id; self.type = type; self.guildID = guildID; self.position = position
        self.name = name; self.topic = topic; self.nsfw = nsfw
        self.lastMessageID = lastMessageID; self.bitrate = bitrate; self.userLimit = userLimit
        self.rateLimitPerUser = rateLimitPerUser; self.recipients = recipients; self.icon = icon
        self.ownerID = ownerID; self.parentID = parentID
        self.permissionOverwrites = permissionOverwrites; self.lastPinTimestamp = lastPinTimestamp
        self.memberCount = memberCount
    }

    /// A display name for any channel type, including computed DM names.
    public func displayName(currentUserID: Snowflake?) -> String {
        if let name, !name.isEmpty { return name }
        switch type {
        case .dm:
            let other = recipients?.first(where: { $0.id != currentUserID }) ?? recipients?.first
            return other?.displayName ?? "Direct Message"
        case .groupDM:
            let names = (recipients ?? []).map { $0.displayName }
            return names.isEmpty ? "Group" : names.joined(separator: ", ")
        default:
            return "channel"
        }
    }

    /// Group-DM icon, or first recipient avatar for a 1:1 DM.
    public func iconURL(currentUserID: Snowflake?, size: Int = 64) -> URL? {
        switch type {
        case .dm:
            let other = recipients?.first(where: { $0.id != currentUserID }) ?? recipients?.first
            return other?.avatarURL(size: size)
        case .groupDM:
            if let icon { return DiscordCDN.channelIcon(channelID: id, hash: icon, size: size) }
            // No custom group icon → fall back to a member's avatar.
            let other = recipients?.first(where: { $0.id != currentUserID }) ?? recipients?.first
            return other?.avatarURL(size: size)
        default:
            return nil
        }
    }

    /// The "other" party of a 1:1 DM (used for presence dots / profile links).
    public func otherRecipient(currentUserID: Snowflake?) -> User? {
        recipients?.first(where: { $0.id != currentUserID }) ?? recipients?.first
    }

    public var slowmodeSeconds: Int { rateLimitPerUser ?? 0 }
}
