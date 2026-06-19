import SwiftUI
import MaccordCore

/// The bottom user panel: the current account's avatar + name, plus mic, deafen
/// and settings controls. Mic/deafen toggle the voice store's intent flags.
struct UserPanelView: View {
    @Environment(AppState.self) private var app
    @Environment(\.openSettings) private var openSettings
    @State private var showSelfProfile = false

    var body: some View {
        HStack(spacing: 8) {
            if let user = app.currentUser {
                Button {
                    showSelfProfile = true
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(
                            url: user.avatarURL(size: 64),
                            fallbackText: user.displayName,
                            size: 32,
                            status: app.currentUserStatus,
                            dotBorderColor: DiscordColor.bgSecondaryAlt
                        )
                        VStack(alignment: .leading, spacing: 0) {
                            Text(user.displayName)
                                .font(DiscordFont.panelUsername)
                                .foregroundStyle(DiscordColor.headerPrimary)
                                .lineLimit(1)
                            Text(subtext(for: user))
                                .font(DiscordFont.panelSubtext)
                                .foregroundStyle(DiscordColor.textMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSelfProfile, arrowEdge: .top) {
                    UserProfilePopover(user: user.asUser)
                }
            } else {
                Text("Connecting…")
                    .font(DiscordFont.panelUsername)
                    .foregroundStyle(DiscordColor.textMuted)
            }

            Spacer(minLength: 4)

            iconButton(
                systemName: app.voice.selfMute ? "mic.slash.fill" : "mic.fill",
                tint: app.voice.selfMute ? DiscordColor.dangerRed : DiscordColor.interactiveNormal,
                tooltip: app.voice.selfMute ? "Unmute" : "Mute"
            ) {
                app.voice.selfMute.toggle()
                if !app.voice.selfMute { app.voice.selfDeaf = false }
            }

            iconButton(
                systemName: app.voice.selfDeaf ? "headphones.slash" : "headphones",
                tint: app.voice.selfDeaf ? DiscordColor.dangerRed : DiscordColor.interactiveNormal,
                tooltip: app.voice.selfDeaf ? "Undeafen" : "Deafen"
            ) {
                app.voice.selfDeaf.toggle()
                if app.voice.selfDeaf { app.voice.selfMute = true }
            }

            iconButton(
                systemName: "gearshape.fill",
                tint: DiscordColor.interactiveNormal,
                tooltip: "User Settings"
            ) { openSettings() }
        }
        .padding(.horizontal, 8)
        .frame(height: Layout.userPanelHeight)
        .glassEffect(.regular.tint(DiscordColor.bgSecondaryAlt.opacity(0.6)), in: .rect(cornerRadius: 0))
    }

    private func subtext(for user: CurrentUser) -> String {
        let handle: String
        if user.discriminator == "0" || user.discriminator.isEmpty {
            handle = user.username
        } else {
            handle = "\(user.username)#\(user.discriminator)"
        }
        return "#\(handle)"
    }

    @ViewBuilder
    private func iconButton(
        systemName: String,
        tint: Color,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .contentShape(.rect(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .discordTooltip(tooltip, edge: .top)
    }
}
