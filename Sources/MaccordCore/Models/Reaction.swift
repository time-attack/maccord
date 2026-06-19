import Foundation

/// A reaction summary on a message.
/// https://discord.com/developers/docs/resources/channel#reaction-object
public struct Reaction: Codable, Hashable, Sendable, Identifiable {
    public let count: Int
    public let countDetails: ReactionCountDetails?
    /// Whether the current user reacted with this emoji.
    public let me: Bool
    public let meBurst: Bool?
    public let emoji: Emoji
    public let burstColors: [String]?

    enum CodingKeys: String, CodingKey {
        case count, me, emoji
        case countDetails = "count_details"
        case meBurst = "me_burst"
        case burstColors = "burst_colors"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        countDetails = try? c.decodeIfPresent(ReactionCountDetails.self, forKey: .countDetails)
        me = (try? c.decode(Bool.self, forKey: .me)) ?? false
        meBurst = try? c.decodeIfPresent(Bool.self, forKey: .meBurst)
        emoji = try c.decode(Emoji.self, forKey: .emoji)
        burstColors = try? c.decodeIfPresent([String].self, forKey: .burstColors)
    }

    public init(count: Int, me: Bool, emoji: Emoji, countDetails: ReactionCountDetails? = nil,
                meBurst: Bool? = nil, burstColors: [String]? = nil) {
        self.count = count; self.me = me; self.emoji = emoji
        self.countDetails = countDetails; self.meBurst = meBurst; self.burstColors = burstColors
    }

    public var id: String { emoji.reactionKey.isEmpty ? (emoji.name ?? "?") : emoji.reactionKey }

    /// A copy with the current-user toggled and the count adjusted — for optimistic UI.
    public func toggled() -> Reaction {
        let delta = me ? -1 : 1
        return Reaction(count: max(0, count + delta), me: !me, emoji: emoji,
                        countDetails: countDetails, meBurst: meBurst, burstColors: burstColors)
    }
}

public struct ReactionCountDetails: Codable, Hashable, Sendable {
    public let burst: Int
    public let normal: Int
}
