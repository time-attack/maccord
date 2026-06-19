import Foundation

/// The initial presence sent inside IDENTIFY.
public struct IdentifyPresence: Encodable, Sendable {
    public let status: String
    public let since: Int
    public let activities: [String]
    public let afk: Bool

    public init(
        status: String = "online",
        since: Int = 0,
        activities: [String] = [],
        afk: Bool = false
    ) {
        self.status = status
        self.since = since
        self.activities = activities
        self.afk = afk
    }
}

/// The op 2 IDENTIFY `d` payload for a **user** account: token, capabilities,
/// super-properties, presence, compression flag, and versioned client_state.
/// User accounts send no `intents`. See `.context/research-gateway.md` §7.
public struct IdentifyPayload: Encodable, Sendable {
    public let token: String
    public let capabilities: Int
    public let properties: SuperProperties
    public let presence: IdentifyPresence
    public let compress: Bool
    public let clientState: ClientState

    public init(
        token: String,
        superProperties: SuperProperties,
        capabilities: Int = 0,
        presence: IdentifyPresence = IdentifyPresence(),
        compress: Bool = false,
        clientState: ClientState = ClientState()
    ) {
        self.token = token
        self.capabilities = capabilities
        self.properties = superProperties
        self.presence = presence
        self.compress = compress
        self.clientState = clientState
    }

    enum CodingKeys: String, CodingKey {
        case token, capabilities, properties, presence, compress
        case clientState = "client_state"
    }
}
