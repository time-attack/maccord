import Foundation
import MaccordCore

extension Channel {
    /// READY nests channels inside guilds without a `guild_id`; backfill it.
    func withGuildID(_ guildID: Snowflake) -> Channel {
        guard self.guildID == nil else { return self }
        return Channel(
            id: id, type: type, guildID: guildID, position: position, name: name,
            topic: topic, nsfw: nsfw, lastMessageID: lastMessageID, bitrate: bitrate,
            userLimit: userLimit, rateLimitPerUser: rateLimitPerUser, recipients: recipients,
            icon: icon, ownerID: ownerID, parentID: parentID,
            permissionOverwrites: permissionOverwrites, lastPinTimestamp: lastPinTimestamp,
            memberCount: memberCount
        )
    }
}

/// Applies a `GatewayEvent` to the `AppState` stores. The single place gateway
/// data turns into observable mutations — keeps `AppState` thin and testable.
enum EventApplier {
    @MainActor
    static func apply(_ event: GatewayEvent, to app: AppState) {
        switch event {

        case .connectionState(let state):
            app.connection = state
            if case .fatal = state {
                // Bad token — drop to the login screen.
                Task { await app.logOut() }
            }

        case .ready(let ready):
            applyReady(ready, to: app)

        case .resumed:
            break

        case .guildCreate(let guild):
            upsertGuild(guild, to: app)
            // Bots receive guilds here (after a READY full of unavailable stubs),
            // so this is where their first server gets auto-opened.
            maybeAutoSelect(app)

        case .guildUpdate(let guild):
            if let store = app.guildStores[guild.id] {
                store.update(meta: guild)
            } else {
                upsertGuild(guild, to: app)
            }

        case .guildDelete(let unavailable):
            app.guildStores[unavailable.id] = nil
            app.guildOrder.removeAll { $0 == unavailable.id }

        case .channelCreate(let channel), .channelUpdate(let channel):
            indexChannel(channel, to: app)

        case .channelDelete(let channel):
            app.channelsByID[channel.id] = nil
            if let gid = channel.guildID { app.guildStores[gid]?.remove(channelID: channel.id) }

        case .messageCreate(let message):
            applyMessageCreate(message, to: app)

        case .messageUpdate(let partial):
            app.messageStore(for: partial.channelID).update(partial)

        case .messageDelete(let event):
            app.messageStore(for: event.channelID).delete(event.id)

        case .messageAck(let ack):
            app.readState.markRead(channelID: ack.channelID, upTo: ack.messageID)

        case .reactionAdd(let event):
            app.messageStore(for: event.channelID)
                .applyReactionEvent(event, add: true, currentUserID: app.currentUser?.id)

        case .reactionRemove(let event):
            app.messageStore(for: event.channelID)
                .applyReactionEvent(event, add: false, currentUserID: app.currentUser?.id)

        case .reactionRemoveAll(let event):
            app.messageStore(for: event.channelID).clearReactions(messageID: event.id)

        case .typingStart(let event):
            let name = event.member?.displayName ?? app.usersByID[event.userID]?.displayName
            app.typing.start(event, displayName: name)

        case .presenceUpdate(let presence):
            app.presences.set(presence)

        case .guildMemberListUpdate(let update):
            if app.members.subscribedGuildID == update.guildID {
                app.members.apply(update)
            }
            // Cache members for author role-color lookups.
            if let store = app.guildStores[update.guildID] {
                for case .member(let entry) in app.members.rows { store.upsertMember(entry.member) }
            }

        case .guildMembersChunk(let chunk):
            let store = app.guildStores[chunk.guildID]
            for member in chunk.members {
                if let user = member.user { app.usersByID[user.id] = user }
                store?.upsertMember(member)
            }

        case .guildMemberAdd(let event), .guildMemberUpdate(let event):
            if let user = event.member.user { app.usersByID[user.id] = user }
            app.guildStores[event.guildID]?.upsertMember(event.member)

        case .guildMemberRemove:
            break

        case .voiceStateUpdate(let state):
            app.voice.apply(state)
            if state.userID == app.currentUser?.id {
                app.voice.connectedChannelID = state.channelID
            }

        case .voiceServerUpdate:
            break  // voice transport is a later milestone

        case .relationshipAdd(let relationship):
            app.relationships[relationship.id] = relationship
            if let user = relationship.user { app.usersByID[user.id] = user }

        case .relationshipRemove(let id):
            app.relationships[id] = nil

        case .unknown:
            break
        }
    }

    // MARK: READY

    @MainActor
    private static func applyReady(_ ready: ReadyPayload, to app: AppState) {
        app.currentUser = ready.user
        app.usersByID[ready.user.id] = ready.user.asUser

        for user in ready.users { app.usersByID[user.id] = user }
        for relationship in ready.relationships { app.relationships[relationship.id] = relationship }

        app.readState.loadReadStates(ready.readStates)
        app.presences.load(from: ready.guilds)
        app.voice.load(from: ready.guilds)

        app.guildStores = [:]
        app.guildOrder = []
        for guild in ready.guilds where guild.unavailable != true {
            upsertGuild(guild, to: app)
        }

        // Folders + folder-defined ordering (when the account ships them).
        app.guildFolders = ready.guildFolders.map { folder in
            AppState.GuildFolder(id: folder.key, name: folder.name, color: folder.color, guildIDs: folder.guildIDs)
        }
        if !app.guildFolders.isEmpty {
            let ordered = app.guildFolders.flatMap(\.guildIDs).filter { app.guildStores[$0] != nil }
            let seen = Set(ordered)
            app.guildOrder = ordered + app.guildOrder.filter { !seen.contains($0) }
        }
        MaccordLog.log("READY guildFolders=\(app.guildFolders.count) guilds=\(app.guildOrder.count)")

        // DMs.
        app.dms = ready.privateChannels.sorted {
            ($0.lastMessageID?.rawValue ?? 0) > ($1.lastMessageID?.rawValue ?? 0)
        }
        for dm in app.dms {
            app.channelsByID[dm.id] = dm
            for recipient in dm.recipients ?? [] { app.usersByID[recipient.id] = recipient }
        }

        // Seed "newest known message" for every channel so unread badges are
        // correct against the acked read-state from READY.
        for (id, channel) in app.channelsByID {
            app.readState.noteLatest(id, channel.lastMessageID)
        }

        // Auto-select the first guild with an openable channel (user accounts get
        // hydrated guilds in READY; bots open via maybeAutoSelect on GUILD_CREATE).
        maybeAutoSelect(app)
        if !app.isBotAccount {
            Task { await app.refreshRelationships() }
        }
    }

    /// Open the first guild's default channel if nothing is selected yet.
    @MainActor
    private static func maybeAutoSelect(_ app: AppState) {
        guard app.selectedChannelID == nil else { return }
        for guildID in app.guildOrder {
            if let store = app.guildStores[guildID], let channel = store.defaultChannel {
                app.selectedGuildID = guildID
                Task { await app.selectChannel(channel.id) }
                return
            }
        }
    }

    @MainActor
    private static func upsertGuild(_ guild: Guild, to app: AppState) {
        if let store = app.guildStores[guild.id] {
            store.update(meta: guild)
            for channel in guild.channels { indexChannel(channel.withGuildID(guild.id), to: app) }
        } else {
            let store = GuildStore(guild: guild)
            app.guildStores[guild.id] = store
            if !app.guildOrder.contains(guild.id) { app.guildOrder.append(guild.id) }
            for channel in guild.channels { app.channelsByID[channel.id] = channel.withGuildID(guild.id) }
            for thread in guild.threads { app.channelsByID[thread.id] = thread.withGuildID(guild.id) }
            for member in guild.members {
                if let user = member.user { app.usersByID[user.id] = user }
            }
        }
    }

    @MainActor
    private static func indexChannel(_ channel: Channel, to app: AppState) {
        app.channelsByID[channel.id] = channel
        if let gid = channel.guildID { app.guildStores[gid]?.upsert(channel: channel) }
        app.readState.noteLatest(channel.id, channel.lastMessageID)
    }

    @MainActor
    private static func applyMessageCreate(_ message: Message, to app: AppState) {
        app.usersByID[message.author.id] = message.author
        app.messageStore(for: message.channelID).append(message)
        app.typing.clear(userID: message.author.id, channelID: message.channelID)

        // Cache the author's guild member (with roles) — REST history lacks it.
        if let gid = message.guildID, let store = app.guildStores[gid], let m = message.member {
            store.upsertMember(Member(
                user: message.author, nick: m.nick, avatar: m.avatar, roles: m.roles,
                joinedAt: m.joinedAt, premiumSince: m.premiumSince, deaf: m.deaf, mute: m.mute,
                pending: m.pending, communicationDisabledUntil: m.communicationDisabledUntil, flags: m.flags
            ))
        }

        // Advance the channel's lastMessageID for unread rollups.
        if var channel = app.channelsByID[message.channelID] {
            channel = channelWithLastMessage(channel, message.id)
            app.channelsByID[message.channelID] = channel
            if let gid = channel.guildID { app.guildStores[gid]?.upsert(channel: channel) }
        }

        app.readState.noteLatest(message.channelID, message.id)
        let isActive = app.selectedChannelID == message.channelID
        let isMine = message.author.id == app.currentUser?.id
        if isMine || isActive {
            // Our own message, or we're viewing the channel → keep it read.
            app.readState.markRead(channelID: message.channelID, upTo: message.id)
            if isActive { app.unreadBoundaries[message.channelID] = nil }
        } else {
            let mentioned = message.mentionEveryone
                || message.mentions.contains { $0.id == app.currentUser?.id }
            app.readState.bumpUnread(channelID: message.channelID, messageID: message.id, mentioned: mentioned)
            app.updateDockBadge()

            // Native notification for direct mentions / DMs, honoring channel mute,
            // server mute, the server's notification level, and whether we're
            // already looking at that channel in the focused window.
            let isDM = app.channelsByID[message.channelID]?.type.isDM ?? false
            let muted = app.mutedChannels.contains(message.channelID)
            let guildMuted = message.guildID.map { app.mutedGuilds.contains($0) } ?? false
            let level = message.guildID.map { app.notificationLevel($0) } ?? .all
            let focusedHere = app.isWindowActive && app.selectedChannelID == message.channelID
            if app.prefEnableNotifications && !muted && !guildMuted && level != .nothing
                && (mentioned || isDM) && !focusedHere {
                let server = message.guildID.flatMap { app.guildStores[$0]?.meta.name }
                NotificationService.shared.notify(
                    title: message.author.displayName,
                    subtitle: server,
                    body: message.content.isEmpty ? "Sent an attachment" : message.content,
                    channelID: message.channelID,
                    messageID: message.id,
                    avatarURL: message.author.avatarURL(size: 128),
                    playSound: app.prefPlayNotificationSound
                )
            }
        }
    }

    private static func channelWithLastMessage(_ channel: Channel, _ id: Snowflake) -> Channel {
        Channel(
            id: channel.id, type: channel.type, guildID: channel.guildID, position: channel.position,
            name: channel.name, topic: channel.topic, nsfw: channel.nsfw, lastMessageID: id,
            bitrate: channel.bitrate, userLimit: channel.userLimit,
            rateLimitPerUser: channel.rateLimitPerUser, recipients: channel.recipients,
            icon: channel.icon, ownerID: channel.ownerID, parentID: channel.parentID,
            permissionOverwrites: channel.permissionOverwrites,
            lastPinTimestamp: channel.lastPinTimestamp, memberCount: channel.memberCount
        )
    }
}
