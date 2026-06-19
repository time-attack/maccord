import SwiftUI
import MaccordCore

/// A floating "Voice Connected" HUD shown above the user panel while connected to
/// a voice channel. Real audio transport is a later milestone (see VoiceStore);
/// the mute/deafen/disconnect controls drive the local intent flags for now.
struct VoicePanelView: View {
    @Environment(AppState.self) private var app

    /// Surfaced so the orchestrator can decide whether to slot the panel in.
    static let isAudioStub = true

    var body: some View {
        if let channelID = app.voice.connectedChannelID {
            panel(channelID: channelID)
        }
    }

    @ViewBuilder
    private func panel(channelID: Snowflake) -> some View {
        let voice = app.voice
        let channel = app.channelsByID[channelID]
        let channelName = channel?.name ?? "Voice"
        let guildName = channel?.guildID.flatMap { app.guildStores[$0]?.meta.name }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DiscordColor.green)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Voice Connected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DiscordColor.green)
                        .lineLimit(1)
                    Text(guildName.map { "\(channelName) / \($0)" } ?? channelName)
                        .font(DiscordFont.panelSubtext)
                        .foregroundStyle(DiscordColor.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    disconnect()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DiscordColor.interactiveNormal)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.glass)
                .tint(DiscordColor.dangerRed)
                .help("Disconnect")
            }

            HStack(spacing: 8) {
                controlButton(
                    title: voice.selfMute ? "Unmute" : "Mute",
                    systemImage: voice.selfMute ? "mic.slash.fill" : "mic.fill",
                    isActive: voice.selfMute
                ) {
                    voice.selfMute.toggle()
                }

                controlButton(
                    title: voice.selfDeaf ? "Undeafen" : "Deafen",
                    systemImage: voice.selfDeaf ? "speaker.slash.fill" : "headphones",
                    isActive: voice.selfDeaf
                ) {
                    voice.selfDeaf.toggle()
                    if voice.selfDeaf { voice.selfMute = true }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DiscordColor.green.opacity(0.25), lineWidth: 1)
        }
        .padding(8)
    }

    private func controlButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isActive ? DiscordColor.dangerRed : DiscordColor.interactiveNormal)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .help(title)
    }

    private func disconnect() {
        app.voice.connectedChannelID = nil
        app.voice.selfMute = false
        app.voice.selfDeaf = false
    }
}
