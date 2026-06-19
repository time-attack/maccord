import Foundation
import Observation
import AppKit
import MaccordCore

/// Root application state. Owns the networking actors, the normalized caches and
/// the sub-stores, and pumps gateway events into them on the main actor.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case loading        // checking keychain
        case login          // needs a token
        case app            // authenticated
    }

    // Auth / connection
    var phase: Phase = .loading
    var loginError: String?
    var isLoggingIn = false
    var connection: GatewayConnectionState = .disconnected

    // Identity + normalized caches
    var currentUser: CurrentUser?
    /// Our own presence/status (online by default; changeable from the user panel).
    var currentUserStatus: Status = .online
    var guildStores: [Snowflake: GuildStore] = [:]
    var guildOrder: [Snowflake] = []
    /// Server-rail folders + singletons, in display order (empty → flat layout).
    var guildFolders: [GuildFolder] = []

    struct GuildFolder: Identifiable, Sendable {
        let id: String
        let name: String?
        let color: Int?
        let guildIDs: [Snowflake]
        var isRealFolder: Bool { (name?.isEmpty == false) || guildIDs.count > 1 }
    }
    var channelsByID: [Snowflake: Channel] = [:]
    var usersByID: [Snowflake: User] = [:]
    var dms: [Channel] = []
    var relationships: [Snowflake: Relationship] = [:]

    // Sub-stores
    let presences = PresenceStore()
    let readState = ReadStateStore()
    let typing = TypingStore()
    let voice = VoiceStore()
    let members = MemberStore()
    let userNotes = UserNotesStore()

    // UI toggles
    var showMemberList = true
    var showQuickSwitcher = false
    var showKeybinds = false
    /// Whether the app is the active (focused) application — gates notifications.
    var isWindowActive = true
    var scrollToMessageID: Snowflake?
    /// Briefly flashed message after a jump (pins / replies / search results).
    var highlightedMessageID: Snowflake?
    var hiddenMessageEmbeds: Set<Snowflake> = []
    var nsfwAcknowledged: Set<Snowflake> = []
    var channelMuteUntil: [Snowflake: Date] = [:]
    var customStatusText = ""
    /// A message queued for forwarding; the composer shows a forward bar and the
    /// next send posts it (plus any typed note) to the current channel.
    var forwarding: Message?
    /// Per-channel composer drafts, restored when you return to a channel.
    var drafts: [Snowflake: String] = [:]
    /// Most-recently-opened channels (newest first), for the quick switcher.
    var recentChannels: [Snowflake] = []
    /// Most-recently-used emoji (newest first), for the picker's "Recent" tab.
    var recentEmojis: [Emoji] = []

    func recordRecentEmoji(_ emoji: Emoji) {
        recentEmojis.removeAll { $0.reactionKey == emoji.reactionKey }
        recentEmojis.insert(emoji, at: 0)
        if recentEmojis.count > 36 { recentEmojis.removeLast(recentEmojis.count - 36) }
    }

    // User preferences (Settings).
    var prefEnableNotifications = true
    var prefCompactMessages = false
    var prefDeveloperMode = true
    var prefTwentyFourHourTime = false
    var prefAnimateEmoji = true
    var prefShowLinkPreview = true
    var prefShowEmbeds = true
    var prefInlineMedia = true
    var prefPlayNotificationSound = true
    var prefShowUnreadBadge = true
    var prefMessageFontScale: Double = 1.0
    var prefSpellcheck = true
    var prefShiftEnterNewline = false
    var prefShowActivity = true
    /// Per-channel "you left off here" anchor (the acked message id at open time),
    /// used to draw the red NEW divider where unread began.
    var unreadBoundaries: [Snowflake: Snowflake] = [:]

    /// True when the logged-in token is a bot token. Bots can't use the user-only
    /// lazy member list (op 14) or read-state ack, so those are gated off.
    var isBotAccount = false

    // Selection (nil guild = Home/DMs)
    var selectedGuildID: Snowflake?
    var selectedChannelID: Snowflake?
    /// Remember the last channel viewed per guild.
    private var lastChannelByGuild: [Snowflake: Snowflake] = [:]

    // Networking
    let rest: RESTClient
    let gateway: GatewaySocket
    let tokenStore: TokenStore
    let superProperties: SuperProperties

    private var messageStores: [Snowflake: MessageStore] = [:]
    private var pump: Task<Void, Never>?
    private var lastTypingSent: [Snowflake: Date] = [:]
    private var lastSendAt: [Snowflake: Date] = [:]
    private var pendingReadAcks: [Snowflake: Task<Void, Never>] = [:]
    private var highlightClearTask: Task<Void, Never>?
    /// Guards against repeated bootstraps (e.g. multiple restored windows each
    /// firing `.task`) and overlapping connects, which would churn the socket.
    private var hasBootstrapped = false
    private var isEstablishing = false

    init(superProperties: SuperProperties = SuperProperties()) {
        self.superProperties = superProperties
        self.rest = RESTClient(superProperties: superProperties)
        self.gateway = GatewaySocket()
        self.tokenStore = TokenStore()
    }

    // MARK: Lifecycle

    func bootstrap() async {
        MaccordLog.log("AppState.bootstrap() called (hasBootstrapped=\(hasBootstrapped))")
        guard !hasBootstrapped else {
            MaccordLog.log("AppState.bootstrap() ignored — already bootstrapped")
            return
        }
        hasBootstrapped = true
        loadPrefs()
        startAutosave()
        observeAppActivation()
        startEventPump()
        NotificationService.shared.requestAuthorization()
        NotificationService.shared.onOpen = { [weak self] channelID, messageID in
            Task { @MainActor in await self?.openFromNotification(channelID, messageID) }
        }
        // Diagnostic override: drive the real app with a token from the environment
        // (used to reproduce gateway issues headlessly). Remove once stable.
        if let envToken = ProcessInfo.processInfo.environment["MACCORD_TOKEN"],
           !envToken.isEmpty {
            MaccordLog.log("bootstrap() using MACCORD_TOKEN override")
            do { try await establish(token: envToken) }
            catch {
                MaccordLog.log("bootstrap() env-token establish failed: \(error)")
                loginError = authErrorMessage(error); phase = .login
            }
            return
        }
        if let token = await tokenStore.currentToken(), TokenStore.looksValid(token) {
            do {
                try await establish(token: token)
            } catch {
                try? await tokenStore.clear()
                loginError = "Your saved token is no longer valid — please log in again."
                phase = .login
            }
        } else {
            phase = .login
        }
    }

    func logIn(token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TokenStore.looksValid(trimmed) else {
            loginError = "That doesn't look like a valid Discord token."
            return
        }
        MaccordLog.log("AppState.logIn() called")
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }
        do {
            try await establish(token: trimmed)
            try? await tokenStore.store(trimmed)   // only persist a token that worked
        } catch {
            loginError = authErrorMessage(error)
            phase = .login
        }
    }

    func logOut() async {
        await gateway.disconnect()
        try? await tokenStore.clear()
        await rest.clearToken()
        resetState()
        phase = .login
    }

    /// Validate the token (detecting bot vs user), then open the gateway with the
    /// matching IDENTIFY. Throws if the token is invalid.
    private func establish(token: String) async throws {
        if isEstablishing {
            MaccordLog.log("establish() ignored — a connect is already in flight")
            return
        }
        isEstablishing = true
        defer { isEstablishing = false }
        MaccordLog.log("establish() authenticating…")
        let auth = try await rest.authenticate(token: token)
        isBotAccount = auth.mode == .bot
        currentUser = auth.user
        usersByID[auth.user.id] = auth.user.asUser
        phase = .app
        MaccordLog.log("establish() authenticated as \(auth.user.username) mode=\(auth.mode.rawValue)")

        let botIntents = isBotAccount ? await rest.recommendedBotIntents() : nil
        MaccordLog.log("establish() connecting gateway, botIntents=\(botIntents.map(String.init) ?? "nil")")
        await gateway.connect(
            token: token,
            superProperties: superProperties,
            capabilities: Int(GatewayCapabilities.m1Default.rawValue),
            botIntents: botIntents
        )
    }

    private func authErrorMessage(_ error: Error) -> String {
        if let rest = error as? RESTError {
            switch rest {
            case .http(401, _, _), .notAuthenticated:
                return "That token was rejected by Discord (401). Double-check it's a current, valid token."
            case .http(let status, _, let message):
                return message ?? "Login failed (HTTP \(status))."
            case .transport(let detail):
                return "Couldn't reach Discord: \(detail)"
            default:
                return "Login failed. Please check the token and your connection."
            }
        }
        return "Login failed. Please check the token and your connection."
    }

    private func resetState() {
        guildStores = [:]
        guildOrder = []
        guildFolders = []
        myMembers = [:]
        channelsByID = [:]
        usersByID = [:]
        dms = []
        relationships = [:]
        selectedGuildID = nil
        selectedChannelID = nil
        messageStores = [:]
        currentUser = nil
        isBotAccount = false
    }

    private func startEventPump() {
        guard pump == nil else { return }
        let stream = gateway.events
        pump = Task { [weak self] in
            for await event in stream {
                guard let self else { break }
                EventApplier.apply(event, to: self)
            }
        }
    }

    // MARK: Derived accessors

    var orderedGuilds: [Guild] {
        guildOrder.compactMap { guildStores[$0]?.meta }
    }

    var selectedGuildStore: GuildStore? {
        guard let id = selectedGuildID else { return nil }
        return guildStores[id]
    }

    var selectedChannel: Channel? {
        guard let id = selectedChannelID else { return nil }
        return channelsByID[id]
    }

    func messageStore(for channelID: Snowflake) -> MessageStore {
        if let store = messageStores[channelID] { return store }
        let store = MessageStore(
            channelID: channelID,
            guildID: channelsByID[channelID]?.guildID,
            rest: rest
        )
        messageStores[channelID] = store
        return store
    }

    var currentMessageStore: MessageStore? {
        guard let id = selectedChannelID else { return nil }
        return messageStore(for: id)
    }

    func displayName(for userID: Snowflake) -> String {
        usersByID[userID]?.displayName ?? "Unknown"
    }

    /// Fetch the full profile (badges, banner, bio, pronouns, connections, mutual
    /// servers) for the profile popover. Returns nil on failure.
    func userProfile(for id: Snowflake) async -> UserProfile? {
        try? await rest.getUserProfile(id, guildID: selectedGuildID)
    }

    /// Change our own presence/status and broadcast it over the gateway.
    func setStatus(_ status: Status) {
        currentUserStatus = status
        if let id = currentUser?.id {
            presences.set(Presence(user: PartialUser(id: id, username: nil, globalName: nil, avatar: nil),
                                   guildID: nil, status: status))
        }
        Task { await pushPresence() }
    }

    /// Set a custom status line (Discord's "Custom Status" activity).
    func setCustomStatus(_ text: String) {
        customStatusText = text
        Task { await pushPresence() }
    }

    private func pushPresence() async {
        var activities: [Activity] = []
        if !customStatusText.isEmpty {
            activities.append(Activity(name: "Custom Status", type: .custom, url: nil,
                                       state: customStatusText, details: nil, applicationID: nil,
                                       timestamps: nil, assets: nil, emoji: nil))
        }
        await gateway.updatePresence(status: currentUserStatus.rawValue, activities: activities)
    }

    /// Scroll to (and briefly highlight) a message — used by replies, pinned
    /// messages and search results. Switches channels and loads a window around
    /// the target first when it isn't already on screen.
    func jumpToMessage(_ id: Snowflake, in channelID: Snowflake? = nil) {
        Task { await performJump(to: id, inChannel: channelID ?? selectedChannelID) }
    }

    private func performJump(to id: Snowflake, inChannel channelID: Snowflake?) async {
        guard let channelID else { return }
        if selectedChannelID != channelID {
            if let gid = channelsByID[channelID]?.guildID { selectedGuildID = gid }
            await selectChannel(channelID)
        }
        let store = messageStore(for: channelID)
        if !store.messages.contains(where: { $0.id == id }) {
            await store.loadAround(messageID: id)
        }
        scrollToMessageID = id
        flashHighlight(id)
    }

    /// Pulse a message's background for a couple of seconds after jumping to it.
    private func flashHighlight(_ id: Snowflake) {
        highlightedMessageID = id
        highlightClearTask?.cancel()
        highlightClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled, let self, self.highlightedMessageID == id else { return }
            self.highlightedMessageID = nil
        }
    }

    func markChannelUnread(_ channelID: Snowflake) {
        let store = messageStore(for: channelID)
        let anchor = store.messages.dropLast().last?.id ?? store.messages.last?.id
        readState.markUnread(channelID, before: anchor)
    }

    func isChannelMuted(_ channelID: Snowflake) -> Bool {
        if mutedChannels.contains(channelID) { return true }
        if let until = channelMuteUntil[channelID], until > Date() { return true }
        if let until = channelMuteUntil[channelID], until <= Date() { channelMuteUntil[channelID] = nil }
        return false
    }

    func muteChannel(_ channelID: Snowflake, duration: TimeInterval?) {
        if let duration { channelMuteUntil[channelID] = Date().addingTimeInterval(duration) }
        else { mutedChannels.insert(channelID) }
    }

    func unmuteChannel(_ channelID: Snowflake) {
        mutedChannels.remove(channelID)
        channelMuteUntil[channelID] = nil
    }

    func hideEmbeds(for messageID: Snowflake) { hiddenMessageEmbeds.insert(messageID) }

    func acknowledgeNSFW(_ channelID: Snowflake) { nsfwAcknowledged.insert(channelID) }

    func threads(in channelID: Snowflake) -> [Channel] {
        guard let gid = channelsByID[channelID]?.guildID,
              let store = guildStores[gid] else { return [] }
        return store.channels.values
            .filter { $0.parentID == channelID && $0.type.isThread }
            .sorted { ($0.lastMessageID?.rawValue ?? 0) > ($1.lastMessageID?.rawValue ?? 0) }
    }

    func blockUser(_ userID: Snowflake) async {
        if let rel = try? await rest.blockUser(userID) {
            relationships[userID] = rel
        }
    }

    func unblockUser(_ userID: Snowflake) async {
        try? await rest.removeRelationship(userID: userID)
        relationships[userID] = nil
    }

    func isBlocked(_ userID: Snowflake) -> Bool {
        relationships[userID]?.type == .blocked
    }

    var blockedUsers: [Relationship] {
        relationships.values.filter { $0.type == .blocked }.sorted {
            ($0.user?.displayName ?? "") < ($1.user?.displayName ?? "")
        }
    }

    // MARK: Moderation

    func canKick(in guildID: Snowflake) -> Bool { hasGuildPerm(guildID, [.kickMembers]) }
    func canBan(in guildID: Snowflake) -> Bool { hasGuildPerm(guildID, [.banMembers]) }
    func canTimeout(in guildID: Snowflake) -> Bool { hasGuildPerm(guildID, [.moderateMembers]) }
    func canManageRoles(in guildID: Snowflake) -> Bool { hasGuildPerm(guildID, [.manageRoles]) }

    /// True when the current user owns the guild, is an admin, or holds any of the
    /// given guild-level permissions.
    private func hasGuildPerm(_ guildID: Snowflake, _ any: [Permissions]) -> Bool {
        if guildStores[guildID]?.meta.ownerID == currentUser?.id { return true }
        guard let store = guildStores[guildID], let me = currentUser?.id,
              let roleIDs = myRoleIDs(in: guildID) else { return false }
        let probe = store.defaultChannel ?? store.channels.values.first { $0.type.isTextLike }
        guard let channel = probe else { return false }
        let perms = store.effectivePermissions(channel, myRoleIDs: roleIDs, myUserID: me)
        if perms.contains(.administrator) { return true }
        return any.contains { perms.contains($0) }
    }

    func kickMember(_ userID: Snowflake, in guildID: Snowflake) async {
        try? await rest.kickMember(guildID: guildID, userID: userID)
    }
    func banMember(_ userID: Snowflake, in guildID: Snowflake, deleteMessageDays: Int = 0) async {
        try? await rest.banMember(guildID: guildID, userID: userID,
                                  deleteMessageSeconds: deleteMessageDays * 86_400)
    }
    func unbanMember(_ userID: Snowflake, in guildID: Snowflake) async {
        try? await rest.unbanMember(guildID: guildID, userID: userID)
    }
    func timeoutMember(_ userID: Snowflake, in guildID: Snowflake, minutes: Int) async {
        let until = minutes > 0 ? Date().addingTimeInterval(TimeInterval(minutes) * 60) : nil
        try? await rest.timeoutMember(guildID: guildID, userID: userID, until: until)
    }
    func bans(in guildID: Snowflake) async -> [GuildBan] {
        (try? await rest.getBans(guildID: guildID)) ?? []
    }

    // MARK: Group DMs

    func createGroupDM(with userIDs: [Snowflake]) async {
        guard !userIDs.isEmpty, let dm = try? await rest.createGroupDM(recipientIDs: userIDs) else { return }
        channelsByID[dm.id] = dm
        if !dms.contains(where: { $0.id == dm.id }) { dms.insert(dm, at: 0) }
        for r in dm.recipients ?? [] { usersByID[r.id] = r }
        selectGuild(nil)
        await selectChannel(dm.id)
    }

    /// Close a DM or leave a group DM.
    func closeDM(_ channelID: Snowflake) async {
        try? await rest.closeChannel(channelID)
        dms.removeAll { $0.id == channelID }
        channelsByID[channelID] = nil
        if selectedChannelID == channelID { selectedChannelID = nil }
    }

    func profileLink(for userID: Snowflake) -> String {
        "https://discord.com/users/\(userID.rawValue)"
    }

    func adjustChatZoom(delta: Double) {
        prefMessageFontScale = min(1.35, max(0.75, prefMessageFontScale + delta))
    }

    // MARK: Selection

    func selectGuild(_ guildID: Snowflake?) {
        selectedGuildID = guildID
        if let guildID, let store = guildStores[guildID] {
            Task { await hydrateGuildIfNeeded(guildID) }
            let target = lastChannelByGuild[guildID] ?? store.defaultChannel?.id
            if let target { Task { await selectChannel(target) } }
            else { selectedChannelID = nil }
        } else {
            // Home / DMs
            selectedChannelID = nil
        }
    }

    func selectChannel(_ channelID: Snowflake) async {
        selectedChannelID = channelID
        recentChannels.removeAll { $0 == channelID }
        recentChannels.insert(channelID, at: 0)
        if recentChannels.count > 8 { recentChannels.removeLast(recentChannels.count - 8) }
        if let guildID = selectedGuildID {
            lastChannelByGuild[guildID] = channelID
            // Ensure roles + our own member (for channel visibility) are loaded,
            // including for the guild auto-selected on launch.
            Task { await hydrateGuildIfNeeded(guildID) }
        }
        // Capture where unread began (before marking read) so the list can draw a
        // NEW divider; then clear the unread indicator immediately.
        let preOpenNewest = channelsByID[channelID]?.lastMessageID
        if let preOpenNewest, let acked = readState.ackedID(channelID), preOpenNewest > acked {
            unreadBoundaries[channelID] = acked
        } else {
            unreadBoundaries[channelID] = nil
        }
        if let preOpenNewest {
            markReadLocally(channelID: channelID, upTo: preOpenNewest, ackServer: false)
        }

        let store = messageStore(for: channelID)
        await store.loadInitialIfNeeded()

        // Subscribe the member list for guild text channels (op 14). This is a
        // user-only gateway feature; bots have no lazy member list, so skip it.
        if !isBotAccount, let guildID = selectedGuildID,
           let channel = channelsByID[channelID], channel.type.isTextLike {
            members.reset(guildID: guildID, channelID: channelID)
            await subscribeMembers(guildID: guildID, channelID: channelID, upTo: 200)
        }

        // History is authoritative for newest — channel.lastMessageID can lag.
        if let latest = store.messages.last?.id {
            readState.noteLatest(channelID, latest)
            syncChannelLastMessage(channelID, messageID: latest)
            markReadLocally(channelID: channelID, upTo: latest, ackServer: true)
        }
    }

    /// Mark a channel read locally and optionally debounce a server ack.
    func markReadLocally(channelID: Snowflake, upTo messageID: Snowflake, ackServer: Bool) {
        readState.markRead(channelID: channelID, upTo: messageID)
        if selectedChannelID == channelID { unreadBoundaries[channelID] = nil }
        updateDockBadge()
        guard ackServer, !isBotAccount else { return }
        pendingReadAcks[channelID]?.cancel()
        pendingReadAcks[channelID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            try? await self.rest.ackMessage(channelID: channelID, messageID: messageID)
        }
    }

    /// Called when the user scrolls to the present — keep read state in sync.
    func acknowledgeVisibleRead(in channelID: Snowflake) {
        guard selectedChannelID == channelID,
              let latest = messageStore(for: channelID).messages.last?.id
                ?? channelsByID[channelID]?.lastMessageID else { return }
        readState.noteLatest(channelID, latest)
        markReadLocally(channelID: channelID, upTo: latest, ackServer: true)
    }

    private func syncChannelLastMessage(_ channelID: Snowflake, messageID: Snowflake) {
        guard var channel = channelsByID[channelID] else { return }
        if (channel.lastMessageID ?? Snowflake(0)) >= messageID { return }
        channel = Channel(
            id: channel.id, type: channel.type, guildID: channel.guildID, position: channel.position,
            name: channel.name, topic: channel.topic, nsfw: channel.nsfw, lastMessageID: messageID,
            bitrate: channel.bitrate, userLimit: channel.userLimit,
            rateLimitPerUser: channel.rateLimitPerUser, recipients: channel.recipients,
            icon: channel.icon, ownerID: channel.ownerID, parentID: channel.parentID,
            permissionOverwrites: channel.permissionOverwrites,
            lastPinTimestamp: channel.lastPinTimestamp, memberCount: channel.memberCount
        )
        channelsByID[channelID] = channel
        if let gid = channel.guildID { guildStores[gid]?.upsert(channel: channel) }
    }

    // MARK: Actions

    func sendMessage(content: String, replyingTo reference: MessageReference? = nil,
                     allowedMentions: AllowedMentions? = nil) async {
        guard let channelID = selectedChannelID,
              let user = currentUser,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isSlowmodeBlocked(in: channelID) else { return }
        let nonce = String(UInt64.random(in: 0...UInt64.max))
        let store = messageStore(for: channelID)
        let optimistic = Message(
            id: Snowflake(timestampMS: UInt64(Date().timeIntervalSince1970 * 1000)),
            channelID: channelID,
            guildID: channelsByID[channelID]?.guildID,
            author: user.asUser,
            content: content,
            type: reference == nil ? .default : .reply,
            messageReference: reference,
            nonce: nonce,
            isPending: true
        )
        store.insertOptimistic(optimistic)
        do {
            _ = try await rest.createMessage(
                channelID: channelID,
                content: content,
                messageReference: reference,
                allowedMentions: allowedMentions ?? .default,
                nonce: nonce
            )
            lastSendAt[channelID] = Date()
            // The MESSAGE_CREATE gateway echo reconciles via nonce.
        } catch {
            store.markFailed(nonce: nonce)
        }
    }

    /// Forward a message to a channel (optionally with an accompanying note).
    func forwardMessage(_ message: Message, to channelID: Snowflake, note: String) async {
        let ref = MessageReference.forward(
            messageID: message.id, channelID: message.channelID, guildID: message.guildID
        )
        let nonce = String(UInt64.random(in: 0...UInt64.max))
        _ = try? await rest.createMessage(
            channelID: channelID, content: note, messageReference: ref,
            allowedMentions: .default, nonce: nonce
        )
        forwarding = nil
    }

    func toggleReaction(messageID: Snowflake, emoji: Emoji) async {
        guard let channelID = selectedChannelID else { return }
        guard canAddReactions(in: channelID) else { return }
        if emoji.isCustom, let guildID = emojiGuildID(emoji), !canUseEmoji(emoji, fromGuild: guildID, in: channelID) {
            return
        }
        let store = messageStore(for: channelID)
        let wasMine = store.messages.first(where: { $0.id == messageID })?
            .reactions.first(where: { $0.emoji.reactionKey == emoji.reactionKey })?.me ?? false
        store.toggleReactionLocally(messageID: messageID, emoji: emoji)
        do {
            if wasMine {
                try await rest.removeOwnReaction(channelID: channelID, messageID: messageID, emoji: emoji)
            } else {
                try await rest.addReaction(channelID: channelID, messageID: messageID, emoji: emoji)
            }
        } catch {
            // Revert on failure.
            store.toggleReactionLocally(messageID: messageID, emoji: emoji)
        }
    }

    func deleteMessage(_ messageID: Snowflake) async {
        guard let channelID = selectedChannelID else { return }
        try? await rest.deleteMessage(channelID: channelID, messageID: messageID)
    }

    func editMessage(_ messageID: Snowflake, content: String) async {
        guard let channelID = selectedChannelID else { return }
        // The MESSAGE_UPDATE gateway echo reconciles the displayed message.
        _ = try? await rest.editMessage(channelID: channelID, messageID: messageID, content: content)
    }

    func pinMessage(_ messageID: Snowflake, pinned: Bool) async {
        guard let channelID = selectedChannelID else { return }
        if pinned {
            try? await rest.unpinMessage(channelID: channelID, messageID: messageID)
        } else {
            try? await rest.pinMessage(channelID: channelID, messageID: messageID)
        }
    }

    func loadPins(for channelID: Snowflake) async -> [Message] {
        (try? await rest.getPins(channelID: channelID)) ?? []
    }

    /// Who reacted to a message with a given emoji (reaction-details popover).
    func reactionUsers(channelID: Snowflake, messageID: Snowflake, emoji: Emoji) async -> [User] {
        (try? await rest.getReactionUsers(channelID: channelID, messageID: messageID,
                                          emoji: emoji, limit: 100)) ?? []
    }

    /// Create an invite link for a specific channel (channel right-click → Invite).
    func createChannelInvite(_ channelID: Snowflake) async -> String? {
        try? await rest.createInvite(channelID: channelID)
    }

    /// A discord.com deep link to a message (for "Copy Message Link").
    func messageLink(_ message: Message) -> String {
        let guild = message.guildID?.description ?? "@me"
        return "https://discord.com/channels/\(guild)/\(message.channelID.rawValue)/\(message.id.rawValue)"
    }

    func channelLink(_ channel: Channel) -> String {
        let guild = channel.guildID?.description ?? "@me"
        return "https://discord.com/channels/\(guild)/\(channel.id.rawValue)"
    }

    /// Mark a single channel fully read (right-click → Mark As Read).
    func markChannelRead(_ channelID: Snowflake) async {
        let newest = messageStore(for: channelID).messages.last?.id
            ?? channelsByID[channelID]?.lastMessageID
        guard let newest else { return }
        readState.noteLatest(channelID, newest)
        markReadLocally(channelID: channelID, upTo: newest, ackServer: true)
    }

    /// Mark every text channel in a guild read (server header → Mark As Read).
    func markGuildRead(_ guildID: Snowflake) async {
        guard let store = guildStores[guildID] else { return }
        for channel in store.channels.values where channel.type.isTextLike {
            guard readState.isUnread(channel.id) else { continue }
            let newest = messageStore(for: channel.id).messages.last?.id ?? channel.lastMessageID
            guard let newest else { continue }
            readState.noteLatest(channel.id, newest)
            markReadLocally(channelID: channel.id, upTo: newest, ackServer: true)
        }
    }

    /// Local per-channel mute (UI-only; server mute settings are a later milestone).
    var mutedChannels: Set<Snowflake> = []
    func toggleChannelMute(_ channelID: Snowflake) {
        if mutedChannels.contains(channelID) { mutedChannels.remove(channelID) }
        else { mutedChannels.insert(channelID) }
    }

    // MARK: Server settings / notifications (local)

    enum NotificationLevel: String, CaseIterable, Identifiable, Sendable {
        case all, mentions, nothing
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All Messages"
            case .mentions: "Only @mentions"
            case .nothing: "Nothing"
            }
        }
    }

    var guildNotificationLevels: [Snowflake: NotificationLevel] = [:]
    var mutedGuilds: Set<Snowflake> = []
    /// Sheet routing for the server settings / notification windows.
    var serverSettingsGuildID: Snowflake?
    var notificationSettingsGuildID: Snowflake?

    func notificationLevel(_ guildID: Snowflake) -> NotificationLevel {
        guildNotificationLevels[guildID] ?? .all
    }
    func setNotificationLevel(_ level: NotificationLevel, for guildID: Snowflake) {
        guildNotificationLevels[guildID] = level
    }
    func toggleGuildMute(_ guildID: Snowflake) {
        if mutedGuilds.contains(guildID) { mutedGuilds.remove(guildID) }
        else { mutedGuilds.insert(guildID) }
    }

    // MARK: Search / leave / invite / hydration

    // Search sheet routing.
    var showSearch = false
    var searchSeed = ""

    func search(_ query: String, filters: SearchFilters = SearchFilters()) async -> [Message] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let hasFilters = filters.authorID != nil || filters.has != nil || filters.pinned != nil || filters.mentions != nil
        guard !q.isEmpty || hasFilters else { return [] }

        func once() async -> [Message] {
            do {
                if let guildID = selectedGuildID {
                    return try await rest.searchGuildMessages(guildID: guildID, query: q, filters: filters)
                } else if let channelID = selectedChannelID {
                    return try await rest.searchChannelMessages(channelID: channelID, query: q, filters: filters)
                }
            } catch {
                MaccordLog.log("search error: \(error)")
            }
            return []
        }

        var results = await once()
        // Discord returns 202/empty while it builds the search index — retry once.
        if results.isEmpty {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            results = await once()
        }
        MaccordLog.log("search '\(q)' guild=\(selectedGuildID?.description ?? "nil") → \(results.count) results")
        return results
    }

    func leaveGuild(_ guildID: Snowflake) async {
        try? await rest.leaveGuild(guildID)
        guildStores[guildID] = nil
        guildOrder.removeAll { $0 == guildID }
        guildFolders.removeAll { $0.guildIDs == [guildID] }
        if selectedGuildID == guildID { selectGuild(nil) }
    }

    /// Open (or create) a DM with a user and switch to it.
    func openDM(with userID: Snowflake) async {
        guard let dm = try? await rest.openDM(recipientID: userID) else { return }
        channelsByID[dm.id] = dm
        if !dms.contains(where: { $0.id == dm.id }) { dms.insert(dm, at: 0) }
        for r in dm.recipients ?? [] { usersByID[r.id] = r }
        selectGuild(nil)
        await selectChannel(dm.id)
    }

    func createInvite(forGuild guildID: Snowflake) async -> String? {
        guard let channel = guildStores[guildID]?.defaultChannel
            ?? channelsByID.values.first(where: { $0.guildID == guildID && $0.type.isTextLike })
        else { return nil }
        return try? await rest.createInvite(channelID: channel.id)
    }

    /// True when the current user owns or can manage the guild.
    func canManageGuild(_ guildID: Snowflake) -> Bool {
        if guildStores[guildID]?.meta.ownerID == currentUser?.id { return true }
        guard let store = guildStores[guildID],
              let me = currentUser?.id,
              let roleIDs = myRoleIDs(in: guildID) else { return false }
        let probe = store.defaultChannel ?? store.channels.values.first { $0.type.isTextLike }
        guard let channel = probe else { return false }
        let perms = store.effectivePermissions(channel, myRoleIDs: roleIDs, myUserID: me)
        return perms.contains(.administrator) || perms.contains(.manageGuild)
    }

    /// Our effective permissions in a channel (nil when roles aren't loaded yet).
    func effectivePermissions(in channelID: Snowflake) -> Permissions? {
        guard let channel = channelsByID[channelID], let gid = channel.guildID,
              let store = guildStores[gid], let me = currentUser?.id,
              let roleIDs = myRoleIDs(in: gid) else { return nil }
        return store.effectivePermissions(channel, myRoleIDs: roleIDs, myUserID: me)
    }

    func canSendMessages(in channelID: Snowflake) -> Bool {
        guard let channel = channelsByID[channelID] else { return true }
        if channel.type.isDM { return true }
        guard let perms = effectivePermissions(in: channelID) else { return true }  // fail open
        return perms.contains(.sendMessages)
    }

    func canAddReactions(in channelID: Snowflake) -> Bool {
        guard let channel = channelsByID[channelID] else { return true }
        if channel.type.isDM { return true }
        guard let perms = effectivePermissions(in: channelID) else { return true }
        return perms.contains(.addReactions)
    }

    func canUseExternalEmojis(in channelID: Snowflake) -> Bool {
        guard let channel = channelsByID[channelID], channel.guildID != nil else { return true }
        guard let perms = effectivePermissions(in: channelID) else { return true }
        return perms.contains(.useExternalEmojis) || perms.contains(.administrator)
    }

    /// Whether a custom emoji from `guildID` may be used in the current channel.
    func canUseEmoji(_ emoji: Emoji, fromGuild guildID: Snowflake, in channelID: Snowflake) -> Bool {
        guard emoji.isCustom else { return true }
        if guildID == channelsByID[channelID]?.guildID { return true }
        return canUseExternalEmojis(in: channelID)
    }

    /// Resolve which guild owns a custom emoji (for permission checks).
    func emojiGuildID(_ emoji: Emoji) -> Snowflake? {
        guard let id = emoji.id else { return nil }
        for (gid, store) in guildStores {
            if store.meta.emojis.contains(where: { $0.id == id }) { return gid }
        }
        return selectedGuildID
    }

    /// Slowmode doesn't apply to admins/owners or those who can manage messages/channels/guild.
    func isSlowmodeExempt(in channelID: Snowflake) -> Bool {
        guard let channel = channelsByID[channelID], let gid = channel.guildID else { return true }
        if guildStores[gid]?.meta.ownerID == currentUser?.id { return true }
        guard let perms = effectivePermissions(in: channelID) else { return false }
        return perms.contains(.administrator)
            || perms.contains(.manageMessages)
            || perms.contains(.manageChannels)
            || perms.contains(.manageGuild)
    }

    /// Seconds until the user can send again (0 = ready).
    func slowmodeRemaining(in channelID: Snowflake) -> Int {
        guard let channel = channelsByID[channelID],
              channel.slowmodeSeconds > 0,
              !isSlowmodeExempt(in: channelID),
              let last = lastSendAt[channelID] else { return 0 }
        let elapsed = Int(Date().timeIntervalSince(last))
        return max(0, channel.slowmodeSeconds - elapsed)
    }

    func isSlowmodeBlocked(in channelID: Snowflake) -> Bool {
        slowmodeRemaining(in: channelID) > 0
    }

    func canDeleteMessage(_ message: Message) -> Bool {
        if message.author.id == currentUser?.id { return true }
        guard let perms = effectivePermissions(in: message.channelID) else { return false }
        return perms.contains(.manageMessages) || perms.contains(.administrator)
    }

    // MARK: Friends

    var friends: [Relationship] {
        relationships.values.filter { $0.type == .friend }.sorted {
            ($0.user?.displayName ?? "") < ($1.user?.displayName ?? "")
        }
    }

    var incomingFriendRequests: [Relationship] {
        relationships.values.filter { $0.type == .incomingRequest }
    }

    var outgoingFriendRequests: [Relationship] {
        relationships.values.filter { $0.type == .outgoingRequest }
    }

    var onlineFriends: [Relationship] {
        friends.filter { rel in
            guard let id = rel.user?.id else { return false }
            return presences.status(id) == .online || presences.status(id) == .idle
        }
    }

    func refreshRelationships() async {
        guard !isBotAccount, let list = try? await rest.getRelationships() else { return }
        relationships = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        for rel in list {
            if let user = rel.user { usersByID[user.id] = user }
        }
    }

    func sendFriendRequest(username: String) async throws {
        let rel = try await rest.sendFriendRequest(username: username.trimmingCharacters(in: .whitespaces))
        relationships[rel.id] = rel
        if let user = rel.user { usersByID[user.id] = user }
    }

    func acceptFriendRequest(_ userID: Snowflake) async {
        if let rel = try? await rest.acceptFriendRequest(userID: userID) {
            relationships[userID] = rel
            if let user = rel.user { usersByID[user.id] = user }
        }
    }

    func removeFriend(_ userID: Snowflake) async {
        try? await rest.removeRelationship(userID: userID)
        relationships[userID] = nil
    }

    func showFriendsHome() {
        selectedGuildID = nil
        selectedChannelID = nil
    }

    /// op14 member-list ranges as 100-row windows up to `count`.
    private func memberRanges(upTo count: Int) -> [ClosedRange<Int>] {
        let ceiling = max(99, ((max(0, count - 1)) / 100 + 1) * 100 - 1)
        return stride(from: 0, through: ceiling, by: 100).map { $0...($0 + 99) }
    }

    func subscribeMembers(guildID: Snowflake, channelID: Snowflake, upTo count: Int) async {
        await gateway.subscribeToMemberList(GuildSubscribePayload(
            guildID: guildID, channelID: channelID, ranges: memberRanges(upTo: count)
        ))
    }

    /// Load the next window of members when the list is scrolled to the bottom.
    func extendMemberList() async {
        guard !isBotAccount,
              let g = members.subscribedGuildID, let c = members.subscribedChannelID else { return }
        let loaded = members.rows.count
        guard loaded < members.memberCount else { return }
        await subscribeMembers(guildID: g, channelID: c, upTo: loaded + 100)
    }

    /// The current user's member object per guild (roles), for permission checks.
    var myMembers: [Snowflake: Member] = [:]
    func myRoleIDs(in guildID: Snowflake) -> [Snowflake]? { myMembers[guildID]?.roles }

    /// Fetch roles/channels/own-member for a guild whose READY didn't hydrate them.
    func hydrateGuildIfNeeded(_ guildID: Snowflake) async {
        guard let store = guildStores[guildID] else { return }
        // Roles: refetch when only @everyone is present (so colors/lists work).
        if store.roles.count <= 1, let roles = try? await rest.fetchGuildRoles(guildID) {
            for role in roles { store.roles[role.id] = role }
        }
        if store.channels.isEmpty, let channels = try? await rest.getGuildChannels(guildID) {
            for channel in channels {
                let c = channel.withGuildID(guildID)
                store.channels[c.id] = c
                channelsByID[c.id] = c
            }
        }
        // Our own roles (for hiding channels we can't view).
        if myMembers[guildID] == nil, let me = try? await rest.getCurrentMember(guildID: guildID) {
            myMembers[guildID] = me
        }
    }

    // MARK: Platform integration

    /// Reflect the unread mention count in the Dock badge.
    func updateDockBadge() {
        guard prefShowUnreadBadge else { NSApplication.shared.dockTile.badgeLabel = nil; return }
        let count = readState.totalMentions
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }

    private func observeAppActivation() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isWindowActive = true }
        }
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isWindowActive = false }
        }
    }

    /// Open a channel/message from a clicked notification.
    func openFromNotification(_ channelID: Snowflake, _ messageID: Snowflake?) async {
        selectedGuildID = channelsByID[channelID]?.guildID
        await selectChannel(channelID)
        if let messageID { jumpToMessage(messageID, in: channelID) }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// Alt+Up / Alt+Down: cycle through the current guild's text channels (or DMs).
    func selectAdjacentChannel(_ delta: Int) {
        let candidates: [Snowflake]
        if let guildID = selectedGuildID, let store = guildStores[guildID] {
            candidates = store.channels.values
                .filter { $0.type.isTextLike }
                .sorted { ($0.position ?? 0, $0.id.rawValue) < ($1.position ?? 0, $1.id.rawValue) }
                .map(\.id)
        } else {
            candidates = dms.map(\.id)
        }
        guard !candidates.isEmpty else { return }
        let idx = candidates.firstIndex { $0 == selectedChannelID } ?? 0
        let next = (idx + delta + candidates.count) % candidates.count
        Task { await selectChannel(candidates[next]) }
    }

    /// Upload one or more files to the current channel (drag-drop / paste).
    func sendAttachments(_ files: [FilePart], content: String = "") async {
        guard let channelID = selectedChannelID, !files.isEmpty else { return }
        _ = try? await rest.createMessage(
            channelID: channelID, content: content, messageReference: nil,
            allowedMentions: .default, nonce: String(UInt64.random(in: 0...UInt64.max)), files: files
        )
    }

    /// Close any open overlay (Esc).
    func dismissOverlays() {
        showQuickSwitcher = false
        showKeybinds = false
        showSearch = false
    }

    // MARK: Preferences persistence

    private static let prefsKey = "maccord.prefs.v1"

    private struct PersistedPrefs: Codable {
        var enableNotifications = true
        var compactMessages = false
        var developerMode = true
        var twentyFourHourTime = false
        var animateEmoji = true
        var showLinkPreview = true
        var showEmbeds = true
        var inlineMedia = true
        var playNotificationSound = true
        var showUnreadBadge = true
        var messageFontScale = 1.0
        var spellcheck = true
        var shiftEnterNewline = false
        var showActivity = true
        var status = "online"
        var customStatus = ""
        var mutedChannels: [UInt64] = []
        var mutedGuilds: [UInt64] = []
        var notificationLevels: [String: String] = [:]
        var drafts: [String: String] = [:]
    }

    func loadPrefs() {
        guard let data = UserDefaults.standard.data(forKey: Self.prefsKey),
              let p = try? JSONDecoder().decode(PersistedPrefs.self, from: data) else { return }
        prefEnableNotifications = p.enableNotifications
        prefCompactMessages = p.compactMessages
        prefDeveloperMode = p.developerMode
        prefTwentyFourHourTime = p.twentyFourHourTime
        prefAnimateEmoji = p.animateEmoji
        prefShowLinkPreview = p.showLinkPreview
        prefShowEmbeds = p.showEmbeds
        prefInlineMedia = p.inlineMedia
        prefPlayNotificationSound = p.playNotificationSound
        prefShowUnreadBadge = p.showUnreadBadge
        prefMessageFontScale = p.messageFontScale
        prefSpellcheck = p.spellcheck
        prefShiftEnterNewline = p.shiftEnterNewline
        prefShowActivity = p.showActivity
        currentUserStatus = Status(rawValue: p.status) ?? .online
        customStatusText = p.customStatus
        mutedChannels = Set(p.mutedChannels.map { Snowflake($0) })
        mutedGuilds = Set(p.mutedGuilds.map { Snowflake($0) })
        guildNotificationLevels = Dictionary(uniqueKeysWithValues: p.notificationLevels.compactMap { key, value in
            guard let id = Snowflake(string: key), let lvl = NotificationLevel(rawValue: value) else { return nil }
            return (id, lvl)
        })
        drafts = Dictionary(uniqueKeysWithValues: p.drafts.compactMap { key, value in
            guard let id = Snowflake(string: key) else { return nil }
            return (id, value)
        })
    }

    func savePrefs() {
        let p = PersistedPrefs(
            enableNotifications: prefEnableNotifications, compactMessages: prefCompactMessages,
            developerMode: prefDeveloperMode, twentyFourHourTime: prefTwentyFourHourTime,
            animateEmoji: prefAnimateEmoji, showLinkPreview: prefShowLinkPreview,
            showEmbeds: prefShowEmbeds, inlineMedia: prefInlineMedia,
            playNotificationSound: prefPlayNotificationSound, showUnreadBadge: prefShowUnreadBadge,
            messageFontScale: prefMessageFontScale, spellcheck: prefSpellcheck,
            shiftEnterNewline: prefShiftEnterNewline, showActivity: prefShowActivity,
            status: currentUserStatus.rawValue, customStatus: customStatusText,
            mutedChannels: mutedChannels.map(\.rawValue), mutedGuilds: mutedGuilds.map(\.rawValue),
            notificationLevels: Dictionary(uniqueKeysWithValues:
                guildNotificationLevels.map { ($0.key.description, $0.value.rawValue) }),
            drafts: Dictionary(uniqueKeysWithValues: drafts.map { ($0.key.description, $0.value) })
        )
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: Self.prefsKey)
        }
    }

    private func startAutosave() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { break }
                self.savePrefs()
            }
        }
    }

    /// Throttled typing indicator (Discord expects ~once per 8–10s).
    func notifyTyping() {
        guard let channelID = selectedChannelID else { return }
        let now = Date()
        if let last = lastTypingSent[channelID], now.timeIntervalSince(last) < 8 { return }
        lastTypingSent[channelID] = now
        Task { try? await rest.triggerTyping(channelID: channelID) }
    }
}
