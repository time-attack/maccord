import SwiftUI
import MaccordCore

/// Auth gate: routes between the loading splash, the token login, and the app.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            // No opaque base — let the window's Liquid Glass material show through
            // behind the translucent panels.
            switch app.phase {
            case .loading:
                LoadingSplashView()
            case .login:
                LoginView()
            case .app:
                MainWindowView()
            }
        }
        .frame(minWidth: Layout.windowMinWidth, minHeight: Layout.windowMinHeight)
        .animation(.easeInOut(duration: 0.25), value: app.phase)
    }
}

struct LoadingSplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(DiscordColor.blurple)
                .symbolEffect(.pulse)
            ProgressView()
                .controlSize(.large)
            Text("Connecting to Discord…")
                .font(DiscordFont.searchText)
                .foregroundStyle(DiscordColor.textMuted)
        }
    }
}
