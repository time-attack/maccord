import SwiftUI
import MaccordCore

/// The chat column: channel header, scrolling message list, a thin typing
/// indicator above the composer, and the composer itself. Composes the area for
/// the currently selected channel, or a friendly empty state when none.
struct ChatView: View {
    @Environment(AppState.self) private var app

    @State private var replyingTo: Message?

    var body: some View {
        VStack(spacing: 0) {
            if let channel = app.selectedChannel {
                ChannelHeaderView(channel: channel)

                if channel.nsfw == true, !app.nsfwAcknowledged.contains(channel.id) {
                    NSFWChannelBanner(channel: channel)
                } else if let store = app.currentMessageStore {
                    MessageListView(store: store) { message in
                        replyingTo = message
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }

                if !typingNames.isEmpty {
                    TypingIndicatorView(names: typingNames)
                }

                ComposerView(replyingTo: $replyingTo)
            } else if app.selectedGuildID == nil {
                FriendsView()
            } else {
                emptyState
            }
        }
        .background(DiscordColor.panelChat)
        .onChange(of: app.selectedChannelID) { _, _ in
            replyingTo = nil
        }
    }

    // MARK: Typing

    private var typingNames: [String] {
        guard let channelID = app.selectedChannelID else { return [] }
        let me = app.currentUser?.id
        return app.typing.typingUserIDs(in: channelID)
            .filter { $0 != me }
            .map { app.typing.name($0) }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(DiscordColor.bgModifierHover)
            Text("No channel selected")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DiscordColor.headerSecondary)
            Text("Pick a channel from the sidebar to start chatting.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DiscordColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DiscordColor.panelChat)
    }
}
