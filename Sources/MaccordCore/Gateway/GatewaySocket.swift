import Foundation

/// The real-time Discord gateway connection.
///
/// `GatewaySocket` owns a single `URLSessionWebSocketTask`, drives the
/// heartbeat/identify/resume lifecycle, decodes every dispatch into a typed
/// ``GatewayEvent``, and publishes those over the `events` stream. The state
/// layer consumes `events`; it never touches the socket directly.
///
/// Concurrency: the public surface is actor-isolated. The `events` continuation
/// is captured in a `nonisolated let` (`AsyncStream` is `Sendable`), and every
/// background `Task` (receive loop, heartbeat, reconnect) hops back onto the
/// actor before reading or mutating state, so there are no data races.
public actor GatewaySocket {
    // MARK: - Public stream

    /// The typed event stream the state layer subscribes to.
    public nonisolated let events: AsyncStream<GatewayEvent>
    private let continuation: AsyncStream<GatewayEvent>.Continuation

    // MARK: - Connection state

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var seq: Int?
    private var sessionID: String?
    private var resumeGatewayURL: String?

    /// Stored from the most recent `connect(...)`, reused on every reconnect.
    private var token: String?
    private var superProperties: SuperProperties?
    private var capabilities: Int = 0
    /// When set, IDENTIFY uses the bot shape (token + these intents) instead of
    /// the user shape (capabilities + super-properties).
    private var botIntents: Int?

    private var heartbeatIntervalMS: Int = 0
    private var heartbeatTask: Task<Void, Never>?
    private var lastHeartbeatAcked: Bool = true

    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var connectionState: GatewayConnectionState = .disconnected
    private var reconnectAttempt: Int = 0
    /// Set by `disconnect()` so a deliberate close doesn't trigger a reconnect.
    private var intentionalDisconnect: Bool = false
    /// When true the next handshake sends RESUME; otherwise a fresh IDENTIFY.
    private var shouldResume: Bool = false

    private static let baseGatewayURL = "wss://gateway.discord.gg/?v=10&encoding=json"
    private static let queryString = "?v=10&encoding=json"

    // MARK: - Init

    public init() {
        let (stream, continuation) = AsyncStream<GatewayEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
        self.session = URLSession(configuration: .default)
        self.decoder = DiscordCoding.makeDecoder()
        self.encoder = DiscordCoding.makeEncoder()
    }

    // MARK: - Public API

    /// Open (or re-open) the connection. Stores the credentials for later
    /// reconnects, then performs a fresh IDENTIFY handshake.
    public func connect(
        token: String,
        superProperties: SuperProperties,
        capabilities: Int = 0,
        botIntents: Int? = nil
    ) async {
        MaccordLog.log("connect() mode=\(botIntents != nil ? "bot" : "user") intents=\(botIntents.map(String.init) ?? "n/a")")
        self.token = token
        self.superProperties = superProperties
        self.capabilities = capabilities
        self.botIntents = botIntents
        self.intentionalDisconnect = false
        self.shouldResume = false
        self.reconnectAttempt = 0
        await openSocket()
    }

    /// Tear down the connection intentionally (no reconnect).
    public func disconnect() async {
        intentionalDisconnect = true
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        updateState(.disconnected)
    }

    /// op 4 — join/leave/move voice + mute/deafen.
    public func updateVoiceState(
        guildID: Snowflake?, channelID: Snowflake?,
        selfMute: Bool, selfDeaf: Bool
    ) async {
        let payload = VoiceStatePayload(
            guildID: guildID, channelID: channelID,
            selfMute: selfMute, selfDeaf: selfDeaf, selfVideo: false
        )
        await sendFrame(op: .voiceStateUpdate, data: payload)
    }

    /// op 3 — update our own presence/status (online/idle/dnd/invisible) + activities.
    public func updatePresence(status: String, activities: [Activity] = [], afk: Bool = false) async {
        let payload = PresenceUpdatePayload(since: 0, activities: activities, status: status, afk: afk)
        await sendFrame(op: .presenceUpdate, data: payload)
    }

    /// op 14 — subscribe to a channel's member-list ranges, typing, presences.
    public func subscribeToMemberList(_ payload: GuildSubscribePayload) async {
        await sendFrame(op: .guildSubscriptions, data: payload)
    }

    /// op 8 — bulk request guild members (returns GUILD_MEMBERS_CHUNK dispatches).
    public func requestGuildMembers(guildID: Snowflake, query: String = "", limit: Int = 0) async {
        let payload = RequestGuildMembersPayload(
            guildID: guildID, query: query, limit: limit, presences: true
        )
        await sendFrame(op: .requestGuildMembers, data: payload)
    }

    // MARK: - Socket lifecycle

    private func openSocket() async {
        // Tear down any prior socket/heartbeat before opening a new one.
        heartbeatTask?.cancel(); heartbeatTask = nil
        receiveTask?.cancel(); receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)

        lastHeartbeatAcked = true

        let urlString: String
        if shouldResume, let resumeURL = resumeGatewayURL {
            urlString = normalizedResumeURL(resumeURL)
        } else {
            urlString = Self.baseGatewayURL
        }

        guard let url = URL(string: urlString) else {
            updateState(.fatal("Invalid gateway URL"))
            return
        }

        updateState(.connecting)

        let newTask = session.webSocketTask(with: url)
        // A user-account READY is large (all guilds hydrated) and easily exceeds
        // URLSessionWebSocketTask's 1 MB default, which fails the receive with
        // "Message too long" → endless reconnect loop. Allow up to 100 MB.
        newTask.maximumMessageSize = 100 * 1024 * 1024
        task = newTask
        newTask.resume()

        // We expect HELLO next; IDENTIFY/RESUME is sent on receipt of op 10.
        updateState(.identifying)

        startReceiveLoop()
    }

    /// Append the standard query string to a bare `resume_gateway_url`.
    private func normalizedResumeURL(_ raw: String) -> String {
        if raw.contains("?") { return raw }
        let trimmed = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        return trimmed + "/" + Self.queryString
    }

    // MARK: - Receive loop

    private func startReceiveLoop() {
        let currentTask = task
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let socket = currentTask else { break }
                do {
                    let message = try await socket.receive()
                    await self.handle(message: message)
                } catch {
                    await self.handleSocketFailure(error: error)
                    break
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) async {
        let rawData: Data
        switch message {
        case .string(let text):
            rawData = Data(text.utf8)
        case .data(let data):
            rawData = data
        @unknown default:
            return
        }

        guard let frame = try? GatewayFrame(rawData: rawData) else { return }
        await route(frame: frame)
    }

    // MARK: - Frame routing

    private func route(frame: GatewayFrame) async {
        switch frame.op {
        case GatewayOpcode.dispatch.rawValue:        // 0
            if let s = frame.sequence { seq = s }
            await dispatch(frame: frame)

        case GatewayOpcode.heartbeat.rawValue:       // 1 — server demands a beat
            await sendHeartbeat()

        case GatewayOpcode.reconnect.rawValue:       // 7 — reconnect + resume
            await reconnect(resume: true, state: .resuming)

        case GatewayOpcode.invalidSession.rawValue:  // 9 — d is a bare Bool
            let canResume = (try? frame.decodeData(Bool.self, using: decoder)) ?? false
            MaccordLog.log("op 9 INVALID_SESSION (resumable=\(canResume))")
            if canResume {
                // Wait 1–5s then resume.
                await reconnect(resume: true, state: .resuming, delay: Double.random(in: 1...5))
            } else {
                clearSession()
                await reconnect(resume: false, state: .reconnecting, delay: Double.random(in: 1...5))
            }

        case GatewayOpcode.hello.rawValue:           // 10
            await handleHello(frame: frame)

        case GatewayOpcode.heartbeatACK.rawValue:    // 11
            lastHeartbeatAcked = true

        default:
            break
        }
    }

    private func handleHello(frame: GatewayFrame) async {
        let interval = (try? frame.decodeData(HelloPayload.self, using: decoder))?.heartbeatInterval
        MaccordLog.log("op 10 HELLO heartbeat_interval=\(interval ?? -1)")
        heartbeatIntervalMS = interval ?? 41250

        startHeartbeat(intervalMS: heartbeatIntervalMS)

        // Resume if we have a live session and were asked to; otherwise identify.
        if shouldResume, let sessionID, let seq, token != nil {
            await sendResume(sessionID: sessionID, seq: seq)
        } else {
            await sendIdentify()
        }
    }

    // MARK: - Dispatch decoding

    private func dispatch(frame: GatewayFrame) async {
        guard let type = frame.type else { return }
        guard let event = decodeDispatch(type: type, frame: frame) else { return }
        continuation.yield(event)
    }

    /// Decode a known dispatch into a `GatewayEvent`. A decode failure for a known
    /// `t` is swallowed (returns `nil`) so one malformed payload never kills the
    /// stream. Side effects (caching session info, emitting `.ready`) happen here.
    private func decodeDispatch(type: String, frame: GatewayFrame) -> GatewayEvent? {
        func decode<T: Decodable>(_ t: T.Type) -> T? {
            try? frame.decodeData(t, using: decoder)
        }

        switch type {
        case "READY":
            guard let payload = decode(ReadyPayload.self) else {
                MaccordLog.log("READY received but decode FAILED")
                return nil
            }
            MaccordLog.log("READY decoded user=\(payload.user.username) guilds=\(payload.guilds.count)")
            sessionID = payload.sessionID.isEmpty ? sessionID : payload.sessionID
            if let url = payload.resumeGatewayURL { resumeGatewayURL = url }
            reconnectAttempt = 0
            shouldResume = true   // future drops should attempt RESUME first
            // Emit the connection-state change before the heavy READY payload so the
            // UI can flip out of "connecting" promptly.
            continuation.yield(.connectionState(.ready))
            connectionState = .ready
            return .ready(payload)

        case "RESUMED":
            reconnectAttempt = 0
            shouldResume = true
            continuation.yield(.connectionState(.ready))
            connectionState = .ready
            return .resumed

        case "GUILD_CREATE":
            return decode(Guild.self).map { .guildCreate($0) }
        case "GUILD_UPDATE":
            return decode(Guild.self).map { .guildUpdate($0) }
        case "GUILD_DELETE":
            return decode(UnavailableGuild.self).map { .guildDelete($0) }

        case "CHANNEL_CREATE":
            return decode(Channel.self).map { .channelCreate($0) }
        case "CHANNEL_UPDATE":
            return decode(Channel.self).map { .channelUpdate($0) }
        case "CHANNEL_DELETE":
            return decode(Channel.self).map { .channelDelete($0) }

        case "MESSAGE_CREATE":
            return decode(Message.self).map { .messageCreate($0) }
        case "MESSAGE_UPDATE":
            return decode(PartialMessage.self).map { .messageUpdate($0) }
        case "MESSAGE_DELETE":
            return decode(MessageDeleteEvent.self).map { .messageDelete($0) }
        case "MESSAGE_ACK":
            return decode(MessageAckEvent.self).map { .messageAck($0) }

        case "MESSAGE_REACTION_ADD":
            return decode(ReactionEvent.self).map { .reactionAdd($0) }
        case "MESSAGE_REACTION_REMOVE":
            return decode(ReactionEvent.self).map { .reactionRemove($0) }
        case "MESSAGE_REACTION_REMOVE_ALL":
            return decode(MessageDeleteEvent.self).map { .reactionRemoveAll($0) }

        case "TYPING_START":
            return decode(TypingStartEvent.self).map { .typingStart($0) }
        case "PRESENCE_UPDATE":
            return decode(Presence.self).map { .presenceUpdate($0) }

        case "GUILD_MEMBER_LIST_UPDATE":
            return decode(MemberListUpdate.self).map { .guildMemberListUpdate($0) }
        case "GUILD_MEMBERS_CHUNK":
            return decode(MembersChunk.self).map { .guildMembersChunk($0) }
        case "GUILD_MEMBER_ADD":
            return decode(GuildMemberEvent.self).map { .guildMemberAdd($0) }
        case "GUILD_MEMBER_UPDATE":
            return decode(GuildMemberEvent.self).map { .guildMemberUpdate($0) }
        case "GUILD_MEMBER_REMOVE":
            return decode(MemberRemoveEvent.self).map { .guildMemberRemove($0) }

        case "VOICE_STATE_UPDATE":
            return decode(VoiceState.self).map { .voiceStateUpdate($0) }
        case "VOICE_SERVER_UPDATE":
            return decode(VoiceServerUpdate.self).map { .voiceServerUpdate($0) }

        case "RELATIONSHIP_ADD":
            return decode(Relationship.self).map { .relationshipAdd($0) }
        case "RELATIONSHIP_REMOVE":
            guard let id = decode(RelationshipRemove.self)?.id else { return nil }
            return .relationshipRemove(id)

        default:
            return .unknown(type: type)
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat(intervalMS: Int) {
        heartbeatTask?.cancel()
        lastHeartbeatAcked = true
        let interval = intervalMS
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            // First beat after a jitter delay of interval * random(0...1).
            let jitterMS = Double(interval) * Double.random(in: 0...1)
            try? await Task.sleep(nanoseconds: UInt64(jitterMS * 1_000_000))
            while !Task.isCancelled {
                let shouldContinue = await self.heartbeatTick()
                if !shouldContinue { break }
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)
            }
        }
    }

    /// One heartbeat cycle, on the actor. Returns false if the loop should stop
    /// (a zombie connection was detected and reconnect handling took over).
    private func heartbeatTick() async -> Bool {
        if !lastHeartbeatAcked {
            // No ACK since the last beat — the connection is zombied.
            await reconnect(resume: true, state: .resuming)
            return false
        }
        lastHeartbeatAcked = false
        await sendHeartbeat()
        return true
    }

    private func sendHeartbeat() async {
        let payload = HeartbeatPayload(seq: seq)
        await sendFrame(op: .heartbeat, data: payload)
    }

    // MARK: - Identify / Resume

    private func sendIdentify() async {
        guard let token else { return }
        if let botIntents {
            // Bot account: token + intents, minimal properties, no capabilities.
            MaccordLog.log("sending IDENTIFY (bot) intents=\(botIntents)")
            let payload = BotIdentifyPayload(token: token, intents: botIntents)
            await sendFrame(op: .identify, data: payload)
        } else {
            guard let superProperties else { return }
            MaccordLog.log("sending IDENTIFY (user) capabilities=\(capabilities)")
            let payload = IdentifyPayload(
                token: token, superProperties: superProperties, capabilities: capabilities
            )
            await sendFrame(op: .identify, data: payload)
        }
    }

    private func sendResume(sessionID: String, seq: Int) async {
        guard let token else { return }
        let payload = ResumePayload(token: token, sessionID: sessionID, seq: seq)
        await sendFrame(op: .resume, data: payload)
    }

    // MARK: - Sending

    private func sendFrame<T: Encodable>(op: GatewayOpcode, data: T) async {
        guard let task else { return }
        let outbound = GatewayOutbound(op: op.rawValue, d: data)
        guard let encoded = try? encoder.encode(outbound),
              let json = String(data: encoded, encoding: .utf8) else {
            return
        }
        do {
            try await task.send(.string(json))
        } catch {
            await handleSocketFailure(error: error)
        }
    }

    // MARK: - Reconnection

    private func handleSocketFailure(error: Error) async {
        if intentionalDisconnect { return }

        heartbeatTask?.cancel(); heartbeatTask = nil

        // Inspect the close code if the socket reported one.
        let closeCode = task?.closeCode ?? .invalid
        MaccordLog.log("socket failure: closeCode=\(closeCode.rawValue) error=\(error.localizedDescription)")
        if let gatewayCode = mapCloseCode(closeCode) {
            if !gatewayCode.isRecoverable {
                let message = (gatewayCode == .authenticationFailed)
                    ? "Authentication failed"
                    : "Gateway closed: \(gatewayCode)"
                updateState(.fatal(message))
                return
            }
            // Recoverable, but the session may be unresumable.
            await reconnect(
                resume: gatewayCode.canResume,
                state: gatewayCode.canResume ? .resuming : .reconnecting
            )
            return
        }

        // No protocol close code (raw drop / send error): try to resume.
        await reconnect(resume: shouldResume, state: shouldResume ? .resuming : .reconnecting)
    }

    /// Map a URLSession websocket close code onto a `GatewayCloseCode` when it
    /// falls in Discord's 4000–4014 range.
    private func mapCloseCode(_ code: URLSessionWebSocketTask.CloseCode) -> GatewayCloseCode? {
        GatewayCloseCode(rawValue: code.rawValue)
    }

    /// Schedule a reconnect with exponential backoff. `resume` chooses RESUME vs
    /// fresh IDENTIFY on the next handshake.
    private func reconnect(
        resume: Bool, state: GatewayConnectionState, delay: Double? = nil
    ) async {
        if intentionalDisconnect { return }

        heartbeatTask?.cancel(); heartbeatTask = nil
        receiveTask?.cancel(); receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        shouldResume = resume && sessionID != nil && seq != nil
        updateState(state)

        // Avoid stacking multiple reconnect tasks.
        reconnectTask?.cancel()
        let backoff: Double
        if let delay {
            backoff = delay
        } else {
            backoff = min(pow(2.0, Double(reconnectAttempt)) * 1.0 + 1.0, 60.0)
            reconnectAttempt += 1
        }

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await self.performReconnect()
        }
    }

    private func performReconnect() async {
        if intentionalDisconnect { return }
        await openSocket()
    }

    private func clearSession() {
        sessionID = nil
        seq = nil
        shouldResume = false
    }

    // MARK: - State helper

    private func updateState(_ state: GatewayConnectionState) {
        MaccordLog.log("gateway state → \(state)")
        connectionState = state
        continuation.yield(.connectionState(state))
    }
}

// MARK: - Outbound wrappers

/// Generic op-wrapper for any outbound frame: `{"op": Int, "d": T}`.
private struct GatewayOutbound<T: Encodable>: Encodable {
    let op: Int
    let d: T
}

/// The op 1 heartbeat `d`: the last sequence number, or JSON `null`.
private struct HeartbeatPayload: Encodable {
    let seq: Int?
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let seq {
            try container.encode(seq)
        } else {
            try container.encodeNil()
        }
    }
}

/// The op 4 voice-state `d`.
private struct VoiceStatePayload: Encodable {
    let guildID: Snowflake?
    let channelID: Snowflake?
    let selfMute: Bool
    let selfDeaf: Bool
    let selfVideo: Bool
    enum CodingKeys: String, CodingKey {
        case guildID = "guild_id"
        case channelID = "channel_id"
        case selfMute = "self_mute"
        case selfDeaf = "self_deaf"
        case selfVideo = "self_video"
    }
}

/// The op 3 presence-update `d`.
private struct PresenceUpdatePayload: Encodable {
    let since: Int
    let activities: [Activity]
    let status: String
    let afk: Bool
}

/// The op 8 request-guild-members `d`.
private struct RequestGuildMembersPayload: Encodable {
    let guildID: Snowflake
    let query: String
    let limit: Int
    let presences: Bool
    enum CodingKeys: String, CodingKey {
        case query, limit, presences
        case guildID = "guild_id"
    }
}

/// RELATIONSHIP_REMOVE carries just an `id` (the user/relationship snowflake).
private struct RelationshipRemove: Decodable {
    let id: Snowflake
}
