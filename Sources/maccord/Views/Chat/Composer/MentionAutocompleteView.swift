import SwiftUI
import MaccordCore

/// A minimal mention-autocomplete popover: a short list of member names on a
/// floating panel. Tapping a row calls `onPick`.
struct MentionAutocompleteView: View {
    let entries: [Entry]
    var onPick: (Entry) -> Void = { _ in }

    struct Entry: Identifiable {
        let id: Snowflake
        let displayName: String
        let avatarURL: URL?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Members")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DiscordColor.textMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            ForEach(entries) { entry in
                Button {
                    onPick(entry)
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(url: entry.avatarURL, fallbackText: entry.displayName, size: 24)
                        Text(entry.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DiscordColor.textNormal)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .contentShape(.rect)
                }
                .buttonStyle(MentionRowStyle())
            }
        }
        .padding(.vertical, 4)
        .frame(width: 260)
        .background(DiscordColor.bgFloating)
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }
}

private struct MentionRowStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hovering ? DiscordColor.bgModifierHover : .clear)
            .onHover { hovering = $0 }
    }
}
