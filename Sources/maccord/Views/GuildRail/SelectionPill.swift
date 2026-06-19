import SwiftUI

/// The white indicator bar that hugs the left edge of the server rail. Its height
/// encodes the icon's state: hidden, a small unread dot, a hover nub, or the full
/// selected bar. Heights animate ~150ms so the bar grows/shrinks like Discord's.
struct SelectionPill: View {
    enum PillState: Equatable {
        case hidden
        case unread
        case hovered
        case selected
    }

    let state: PillState

    private var height: CGFloat {
        switch state {
        case .hidden:   0
        case .unread:   Layout.pillUnreadHeight     // 8
        case .hovered:  Layout.pillHoverHeight       // 20
        case .selected: Layout.pillSelectedHeight    // 40
        }
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(DiscordColor.headerPrimary)
            .frame(width: Layout.pillWidth, height: height)
            // The pill is fully rounded on the right and flush to the rail's left
            // edge, so it reads as a bar emerging from the wall.
            .offset(x: -Layout.pillWidth / 2)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: state)
    }
}
