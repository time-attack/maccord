import Foundation

/// The typed stream element the `GatewaySocket` actor yields and the state layer
/// consumes. This is the single contract between networking and state.
public enum GatewayEvent: Sendable {
    case connectionState(GatewayConnectionState)   // synthetic, for the UI
    case ready(ReadyPayload)
    case resumed

    case guildCreate(Guild)
    case guildUpdate(Guild)
    case guildDelete(UnavailableGuild)

    case channelCreate(Channel)
    case channelUpdate(Channel)
    case channelDelete(Channel)

    case messageCreate(Message)
    case messageUpdate(PartialMessage)
    case messageDelete(MessageDeleteEvent)
    case messageAck(MessageAckEvent)

    case reactionAdd(ReactionEvent)
    case reactionRemove(ReactionEvent)
    case reactionRemoveAll(MessageDeleteEvent)   // reuse {id,channelID,guildID}

    case typingStart(TypingStartEvent)
    case presenceUpdate(Presence)

    case guildMemberListUpdate(MemberListUpdate)
    case guildMembersChunk(MembersChunk)
    case guildMemberAdd(GuildMemberEvent)
    case guildMemberUpdate(GuildMemberEvent)
    case guildMemberRemove(MemberRemoveEvent)

    case voiceStateUpdate(VoiceState)
    case voiceServerUpdate(VoiceServerUpdate)

    case relationshipAdd(Relationship)
    case relationshipRemove(Snowflake)

    /// Forward-compat: a dispatch we don't model yet.
    case unknown(type: String)
}

// MARK: - READY

/// The initial READY dispatch. https://discord.com/developers/docs/topics/gateway-events#ready
public struct ReadyPayload: Sendable {
    public let version: Int
    public let user: CurrentUser
    public let guilds: [Guild]
    public let privateChannels: [Channel]
    public let relationships: [Relationship]
    public let readStates: [ReadState]
    public let users: [User]
    public let sessionID: String
    public let resumeGatewayURL: String?
    /// Server folders/ordering from `user_settings.guild_folders` (empty when the
    /// account only ships protobuf settings).
    public let guildFolders: [GuildFolderData]

    public init(
        version: Int, user: CurrentUser, guilds: [Guild], privateChannels: [Channel],
        relationships: [Relationship], readStates: [ReadState], users: [User],
        sessionID: String, resumeGatewayURL: String?, guildFolders: [GuildFolderData] = []
    ) {
        self.version = version; self.user = user; self.guilds = guilds
        self.privateChannels = privateChannels; self.relationships = relationships
        self.readStates = readStates; self.users = users; self.sessionID = sessionID
        self.resumeGatewayURL = resumeGatewayURL
        self.guildFolders = guildFolders
    }
}

/// A server folder (or singleton wrapper) from Discord's guild-folder settings.
/// A real folder has a `name` and/or more than one guild; a singleton wraps one
/// guild with a nil id/name.
public struct GuildFolderData: Codable, Sendable, Hashable {
    public let id: Int?
    public let name: String?
    public let color: Int?
    public let guildIDs: [Snowflake]

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case guildIDs = "guild_ids"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decodeIfPresent(Int.self, forKey: .id)
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        color = try? c.decodeIfPresent(Int.self, forKey: .color)
        guildIDs = (try? c.decode([Snowflake].self, forKey: .guildIDs)) ?? []
    }

    /// Stable identifier for SwiftUI lists.
    public var key: String {
        if let id { return "folder-\(id)" }
        return "single-\(guildIDs.first?.rawValue ?? 0)"
    }

    public var isRealFolder: Bool {
        (name != nil && !(name?.isEmpty ?? true)) || guildIDs.count > 1
    }
}

extension ReadyPayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case user, guilds, relationships, users
        case privateChannels = "private_channels"
        case readState = "read_state"
        case sessionID = "session_id"
        case resumeGatewayURL = "resume_gateway_url"
        case userSettings = "user_settings"
        case guildFolders = "guild_folders"
    }

    private struct UserSettingsContainer: Decodable {
        let guildFolders: [GuildFolderData]?
        enum CodingKeys: String, CodingKey { case guildFolders = "guild_folders" }
    }

    private struct ReadStateContainer: Decodable {
        let entries: [ReadState]?
        // Some payloads send read_state as a bare array; handle both.
        init(from decoder: Decoder) throws {
            if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
               let e = try? keyed.decodeIfPresent([ReadState].self, forKey: .entries) {
                entries = e
            } else if let arr = try? decoder.singleValueContainer().decode([ReadState].self) {
                entries = arr
            } else {
                entries = []
            }
        }
        enum CodingKeys: String, CodingKey { case entries }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 10
        user = try c.decode(CurrentUser.self, forKey: .user)
        guilds = (try? c.decode([Guild].self, forKey: .guilds)) ?? []
        privateChannels = (try? c.decode([Channel].self, forKey: .privateChannels)) ?? []
        relationships = (try? c.decode([Relationship].self, forKey: .relationships)) ?? []
        users = (try? c.decode([User].self, forKey: .users)) ?? []
        sessionID = (try? c.decode(String.self, forKey: .sessionID)) ?? ""
        resumeGatewayURL = try? c.decodeIfPresent(String.self, forKey: .resumeGatewayURL)
        if let rs = try? c.decodeIfPresent(ReadStateContainer.self, forKey: .readState) {
            readStates = rs.entries ?? []
        } else {
            readStates = []
        }
        // Folders live under user_settings.guild_folders (legacy) or, rarely, a
        // top-level guild_folders. Either is fine; proto-only accounts have neither.
        if let top = try? c.decodeIfPresent([GuildFolderData].self, forKey: .guildFolders), !top.isEmpty {
            guildFolders = top
        } else if let settings = try? c.decodeIfPresent(UserSettingsContainer.self, forKey: .userSettings) {
            guildFolders = settings.guildFolders ?? []
        } else {
            guildFolders = []
        }
    }
}

// MARK: - Message events

public struct MessageDeleteEvent: Codable, Sendable {
    public let id: Snowflake
    public let channelID: Snowflake
    public let guildID: Snowflake?
    enum CodingKeys: String, CodingKey {
        case id
        case channelID = "channel_id"
        case guildID = "guild_id"
    }
}

public struct MessageAckEvent: Codable, Sendable {
    public let channelID: Snowflake
    public let messageID: Snowflake
    public let mentionCount: Int?
    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
        case messageID = "message_id"
        case mentionCount = "mention_count"
    }
}

public struct ReactionEvent: Codable, Sendable {
    public let userID: Snowflake
    public let channelID: Snowflake
    public let messageID: Snowflake
    public let guildID: Snowflake?
    public let emoji: Emoji
    public let burst: Bool?
    enum CodingKeys: String, CodingKey {
        case emoji, burst
        case userID = "user_id"
        case channelID = "channel_id"
        case messageID = "message_id"
        case guildID = "guild_id"
    }
}

public struct TypingStartEvent: Codable, Sendable {
    public let channelID: Snowflake
    public let guildID: Snowflake?
    public let userID: Snowflake
    public let timestamp: Int
    public let member: Member?
    enum CodingKeys: String, CodingKey {
        case timestamp, member
        case channelID = "channel_id"
        case guildID = "guild_id"
        case userID = "user_id"
    }
}

// MARK: - Member events

/// GUILD_MEMBER_ADD / GUILD_MEMBER_UPDATE: a member object with a `guild_id`.
public struct GuildMemberEvent: Codable, Sendable {
    public let guildID: Snowflake
    public let member: Member
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guildID = try c.decode(Snowflake.self, forKey: .guildID)
        member = try Member(from: decoder)   // member fields are siblings of guild_id
    }
    enum CodingKeys: String, CodingKey { case guildID = "guild_id" }
}

public struct MemberRemoveEvent: Codable, Sendable {
    public let guildID: Snowflake
    public let user: User
    enum CodingKeys: String, CodingKey {
        case user
        case guildID = "guild_id"
    }
}

public struct MembersChunk: Codable, Sendable {
    public let guildID: Snowflake
    public let members: [Member]
    public let chunkIndex: Int
    public let chunkCount: Int
    public let presences: [Presence]?
    enum CodingKeys: String, CodingKey {
        case members, presences
        case guildID = "guild_id"
        case chunkIndex = "chunk_index"
        case chunkCount = "chunk_count"
    }
}

// MARK: - Voice

public struct VoiceServerUpdate: Codable, Sendable {
    public let token: String
    public let guildID: Snowflake?
    public let endpoint: String?
    enum CodingKeys: String, CodingKey {
        case token, endpoint
        case guildID = "guild_id"
    }
}
