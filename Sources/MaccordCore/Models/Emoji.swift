import Foundation

/// A custom or unicode emoji. https://discord.com/developers/docs/resources/emoji
public struct Emoji: Codable, Hashable, Sendable, Identifiable {
    /// nil for unicode emoji.
    public let id: Snowflake?
    /// The unicode character for standard emoji, or the name for custom ones.
    public let name: String?
    public let roles: [Snowflake]?
    public let requireColons: Bool?
    public let managed: Bool?
    public let animated: Bool?
    public let available: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, roles, managed, animated, available
        case requireColons = "require_colons"
    }

    public init(
        id: Snowflake? = nil, name: String? = nil, roles: [Snowflake]? = nil,
        requireColons: Bool? = nil, managed: Bool? = nil, animated: Bool? = nil,
        available: Bool? = nil
    ) {
        self.id = id; self.name = name; self.roles = roles
        self.requireColons = requireColons; self.managed = managed
        self.animated = animated; self.available = available
    }

    public var isCustom: Bool { id != nil }
    public var isAnimated: Bool { animated ?? false }

    public func imageURL(size: Int = 64) -> URL? {
        guard let id else { return nil }
        return DiscordCDN.emoji(id: id, animated: isAnimated, size: size)
    }

    /// Reaction API path component: `name:id` for custom, raw char for unicode.
    public var reactionKey: String {
        if let id, let name { return "\(name):\(id.rawValue)" }
        return name ?? ""
    }
}
