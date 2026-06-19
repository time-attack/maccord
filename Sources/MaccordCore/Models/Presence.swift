import Foundation

public enum Status: String, Codable, Sendable, Hashable, CaseIterable {
    case online
    case idle
    case dnd
    case invisible
    case offline

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Status(rawValue: raw) ?? .offline
    }

    public var label: String {
        switch self {
        case .online: "Online"
        case .idle: "Idle"
        case .dnd: "Do Not Disturb"
        case .invisible: "Invisible"
        case .offline: "Offline"
        }
    }
}

public enum ActivityType: Int, Codable, Sendable, Hashable {
    case playing = 0
    case streaming = 1
    case listening = 2
    case watching = 3
    case custom = 4
    case competing = 5

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = ActivityType(rawValue: raw) ?? .playing
    }
}

public struct ActivityTimestamps: Codable, Hashable, Sendable {
    public let start: Int?
    public let end: Int?
}

public struct ActivityAssets: Codable, Hashable, Sendable {
    public let largeImage: String?
    public let largeText: String?
    public let smallImage: String?
    public let smallText: String?
    enum CodingKeys: String, CodingKey {
        case largeImage = "large_image"
        case largeText = "large_text"
        case smallImage = "small_image"
        case smallText = "small_text"
    }
}

public struct Activity: Codable, Hashable, Sendable, Identifiable {
    public let name: String
    public let type: ActivityType
    public let url: String?
    public let state: String?
    public let details: String?
    public let applicationID: Snowflake?
    public let timestamps: ActivityTimestamps?
    public let assets: ActivityAssets?
    public let emoji: Emoji?

    enum CodingKeys: String, CodingKey {
        case name, type, url, state, details, timestamps, assets, emoji
        case applicationID = "application_id"
    }

    public var id: String { "\(name)-\(type.rawValue)" }

    public init(
        name: String, type: ActivityType, url: String? = nil, state: String? = nil,
        details: String? = nil, applicationID: Snowflake? = nil,
        timestamps: ActivityTimestamps? = nil, assets: ActivityAssets? = nil, emoji: Emoji? = nil
    ) {
        self.name = name; self.type = type; self.url = url; self.state = state
        self.details = details; self.applicationID = applicationID
        self.timestamps = timestamps; self.assets = assets; self.emoji = emoji
    }
}

public struct ClientStatus: Codable, Hashable, Sendable {
    public let desktop: String?
    public let mobile: String?
    public let web: String?
}

/// A presence update. https://discord.com/developers/docs/topics/gateway-events#presence-update
public struct Presence: Codable, Hashable, Sendable {
    public let user: PartialUser
    public let guildID: Snowflake?
    public let status: Status
    public let activities: [Activity]
    public let clientStatus: ClientStatus?

    enum CodingKeys: String, CodingKey {
        case user, status, activities
        case guildID = "guild_id"
        case clientStatus = "client_status"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(PartialUser.self, forKey: .user)
        guildID = try? c.decodeIfPresent(Snowflake.self, forKey: .guildID)
        status = (try? c.decode(Status.self, forKey: .status)) ?? .offline
        activities = (try? c.decode([Activity].self, forKey: .activities)) ?? []
        clientStatus = try? c.decodeIfPresent(ClientStatus.self, forKey: .clientStatus)
    }

    public init(user: PartialUser, guildID: Snowflake?, status: Status,
                activities: [Activity] = [], clientStatus: ClientStatus? = nil) {
        self.user = user; self.guildID = guildID; self.status = status
        self.activities = activities; self.clientStatus = clientStatus
    }

    /// The custom-status text, if the user has one set.
    public var customStatus: Activity? {
        activities.first(where: { $0.type == .custom })
    }
}

/// Presence payloads only carry the user id (and maybe partial fields).
public struct PartialUser: Codable, Hashable, Sendable, Identifiable {
    public let id: Snowflake
    public let username: String?
    public let globalName: String?
    public let avatar: String?

    public init(id: Snowflake, username: String? = nil, globalName: String? = nil, avatar: String? = nil) {
        self.id = id
        self.username = username
        self.globalName = globalName
        self.avatar = avatar
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar
        case globalName = "global_name"
    }
}
