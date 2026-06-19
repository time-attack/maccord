import Foundation

/// A guild invite. https://discord.com/developers/docs/resources/invite#invite-object
public struct GuildInvite: Codable, Identifiable, Sendable, Hashable {
    public let code: String
    public let uses: Int?
    public let maxUses: Int?
    public let maxAge: Int?
    public let temporary: Bool?
    public let createdAt: Date?
    public let expiresAt: Date?
    public let inviter: User?

    public var id: String { code }
    public var url: String { "https://discord.gg/\(code)" }

    enum CodingKeys: String, CodingKey {
        case code, uses, temporary, inviter
        case maxUses = "max_uses"
        case maxAge = "max_age"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        uses = try? c.decodeIfPresent(Int.self, forKey: .uses)
        maxUses = try? c.decodeIfPresent(Int.self, forKey: .maxUses)
        maxAge = try? c.decodeIfPresent(Int.self, forKey: .maxAge)
        temporary = try? c.decodeIfPresent(Bool.self, forKey: .temporary)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
        expiresAt = try? c.decodeIfPresent(Date.self, forKey: .expiresAt)
        inviter = try? c.decodeIfPresent(User.self, forKey: .inviter)
    }
}
