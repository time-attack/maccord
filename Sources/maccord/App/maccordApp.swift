import SwiftUI
import MaccordCore

struct MaccordApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.bootstrap() }
                .preferredColorScheme(.dark)
                .tint(DiscordColor.blurple)
                // Vibrant Liquid Glass window base; translucent panels layer over it.
                .containerBackground(.ultraThinMaterial, for: .window)
        }
        .windowStyle(.hiddenTitleBar)   // immersive, full-bleed like the real Discord
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Quick Switcher") { app.showQuickSwitcher.toggle() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Toggle Member List") { app.showMemberList.toggle() }
                    .keyboardShortcut("u", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Increase Text Size") { app.adjustChatZoom(delta: 0.05) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Decrease Text Size") { app.adjustChatZoom(delta: -0.05) }
                    .keyboardShortcut("-", modifiers: .command)
            }
        }

        Settings {
            AppSettingsView()
                .environment(app)
                .preferredColorScheme(.dark)
                .tint(DiscordColor.blurple)
        }
    }
}

/// Minimal settings scene (Cmd-,). Expanded in a later milestone.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        Form {
            Section("Account") {
                if let user = app.currentUser {
                    LabeledContent("Logged in as", value: user.displayName)
                    LabeledContent("Handle", value: user.username)
                }
                Button("Log Out", role: .destructive) {
                    Task { await app.logOut() }
                }
            }
            Section("About") {
                LabeledContent("maccord", value: "Native macOS Discord client")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
    }
}
