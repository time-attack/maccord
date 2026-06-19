import SwiftUI
import MaccordCore

/// Token-paste login. (User-token auth is against Discord's ToS — see the note.)
struct LoginView: View {
    @Environment(AppState.self) private var app
    @State private var token = ""
    @State private var showToken = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x404EED), DiscordColor.blurple, Color(hex: 0x2B2D31)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                card
            }
            .frame(maxWidth: 480)
            .padding(40)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to maccord")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DiscordColor.headerPrimary)
                Text("Log in with your Discord token — user or bot (auto-detected).")
                    .font(DiscordFont.searchText)
                    .foregroundStyle(DiscordColor.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("TOKEN")
                    .font(DiscordFont.categoryHeader)
                    .tracking(0.4)
                    .foregroundStyle(DiscordColor.headerSecondary)

                HStack {
                    Group {
                        if showToken {
                            TextField("Paste your token", text: $token)
                        } else {
                            SecureField("Paste your token", text: $token)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(DiscordFont.composerText)
                    .foregroundStyle(DiscordColor.textNormal)
                    .onSubmit(submit)

                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(DiscordColor.interactiveNormal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(DiscordColor.bgTertiary)
                .clipShape(.rect(cornerRadius: 6))
            }

            if let error = app.loginError {
                Text(error)
                    .font(DiscordFont.replyPreview)
                    .foregroundStyle(DiscordColor.dangerRed)
            }

            Button(action: submit) {
                HStack {
                    if app.isLoggingIn { ProgressView().controlSize(.small) }
                    Text(app.isLoggingIn ? "Logging in…" : "Log In")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(DiscordColor.blurple)
            .disabled(token.isEmpty || app.isLoggingIn)

            disclaimer
        }
        .padding(28)
        .background(DiscordColor.bgSecondary)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DiscordColor.statusIdle)
                .font(.system(size: 12))
            Text("Bot tokens are fully supported. Using a personal user token (a so-called self-bot) violates Discord's Terms of Service and can get that account terminated. Either way, your token is stored only in the macOS Keychain and sent only to Discord over TLS.")
                .font(.system(size: 11))
                .foregroundStyle(DiscordColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(DiscordColor.bgTertiary.opacity(0.6))
        .clipShape(.rect(cornerRadius: 6))
    }

    private func submit() {
        guard !token.isEmpty else { return }
        Task { await app.logIn(token: token) }
    }
}
