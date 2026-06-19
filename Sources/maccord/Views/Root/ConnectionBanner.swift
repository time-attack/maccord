import SwiftUI
import MaccordCore

/// A thin status strip that drops down when the gateway is not in a healthy
/// `.ready` state — reconnecting, resuming, or fatally disconnected.
struct ConnectionBanner: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            if let info = bannerInfo {
                HStack(spacing: 8) {
                    if info.spinning {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: info.icon).foregroundStyle(.white)
                    }
                    Text(info.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassPill(tint: info.tint)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.connection)
    }

    private struct Info {
        let text: String
        let icon: String
        let tint: Color
        let spinning: Bool
    }

    private var bannerInfo: Info? {
        switch app.connection {
        case .ready, .disconnected:
            return nil
        case .connecting:
            return Info(text: "Connecting…", icon: "wifi", tint: DiscordColor.statusIdle, spinning: true)
        case .identifying:
            return Info(text: "Authenticating…", icon: "wifi", tint: DiscordColor.statusIdle, spinning: true)
        case .resuming:
            return Info(text: "Resuming session…", icon: "wifi", tint: DiscordColor.statusIdle, spinning: true)
        case .reconnecting:
            return Info(text: "Reconnecting…", icon: "wifi.exclamationmark", tint: DiscordColor.dangerRed, spinning: true)
        case .fatal(let message):
            return Info(text: message, icon: "exclamationmark.triangle.fill", tint: DiscordColor.dangerRed, spinning: false)
        }
    }
}
