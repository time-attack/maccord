import Foundation

// MARK: - Subscribe (op 14)

/// The `d` payload for a GUILD_SUBSCRIPTIONS (op 14) request — how the official
/// client lazily asks for a channel's member list, presences and typing.
public struct GuildSubscribePayload: Encodable, Sendable {
    public let guildID: Snowflake
    public let typing: Bool
    public let threads: Bool
    public let activities: Bool
    /// channel id → list of `[start, end]` index ranges (100 rows per window).
    public let channels: [String: [[Int]]]

    public init(guildID: Snowflake, channelID: Snowflake, ranges: [ClosedRange<Int>] = [0...99],
                typing: Bool = true, threads: Bool = false, activities: Bool = true) {
        self.guildID = guildID
        self.typing = typing
        self.threads = threads
        self.activities = activities
        self.channels = [channelID.description: ranges.map { [$0.lowerBound, $0.upperBound] }]
    }

    enum CodingKeys: String, CodingKey {
        case typing, threads, activities, channels
        case guildID = "guild_id"
    }
}

// MARK: - GUILD_MEMBER_LIST_UPDATE

public struct MemberListGroup: Sendable, Hashable, Identifiable {
    /// A role id, or the literal "online" / "offline".
    public let id: String
    public let count: Int

    public init(id: String, count: Int) {
        self.id = id
        self.count = count
    }
}

public struct MemberListEntry: Sendable, Hashable {
    public let member: Member
    public let presence: Presence?

    public init(member: Member, presence: Presence?) {
        self.member = member
        self.presence = presence
    }
}

public enum MemberListItem: Sendable, Hashable {
    case group(MemberListGroup)
    case member(MemberListEntry)
}

public enum MemberListOp: Sendable {
    case sync(range: ClosedRange<Int>, items: [MemberListItem])
    case insert(index: Int, item: MemberListItem)
    case update(index: Int, item: MemberListItem)
    case delete(index: Int)
    case invalidate(range: ClosedRange<Int>)
}

/// The decoded op14 response. Ops are index-addressable against an ordered list
/// of rows (group headers consume index slots too).
public struct MemberListUpdate: Sendable {
    public let guildID: Snowflake
    public let listID: String
    public let memberCount: Int
    public let onlineCount: Int
    public let groups: [MemberListGroup]
    public let ops: [MemberListOp]
}

extension MemberListUpdate: Decodable {
    enum CodingKeys: String, CodingKey {
        case groups, ops
        case guildID = "guild_id"
        case listID = "id"
        case memberCount = "member_count"
        case onlineCount = "online_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guildID = try c.decode(Snowflake.self, forKey: .guildID)
        listID = (try? c.decode(String.self, forKey: .listID)) ?? "everyone"
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        onlineCount = (try? c.decode(Int.self, forKey: .onlineCount)) ?? 0
        groups = (try? c.decode([MemberListGroup].self, forKey: .groups)) ?? []
        ops = (try? c.decode([MemberListOp].self, forKey: .ops)) ?? []
    }
}

extension MemberListGroup: Decodable {
    enum CodingKeys: String, CodingKey { case id, count }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` may be a role snowflake (string) or a status keyword.
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let n = try? c.decode(UInt64.self, forKey: .id) {
            id = String(n)
        } else {
            id = "online"
        }
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    }
}

/// A list item is `{"group": {...}}` or `{"member": {...}}` (with nested presence).
extension MemberListItem: Decodable {
    private struct MemberItemWrapper: Decodable {
        let member: Member
        let presence: Presence?
        enum CodingKeys: String, CodingKey { case presence }
        init(from decoder: Decoder) throws {
            member = try Member(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            presence = try? c.decodeIfPresent(Presence.self, forKey: .presence)
        }
    }
    enum CodingKeys: String, CodingKey { case group, member }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let group = try? c.decode(MemberListGroup.self, forKey: .group) {
            self = .group(group)
        } else if let wrap = try? c.decode(MemberItemWrapper.self, forKey: .member) {
            self = .member(MemberListEntry(member: wrap.member, presence: wrap.presence))
        } else {
            // Unknown item shape — represent as an empty offline group to keep indices aligned.
            self = .group(MemberListGroup(id: "offline", count: 0))
        }
    }
}

extension MemberListOp: Decodable {
    enum CodingKeys: String, CodingKey { case op, range, index, item, items }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let op = (try? c.decode(String.self, forKey: .op)) ?? ""
        switch op {
        case "SYNC":
            let r = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
            let items = (try? c.decode([MemberListItem].self, forKey: .items)) ?? []
            self = .sync(range: MemberListOp.range(r), items: items)
        case "INSERT":
            let i = (try? c.decode(Int.self, forKey: .index)) ?? 0
            let item = try c.decode(MemberListItem.self, forKey: .item)
            self = .insert(index: i, item: item)
        case "UPDATE":
            let i = (try? c.decode(Int.self, forKey: .index)) ?? 0
            let item = try c.decode(MemberListItem.self, forKey: .item)
            self = .update(index: i, item: item)
        case "DELETE":
            let i = (try? c.decode(Int.self, forKey: .index)) ?? 0
            self = .delete(index: i)
        case "INVALIDATE":
            let r = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
            self = .invalidate(range: MemberListOp.range(r))
        default:
            self = .invalidate(range: 0...0)
        }
    }

    private static func range(_ arr: [Int]) -> ClosedRange<Int> {
        let lo = arr.first ?? 0
        let hi = arr.count > 1 ? arr[1] : lo
        return lo <= hi ? lo...hi : hi...lo
    }
}
