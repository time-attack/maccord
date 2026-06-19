import SwiftUI
import MaccordCore

/// The 4-pane Discord layout: server rail → channel sidebar (or DM list) → chat →
/// member list. Built as a fixed-width HStack to match Discord pixel-for-pixel;
/// Liquid Glass lives on the floating chrome inside each pane, not the panels.
struct MainWindowView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            GuildRailView()
                .frame(width: Layout.guildRailWidth)

            sidebar
                .frame(width: Layout.channelSidebarWidth)

            Divider().overlay(DiscordColor.bgTertiary)

            ChatView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if app.showMemberList && app.selectedGuildID != nil {
                MemberListView()
                    .frame(width: Layout.memberListWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            ConnectionBanner()
        }
        .overlay(alignment: .bottomLeading) {
            if app.voice.connectedChannelID != nil {
                VoicePanelView()
                    .padding(.leading, Layout.guildRailWidth + 8)
                    .padding(.bottom, Layout.userPanelHeight + 8)
            }
        }
        .overlay {
            EmptyView()
        }
        // ⌘K quick switcher as a sheet — reliable keyboard focus + input.
        .sheet(isPresented: Binding(
            get: { app.showQuickSwitcher },
            set: { app.showQuickSwitcher = $0 }
        )) {
            QuickSwitcherView(isPresented: Binding(
                get: { app.showQuickSwitcher },
                set: { app.showQuickSwitcher = $0 }
            ))
        }
        .sheet(isPresented: Binding(
            get: { app.serverSettingsGuildID != nil },
            set: { if !$0 { app.serverSettingsGuildID = nil } }
        )) {
            if let id = app.serverSettingsGuildID {
                ServerSettingsView(guildID: id)
            }
        }
        .sheet(isPresented: Binding(
            get: { app.notificationSettingsGuildID != nil },
            set: { if !$0 { app.notificationSettingsGuildID = nil } }
        )) {
            if let id = app.notificationSettingsGuildID {
                NotificationSettingsView(guildID: id)
            }
        }
        .sheet(isPresented: Binding(
            get: { app.showSearch },
            set: { app.showSearch = $0 }
        )) {
            SearchPanelView(seed: app.searchSeed)
        }
        .sheet(isPresented: Binding(
            get: { app.showKeybinds },
            set: { app.showKeybinds = $0 }
        )) {
            KeybindsHelpView()
        }
        .animation(.easeInOut(duration: 0.2), value: app.showMemberList)
        .animation(.easeOut(duration: 0.12), value: app.showQuickSwitcher)
    }

    @ViewBuilder
    private var sidebar: some View {
        if app.selectedGuildID == nil {
            DMListView()
        } else {
            ChannelSidebarView()
        }
    }
}
