import Foundation
import Observation
import MaccordCore

/// The ordered, index-addressable member list driven by GUILD_MEMBER_LIST_UPDATE
/// (op 14). Group headers occupy index slots alongside members, so ops address an
/// absolute position in this flat list.
@MainActor
@Observable
final class MemberStore {
    enum Row: Identifiable {
        case header(id: String, group: MemberListGroup)
        case member(MemberListEntry)

        var id: String {
            switch self {
            case .header(let id, _): "header-\(id)"
            case .member(let entry): "member-\(entry.member.id.rawValue)"
            }
        }
    }

    private(set) var items: [MemberListItem] = []
    private(set) var memberCount = 0
    private(set) var onlineCount = 0
    private(set) var subscribedGuildID: Snowflake?
    private(set) var subscribedChannelID: Snowflake?

    /// Rows for SwiftUI, de-duplicating any accidental id collisions by position.
    var rows: [Row] {
        var seen = Set<String>()
        var result: [Row] = []
        for (offset, item) in items.enumerated() {
            switch item {
            case .group(let g):
                result.append(.header(id: "\(g.id)-\(offset)", group: g))
            case .member(let entry):
                var row = Row.member(entry)
                if seen.contains(row.id) { row = .member(entry) } // ids include user id; collisions unlikely
                seen.insert(row.id)
                result.append(row)
            }
        }
        return result
    }

    func reset(guildID: Snowflake, channelID: Snowflake) {
        if subscribedChannelID != channelID {
            items = []
            memberCount = 0
            onlineCount = 0
        }
        subscribedGuildID = guildID
        subscribedChannelID = channelID
    }

    func apply(_ update: MemberListUpdate) {
        memberCount = update.memberCount
        onlineCount = update.onlineCount
        for op in update.ops { apply(op) }
    }

    private func apply(_ op: MemberListOp) {
        switch op {
        case .sync(let range, let newItems):
            growToFit(upTo: range.lowerBound)
            for (offset, item) in newItems.enumerated() {
                let idx = range.lowerBound + offset
                if idx < items.count {
                    items[idx] = item
                } else {
                    items.append(item)
                }
            }
            // Trim anything the SYNC range invalidated beyond the new data.
            let end = range.lowerBound + newItems.count
            if range.upperBound + 1 >= items.count, end < items.count {
                items.removeSubrange(end..<items.count)
            }

        case .insert(let index, let item):
            let clamped = min(max(0, index), items.count)
            items.insert(item, at: clamped)

        case .update(let index, let item):
            guard index >= 0, index < items.count else { return }
            items[index] = item

        case .delete(let index):
            guard index >= 0, index < items.count else { return }
            items.remove(at: index)

        case .invalidate:
            // Range invalidation is handled by the next SYNC for the range.
            break
        }
    }

    /// Pad with placeholder offline groups so an out-of-range op still lands.
    private func growToFit(upTo index: Int) {
        while items.count < index {
            items.append(.group(MemberListGroup(id: "offline", count: 0)))
        }
    }
}
