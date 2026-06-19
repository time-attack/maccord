import Foundation

/// Per-channel read state from the READY payload's `read_state` collection.
public struct ReadState: Codable, Hashable, Sendable, Identifiable {
    /// The channel id.
    public let id: Snowflake
    public let lastMessageID: Snowflake?
    public let lastPinTimestamp: Date?
    public let mentionCount: Int
    public let flags: Int?

    enum CodingKeys: String, CodingKey {
        case id, flags
        case lastMessageID = "last_message_id"
        case lastPinTimestamp = "last_pin_timestamp"
        case mentionCount = "mention_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        lastMessageID = try? c.decodeIfPresent(Snowflake.self, forKey: .lastMessageID)
        lastPinTimestamp = try? c.decodeIfPresent(Date.self, forKey: .lastPinTimestamp)
        mentionCount = (try? c.decode(Int.self, forKey: .mentionCount)) ?? 0
        flags = try? c.decodeIfPresent(Int.self, forKey: .flags)
    }

    public init(id: Snowflake, lastMessageID: Snowflake?, mentionCount: Int = 0) {
        self.id = id; self.lastMessageID = lastMessageID
        self.mentionCount = mentionCount; self.lastPinTimestamp = nil; self.flags = nil
    }
}
