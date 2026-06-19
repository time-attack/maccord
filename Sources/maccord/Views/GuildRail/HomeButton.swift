import SwiftUI

/// The Discord "Home"/DM button at the top of the server rail. Behaves like a
/// guild icon: a 48×48 squircle that morphs toward a circle on hover/selection,
/// tints to blurple, and carries a leading selection pill.
struct HomeButton: View {
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var isActive: Bool { isSelected || isHovering }

    private var pillState: SelectionPill.PillState {
        if isSelected { return .selected }
        if isHovering { return .hovered }
        return .hidden
    }

    var body: some View {
        HStack(spacing: 0) {
            SelectionPill(state: pillState)
                .frame(width: Layout.pillWidth)

            Spacer(minLength: 0)

            Button(action: action) {
                tile
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            .discordTooltip("Direct Messages")

            Spacer(minLength: 0)
        }
        .frame(width: Layout.guildRailWidth, height: Layout.serverIconSize)
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: isActive ? Layout.iconCornerActive : Layout.iconRadiusIdle,
                style: .continuous
            )
            .fill(isActive ? DiscordColor.blurple : DiscordColor.bgSecondary)

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isActive ? .white : DiscordColor.headerSecondary)
        }
        .frame(width: Layout.serverIconSize, height: Layout.serverIconSize)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }
}
