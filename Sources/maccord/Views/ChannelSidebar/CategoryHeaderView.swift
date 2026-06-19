import SwiftUI
import MaccordCore

/// A collapsible category section header: an uppercase tracked label with a
/// disclosure chevron that rotates as the section opens and closes.
struct CategoryHeaderView: View {
    let name: String
    let isCollapsed: Bool
    let toggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DiscordColor.channelDefault)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                Text(name)
                    .categoryHeaderStyle()
                    .foregroundStyle(isHovering ? DiscordColor.interactiveHover : DiscordColor.channelDefault)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(height: Layout.categoryHeaderHeight, alignment: .bottom)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isCollapsed)
    }
}
