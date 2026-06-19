import SwiftUI
import MaccordCore

/// User Settings + App Settings (Discord's two-pane structure).
struct AppSettingsView: View {
    @Environment(AppState.self) private var app
    @State private var tab: Tab = .account

    enum Tab: String, Identifiable {
        // User Settings
        case account = "My Account", profile = "Profile", privacy = "Privacy & Safety"
        // App Settings
        case appearance = "Appearance", notifications = "Notifications", textMedia = "Text & Media"
        case behavior = "Advanced", keybinds = "Keybinds", about = "About"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .account: "person.crop.circle.fill"
            case .profile: "person.text.rectangle.fill"
            case .privacy: "hand.raised.fill"
            case .appearance: "paintbrush.fill"
            case .notifications: "bell.fill"
            case .textMedia: "text.bubble.fill"
            case .behavior: "gearshape.2.fill"
            case .keybinds: "keyboard.fill"
            case .about: "info.circle.fill"
            }
        }
        var isUserSetting: Bool {
            switch self {
            case .account, .profile, .privacy: true
            default: false
            }
        }
    }

    private static let userTabs: [Tab] = [.account, .profile, .privacy]
    private static let appTabs: [Tab] = [.appearance, .notifications, .textMedia, .behavior, .keybinds, .about]

    var body: some View {
        @Bindable var app = app
        return HStack(spacing: 0) {
            sidebar
            Divider().overlay(DiscordColor.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tab.rawValue).font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                    content(app)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DiscordColor.bgPrimary)
        }
        .frame(width: 800, height: 580)
        .background(DiscordColor.bgSecondary)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("USER SETTINGS")
            ForEach(Self.userTabs) { t in tabButton(t) }

            sectionHeader("APP SETTINGS").padding(.top, 12)
            ForEach(Self.appTabs) { t in tabButton(t) }

            Spacer()
            Button(role: .destructive) { Task { await app.logOut() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 18)
                    Text("Log Out").font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(DiscordColor.dangerRed)
                .padding(.horizontal, 10).frame(height: 32).contentShape(.rect)
            }
            .buttonStyle(.plain).padding(.bottom, 12)
        }
        .padding(.horizontal, 8).frame(width: 220)
        .background(DiscordColor.bgTertiary)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .bold)).tracking(0.4)
            .foregroundStyle(DiscordColor.headerSecondary)
            .padding(.horizontal, 10).padding(.top, 16).padding(.bottom, 6)
    }

    private func tabButton(_ t: Tab) -> some View {
        Button { tab = t } label: {
            HStack(spacing: 8) {
                Image(systemName: t.icon).frame(width: 18)
                Text(t.rawValue).font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tab == t ? DiscordColor.interactiveActive : DiscordColor.interactiveNormal)
            .padding(.horizontal, 10).frame(height: 32)
            .background(tab == t ? DiscordColor.channelSelected : .clear, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func content(_ app: AppState) -> some View {
        switch tab {
        case .account: account
        case .profile: profile(app)
        case .privacy: privacy(app)
        case .appearance: appearance(app)
        case .notifications: notifications(app)
        case .textMedia: textMedia(app)
        case .behavior: behavior(app)
        case .keybinds: keybinds
        case .about: about
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let user = app.currentUser {
                HStack(spacing: 14) {
                    AvatarView(url: user.avatarURL(size: 160), fallbackText: user.displayName,
                               size: 72, status: app.currentUserStatus)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName).font(.system(size: 20, weight: .bold))
                        Text(user.username).font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
                    }
                    Spacer()
                    Button("Edit Profile") {}.buttonStyle(.bordered).disabled(true)
                        .help("Profile editing opens in Discord's official client")
                }
                card {
                    field("Display Name", user.displayName)
                    field("Username", user.username)
                    field("Email", user.email ?? "—")
                    field("Phone", user.phone ?? "—")
                    field("User ID", user.id.description)
                    field("2FA", (user.mfaEnabled ?? false) ? "Enabled" : "Disabled")
                    field("Nitro", nitroLabel(user.premiumType))
                }
            } else {
                Text("Not signed in").foregroundStyle(DiscordColor.textMuted)
            }
        }
    }

    private func profile(_ app: AppState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if app.currentUser != nil {
                card {
                    Text("Status").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 8) {
                        ForEach([Status.online, .idle, .dnd, .invisible], id: \.self) { s in
                            Button { app.setStatus(s) } label: {
                                HStack(spacing: 6) {
                                    PresenceDotView(status: s, size: 10, borderColor: DiscordColor.bgSecondaryAlt)
                                    Text(s.label).font(.system(size: 13))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(app.currentUserStatus == s ? DiscordColor.blurple.opacity(0.2) : DiscordColor.bgSecondaryAlt,
                                           in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                card {
                    Text("Custom Status").font(.system(size: 13, weight: .semibold))
                    TextField("What's on your mind?", text: Binding(
                        get: { app.customStatusText },
                        set: { app.setCustomStatus($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(DiscordColor.bgPrimary, in: .rect(cornerRadius: 6))
                }
            }
        }
    }

    private func appearance(_ app: AppState) -> some View {
        card {
            row("Theme", trailing: AnyView(Text("Dark").foregroundStyle(DiscordColor.textMuted)))
            toggleRow("Compact message mode", isOn: Binding(get: { app.prefCompactMessages }, set: { app.prefCompactMessages = $0 }))
            toggleRow("Use 24-hour time", isOn: Binding(get: { app.prefTwentyFourHourTime }, set: { app.prefTwentyFourHourTime = $0 }))
            toggleRow("Show member list by default", isOn: Binding(get: { app.showMemberList }, set: { app.showMemberList = $0 }))
            toggleRow("Animate emoji", isOn: Binding(get: { app.prefAnimateEmoji }, set: { app.prefAnimateEmoji = $0 }))
            sliderRow("Message text size", value: Binding(get: { app.prefMessageFontScale }, set: { app.prefMessageFontScale = $0 }),
                      range: 0.85...1.25)
        }
    }

    private func notifications(_ app: AppState) -> some View {
        card {
            toggleRow("Enable desktop notifications", isOn: Binding(get: { app.prefEnableNotifications }, set: { app.prefEnableNotifications = $0 }))
            toggleRow("Play notification sound", isOn: Binding(get: { app.prefPlayNotificationSound }, set: { app.prefPlayNotificationSound = $0 }))
            toggleRow("Show unread badge", isOn: Binding(get: { app.prefShowUnreadBadge }, set: { app.prefShowUnreadBadge = $0 }))
        }
    }

    private func textMedia(_ app: AppState) -> some View {
        card {
            toggleRow("Show link preview", isOn: Binding(get: { app.prefShowLinkPreview }, set: { app.prefShowLinkPreview = $0 }))
            toggleRow("Show embeds", isOn: Binding(get: { app.prefShowEmbeds }, set: { app.prefShowEmbeds = $0 }))
            toggleRow("Show images inline", isOn: Binding(get: { app.prefInlineMedia }, set: { app.prefInlineMedia = $0 }))
            toggleRow("Spellcheck in composer", isOn: Binding(get: { app.prefSpellcheck }, set: { app.prefSpellcheck = $0 }))
        }
    }

    private func behavior(_ app: AppState) -> some View {
        card {
            toggleRow("Developer Mode", isOn: Binding(get: { app.prefDeveloperMode }, set: { app.prefDeveloperMode = $0 }))
            toggleRow("Return sends message", isOn: Binding(get: { !app.prefShiftEnterNewline }, set: { app.prefShiftEnterNewline = !$0 }))
        }
    }

    private var keybinds: some View {
        card {
            keybindRow("Quick Switcher", "⌘K")
            keybindRow("Toggle Member List", "⌘U")
            keybindRow("User Settings", "⌘,")
        }
    }

    private func privacy(_ app: AppState) -> some View {
        card {
            toggleRow("Share current activity", isOn: Binding(get: { app.prefShowActivity }, set: { app.prefShowActivity = $0 }))
            Text("Controls whether friends can see what you're playing or listening to.")
                .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
        }
    }

    private var about: some View {
        card {
            field("App", "maccord")
            field("Version", "0.2.0")
            field("Built with", "Swift 6 · SwiftUI · gg sans")
        }
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { c() }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 10, style: .continuous))
    }
    private func field(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
            Spacer(); Text(value).font(.system(size: 13, weight: .medium)).textSelection(.enabled).lineLimit(3) }
    }
    private func row(_ label: String, trailing: AnyView) -> some View {
        HStack { Text(label).font(.system(size: 14)); Spacer(); trailing }.frame(height: 28)
    }
    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { Text(label).font(.system(size: 14)) }.toggleStyle(.switch).tint(DiscordColor.blurple)
    }
    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(label).font(.system(size: 14)); Spacer()
                Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted) }
            Slider(value: value, in: range).tint(DiscordColor.blurple)
        }
    }
    private func keybindRow(_ action: String, _ keys: String) -> some View {
        HStack { Text(action).font(.system(size: 14)); Spacer()
            Text(keys).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3).background(DiscordColor.bgPrimary, in: .rect(cornerRadius: 4)) }
            .frame(height: 28)
    }
    private func nitroLabel(_ type: Int?) -> String {
        switch type { case 1: "Nitro Classic"; case 2: "Nitro"; case 3: "Nitro Basic"; default: "None" }
    }
}
