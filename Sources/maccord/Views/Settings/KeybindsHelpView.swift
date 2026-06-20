import SwiftUI

/// A searchable reference of keyboard shortcuts (⌘/). Mirrors the bindings
/// registered in `maccordApp` plus the in-view ones.
struct KeybindsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct Shortcut: Identifiable {
        let id = UUID()
        let keys: String
        let action: String
    }

    private let shortcuts: [Shortcut] = [
        .init(keys: "⌘K", action: "Quick Switcher — jump to any server, channel, DM or friend"),
        .init(keys: "⌘U", action: "Toggle Member List"),
        .init(keys: "⌘/", action: "Keyboard Shortcuts"),
        .init(keys: "⌥↑", action: "Previous Channel"),
        .init(keys: "⌥↓", action: "Next Channel"),
        .init(keys: "⌘=", action: "Increase Text Size"),
        .init(keys: "⌘−", action: "Decrease Text Size"),
        .init(keys: "⌘,", action: "Settings"),
        .init(keys: "⌘B / ⌘I / ⌘U", action: "Bold / Italic / Underline in composer"),
        .init(keys: "Return", action: "Send message"),
        .init(keys: "⇧Return", action: "New line in composer"),
        .init(keys: "Esc", action: "Close popovers / cancel edit"),
    ]

    private var filtered: [Shortcut] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return shortcuts }
        return shortcuts.filter { $0.action.lowercased().contains(q) || $0.keys.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DiscordColor.interactiveNormal)
            }
            .padding(14)

            TextField("Search shortcuts", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(8)
                .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 6))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider().overlay(DiscordColor.bgTertiary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered) { sc in
                        HStack {
                            Text(sc.action)
                                .font(.system(size: 14))
                                .foregroundStyle(DiscordColor.textNormal)
                            Spacer()
                            Text(sc.keys)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(DiscordColor.headerSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 5))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 420, height: 440)
        .background(DiscordColor.bgSecondary)
    }
}
