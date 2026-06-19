import SwiftUI
import MaccordCore

/// A single message row. Renders in one of three modes:
/// - **full**: avatar + author header + content (start of a group)
/// - **grouped**: no avatar/header, content indented, hover-only gutter timestamp
/// - **system**: centered gray notice (joins, pins, boosts, …)
struct MessageRowView: View {
    @Environment(AppState.self) private var app

    let message: Message
    let isGrouped: Bool
    var isFirstUnread: Bool = false
    var onReply: (Message) -> Void = { _ in }

    @State private var hovering = false
    @State private var showProfile = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var confirmingDelete = false
    @State private var showReactionPicker = false

    var body: some View {
        Group {
            if message.type.isSystem {
                systemRow
            } else {
                normalRow
            }
        }
        .background(rowBackground)
        .animation(.easeInOut(duration: 0.35), value: isHighlighted)
        .overlay(alignment: .leading) {
            if mentionsMe {
                Rectangle()
                    .fill(DiscordColor.mentionBar)
                    .frame(width: 2)
            }
        }
        .background(mentionsMe ? DiscordColor.mentionBackground : Color.clear)
        .overlay(alignment: .topTrailing) {
            if hovering && !message.type.isSystem && !isEditing {
                MessageHoverToolbar(
                    showReact: app.canAddReactions(in: message.channelID),
                    canEdit: isOwnMessage,
                    canDelete: app.canDeleteMessage(message),
                    isPinned: message.pinned,
                    canPin: canPinMessages,
                    onReact: { showReactionPicker = true },
                    onReply: { onReply(message) },
                    onEdit: { beginEditing() },
                    onPin: { Task { await app.pinMessage(message.id, pinned: message.pinned) } },
                    onDelete: { confirmingDelete = true }
                )
                .padding(.trailing, Layout.messageHGutter)
                .padding(.top, isGrouped ? 0 : 2)
                .transition(.opacity)
                .popover(isPresented: $showReactionPicker, arrowEdge: .top) {
                    EmojiPickerView { emoji in
                        Task { await app.toggleReaction(messageID: message.id, emoji: emoji) }
                        showReactionPicker = false
                    }
                }
            }
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.08), value: hovering)
        .opacity(message.isPending ? 0.5 : 1)
        // Lift the hovered row above its neighbours so the floating toolbar renders
        // on top instead of behind the following message.
        .zIndex(hovering ? 1 : 0)
        .contextMenu { contextMenu }
        .confirmationDialog("Delete Message", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await app.deleteMessage(message.id) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this message?")
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenu: some View {
        Button { Task { await quickReact() } } label: { Label("Add Reaction", systemImage: "face.smiling") }
        Button { onReply(message) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
        Button { app.forwarding = message } label: { Label("Forward", systemImage: "arrowshape.turn.up.forward") }
        if isOwnMessage {
            Button { beginEditing() } label: { Label("Edit Message", systemImage: "pencil") }
        }
        Button { Task { await app.pinMessage(message.id, pinned: message.pinned) } } label: {
            Label(message.pinned ? "Unpin Message" : "Pin Message", systemImage: "pin")
        }
        if !message.embeds.isEmpty {
            Button { app.hideEmbeds(for: message.id) } label: {
                Label("Hide Embed", systemImage: "eye.slash")
            }
        }
        Divider()
        Button { Clipboard.copy(message.content) } label: { Label("Copy Text", systemImage: "doc.on.doc") }
        Button { Clipboard.copy(app.messageLink(message)) } label: { Label("Copy Message Link", systemImage: "link") }
        Button { Clipboard.copy(message.id.description) } label: { Label("Copy Message ID", systemImage: "number") }
        Button { Clipboard.copy(message.author.id.description) } label: { Label("Copy User ID", systemImage: "person") }
        if isOwnMessage {
            Divider()
            Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete Message", systemImage: "trash") }
        }
    }

    private func beginEditing() {
        editText = message.content
        isEditing = true
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        guard trimmed != message.content else { return }
        if trimmed.isEmpty {
            confirmingDelete = true
        } else {
            Task { await app.editMessage(message.id, content: trimmed) }
        }
    }

    // MARK: Normal (full / grouped)

    private var normalRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Reply spine spans the full row width (its own gutter), so it lines
            // up with the avatar below instead of relying on a negative inset.
            if !isGrouped, message.isReply {
                ReplyPreviewView(reply: message.referencedMessage) { id in
                    app.jumpToMessage(id)
                }
            }
            HStack(alignment: .top, spacing: 0) {
                gutter
                VStack(alignment: .leading, spacing: 2) {
                    if !isGrouped {
                        MessageGroupHeaderView(
                            message: message,
                            authorName: authorName,
                            authorColor: authorColor,
                            isOwner: app.selectedGuildStore?.meta.ownerID == message.author.id
                        )
                    }
                    bodyContent
                }
                .padding(.trailing, 48)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, isGrouped ? 1 : 12)
        .padding(.bottom, 2)
    }

    /// The leading avatar column (full) or hover-only mini timestamp (grouped).
    @ViewBuilder
    private var gutter: some View {
        if isGrouped {
            ZStack(alignment: .trailing) {
                Color.clear
                if hovering {
                    Text(Self.gutterTime(message.timestamp))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DiscordColor.textMuted)
                        .padding(.trailing, 4)
                }
            }
            .frame(width: Layout.messageLeftGutter)
        } else {
            Button {
                showProfile = true
            } label: {
                AvatarView(
                    url: message.author.avatarURL(size: 80),
                    fallbackText: message.author.displayName,
                    size: Layout.messageAvatar
                )
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showProfile, arrowEdge: .trailing) {
                if message.guildID != nil {
                    MemberProfilePopover(
                        member: cachedMember ?? Member(user: message.author),
                        presence: app.presences.presence(message.author.id)
                    )
                } else {
                    UserProfilePopover(
                        user: message.author,
                        presence: app.presences.presence(message.author.id)
                    )
                }
            }
            .padding(.top, 2)   // align avatar top with the author-name line
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(width: Layout.messageLeftGutter, alignment: .leading)
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                editField
            } else if !message.content.isEmpty {
                MessageContentView(message: message, context: markdownContext)
            }
            if !message.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.attachments) { attachment in
                        AttachmentView(attachment: attachment)
                    }
                }
            }
            if !message.embeds.isEmpty, !app.hiddenMessageEmbeds.contains(message.id),
               !(message.flags?.contains(.suppressEmbeds) ?? false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.embeds) { embed in
                        EmbedView(embed: embed)
                    }
                }
            }
            ReactionBarView(message: message)
            if message.failedToSend {
                failedHint
            }
        }
    }

    private var failedHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text("Failed to send")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(DiscordColor.dangerRed)
    }

    private var editField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Edit message", text: $editText)
                .textFieldStyle(.plain)
                .font(DiscordFont.messageBody)
                .foregroundStyle(DiscordColor.textNormal)
                .padding(8)
                .background(DiscordColor.surfaceRaised, in: .rect(cornerRadius: 8, style: .continuous))
                .onSubmit { commitEdit() }
                .onExitCommand { isEditing = false }
            HStack(spacing: 3) {
                Text("escape to").foregroundStyle(DiscordColor.textMuted)
                Text("cancel").foregroundStyle(DiscordColor.linkBlue)
                Text("• enter to").foregroundStyle(DiscordColor.textMuted)
                Text("save").foregroundStyle(DiscordColor.linkBlue)
            }
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: System

    private var systemRow: some View {
        HStack(spacing: 8) {
            Image(systemName: systemIcon)
                .font(.system(size: 14))
                .foregroundStyle(DiscordColor.textMuted)
                .frame(width: Layout.messageLeftGutter, alignment: .center)
            Text(message.content.isEmpty ? systemFallbackText : message.content)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DiscordColor.textMuted)
            Text(Self.gutterTime(message.timestamp))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DiscordColor.textFaint)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.trailing, 16)
    }

    private var systemIcon: String {
        switch message.type {
        case .userJoin: return "arrow.right.circle.fill"
        case .channelPinnedMessage: return "pin.fill"
        case .guildBoost, .guildBoostTier1, .guildBoostTier2, .guildBoostTier3: return "sparkles"
        case .call: return "phone.fill"
        default: return "number"
        }
    }

    private var systemFallbackText: String {
        switch message.type {
        case .userJoin: return "\(message.author.displayName) joined the server."
        case .channelPinnedMessage: return "\(message.author.displayName) pinned a message to this channel."
        case .guildBoost, .guildBoostTier1, .guildBoostTier2, .guildBoostTier3:
            return "\(message.author.displayName) boosted the server!"
        default: return ""
        }
    }

    // MARK: Derived

    /// The cached guild member for the author (REST history omits message.member).
    private var cachedMember: Member? {
        if let cached = app.selectedGuildStore?.member(message.author.id) { return cached }
        if let partial = message.member {
            return Member(user: message.author, nick: partial.nick, avatar: partial.avatar,
                          roles: partial.roles, joinedAt: partial.joinedAt)
        }
        return nil
    }

    private var authorName: String {
        cachedMember?.displayName ?? message.author.displayName
    }

    private var authorColor: Color {
        if let member = cachedMember,
           let role = app.selectedGuildStore?.colorRole(for: member),
           let color = Color(discordColor: role.color) {
            return color
        }
        return DiscordColor.headerPrimary
    }

    private var isOwnMessage: Bool {
        message.author.id == app.currentUser?.id
    }

    private var mentionsMe: Bool {
        guard let me = app.currentUser?.id else { return false }
        if message.mentionEveryone { return true }
        return message.mentions.contains { $0.id == me }
    }

    private var markdownContext: MarkdownContext {
        var users: [Snowflake: String] = [:]
        for user in message.mentions { users[user.id] = user.displayName }
        // Resolve <#channel> mentions to their names (was previously empty, so
        // every channel mention rendered as a bare "channel" placeholder).
        var channels: [Snowflake: String] = [:]
        if let store = app.selectedGuildStore {
            for (id, channel) in store.channels { channels[id] = channel.name ?? "channel" }
        }
        return MarkdownContext(
            users: users,
            channels: channels,
            roles: app.selectedGuildStore?.roles ?? [:],
            currentUserID: app.currentUser?.id,
            baseSize: 15
        )
    }

    private var isHighlighted: Bool { app.highlightedMessageID == message.id }

    /// Row background: a brief blurple flash after a jump wins over the hover tint.
    @ViewBuilder private var rowBackground: some View {
        if isHighlighted {
            DiscordColor.blurple.opacity(0.16)
        } else if hovering {
            DiscordColor.messageHover
        } else {
            Color.clear
        }
    }

    /// Pinning requires Manage Messages in guilds; always allowed in DMs.
    private var canPinMessages: Bool {
        if app.selectedChannel?.type.isDM == true { return true }
        guard let perms = app.effectivePermissions(in: message.channelID) else { return false }
        return perms.contains(.manageMessages) || perms.contains(.administrator)
    }

    private func quickReact() async {
        let thumbsUp = Emoji(name: "👍")
        await app.toggleReaction(messageID: message.id, emoji: thumbsUp)
    }

    static func gutterTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
