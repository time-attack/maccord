import Foundation

/// A voice state. https://discord.com/developers/docs/resources/voice#voice-state-object
public struct VoiceState: Codable, Hashable, Sendable, Identifiable {
    public let guildID: Snowflake?
    /// nil means the user left voice.
    public let channelID: Snowflake?
    public let userID: Snowflake
    public let member: Member?
    public let sessionID: String
    public let deaf: Bool
    public let mute: Bool
    public let selfDeaf: Bool
    public let selfMute: Bool
    public let selfStream: Bool?
    public let selfVideo: Bool
    public let suppress: Bool

    public var id: Snowflake { userID }

    enum CodingKeys: String, CodingKey {
        case member, deaf, mute, suppress
        case guildID = "guild_id"
        case channelID = "channel_id"
        case userID = "user_id"
        case sessionID = "session_id"
        case selfDeaf = "self_deaf"
        case selfMute = "self_mute"
        case selfStream = "self_stream"
        case selfVideo = "self_video"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guildID = try? c.decodeIfPresent(Snowflake.self, forKey: .guildID)
        channelID = try? c.decodeIfPresent(Snowflake.self, forKey: .channelID)
        userID = try c.decode(Snowflake.self, forKey: .userID)
        member = try? c.decodeIfPresent(Member.self, forKey: .member)
        sessionID = (try? c.decode(String.self, forKey: .sessionID)) ?? ""
        deaf = (try? c.decode(Bool.self, forKey: .deaf)) ?? false
        mute = (try? c.decode(Bool.self, forKey: .mute)) ?? false
        selfDeaf = (try? c.decode(Bool.self, forKey: .selfDeaf)) ?? false
        selfMute = (try? c.decode(Bool.self, forKey: .selfMute)) ?? false
        selfStream = try? c.decodeIfPresent(Bool.self, forKey: .selfStream)
        selfVideo = (try? c.decode(Bool.self, forKey: .selfVideo)) ?? false
        suppress = (try? c.decode(Bool.self, forKey: .suppress)) ?? false
    }
}
