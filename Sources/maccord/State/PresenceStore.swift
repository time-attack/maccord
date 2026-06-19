import Foundation
import Observation
import MaccordCore

/// Tracks per-user presence (online/idle/dnd/offline + activities).
@MainActor
@Observable
final class PresenceStore {
    private(set) var byUser: [Snowflake: Presence] = [:]

    func set(_ presence: Presence) {
        byUser[presence.user.id] = presence
    }

    func load(from guilds: [Guild]) {
        for guild in guilds {
            for presence in guild.presences {
                byUser[presence.user.id] = presence
            }
        }
    }

    func status(_ userID: Snowflake) -> Status {
        byUser[userID]?.status ?? .offline
    }

    func presence(_ userID: Snowflake) -> Presence? {
        byUser[userID]
    }

    func isOnline(_ userID: Snowflake) -> Bool {
        let s = status(userID)
        return s != .offline && s != .invisible
    }
}
