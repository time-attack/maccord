import SwiftUI
import MaccordCore

/// Per-server notification settings (level + mute), Apple-styled on glass.
struct NotificationSettingsView: View {
    let guildID: Snowflake

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var suppressEveryone = false

    private var guild: Guild? { app.guildStores[guildID]?.meta }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(url: guild?.iconURL(size: 96), fallbackText: guild?.acronym ?? "S", size: 36)
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notification Settings").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                    Text(guild?.name ?? "Server").font(.system(size: 12))
                        .foregroundStyle(DiscordColor.textMuted)
                }
                Spacer()
            }
            .padding(16)
            Divider().overlay(DiscordColor.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { app.mutedGuilds.contains(guildID) },
                        set: { _ in app.toggleGuildMute(guildID) }
                    )) {
                        Label("Mute \(guild?.name ?? "Server")", systemImage: "bell.slash.fill")
                    }
                    .toggleStyle(.switch)
                    .tint(DiscordColor.blurple)

                    section("Server Notification Settings") {
                        ForEach(AppState.NotificationLevel.allCases) { level in
                            radioRow(level)
                        }
                    }

                    section("Suppress") {
                        Toggle("Suppress @everyone and @here", isOn: $suppressEveryone)
                            .toggleStyle(.switch)
                            .tint(DiscordColor.blurple)
                            .font(.system(size: 14))
                            .foregroundStyle(DiscordColor.textNormal)
                    }
                }
                .padding(16)
            }

            Divider().overlay(DiscordColor.divider)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(DiscordColor.blurple)
            }
            .padding(12)
        }
        .frame(width: 460, height: 420)
        .background(DiscordColor.bgSecondary)
    }

    private func radioRow(_ level: AppState.NotificationLevel) -> some View {
        let selected = app.notificationLevel(guildID) == level
        return Button { app.setNotificationLevel(level, for: guildID) } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? DiscordColor.blurple : DiscordColor.interactiveMuted)
                Text(level.label).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DiscordColor.textNormal)
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(selected ? DiscordColor.bgModifierHover : Color.clear,
                       in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(0.4)
                .foregroundStyle(DiscordColor.headerSecondary)
            content()
        }
    }
}
