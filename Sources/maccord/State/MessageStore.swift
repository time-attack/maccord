import Foundation
import Observation
import MaccordCore

/// Per-channel message list with pagination and live-event application.
@MainActor
@Observable
final class MessageStore {
    let channelID: Snowflake
    let guildID: Snowflake?

    /// Oldest → newest.
    private(set) var messages: [Message] = []
    private(set) var hasMoreBefore = true
    private(set) var isLoadingOlder = false
    private(set) var loadedInitial = false
    var loadError: String?

    private let rest: RESTClient

    init(channelID: Snowflake, guildID: Snowflake?, rest: RESTClient) {
        self.channelID = channelID
        self.guildID = guildID
        self.rest = rest
    }

    // MARK: Loading

    func loadInitialIfNeeded() async {
        guard !loadedInitial else { return }
        await loadInitial()
    }

    func loadInitial() async {
        loadError = nil
        do {
            let fetched = try await rest.getMessages(channelID: channelID, limit: 50)
            // API returns newest → oldest; we store oldest → newest.
            messages = fetched.reversed()
            hasMoreBefore = fetched.count >= 50
            loadedInitial = true
        } catch {
            loadError = friendly(error)
        }
    }

    func loadOlder() async {
        guard hasMoreBefore, !isLoadingOlder, let oldest = messages.first?.id else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let fetched = try await rest.getMessages(channelID: channelID, before: oldest, limit: 50)
            guard !fetched.isEmpty else { hasMoreBefore = false; return }
            let older = fetched.reversed().filter { msg in !messages.contains { $0.id == msg.id } }
            messages.insert(contentsOf: older, at: 0)
            hasMoreBefore = fetched.count >= 50
        } catch {
            loadError = friendly(error)
        }
    }

    /// Load a window of history centred on `messageID` (jump-to-message) and merge
    /// it into the list, so a pinned/searched/replied message that isn't in the
    /// current window becomes scrollable. Existing (possibly live) copies win.
    func loadAround(messageID: Snowflake) async {
        if messages.contains(where: { $0.id == messageID }) { return }
        loadError = nil
        do {
            let fetched = try await rest.getMessages(channelID: channelID, around: messageID, limit: 50)
            guard !fetched.isEmpty else { return }
            var byID: [Snowflake: Message] = [:]
            for m in messages { byID[m.id] = m }
            for m in fetched where byID[m.id] == nil { byID[m.id] = m }
            messages = byID.values.sorted { $0.id < $1.id }
            loadedInitial = true
        } catch {
            loadError = friendly(error)
        }
    }

    // MARK: Live events

    func append(_ message: Message) {
        // Reconcile an optimistic message by nonce.
        if let nonce = message.nonce,
           let idx = messages.firstIndex(where: { $0.nonce == nonce && $0.isPending }) {
            messages[idx] = message
            return
        }
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    func insertOptimistic(_ message: Message) {
        messages.append(message)
    }

    func markFailed(nonce: String) {
        guard let idx = messages.firstIndex(where: { $0.nonce == nonce }) else { return }
        var m = messages[idx]
        m.isPending = false
        m.failedToSend = true
        messages[idx] = m
    }

    func update(_ partial: PartialMessage) {
        guard let idx = messages.firstIndex(where: { $0.id == partial.id }) else { return }
        messages[idx] = messages[idx].merging(partial)
    }

    func delete(_ id: Snowflake) {
        // Keep the message as a tombstone (grayed "message deleted") until the
        // channel is reloaded, matching Discord's behavior.
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isDeleted = true
        }
    }

    func clearReactions(messageID: Snowflake) {
        guard let idx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[idx] = messages[idx].withReactions([])
    }

    func applyReactionEvent(_ event: ReactionEvent, add: Bool, currentUserID: Snowflake?) {
        guard let idx = messages.firstIndex(where: { $0.id == event.messageID }) else { return }
        var reactions = messages[idx].reactions
        let isMe = event.userID == currentUserID
        let emojiMatch: (Reaction) -> Bool = {
            $0.emoji.reactionKey == event.emoji.reactionKey
                || ($0.emoji.name == event.emoji.name && $0.emoji.id == event.emoji.id)
        }
        if let rIdx = reactions.firstIndex(where: emojiMatch) {
            let r = reactions[rIdx]
            // Skip gateway echoes of our own optimistic toggle (prevents double-count).
            if isMe, add, r.me { return }
            if isMe, !add, !r.me { return }
            let newCount = add ? r.count + 1 : max(0, r.count - 1)
            if newCount == 0 {
                reactions.remove(at: rIdx)
            } else {
                reactions[rIdx] = Reaction(count: newCount, me: isMe ? add : r.me, emoji: r.emoji)
            }
        } else if add {
            if isMe, reactions.contains(where: { emojiMatch($0) && $0.me }) { return }
            reactions.append(Reaction(count: 1, me: isMe, emoji: event.emoji))
        }
        messages[idx] = messages[idx].withReactions(reactions)
    }

    /// Optimistic local reaction toggle (before the gateway echoes back).
    func toggleReactionLocally(messageID: Snowflake, emoji: Emoji) {
        guard let idx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        var reactions = messages[idx].reactions
        if let rIdx = reactions.firstIndex(where: { $0.emoji.reactionKey == emoji.reactionKey }) {
            reactions[rIdx] = reactions[rIdx].toggled()
            if reactions[rIdx].count == 0 { reactions.remove(at: rIdx) }
        } else {
            reactions.append(Reaction(count: 1, me: true, emoji: emoji))
        }
        messages[idx] = messages[idx].withReactions(reactions)
    }

    private func friendly(_ error: Error) -> String {
        if let rest = error as? RESTError {
            switch rest {
            case .http(let status, _, let message):
                return message ?? "Request failed (\(status))"
            case .notAuthenticated: return "Not authenticated"
            case .rateLimited: return "Rate limited — try again shortly"
            default: return "Couldn't load messages"
            }
        }
        return "Couldn't load messages"
    }
}
