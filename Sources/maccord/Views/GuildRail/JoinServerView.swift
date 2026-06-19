import SwiftUI
import MaccordCore

/// A sheet to join a server by pasting an invite link or code (discord.gg/…).
struct JoinServerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var invite = ""
    @State private var joining = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Join a Server")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DiscordColor.interactiveNormal)
            }
            Text("Enter an invite link or code to join an existing server.")
                .font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)

            TextField("https://discord.gg/  or  invite code", text: $invite)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(DiscordColor.bgTertiary, in: .rect(cornerRadius: 8))

            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(DiscordColor.dangerRed)
            }

            Button {
                Task {
                    joining = true; error = nil
                    let ok = await app.acceptInvite(invite)
                    joining = false
                    if ok { dismiss() } else { error = "Couldn't join — check the invite and try again." }
                }
            } label: {
                Text(joining ? "Joining…" : "Join Server")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DiscordColor.blurple)
            .controlSize(.large)
            .disabled(invite.trimmingCharacters(in: .whitespaces).isEmpty || joining)
        }
        .padding(20)
        .frame(width: 420)
        .background(DiscordColor.bgSecondary)
    }
}
