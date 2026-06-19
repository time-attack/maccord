import Foundation
import Observation
import MaccordCore

/// Tracks who is currently typing in each channel. Entries auto-expire ~10s
/// after the last TYPING_START, matching Discord's behavior.
@MainActor
@Observable
final class TypingStore {
    /// channel id → (user id → expiry date)
    private(set) var byChannel: [Snowflake: [Snowflake: Date]] = [:]

    private let timeout: TimeInterval = 10

    func start(_ event: TypingStartEvent, displayName: String?) {
        var users = byChannel[event.channelID] ?? [:]
        users[event.userID] = Date().addingTimeInterval(timeout)
        byChannel[event.channelID] = users
        if let displayName { names[event.userID] = displayName }
    }

    /// Removed when a message from that user lands.
    func clear(userID: Snowflake, channelID: Snowflake) {
        guard var users = byChannel[channelID] else { return }
        users.removeValue(forKey: userID)
        byChannel[channelID] = users.isEmpty ? nil : users
    }

    func typingUserIDs(in channelID: Snowflake) -> [Snowflake] {
        let now = Date()
        return (byChannel[channelID] ?? [:])
            .filter { $0.value > now }
            .keys
            .sorted()
    }

    /// Cached display names so the indicator can render without a member lookup.
    private(set) var names: [Snowflake: String] = [:]

    func name(_ userID: Snowflake) -> String { names[userID] ?? "Someone" }
}
