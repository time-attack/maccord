import SwiftUI

/// A red rule with a trailing "NEW" pill marking the first unread message.
struct UnreadDividerView: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(DiscordColor.dangerRed)
                .frame(height: 1)
            Text("NEW")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(DiscordColor.dangerRed)
                .clipShape(.rect(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal, Layout.messageHGutter)
        .padding(.vertical, 4)
    }
}
