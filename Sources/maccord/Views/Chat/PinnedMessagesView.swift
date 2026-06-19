import SwiftUI
import MaccordCore

/// The pinned-messages popover for a channel (the header pin button). Fetches
/// `GET /channels/{id}/pins` and shows a compact list.
struct PinnedMessagesView: View {
    let channelID: Snowflake

    @Environment(AppState.self) private var app
    @State private var pins: [Message] = []
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "pin.fill")
                Text("Pinned Messages")
                    .font(.system(size: 15, weight: .semibold))
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
        .frame(width: 360, height: 400)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 12, style: .continuous))
        .task(id: channelID) {
            loading = true
            pins = await app.loadPins(for: channelID)
            loading = false
        }
    }

    private func pinRow(_ message: Message) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: message.author.avatarURL(size: 48),
                       fallbackText: message.author.displayName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(message.author.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                    Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(DiscordColor.textMuted)
                }
                Text(message.content.isEmpty ? "(attachment)" : message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(DiscordColor.textNormal)
                    .lineLimit(4)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiscordColor.bgSecondary, in: .rect(cornerRadius: 8, style: .continuous))
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack { Spacer(); content(); Spacer() }.frame(maxWidth: .infinity)
    }
}
