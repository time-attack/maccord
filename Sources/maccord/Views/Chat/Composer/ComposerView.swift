import SwiftUI
import MaccordCore

/// The message input bar at the bottom of the chat column.
struct ComposerView: View {
    @Environment(AppState.self) private var app

    @Binding var replyingTo: Message?

    @State private var text = ""
    @State private var showEmoji = false
    @State private var editorHeight: CGFloat = 22
    @State private var slowmodeTick = Date()
    @State private var autocomplete: (ComposerAutocompleteView.Kind, String, Int)?
    @FocusState private var focused: Bool

    private var channelID: Snowflake? { app.selectedChannelID }

    private var canSend: Bool {
        guard let id = channelID else { return true }
        return app.canSendMessages(in: id) && !app.isSlowmodeBlocked(in: id)
    }

    private var slowmodeSeconds: Int { app.selectedChannel?.slowmodeSeconds ?? 0 }

    private var showSlowmodeHint: Bool {
        guard slowmodeSeconds > 0, let id = channelID else { return false }
        return !app.isSlowmodeExempt(in: id)
    }

    private var slowmodeRemaining: Int {
        guard let id = channelID else { return 0 }
        return app.slowmodeRemaining(in: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            if app.canSendMessages(in: channelID ?? Snowflake(0)) {
                if let ac = autocomplete {
                    ComposerAutocompleteView(kind: ac.0, query: ac.1) { insert in
                        applyAutocomplete(insert: insert, triggerAt: ac.2)
                    }
                    .padding(.bottom, 4)
                }
                if let reply = replyingTo { replyBar(reply) }
                inputBar
                if showSlowmodeHint { slowmodeHint }
            } else {
                noPermissionBar
            }
        }
        .padding(.horizontal, Layout.composerHPadding)
        .padding(.bottom, 16)
        .padding(.top, 6)
        .background(DiscordColor.bgPrimary)
        .onChange(of: text) { _, new in detectAutocomplete(in: new) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if showSlowmodeHint && slowmodeRemaining > 0 { slowmodeTick = Date() }
        }
    }

    private func detectAutocomplete(in value: String) {
        guard let range = value.range(of: #"[@#:][^\s]*$"#, options: .regularExpression) else {
            autocomplete = nil
            return
        }
        let token = String(value[range])
        let offset = value.distance(from: value.startIndex, to: range.lowerBound)
        if token.hasPrefix("@") {
            autocomplete = (.mention, String(token.dropFirst()), offset)
        } else if token.hasPrefix("#") {
            autocomplete = (.channel, String(token.dropFirst()), offset)
        } else if token.hasPrefix(":") {
            autocomplete = (.emoji, String(token.dropFirst()), offset)
        } else {
            autocomplete = nil
        }
    }

    private func applyAutocomplete(insert: String, triggerAt: Int) {
        let idx = text.index(text.startIndex, offsetBy: min(triggerAt, text.count))
        text = String(text[..<idx]) + insert + " "
        autocomplete = nil
    }

    private var noPermissionBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("You do not have permission to send messages in this channel.")
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(DiscordColor.textMuted)
        .padding(.horizontal, 16)
        .frame(minHeight: Layout.composerMinHeight)
        .background(DiscordColor.surfaceRaised.opacity(0.5))
        .clipShape(.rect(cornerRadius: Layout.composerRadius, style: .continuous))
    }

    private func replyBar(_ reply: Message) -> some View {
        HStack(spacing: 2) {
            Text("Replying to ").font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
            Text(reply.author.displayName).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DiscordColor.headerSecondary).lineLimit(1)
            Spacer(minLength: 0)
            Button { replyingTo = nil } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                    .foregroundStyle(DiscordColor.interactiveNormal)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(DiscordColor.bgSecondaryAlt)
        .clipShape(.rect(topLeadingRadius: Layout.composerRadius, topTrailingRadius: Layout.composerRadius))
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {} label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 20))
                    .foregroundStyle(DiscordColor.interactiveNormal)
            }.buttonStyle(.plain).help("Upload a file")

            ComposerTextEditor(text: $text, measuredHeight: $editorHeight, placeholder: placeholder,
                               onSend: { send() }, onChange: { app.notifyTyping() })
                .frame(height: editorHeight)
                .disabled(!canSend)

            trailingButtons
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(DiscordColor.surfaceRaised)
        .clipShape(inputBarShape)
        .opacity(canSend ? 1 : 0.55)
    }

    private var inputBarShape: AnyShape {
        if replyingTo == nil {
            return AnyShape(RoundedRectangle(cornerRadius: Layout.composerRadius, style: .continuous))
        }
        return AnyShape(UnevenRoundedRectangle(bottomLeadingRadius: Layout.composerRadius,
                                               bottomTrailingRadius: Layout.composerRadius))
    }

    private var trailingButtons: some View {
        HStack(spacing: 14) {
            composerIcon("gift", help: "Send a gift") {}
            composerIcon("face.smiling", help: "Emoji") { showEmoji.toggle() }
                .popover(isPresented: $showEmoji, arrowEdge: .top) {
                    EmojiPickerView { emoji in
                        if emoji.isCustom, let id = emoji.id {
                            text += "<\(emoji.isAnimated ? "a" : ""):\(emoji.name ?? "emoji"):\(id.rawValue)>"
                        } else { text += emoji.name ?? "" }
                    }
                }
            composerIcon("photo.on.rectangle", help: "Sticker") {}
            if !text.isEmpty && canSend {
                Button(action: send) {
                    Image(systemName: "paperplane.fill").font(.system(size: 18))
                        .foregroundStyle(DiscordColor.blurple)
                }.buttonStyle(.plain).help("Send (Return)")
            }
        }
    }

    private func composerIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(DiscordColor.interactiveNormal)
        }.buttonStyle(.plain).help(help)
    }

    private var slowmodeHint: some View {
        HStack(spacing: 4) {
            Image(systemName: slowmodeRemaining > 0 ? "hourglass" : "clock").font(.system(size: 11))
            Text(slowmodeRemaining > 0
                 ? "Slowmode: wait \(slowmodeRemaining)s before sending again."
                 : "Slowmode is enabled (\(slowmodeSeconds)s between messages).")
                .font(.system(size: 12))
        }
        .foregroundStyle(DiscordColor.textMuted)
        .padding(.top, 4).id(slowmodeTick)
    }

    private var placeholder: String {
        if slowmodeRemaining > 0 { return "Slowmode enabled…" }
        if let channel = app.selectedChannel {
            return "Message #\(channel.displayName(currentUserID: app.currentUser?.id))"
        }
        return "Message"
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canSend else { return }
        let reference: MessageReference?
        if let reply = replyingTo, let channelID = app.selectedChannelID {
            reference = MessageReference.reply(to: reply.id, in: channelID, guildID: reply.guildID)
        } else { reference = nil }
        let toSend = text
        text = ""; replyingTo = nil; autocomplete = nil
        Task { await app.sendMessage(content: toSend, replyingTo: reference) }
    }
}
