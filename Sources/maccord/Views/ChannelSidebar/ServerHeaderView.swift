import SwiftUI
import MaccordCore

/// The 48pt header atop the channel sidebar: the guild name + a disclosure
/// chevron that opens the server dropdown menu (mark read, copy id, mute…).
struct ServerHeaderView: View {
    let guild: Guild

    @Environment(AppState.self) private var app
    @State private var isHovering = false
    @State private var menuOpen = false

    var body: some View {
        Button { menuOpen.toggle() } label: {
            HStack(spacing: 8) {
                Text(guild.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: menuOpen ? "xmark" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiscordColor.interactiveNormal)
            }
            .padding(.horizontal, 16)
            .frame(height: Layout.headerHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering || menuOpen ? DiscordColor.bgModifierHover : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DiscordColor.bgTertiary).frame(height: 1)
        }
        .onHover { isHovering = $0 }
        .popover(isPresented: $menuOpen, arrowEdge: .bottom) {
            serverMenu
        }
    }

    private var isOwner: Bool { guild.ownerID == app.currentUser?.id }
    private var canManage: Bool { app.canManageGuild(guild.id) }

    private var serverMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            if canManage {
                menuRow("Server Settings", "gearshape.fill") { app.serverSettingsGuildID = guild.id }
            }
            menuRow("Notification Settings", "bell.fill") { app.notificationSettingsGuildID = guild.id }
            Divider().overlay(DiscordColor.divider).padding(.vertical, 2)
            menuRow("Mark As Read", "envelope.open") { Task { await app.markGuildRead(guild.id) } }
            menuRow("Invite People", "person.crop.circle.badge.plus") {
                Task { if let url = await app.createInvite(forGuild: guild.id) { Clipboard.copy(url) } }
            }
            menuRow("Copy Server ID", "number") { Clipboard.copy(guild.id.description) }
            if !isOwner {
                Divider().overlay(DiscordColor.divider).padding(.vertical, 2)
                menuRow("Leave Server", "rectangle.portrait.and.arrow.right", destructive: true) {
                    Task { await app.leaveGuild(guild.id) }
                }
            }
        }
        .padding(6)
        .frame(width: 240)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 10, style: .continuous))
    }

    private func menuRow(_ title: String, _ symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button { action(); menuOpen = false } label: {
            HStack {
                Text(title).font(.system(size: 14, weight: .medium))
                Spacer(minLength: 12)
                Image(systemName: symbol).font(.system(size: 13))
            }
            .foregroundStyle(destructive ? DiscordColor.dangerRed : DiscordColor.interactiveNormal)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }
}

/// Small reusable hover background for menu rows.
private struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? DiscordColor.blurple : Color.clear, in: .rect(cornerRadius: 4))
            .onHover { hovering = $0 }
    }
}
private extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }
}
