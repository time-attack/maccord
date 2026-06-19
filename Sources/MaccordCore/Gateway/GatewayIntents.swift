import Foundation

/// Whether a token authenticates as a normal user account or a bot account.
/// They differ in the REST `Authorization` header (`Bot ` prefix for bots) and
/// in the gateway IDENTIFY shape (bots send `intents`; users send `capabilities`).
public enum DiscordAuthMode: String, Sendable, Codable {
    case user
    case bot
}

/// Gateway intents bitfield (bot accounts only).
/// https://discord.com/developers/docs/topics/gateway#gateway-intents
public struct GatewayIntents: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let guilds                 = GatewayIntents(rawValue: 1 << 0)
    public static let guildMembers           = GatewayIntents(rawValue: 1 << 1)   // privileged
    public static let guildModeration        = GatewayIntents(rawValue: 1 << 2)
    public static let guildEmojis            = GatewayIntents(rawValue: 1 << 3)
    public static let guildIntegrations      = GatewayIntents(rawValue: 1 << 4)
    public static let guildWebhooks          = GatewayIntents(rawValue: 1 << 5)
    public static let guildInvites           = GatewayIntents(rawValue: 1 << 6)
    public static let guildVoiceStates       = GatewayIntents(rawValue: 1 << 7)
    public static let guildPresences         = GatewayIntents(rawValue: 1 << 8)   // privileged
    public static let guildMessages          = GatewayIntents(rawValue: 1 << 9)
    public static let guildMessageReactions  = GatewayIntents(rawValue: 1 << 10)
    public static let guildMessageTyping     = GatewayIntents(rawValue: 1 << 11)
    public static let directMessages         = GatewayIntents(rawValue: 1 << 12)
    public static let directMessageReactions = GatewayIntents(rawValue: 1 << 13)
    public static let directMessageTyping    = GatewayIntents(rawValue: 1 << 14)
    public static let messageContent         = GatewayIntents(rawValue: 1 << 15)  // privileged
    public static let guildScheduledEvents   = GatewayIntents(rawValue: 1 << 16)

    /// Everything a client cares about that is NOT a privileged intent — always
    /// safe to request without portal approval.
    public static let clientNonPrivileged: GatewayIntents = [
        .guilds, .guildVoiceStates, .guildMessages, .guildMessageReactions,
        .guildMessageTyping, .directMessages, .directMessageReactions,
        .directMessageTyping, .guildEmojis,
    ]

    /// The recommended set for a client, adding each privileged intent only when
    /// the bot actually has it enabled (requesting a disabled one closes the
    /// socket with 4014, which looks like an endless reconnect loop).
    public static func recommended(messageContent: Bool, members: Bool, presences: Bool) -> GatewayIntents {
        var set = clientNonPrivileged
        if messageContent { set.insert(.messageContent) }
        if members { set.insert(.guildMembers) }
        if presences { set.insert(.guildPresences) }
        return set
    }
}

/// Connection properties a bot reports in IDENTIFY (kept minimal, unlike the
/// browser-mimicking super-properties a user client sends).
public struct BotProperties: Encodable, Sendable {
    public let os: String
    public let browser: String
    public let device: String
    public init(os: String = "macOS", browser: String = "maccord", device: String = "maccord") {
        self.os = os
        self.browser = browser
        self.device = device
    }
}

/// The op 2 IDENTIFY `d` payload for a **bot** account: token + intents +
/// minimal properties. Bots send no `capabilities`/`client_state`.
public struct BotIdentifyPayload: Encodable, Sendable {
    public let token: String
    public let intents: Int
    public let properties: BotProperties
    public let presence: IdentifyPresence
    public let compress: Bool

    public init(
        token: String,
        intents: Int,
        properties: BotProperties = BotProperties(),
        presence: IdentifyPresence = IdentifyPresence(),
        compress: Bool = false
    ) {
        self.token = token
        self.intents = intents
        self.properties = properties
        self.presence = presence
        self.compress = compress
    }
}
