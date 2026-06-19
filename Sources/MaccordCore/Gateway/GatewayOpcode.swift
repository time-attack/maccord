import Foundation

/// Gateway opcodes. https://discord.com/developers/docs/topics/opcodes-and-status-codes
public enum GatewayOpcode: Int, Codable, Sendable {
    case dispatch = 0
    case heartbeat = 1
    case identify = 2
    case presenceUpdate = 3
    case voiceStateUpdate = 4
    case resume = 6
    case reconnect = 7
    case requestGuildMembers = 8
    case invalidSession = 9
    case hello = 10
    case heartbeatACK = 11
    /// Used by the official client to lazily subscribe to a guild's member list.
    case guildSubscriptions = 14
}

/// Gateway close codes. Some are recoverable (resume/reconnect), some fatal.
public enum GatewayCloseCode: Int, Sendable {
    case unknownError = 4000
    case unknownOpcode = 4001
    case decodeError = 4002
    case notAuthenticated = 4003
    case authenticationFailed = 4004   // FATAL — bad token
    case alreadyAuthenticated = 4005
    case invalidSeq = 4007
    case rateLimited = 4008
    case sessionTimedOut = 4009
    case invalidShard = 4010
    case shardingRequired = 4011
    case invalidAPIVersion = 4012
    case invalidIntents = 4013
    case disallowedIntents = 4014

    /// Whether reconnecting/resuming makes sense, vs. surfacing a fatal error.
    public var isRecoverable: Bool {
        switch self {
        case .authenticationFailed, .invalidShard, .shardingRequired,
             .invalidAPIVersion, .invalidIntents, .disallowedIntents:
            return false
        default:
            return true
        }
    }

    /// Whether a RESUME may succeed, vs. a fresh IDENTIFY being required.
    public var canResume: Bool {
        switch self {
        case .invalidSeq, .sessionTimedOut, .authenticationFailed:
            return false
        default:
            return isRecoverable
        }
    }
}

/// High-level connection state surfaced to the UI.
public enum GatewayConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case identifying
    case ready
    case resuming
    case reconnecting
    case fatal(String)
}
