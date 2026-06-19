import SwiftUI
import MaccordCore

/// Discord's status indicator: a mask-cut shape "punched" out of the avatar's
/// bottom-right with a surface-colored gap ring. These are NOT bordered dots —
/// idle is a crescent, dnd a bar-cut circle, offline a hollow ring (drawn with
/// even-odd fills), matching the real client geometry.
struct PresenceDotView: View {
    let status: Status
    var size: CGFloat = Layout.presenceDotSize
    var borderColor: Color = DiscordColor.bgSecondary
    var showStreaming: Bool = false

    private var gap: CGFloat { max(2, size * 0.22) }

    var body: some View {
        ZStack {
            // Surface-colored gap so the dot reads as punched out of the avatar.
            Circle()
                .fill(borderColor)
                .frame(width: size + gap, height: size + gap)
            StatusShape(status: status)
                .fill(color, style: FillStyle(eoFill: true))
                .frame(width: size, height: size)
        }
    }

    private var color: Color {
        switch status {
        case .online: DiscordColor.statusOnline
        case .idle: DiscordColor.statusIdle
        case .dnd: DiscordColor.statusDND
        case .invisible, .offline: DiscordColor.statusOffline
        }
    }
}

/// Even-odd status geometry per Discord's mask-cut shapes.
private struct StatusShape: Shape, @unchecked Sendable {
    let status: Status

    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        var p = Path()
        switch status {
        case .online:
            p.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))

        case .idle:
            // Crescent: full circle minus a circle subtracted toward the top-left.
            p.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
            p.addEllipse(in: CGRect(x: -0.28 * d, y: -0.28 * d, width: 0.78 * d, height: 0.78 * d))

        case .dnd:
            // Circle with a horizontal rounded bar cut out of the middle.
            p.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
            let bw = 0.60 * d, bh = 0.24 * d
            p.addRoundedRect(
                in: CGRect(x: (d - bw) / 2, y: (d - bh) / 2, width: bw, height: bh),
                cornerSize: CGSize(width: bh / 2, height: bh / 2)
            )

        case .invisible, .offline:
            // Hollow ring (donut).
            p.addEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
            let hole = 0.42 * d
            p.addEllipse(in: CGRect(x: (d - hole) / 2, y: (d - hole) / 2, width: hole, height: hole))
        }
        return p
    }
}
