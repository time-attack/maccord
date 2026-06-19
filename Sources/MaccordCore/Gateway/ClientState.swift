import Foundation

/// The `client_state` object in IDENTIFY. On first connect we send zero/empty/`-1`
/// values so the server ships full state; persisting and replaying the returned
/// versions later yields delta-only updates. See `.context/research-gateway.md` §7.
public struct ClientState: Encodable, Sendable {
    public let guildVersions: [String: Int]
    public let highestLastMessageID: String
    public let readStateVersion: Int
    public let userGuildSettingsVersion: Int
    public let privateChannelsVersion: String
    public let apiCodeVersion: Int

    public init(
        guildVersions: [String: Int] = [:],
        highestLastMessageID: String = "0",
        readStateVersion: Int = 0,
        userGuildSettingsVersion: Int = -1,
        privateChannelsVersion: String = "0",
        apiCodeVersion: Int = 0
    ) {
        self.guildVersions = guildVersions
        self.highestLastMessageID = highestLastMessageID
        self.readStateVersion = readStateVersion
        self.userGuildSettingsVersion = userGuildSettingsVersion
        self.privateChannelsVersion = privateChannelsVersion
        self.apiCodeVersion = apiCodeVersion
    }

    enum CodingKeys: String, CodingKey {
        case guildVersions = "guild_versions"
        case highestLastMessageID = "highest_last_message_id"
        case readStateVersion = "read_state_version"
        case userGuildSettingsVersion = "user_guild_settings_version"
        case privateChannelsVersion = "private_channels_version"
        case apiCodeVersion = "api_code_version"
    }
}
