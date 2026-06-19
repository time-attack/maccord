import Foundation

/// A guild role. https://discord.com/developers/docs/topics/permissions#role-object
public struct Role: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let name: String
    /// Integer RGB; 0 means "no color" (inherits default).
    public let color: Int
    public let hoist: Bool
    public let icon: String?
    public let unicodeEmoji: String?
    public let position: Int
    public let permissions: Permissions
    public let managed: Bool
    public let mentionable: Bool
    public let flags: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, color, hoist, icon, position, permissions, managed, mentionable, flags
        case unicodeEmoji = "unicode_emoji"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = (try? c.decode(Int.self, forKey: .color)) ?? 0
        hoist = (try? c.decode(Bool.self, forKey: .hoist)) ?? false
        icon = try? c.decodeIfPresent(String.self, forKey: .icon)
        unicodeEmoji = try? c.decodeIfPresent(String.self, forKey: .unicodeEmoji)
        position = (try? c.decode(Int.self, forKey: .position)) ?? 0
        // Permissions arrive as a stringified bitfield.
        permissions = (try? c.decode(Permissions.self, forKey: .permissions)) ?? Permissions(rawValue: 0)
        managed = (try? c.decode(Bool.self, forKey: .managed)) ?? false
        mentionable = (try? c.decode(Bool.self, forKey: .mentionable)) ?? false
        flags = try? c.decodeIfPresent(Int.self, forKey: .flags)
    }

    public init(
        id: Snowflake, name: String, color: Int = 0, hoist: Bool = false,
        icon: String? = nil, unicodeEmoji: String? = nil, position: Int = 0,
        permissions: Permissions = Permissions(rawValue: 0), managed: Bool = false,
        mentionable: Bool = false, flags: Int? = nil
    ) {
        self.id = id; self.name = name; self.color = color; self.hoist = hoist
        self.icon = icon; self.unicodeEmoji = unicodeEmoji; self.position = position
        self.permissions = permissions; self.managed = managed
        self.mentionable = mentionable; self.flags = flags
    }

    /// True when this role contributes a color (0 = default/no color).
    public var hasColor: Bool { color != 0 }

    public func iconURL(size: Int = 64) -> URL? {
        guard let icon else { return nil }
        return DiscordCDN.roleIcon(roleID: id, hash: icon, size: size)
    }
}

/// Discord permission bitfield (transported as a stringified 64-bit integer).
public struct Permissions: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.rawValue = UInt64(string) ?? 0
        } else {
            self.rawValue = (try? container.decode(UInt64.self)) ?? 0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(rawValue))
    }

    public static let createInstantInvite  = Permissions(rawValue: 1 << 0)
    public static let kickMembers           = Permissions(rawValue: 1 << 1)
    public static let banMembers            = Permissions(rawValue: 1 << 2)
    public static let administrator         = Permissions(rawValue: 1 << 3)
    public static let manageChannels        = Permissions(rawValue: 1 << 4)
    public static let manageGuild           = Permissions(rawValue: 1 << 5)
    public static let addReactions          = Permissions(rawValue: 1 << 6)
    public static let viewAuditLog          = Permissions(rawValue: 1 << 7)
    public static let prioritySpeaker       = Permissions(rawValue: 1 << 8)
    public static let stream                = Permissions(rawValue: 1 << 9)
    public static let viewChannel           = Permissions(rawValue: 1 << 10)
    public static let sendMessages          = Permissions(rawValue: 1 << 11)
    public static let sendTTSMessages       = Permissions(rawValue: 1 << 12)
    public static let manageMessages        = Permissions(rawValue: 1 << 13)
    public static let embedLinks            = Permissions(rawValue: 1 << 14)
    public static let attachFiles           = Permissions(rawValue: 1 << 15)
    public static let readMessageHistory    = Permissions(rawValue: 1 << 16)
    public static let mentionEveryone       = Permissions(rawValue: 1 << 17)
    public static let useExternalEmojis     = Permissions(rawValue: 1 << 18)
    public static let connect               = Permissions(rawValue: 1 << 20)
    public static let speak                 = Permissions(rawValue: 1 << 21)
    public static let muteMembers           = Permissions(rawValue: 1 << 22)
    public static let deafenMembers         = Permissions(rawValue: 1 << 23)
    public static let moveMembers           = Permissions(rawValue: 1 << 24)
    public static let useVAD                = Permissions(rawValue: 1 << 25)
    public static let changeNickname        = Permissions(rawValue: 1 << 26)
    public static let manageNicknames       = Permissions(rawValue: 1 << 27)
    public static let manageRoles           = Permissions(rawValue: 1 << 28)
    public static let manageWebhooks        = Permissions(rawValue: 1 << 29)
    public static let manageEmojis          = Permissions(rawValue: 1 << 30)
    public static let useApplicationCommands = Permissions(rawValue: 1 << 31)
    public static let sendMessagesInThreads = Permissions(rawValue: 1 << 38)

    public var isAdministrator: Bool { contains(.administrator) }
}

extension Permissions {
    /// Human-readable permission names for settings UI.
    public var labeledFlags: [String] {
        if contains(.administrator) { return ["Administrator"] }
        var names: [String] = []
        let map: [(Permissions, String)] = [
            (.manageGuild, "Manage Server"), (.manageChannels, "Manage Channels"),
            (.manageRoles, "Manage Roles"), (.manageMessages, "Manage Messages"),
            (.manageNicknames, "Manage Nicknames"), (.manageWebhooks, "Manage Webhooks"),
            (.manageEmojis, "Manage Emoji"), (.kickMembers, "Kick Members"),
            (.banMembers, "Ban Members"), (.viewAuditLog, "View Audit Log"),
            (.viewChannel, "View Channels"), (.sendMessages, "Send Messages"),
            (.sendMessagesInThreads, "Send in Threads"), (.embedLinks, "Embed Links"),
            (.attachFiles, "Attach Files"), (.addReactions, "Add Reactions"),
            (.useExternalEmojis, "Use External Emoji"), (.mentionEveryone, "Mention @everyone"),
            (.readMessageHistory, "Read Message History"), (.connect, "Connect (Voice)"),
            (.speak, "Speak"), (.muteMembers, "Mute Members"), (.deafenMembers, "Deafen Members"),
            (.moveMembers, "Move Members"), (.changeNickname, "Change Nickname"),
            (.createInstantInvite, "Create Invite"), (.prioritySpeaker, "Priority Speaker"),
            (.stream, "Video"), (.useVAD, "Voice Activity"), (.useApplicationCommands, "Use Commands"),
        ]
        for (flag, label) in map where contains(flag) { names.append(label) }
        return names
    }
}
