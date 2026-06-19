import SwiftUI

/// Type ramp using Discord's "gg sans" when available, falling back to SF Pro.
/// Change `family` (or drop a font into Resources/Fonts) to swap the typeface.
enum DiscordFont {
    /// gg sans ships each weight as its own family, so we address faces by their
    /// exact PostScript name. `Font.custom` falls back to the system font if the
    /// font isn't bundled/registered, so this is always safe.
    static let family = "gg sans"

    static func postScriptName(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "ggsans-Bold"
        case .semibold: "ggsans-Semibold"
        case .medium: "ggsans-Medium"
        default: "ggsans-Normal"
        }
    }

    /// A gg sans face at the given size/weight (system fallback).
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(weight), size: size)
    }

    static let messageBody    = ui(16)                 // Discord body is 16pt
    static let authorName     = ui(16, .medium)
    static let timestamp      = ui(12)

    static let channelName    = ui(15, .medium)
    static let categoryHeader = ui(11, .semibold)
    static let serverName     = ui(15, .semibold)
    static let channelHeaderTitle = ui(15, .semibold)
    static let channelTopic   = ui(13)

    static let memberRoleHeader = ui(12, .semibold)
    static let memberName     = ui(15, .medium)

    static let panelUsername  = ui(13, .semibold)
    static let panelSubtext   = ui(11)

    static let composerText   = ui(15)
    static let searchText     = ui(13)
    static let tooltip        = ui(13, .semibold)
    static let reactionCount  = ui(13, .semibold)
    static let replyPreview   = ui(13)
    static let badge          = ui(11, .bold)
    static let sectionTitle   = ui(12, .bold)

    static let codeInline     = Font.system(size: 14, design: .monospaced)
    static let codeBlock      = Font.system(size: 13, design: .monospaced)
}

extension Text {
    /// Uppercase tracked styling used by category + member-section headers.
    func categoryHeaderStyle() -> some View {
        self.font(DiscordFont.categoryHeader)
            .tracking(0.4)
            .foregroundStyle(DiscordColor.channelDefault)
            .textCase(.uppercase)
    }
}
