import SwiftUI
import MaccordCore

/// Active threads under the current channel (Discord header → Threads).
struct ThreadsListView: View {
    let channelID: Snowflake
    @Environment(AppState.self) private var app

    var body: some View {
        let threads = app.threads(in: channelID)
        VStack(alignment: .leading, spacing: 0) {
            Text("Threads").font(.system(size: 14, weight: .bold)).padding(12)
            if threads.isEmpty {
                Text("No active threads").font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
                    .padding(12)
            } else {
                ForEach(threads) { thread in
                    Button {
                        Task { await app.selectChannel(thread.id) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "number").foregroundStyle(DiscordColor.channelIcon)
                            Text(thread.name ?? "thread").font(.system(size: 14)).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12).frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.7)),
                     in: .rect(cornerRadius: 10, style: .continuous))
    }
}
