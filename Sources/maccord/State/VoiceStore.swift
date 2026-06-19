import Foundation
import Observation
import MaccordCore

/// Tracks which users occupy each voice channel + our own connection intent.
/// (Actual audio transport is a later milestone — see Voice in ARCHITECTURE.md.)
@MainActor
@Observable
final class VoiceStore {
    /// channel id → voice states of its occupants.
    private(set) var statesByChannel: [Snowflake: [VoiceState]] = [:]
    /// user id → channel id, for fast relocation on updates.
    private var channelByUser: [Snowflake: Snowflake] = [:]

    /// The voice channel we are connected to (nil = not connected).
    var connectedChannelID: Snowflake?
    var selfMute = false
    var selfDeaf = false

    func load(from guilds: [Guild]) {
        for guild in guilds {
            for state in guild.voiceStates { apply(state) }
        }
    }

    func apply(_ state: VoiceState) {
        // Remove from previous channel.
        if let prev = channelByUser[state.userID] {
            statesByChannel[prev]?.removeAll { $0.userID == state.userID }
            if statesByChannel[prev]?.isEmpty == true { statesByChannel[prev] = nil }
            channelByUser[state.userID] = nil
        }
        // Add to new channel (nil channel = left voice entirely).
        if let channel = state.channelID {
            statesByChannel[channel, default: []].append(state)
            channelByUser[state.userID] = channel
        }
    }

    func states(in channelID: Snowflake) -> [VoiceState] {
        statesByChannel[channelID] ?? []
    }

    func occupantCount(_ channelID: Snowflake) -> Int {
        statesByChannel[channelID]?.count ?? 0
    }
}
