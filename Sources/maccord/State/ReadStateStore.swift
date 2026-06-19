import Foundation
import Observation
import MaccordCore

/// Tracks read/unread + mention badges per channel.
///
/// Two separate facts are kept so unread logic is unambiguous:
/// - `latest[channel]`  — the newest message id known to exist in the channel.
/// - `acked[channel]`   — the newest message id the user has read.
/// A channel is unread when `latest > acked`. This mirrors Discord's model and
/// avoids conflating "newest known" with "read up to".
@MainActor
@Observable
final class ReadStateStore {
    private(set) var latest: [Snowflake: Snowflake] = [:]
    private(set) var acked: [Snowflake: Snowflake] = [:]
    private(set) var mentions: [Snowflake: Int] = [:]

    // MARK: Seeding from READY

    func loadReadStates(_ states: [ReadState]) {
        for s in states {
            if let last = s.lastMessageID {
                acked[s.id] = last
                // Seed latest from the ack too so we don't show unread before
                // channel metadata arrives.
                noteLatest(s.id, last)
            }
            if s.mentionCount > 0 { mentions[s.id] = s.mentionCount }
        }
    }

    /// Seed/advance the newest-known id for a channel (from READY channel
    /// last_message_id, history loads, or new messages).
    func noteLatest(_ channelID: Snowflake, _ messageID: Snowflake?) {
        guard let messageID else { return }
        if (latest[channelID] ?? Snowflake(0)) < messageID { latest[channelID] = messageID }
    }

    // MARK: Queries

    func isUnread(_ channelID: Snowflake) -> Bool {
        guard let l = latest[channelID] else { return false }
        guard let a = acked[channelID] else { return true }
        return l > a
    }

    func mentionCount(_ channelID: Snowflake) -> Int { mentions[channelID] ?? 0 }

    /// The id the user had read before now — used to draw the NEW divider.
    func ackedID(_ channelID: Snowflake) -> Snowflake? { acked[channelID] }

    // MARK: Mutations

    /// A new message arrived: advance latest + bump mentions if it pings us.
    func bumpUnread(channelID: Snowflake, messageID: Snowflake, mentioned: Bool) {
        noteLatest(channelID, messageID)
        if mentioned { mentions[channelID, default: 0] += 1 }
    }

    /// Mark the channel read up to its newest known message.
    func markRead(_ channelID: Snowflake) {
        if let l = latest[channelID] { acked[channelID] = l }
        mentions[channelID] = 0
    }

    /// Mark read up to a specific id (also advances latest and clears mentions).
    func markRead(channelID: Snowflake, upTo messageID: Snowflake) {
        noteLatest(channelID, messageID)
        acked[channelID] = max(acked[channelID] ?? Snowflake(0), messageID)
        mentions[channelID] = 0
    }

    /// Mark a channel unread (Discord: right-click → Mark As Unread).
    func markUnread(_ channelID: Snowflake, before messageID: Snowflake? = nil) {
        if let messageID {
            acked[channelID] = messageID
        } else if let l = latest[channelID], l.rawValue > 0 {
            acked[channelID] = Snowflake(l.rawValue - 1)
        } else {
            acked[channelID] = Snowflake(0)
            latest[channelID] = Snowflake(1)
        }
    }

    // MARK: Guild rollups

    func guildHasUnread(_ guild: Guild, channels: [Channel], excluding selectedChannelID: Snowflake? = nil) -> Bool {
        channels.contains {
            $0.type.isTextLike
                && $0.id != selectedChannelID
                && isUnread($0.id)
        }
    }

    func guildMentionCount(_ guild: Guild, channels: [Channel]) -> Int {
        channels.reduce(0) { $0 + mentionCount($1.id) }
    }
}
