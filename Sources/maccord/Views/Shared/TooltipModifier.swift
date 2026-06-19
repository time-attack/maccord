import SwiftUI

/// A Discord-style dark tooltip pill that appears on hover. Use `.discordTooltip`
/// for the server rail and icon buttons where the native yellow tooltip would
/// look out of place. The pill measures itself so it sits flush beside the view.
struct DiscordTooltip: ViewModifier {
    let text: String
    var edge: Edge = .trailing

    @State private var isHovering = false
    @State private var pillSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .overlay(alignment: overlayAlignment) {
                if isHovering && !text.isEmpty {
                    pill
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { pillSize = $0 }
                        .offset(offset)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    private var pill: some View {
        Text(text)
            .font(DiscordFont.tooltip)
            .foregroundStyle(DiscordColor.headerPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DiscordColor.bgFloating)
            .clipShape(.rect(cornerRadius: 6))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .fixedSize()
    }

    private var overlayAlignment: Alignment {
        switch edge {
        case .trailing: .trailing
        case .leading: .leading
        case .top: .top
        case .bottom: .bottom
        }
    }

    private var offset: CGSize {
        let gap: CGFloat = 12
        return switch edge {
        case .trailing: CGSize(width: pillSize.width / 2 + gap, height: 0)
        case .leading: CGSize(width: -(pillSize.width / 2 + gap), height: 0)
        case .top: CGSize(width: 0, height: -(pillSize.height / 2 + gap))
        case .bottom: CGSize(width: 0, height: pillSize.height / 2 + gap)
        }
    }
}

extension View {
    /// Tooltip helper. Uses the native `.help()` tooltip, which renders in its own
    /// top-level window — so it is never clipped by a `ScrollView`/row and always
    /// sits above everything (the custom overlay version got cut off).
    func discordTooltip(_ text: String, edge: Edge = .trailing) -> some View {
        self.help(text)
    }
}
