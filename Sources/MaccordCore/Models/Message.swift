import Foundation

public enum MessageType: Int, Codable, Sendable, Hashable {
    case `default` = 0
    case recipientAdd = 1
    case recipientRemove = 2
    case call = 3
    case channelNameChange = 4
    case channelIconChange = 5
    case channelPinnedMessage = 6
    case userJoin = 7
    case guildBoost = 8
    case guildBoostTier1 = 9
    case guildBoostTier2 = 10
    case guildBoostTier3 = 11
    case channelFollowAdd = 12
    case threadCreated = 18
    case reply = 19
    case chatInputCommand = 20
    case threadStarterMessage = 21
    case contextMenuCommand = 23
    case autoModerationAction = 24

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = MessageType(rawValue: raw) ?? .default
    }

    /// System messages render differently (centered, gray, no avatar bubble).
    public var isSystem: Bool {
        switch self {
        case .default, .reply, .chatInputCommand, .contextMenuCommand, .threadStarterMessage:
            return false
        default:
            return true
        }
    }
}

public struct MessageFlags: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let crossposted          = MessageFlags(rawValue: 1 << 0)
    public static let isCrosspost          = MessageFlags(rawValue: 1 << 1)
    public static let suppressEmbeds       = MessageFlags(rawValue: 1 << 2)
    public static let sourceMessageDeleted = MessageFlags(rawValue: 1 << 3)
    public static let urgent               = MessageFlags(rawValue: 1 << 4)
    public static let hasThread            = MessageFlags(rawValue: 1 << 5)
    public static let ephemeral            = MessageFlags(rawValue: 1 << 6)
    public static let loading              = MessageFlags(rawValue: 1 << 7)
    public static let suppressNotifications = MessageFlags(rawValue: 1 << 12)
    public static let isVoiceMessage       = MessageFlags(rawValue: 1 << 13)
}

/// A message. https://discord.com/developers/docs/resources/channel#message-object
///
/// A value type; partial gateway updates are merged via `merging(_:)` which
/// returns a new value rather than mutating shared state.
public struct Message: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let channelID: Snowflake
    public let guildID: Snowflake?
    public let author: User
    public let member: Member?
    public let content: String
    public let timestamp: Date
    public let editedTimestamp: Date?
    public let tts: Bool
    public let mentionEveryone: Bool
    public let mentions: [User]
    public let mentionRoles: [Snowflake]
    public let attachments: [Attachment]
    public let embeds: [Embed]
    public let reactions: [Reaction]
    public let pinned: Bool
    public let webhookID: Snowflake?
    public let type: MessageType
    public let messageReference: MessageReference?
    public let flags: MessageFlags?
    public let stickerItems: [StickerItem]
    public let nonce: String?

    // Recursive reference broken via array-backed storage (value-type safe).
    private let referencedMessageStorage: [Message]
    public var referencedMessage: Message? { referencedMessageStorage.first }

    /// Set by the client for optimistic sends not yet confirmed by the gateway.
    public var isPending: Bool = false
    /// Set when a send failed.
    public var failedToSend: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, author, member, content, timestamp, tts, mentions, attachments
        case embeds, reactions, pinned, type, flags, nonce
        case channelID = "channel_id"
        case guildID = "guild_id"
        case editedTimestamp = "edited_timestamp"
        case mentionEveryone = "mention_everyone"
        case mentionRoles = "mention_roles"
        case webhookID = "webhook_id"
        case messageReference = "message_reference"
        case referencedMessage = "referenced_message"
        case stickerItems = "sticker_items"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        channelID = try c.decode(Snowflake.self, forKey: .channelID)
        guildID = try? c.decodeIfPresent(Snowflake.self, forKey: .guildID)
        author = (try? c.decode(User.self, forKey: .author))
            ?? User(id: Snowflake(0), username: "Unknown User")
        member = try? c.decodeIfPresent(Member.self, forKey: .member)
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        timestamp = (try? c.decode(Date.self, forKey: .timestamp)) ?? id.createdAt
        editedTimestamp = try? c.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        tts = (try? c.decode(Bool.self, forKey: .tts)) ?? false
        mentionEveryone = (try? c.decode(Bool.self, forKey: .mentionEveryone)) ?? false
        mentions = (try? c.decode([User].self, forKey: .mentions)) ?? []
        mentionRoles = (try? c.decode([Snowflake].self, forKey: .mentionRoles)) ?? []
        attachments = (try? c.decode([Attachment].self, forKey: .attachments)) ?? []
        embeds = (try? c.decode([Embed].self, forKey: .embeds)) ?? []
        reactions = (try? c.decode([Reaction].self, forKey: .reactions)) ?? []
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        webhookID = try? c.decodeIfPresent(Snowflake.self, forKey: .webhookID)
        type = (try? c.decode(MessageType.self, forKey: .type)) ?? .default
        messageReference = try? c.decodeIfPresent(MessageReference.self, forKey: .messageReference)
        if let flagsRaw = try? c.decodeIfPresent(Int.self, forKey: .flags) {
            flags = MessageFlags(rawValue: flagsRaw)
        } else {
            flags = nil
        }
        stickerItems = (try? c.decode([StickerItem].self, forKey: .stickerItems)) ?? []
        nonce = try? c.decodeIfPresent(String.self, forKey: .nonce)
        if let ref = try? c.decodeIfPresent(Message.self, forKey: .referencedMessage) {
            referencedMessageStorage = [ref]
        } else {
            referencedMessageStorage = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(channelID, forKey: .channelID)
        try c.encodeIfPresent(guildID, forKey: .guildID)
        try c.encode(author, forKey: .author)
        try c.encode(content, forKey: .content)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(editedTimestamp, forKey: .editedTimestamp)
        try c.encode(type, forKey: .type)
    }

    // Memberwise init for synthesizing optimistic messages.
    public init(
        id: Snowflake, channelID: Snowflake, guildID: Snowflake? = nil, author: User,
        member: Member? = nil, content: String, timestamp: Date = Date(),
        editedTimestamp: Date? = nil, tts: Bool = false, mentionEveryone: Bool = false,
        mentions: [User] = [], mentionRoles: [Snowflake] = [], attachments: [Attachment] = [],
        embeds: [Embed] = [], reactions: [Reaction] = [], pinned: Bool = false,
        webhookID: Snowflake? = nil, type: MessageType = .default,
        messageReference: MessageReference? = nil, referencedMessage: Message? = nil,
        flags: MessageFlags? = nil, stickerItems: [StickerItem] = [], nonce: String? = nil,
        isPending: Bool = false, failedToSend: Bool = false
    ) {
        self.id = id; self.channelID = channelID; self.guildID = guildID; self.author = author
        self.member = member; self.content = content; self.timestamp = timestamp
        self.editedTimestamp = editedTimestamp; self.tts = tts
        self.mentionEveryone = mentionEveryone; self.mentions = mentions
        self.mentionRoles = mentionRoles; self.attachments = attachments; self.embeds = embeds
        self.reactions = reactions; self.pinned = pinned; self.webhookID = webhookID
        self.type = type; self.messageReference = messageReference
        self.referencedMessageStorage = referencedMessage.map { [$0] } ?? []
        self.flags = flags; self.stickerItems = stickerItems; self.nonce = nonce
        self.isPending = isPending; self.failedToSend = failedToSend
    }

    public var isEdited: Bool { editedTimestamp != nil }
    public var isReply: Bool { type == .reply || (messageReference?.messageID != nil) }
    public var hasContent: Bool {
        !content.isEmpty || !attachments.isEmpty || !embeds.isEmpty || !stickerItems.isEmpty
    }

    /// Merge a partial `MESSAGE_UPDATE` into this message, returning a new value.
    public func merging(_ partial: PartialMessage) -> Message {
        Message(
            id: id, channelID: channelID, guildID: guildID,
            author: partial.author ?? author,
            member: member,
            content: partial.content ?? content,
            timestamp: timestamp,
            editedTimestamp: partial.editedTimestamp ?? editedTimestamp,
            tts: tts, mentionEveryone: partial.mentionEveryone ?? mentionEveryone,
            mentions: partial.mentions ?? mentions,
            mentionRoles: partial.mentionRoles ?? mentionRoles,
            attachments: partial.attachments ?? attachments,
            embeds: partial.embeds ?? embeds,
            reactions: partial.reactions ?? reactions,
            pinned: partial.pinned ?? pinned,
            webhookID: webhookID, type: type, messageReference: messageReference,
            referencedMessage: referencedMessage,
            flags: partial.flags ?? flags, stickerItems: stickerItems, nonce: nonce
        )
    }

    /// Replace the reaction list (optimistic toggle / gateway reaction events).
    public func withReactions(_ reactions: [Reaction]) -> Message {
        var copy = self.rebuilt(reactions: reactions)
        copy.isPending = isPending
        copy.failedToSend = failedToSend
        return copy
    }

    private func rebuilt(reactions: [Reaction]) -> Message {
        Message(
            id: id, channelID: channelID, guildID: guildID, author: author, member: member,
            content: content, timestamp: timestamp, editedTimestamp: editedTimestamp, tts: tts,
            mentionEveryone: mentionEveryone, mentions: mentions, mentionRoles: mentionRoles,
            attachments: attachments, embeds: embeds, reactions: reactions, pinned: pinned,
            webhookID: webhookID, type: type, messageReference: messageReference,
            referencedMessage: referencedMessage, flags: flags, stickerItems: stickerItems,
            nonce: nonce
        )
    }
}

/// A lenient decode of `MESSAGE_UPDATE`, which may carry any subset of fields.
public struct PartialMessage: Codable, Sendable, Identifiable {
    public let id: Snowflake
    public let channelID: Snowflake
    public let author: User?
    public let content: String?
    public let editedTimestamp: Date?
    public let mentionEveryone: Bool?
    public let mentions: [User]?
    public let mentionRoles: [Snowflake]?
    public let attachments: [Attachment]?
    public let embeds: [Embed]?
    public let reactions: [Reaction]?
    public let pinned: Bool?
    public let flags: MessageFlags?

    enum CodingKeys: String, CodingKey {
        case id, author, content, mentions, attachments, embeds, reactions, pinned, flags
        case channelID = "channel_id"
        case editedTimestamp = "edited_timestamp"
        case mentionEveryone = "mention_everyone"
        case mentionRoles = "mention_roles"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Snowflake.self, forKey: .id)
        channelID = try c.decode(Snowflake.self, forKey: .channelID)
        author = try? c.decodeIfPresent(User.self, forKey: .author)
        content = try? c.decodeIfPresent(String.self, forKey: .content)
        editedTimestamp = try? c.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        mentionEveryone = try? c.decodeIfPresent(Bool.self, forKey: .mentionEveryone)
        mentions = try? c.decodeIfPresent([User].self, forKey: .mentions)
        mentionRoles = try? c.decodeIfPresent([Snowflake].self, forKey: .mentionRoles)
        attachments = try? c.decodeIfPresent([Attachment].self, forKey: .attachments)
        embeds = try? c.decodeIfPresent([Embed].self, forKey: .embeds)
        reactions = try? c.decodeIfPresent([Reaction].self, forKey: .reactions)
        pinned = try? c.decodeIfPresent(Bool.self, forKey: .pinned)
        if let raw = try? c.decodeIfPresent(Int.self, forKey: .flags) {
            flags = MessageFlags(rawValue: raw)
        } else {
            flags = nil
        }
    }
}
