import SwiftUI
import MaccordCore

/// NSFW channel age-gate (Discord shows a banner before revealing content).
struct NSFWChannelBanner: View {
    let channel: Channel
    @Environment(AppState.self) private var app

    var body: some View {
        if channel.nsfw == true, !app.nsfwAcknowledged.contains(channel.id) {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DiscordColor.statusIdle)
                Text("NSFW Channel")
                    .font(.system(size: 18, weight: .bold))
                Text("This channel may contain content inappropriate for viewers under 18.")
                    .font(.system(size: 14))
                    .foregroundStyle(DiscordColor.textMuted)
                    .multilineTextAlignment(.center)
                Button("I am 18 or older — Enter Channel") {
                    app.acknowledgeNSFW(channel.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(DiscordColor.blurple)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DiscordColor.panelChat)
        }
    }
}
