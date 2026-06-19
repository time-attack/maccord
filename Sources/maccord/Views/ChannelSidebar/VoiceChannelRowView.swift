import SwiftUI
import MaccordCore

/// A voice/stage channel row plus the list of currently-connected occupants,
/// each indented under the channel with mute/deafen indicators.
struct VoiceChannelRowView: View {
    let channel: Channel
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppState.self) private var app
    @State private var isHovering = false

    private var iconName: String {
        channel.type == .stageVoice ? "antenna.radiowaves.left.and.right" : "speaker.wave.2.fill"
    }

    private var rowBackground: Color {
        if isSelected { return DiscordColor.channelSelected }
        if isHovering { return DiscordColor.channelHover }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(isSelected ? DiscordColor.interactiveActive : DiscordColor.channelIcon)
                        .frame(width: 20, alignment: .center)
                    Text(channel.name ?? "voice")
                        .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? DiscordColor.interactiveActive : DiscordColor.channelDefault)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    let count = app.voice.occupantCount(channel.id)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DiscordColor.textMuted)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: Layout.channelRowHeight)
                .background(rowBackground)
                .clipShape(.rect(cornerRadius: 4))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            ForEach(app.voice.states(in: channel.id)) { state in
                occupant(state)
            }
        }
    }

    @ViewBuilder
    private func occupant(_ state: VoiceState) -> some View {
        let user = state.member?.user ?? app.usersByID[state.userID]
        let name = state.member?.displayName ?? user?.displayName ?? "Unknown"
        HStack(spacing: 8) {
            AvatarView(
                url: user?.avatarURL(size: 40),
                fallbackText: name,
                size: 20
            )
            Text(name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DiscordColor.channelDefault)
                .lineLimit(1)
            Spacer(minLength: 0)
            if state.selfMute || state.mute {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DiscordColor.textMuted)
            }
            if state.selfDeaf || state.deaf {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(DiscordColor.textMuted)
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, 8)
        .frame(height: 28)
    }
}
