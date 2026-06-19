import SwiftUI
import MaccordCore

/// A sheet to start a group DM by selecting friends to include.
struct GroupDMCreateView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<Snowflake> = []
    @State private var query = ""
    @State private var creating = false

    private var friends: [User] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return app.friends.compactMap(\.user).filter {
            q.isEmpty || $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("New Group DM")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DiscordColor.interactiveNormal)
            }
            .padding(14)

            TextField("Search friends", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(8)
                .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 6))
                .padding(.horizontal, 14)

            Divider().overlay(DiscordColor.bgTertiary).padding(.top, 10)

            if friends.isEmpty {
                Text("Add friends first to start a group.")
                    .font(.system(size: 13))
                    .foregroundStyle(DiscordColor.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(friends) { user in row(user) }
                    }
                    .padding(8)
                }
            }

            Divider().overlay(DiscordColor.bgTertiary)
            HStack {
                Text("\(selected.count) selected")
                    .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
                Spacer()
                Button {
                    creating = true
                    Task {
                        await app.createGroupDM(with: Array(selected))
                        dismiss()
                    }
                } label: {
                    Text(creating ? "Creating…" : "Create Group")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(DiscordColor.blurple)
                .disabled(selected.isEmpty || creating)
            }
            .padding(14)
        }
        .frame(width: 380, height: 460)
        .background(DiscordColor.bgSecondary)
    }

    private func row(_ user: User) -> some View {
        Button {
            if selected.contains(user.id) { selected.remove(user.id) } else { selected.insert(user.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected.contains(user.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(user.id) ? DiscordColor.blurple : DiscordColor.textMuted)
                AvatarView(url: user.avatarURL(size: 48), fallbackText: user.displayName, size: 28)
                Text(user.displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(DiscordColor.textNormal)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
