import SwiftUI
import MaccordCore

/// The pinned-messages popover for a channel (the header pin button). Fetches
/// `GET /channels/{id}/pins` and shows a compact list. Each row jumps to the
/// message in the chat (loading a window around it if needed) and highlights it,
/// shows a rich preview of attachments/embeds/stickers, and can unpin on hover.
struct PinnedMessagesView: View {
    let channelID: Snowflake

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var pins: [Message] = []
    @State private var loading = true
    @State private var hoveredID: Snowflake?

    private var canManage: Bool {
        if app.channelsByID[channelID]?.type.isDM == true { return true }
        guard let perms = app.effectivePermissions(in: channelID) else { return false }
        return perms.contains(.manageMessages) || perms.contains(.administrator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "pin.fill")
                Text("Pinned Messages")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if !pins.isEmpty {
                    Text("\(pins.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DiscordColor.textMuted)
                }
            }
            .foregroundStyle(DiscordColor.headerPrimary)
            .padding(12)
            Divider().overlay(DiscordColor.bgTertiary)

            Group {
                if loading {
                    centered { ProgressView().controlSize(.small) }
                } else if pins.isEmpty {
                    centered {
                        VStack(spacing: 6) {
                            Image(systemName: "pin.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(DiscordColor.textFaint)
                            Text("No pinned messages yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(DiscordColor.textMuted)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(pins) { pin in pinRow(pin) }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .frame(width: 380, height: 440)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 12, style: .continuous))
        .task(id: channelID) {
            loading = true
            pins = await app.loadPins(for: channelID)
            loading = false
        }
    }

    private func pinRow(_ message: Message) -> some View {
        Button {
            app.jumpToMessage(message.id, in: channelID)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(url: message.author.avatarURL(size: 48),
                           fallbackText: message.author.displayName, size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(message.author.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DiscordColor.headerPrimary)
                        Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(DiscordColor.textMuted)
                        Spacer(minLength: 0)
                    }
                    preview(for: message)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondary, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topTrailing) { rowActions(message) }
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? message.id : (hoveredID == message.id ? nil : hoveredID) }
    }

    /// Rich preview: text, then attachment thumbnails / file chips, embed and
    /// sticker indicators — instead of the old bare "(attachment)" placeholder.
    @ViewBuilder
    private func preview(for message: Message) -> some View {
        if !message.content.isEmpty {
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(DiscordColor.textNormal)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }

        if let image = message.attachments.first(where: { $0.isImage }) {
            CachedAsyncImage(url: image.bestURL)
                .frame(width: 120, height: 72)
                .clipShape(.rect(cornerRadius: 6, style: .continuous))
        }

        ForEach(message.attachments.filter { !$0.isImage }) { file in
            attachmentChip(systemImage: fileIcon(file), label: file.filename, detail: file.humanSize)
        }

        if let embed = message.embeds.first {
            let label = embed.title ?? embed.description ?? embed.url ?? "Embed"
            attachmentChip(systemImage: "link", label: label, detail: nil)
        }

        if let sticker = message.stickerItems.first {
            attachmentChip(systemImage: "face.smiling.inverse", label: "Sticker: \(sticker.name)", detail: nil)
        }

        if message.content.isEmpty, message.attachments.isEmpty,
           message.embeds.isEmpty, message.stickerItems.isEmpty {
            Text("Click to jump to message")
                .font(.system(size: 13))
                .foregroundStyle(DiscordColor.textMuted)
        }
    }

    private func attachmentChip(systemImage: String, label: String, detail: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(DiscordColor.interactiveNormal)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DiscordColor.linkBlue)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(DiscordColor.textMuted)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private func rowActions(_ message: Message) -> some View {
        if hoveredID == message.id {
            HStack(spacing: 4) {
                actionButton("arrow.right.circle.fill", help: "Jump") {
                    app.jumpToMessage(message.id, in: channelID)
                    dismiss()
                }
                if canManage {
                    actionButton("xmark.circle.fill", help: "Unpin") {
                        Task {
                            await app.pinMessage(message.id, pinned: true)  // currently pinned → unpin
                            pins.removeAll { $0.id == message.id }
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private func actionButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(DiscordColor.interactiveNormal)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func fileIcon(_ attachment: Attachment) -> String {
        if attachment.isVideo { return "play.rectangle.fill" }
        if attachment.isAudio { return "waveform" }
        return "doc.fill"
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack { Spacer(); content(); Spacer() }.frame(maxWidth: .infinity)
    }
}
