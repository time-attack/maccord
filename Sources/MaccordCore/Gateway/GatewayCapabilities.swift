import Foundation

/// Gateway `capabilities` bitfield sent in IDENTIFY. Each bit opts the client into
/// a behavior that **changes the shape of READY**, so they must be set with care.
///
/// See `.context/research-gateway.md` §7. For maccord's first cut we send
/// ``m1Default`` (`0`) to receive a fully-hydrated READY (each guild carries its
/// own `members`/`presences`, single READY, no protobuf settings).
public struct GatewayCapabilities: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Drops `notes` from READY (fetch lazily).
    public static let lazyUserNotification = GatewayCapabilities(rawValue: 1 << 0)
    /// Don't auto-sync members/presences.
    public static let noAffineUserIDs = GatewayCapabilities(rawValue: 1 << 1)
    /// Versioned read states (delta updates).
    public static let versionedReadStates = GatewayCapabilities(rawValue: 1 << 2)
    /// Versioned guild settings.
    public static let versionedUserGuildSettings = GatewayCapabilities(rawValue: 1 << 3)
    /// Dehydrates READY: per-guild members/presences collapse into top-level
    /// `merged_members` / `merged_presences` + a shared `users` array.
    public static let dedupeUserObjects = GatewayCapabilities(rawValue: 1 << 4)
    /// Splits into READY (fast, minimal) + READY_SUPPLEMENTAL (rest).
    public static let prioritizedReadyPayload = GatewayCapabilities(rawValue: 1 << 5)
    /// Changes experiment populations format.
    public static let multipleGuildExperimentPopulations = GatewayCapabilities(rawValue: 1 << 6)
    /// Adds non-channel read states.
    public static let nonChannelReadStates = GatewayCapabilities(rawValue: 1 << 7)
    /// Enables token refresh.
    public static let authTokenRefresh = GatewayCapabilities(rawValue: 1 << 8)
    /// User settings delivered as base64 protobuf (`user_settings_proto`).
    public static let userSettingsProto = GatewayCapabilities(rawValue: 1 << 9)
    /// Client-state caching v2.
    public static let clientStateV2 = GatewayCapabilities(rawValue: 1 << 10)
    /// Passive guild updates (deltas instead of full GUILD_CREATE re-sends).
    public static let passiveGuildUpdate = GatewayCapabilities(rawValue: 1 << 11)

    /// Fully-hydrated READY: every guild self-contained, single READY payload.
    /// The safest default until the dedupe/supplemental merge logic exists.
    public static let m1Default: GatewayCapabilities = []
}
