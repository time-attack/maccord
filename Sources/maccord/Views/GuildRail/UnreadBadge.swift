import SwiftUI

/// The red mention-count capsule pinned to the bottom-trailing corner of a guild
/// icon. Renders nothing for a zero count. A separate small white dot variant
/// signals "unread, no mention".
struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(label)
                .font(DiscordFont.badge)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(minWidth: 16, minHeight: 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(DiscordColor.badgeRed)
                )
                // A small "ring" gap punched in the rail background, matching the
                // notched look Discord uses behind badges.
                .background(
                    Capsule(style: .continuous)
                        .fill(DiscordColor.bgTertiary)
                        .padding(-3)
                )
        }
    }

    private var label: String {
        count > 99 ? "99+" : "\(count)"
    }

    /// The small white "unread, no mention" dot. Callers place this where the
    /// numeric badge would otherwise go.
    struct Dot: View {
        var size: CGFloat = 8

        var body: some View {
            Circle()
                .fill(DiscordColor.headerPrimary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(DiscordColor.bgTertiary)
                        .padding(-3)
                )
        }
    }
}
