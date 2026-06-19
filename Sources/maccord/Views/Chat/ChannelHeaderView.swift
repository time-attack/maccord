import SwiftUI
import MaccordCore

/// The top bar of the chat column: the channel's "#" icon + name, an optional
/// topic, and a trailing toolbar of icon buttons plus a compact search field.
struct ChannelHeaderView: View {
    @Environment(AppState.self) private var app

    let channel: Channel

    @State private var searchText = ""
    @State private var showPins = false
    @State private var showThreads = false
    @State private var showTopic = false
    @State private var pinCount = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: channelIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DiscordColor.channelIcon)

            Text(channel.displayName(currentUserID: app.currentUser?.id))
                .font(DiscordFont.channelHeaderTitle)
                .foregroundStyle(DiscordColor.headerPrimary)
                .lineLimit(1)
                .fixedSize()

            if let topic = channel.topic, !topic.isEmpty {
                Rectangle()
                    .fill(DiscordColor.divider)
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 4)
                Button { showTopic = true } label: {
                    Text(topic)
                        .font(DiscordFont.channelTopic)
                        .foregroundStyle(DiscordColor.channelDefault)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTopic, arrowEdge: .bottom) {
                    Text(topic)
                        .font(.system(size: 14))
                        .foregroundStyle(DiscordColor.textNormal)
                        .padding(14)
                        .frame(maxWidth: 360)
                }
            }

            Spacer(minLength: 12)

            toolbar
        }
        .padding(.horizontal, Layout.messageHGutter)
        .frame(height: Layout.headerHeight)
        .glassEffect(.regular.tint(DiscordColor.bgSecondary.opacity(0.45)), in: .rect(cornerRadius: 0))
        // A single subtle bottom border (no doubled divider + shadow).
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.16))
                .frame(height: 1)
        }
        .zIndex(1)
        .task(id: channel.id) {
            pinCount = (await app.loadPins(for: channel.id)).count
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            if !channel.type.isDM {
                iconButton("bubble.left.and.bubble.right", help: "Threads") { showThreads.toggle() }
                    .popover(isPresented: $showThreads, arrowEdge: .bottom) {
                        ThreadsListView(channelID: channel.id)
                    }
                iconButton("bell.fill", help: "Notification Settings") {
                    if let gid = channel.guildID { app.notificationSettingsGuildID = gid }
                }
            }
            ZStack(alignment: .topTrailing) {
                iconButton("pin.fill", help: "Pinned Messages") { showPins.toggle() }
                if pinCount > 0 {
                    Text("\(min(pinCount, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(DiscordColor.badgeRed))
                        .offset(x: 6, y: -6)
                }
            }
            .popover(isPresented: $showPins, arrowEdge: .bottom) {
                PinnedMessagesView(channelID: channel.id)
            }
            if !channel.type.isDM {
                iconButton(
                    "person.2.fill",
                    help: app.showMemberList ? "Hide Member List" : "Show Member List",
                    active: app.showMemberList
                ) {
                    app.showMemberList.toggle()
                }
            }
            searchField
        }
    }

    @FocusState private var searchFocused: Bool

    private var searchField: some View {
        HStack(spacing: 6) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(DiscordFont.searchText)
                .foregroundStyle(DiscordColor.textNormal)
                .focused($searchFocused)
                .frame(width: searchFocused || !searchText.isEmpty ? 180 : 130)
                .onSubmit(runSearch)
            Button(action: runSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(DiscordColor.channelIcon)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(DiscordColor.bgTertiary)
        .clipShape(.rect(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(searchFocused ? DiscordColor.blurple.opacity(0.6) : .clear, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.15), value: searchFocused)
    }

    private func runSearch() {
        app.searchSeed = searchText.trimmingCharacters(in: .whitespaces)
        app.showSearch = true
    }

    private func iconButton(_ symbol: String, help: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(active ? DiscordColor.interactiveActive : DiscordColor.interactiveNormal)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .discordTooltip(help, edge: .bottom)
    }

    private var channelIcon: String {
        switch channel.type {
        case .voice, .stageVoice: return "speaker.wave.2.fill"
        case .announcement: return "megaphone.fill"
        case .forum: return "list.bullet.rectangle"
        case .dm, .groupDM: return "at"
        default:
            return channel.type.isThread ? "number" : "number"
        }
    }
}
