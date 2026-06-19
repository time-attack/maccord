import Foundation
import Observation
import MaccordCore

/// A node in the sidebar channel tree: a category and its child channels, or a
/// group of uncategorized top-level channels (category == nil).
struct ChannelTreeNode: Identifiable {
    let category: Channel?
    var channels: [Channel]
    var id: Snowflake { category?.id ?? Snowflake(0) }
}

/// Mutable per-guild state: metadata, roles, channels and voice occupancy.
@MainActor
@Observable
final class GuildStore {
    let id: Snowflake
    var meta: Guild
    var roles: [Snowflake: Role] = [:]
    var channels: [Snowflake: Channel] = [:]
    /// Member cache keyed by user id. REST message history omits the per-message
    /// `member` object, so author role colors come from here (populated by the
    /// member list, member chunks, and gateway member/message events).
    var members: [Snowflake: Member] = [:]

    init(guild: Guild) {
        self.id = guild.id
        self.meta = guild
        for role in guild.roles { roles[role.id] = role }
        for channel in guild.channels { channels[channel.id] = channel }
        for thread in guild.threads { channels[thread.id] = thread }
        for member in guild.members { upsertMember(member) }
    }

    func upsertMember(_ member: Member) {
        guard let uid = member.user?.id else { return }
        members[uid] = member
    }

    func member(_ id: Snowflake) -> Member? { members[id] }

    /// The color role for a user id, using the member cache.
    func colorRole(forUser id: Snowflake) -> Role? {
        members[id].flatMap { colorRole(for: $0) }
    }

    func update(meta: Guild) {
        self.meta = meta
        for role in meta.roles { roles[role.id] = role }
    }

    func upsert(channel: Channel) { channels[channel.id] = channel }
    func remove(channelID: Snowflake) { channels[channelID] = nil }

    var roleList: [Role] {
        roles.values.sorted { $0.position > $1.position }
    }

    func role(_ id: Snowflake) -> Role? { roles[id] }

    /// The highest-positioned colored role determines a member's name color.
    func colorRole(for member: Member) -> Role? {
        member.roles
            .compactMap { roles[$0] }
            .filter { $0.hasColor }
            .max { $0.position < $1.position }
    }

    /// The hoisted role a member should be grouped under in the member list.
    func hoistRole(for member: Member) -> Role? {
        member.roles
            .compactMap { roles[$0] }
            .filter { $0.hoist }
            .max { $0.position < $1.position }
    }

    /// Discord's effective-permissions algorithm for a member in a channel:
    /// base roles → @everyone overwrite → aggregated role overwrites → member
    /// overwrite. Administrator/owner short-circuit to all permissions.
    func effectivePermissions(_ channel: Channel, myRoleIDs: [Snowflake], myUserID: Snowflake) -> Permissions {
        if meta.ownerID == myUserID { return Permissions(rawValue: .max) }
        var perms = roles[id]?.permissions.rawValue ?? 0   // @everyone (role id == guild id)
        for rid in myRoleIDs { perms |= roles[rid]?.permissions.rawValue ?? 0 }
        if perms & Permissions.administrator.rawValue != 0 { return Permissions(rawValue: .max) }

        let overwrites = channel.permissionOverwrites ?? []
        func ow(_ sf: Snowflake) -> PermissionOverwrite? { overwrites.first { $0.id == sf } }
        if let e = ow(id) { perms = (perms & ~e.deny.rawValue) | e.allow.rawValue }
        var allow: UInt64 = 0, deny: UInt64 = 0
        for rid in myRoleIDs { if let o = ow(rid) { allow |= o.allow.rawValue; deny |= o.deny.rawValue } }
        perms = (perms & ~deny) | allow
        if let m = ow(myUserID) { perms = (perms & ~m.deny.rawValue) | m.allow.rawValue }
        return Permissions(rawValue: perms)
    }

    /// VIEW_CHANNEL check (used to hide channels). Fails open if roles unknown.
    func canViewChannel(_ channel: Channel, myRoleIDs: [Snowflake], myUserID: Snowflake) -> Bool {
        effectivePermissions(channel, myRoleIDs: myRoleIDs, myUserID: myUserID).contains(.viewChannel)
    }

    /// Build the categorized sidebar tree (Discord ordering rules), optionally
    /// filtering out channels the current member can't view.
    func channelTree(myRoleIDs: [Snowflake]? = nil, myUserID: Snowflake? = nil) -> [ChannelTreeNode] {
        let canSee: (Channel) -> Bool = { ch in
            guard let myRoleIDs, let myUserID else { return true }   // fail open
            return self.canViewChannel(ch, myRoleIDs: myRoleIDs, myUserID: myUserID)
        }
        let all = Array(channels.values)
        let categories = all
            .filter { $0.type == .category }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }

        func sortChannels(_ list: [Channel]) -> [Channel] {
            // Voice channels sort after text within the same position bucket.
            list.sorted { a, b in
                let pa = a.position ?? 0, pb = b.position ?? 0
                if pa != pb { return pa < pb }
                return a.id < b.id
            }
        }

        var nodes: [ChannelTreeNode] = []

        // Uncategorized text/voice channels appear first, above all categories.
        let uncategorized = all.filter {
            $0.parentID == nil && $0.type != .category && !$0.type.isThread && !$0.type.isDM && canSee($0)
        }
        if !uncategorized.isEmpty {
            nodes.append(ChannelTreeNode(category: nil, channels: sortChannels(uncategorized)))
        }

        for category in categories {
            // Hide a category the member can't view, or one with no visible children.
            guard canSee(category) else { continue }
            let children = all.filter { $0.parentID == category.id && !$0.type.isThread && canSee($0) }
            guard !children.isEmpty else { continue }
            nodes.append(ChannelTreeNode(category: category, channels: sortChannels(children)))
        }
        return nodes
    }

    /// The first text channel a guild should open to.
    var defaultChannel: Channel? {
        channels.values
            .filter { $0.type == .text || $0.type == .announcement }
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            .first
    }
}
