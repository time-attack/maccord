import Foundation

public enum RelationshipType: Int, Codable, Sendable, Hashable {
    case none = 0
    case friend = 1
    case blocked = 2
    case incomingRequest = 3
    case outgoingRequest = 4

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = RelationshipType(rawValue: raw) ?? .none
    }
}

/// A friend / blocked / pending relationship from the READY payload.
public struct Relationship: Codable, Hashable, Sendable, Identifiable {
    public let id: Snowflake
    public let type: RelationshipType
    public let nickname: String?
    public let user: User?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        type = (try? c.decode(RelationshipType.self, forKey: .type)) ?? .none
        nickname = try? c.decodeIfPresent(String.self, forKey: .nickname)
        user = try? c.decodeIfPresent(User.self, forKey: .user)
    }

    enum CodingKeys: String, CodingKey { case id, type, nickname, user }
}
