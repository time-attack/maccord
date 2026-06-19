import SwiftUI

/// The floating action bar on a hovered message row.
struct MessageHoverToolbar: View {
    var showReact: Bool = true
    var canEdit: Bool = false
    var canDelete: Bool = false
    var onReact: () -> Void = {}
    var onReply: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        GlassEffectContainer(spacing: 2) {
            HStack(spacing: 2) {
                if showReact {
                    button("face.smiling", help: "Add Reaction", action: onReact)
                }
                button("arrowshape.turn.up.left.fill", help: "Reply", action: onReply)
                if canEdit {
                    button("square.and.pencil", help: "Edit", action: onEdit)
                }
                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DiscordColor.dangerRed)
                            .frame(width: 30, height: 30)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .discordTooltip("Delete", edge: .top)
                }
            }
            .padding(2)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }

    private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(HoverIconButtonStyle())
        .discordTooltip(help, edge: .top)
    }
}

/// A plain icon button that lightens from interactiveNormal to interactiveHover
/// on hover, with a subtle hover background. Used throughout the chat chrome.
struct HoverIconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(hovering ? DiscordColor.interactiveHover : DiscordColor.interactiveNormal)
            .background {
                if hovering {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DiscordColor.bgModifierHover.opacity(0.5))
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.08), value: hovering)
    }
}
