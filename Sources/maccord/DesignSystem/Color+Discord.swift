import SwiftUI
import MaccordCore

extension Color {
    /// Build a color from a packed 0xRRGGBB integer.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Build a color from a Discord integer color (role/embed `color` fields).
    /// 0 means "no color".
    init?(discordColor: Int) {
        guard discordColor != 0 else { return nil }
        self.init(hex: UInt32(truncatingIfNeeded: discordColor))
    }

    /// Build a color from a CSS-style hex string ("#rrggbb").
    init?(cssHex: String) {
        var s = cssHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt32(s, radix: 16) else { return nil }
        self.init(hex: value)
    }
}

/// The Discord dark-theme palette (the "onyx"/refreshed surface set).
enum DiscordColor {
    // Translucent panel fills — let the window's Liquid Glass material show
    // through so the surfaces read as layered glass (Apple look). Chat stays
    // near-opaque so message text stays crisp.
    static let panelRail      = Color(hex: 0x1E1F22, opacity: 0.78)
    static let panelSidebar   = Color(hex: 0x2B2D31, opacity: 0.74)
    static let panelChat      = Color(hex: 0x313338, opacity: 0.92)
    static let panelMembers   = Color(hex: 0x2B2D31, opacity: 0.74)

    // Surfaces
    static let bgPrimary      = Color(hex: 0x313338)   // chat area
    static let bgSecondary    = Color(hex: 0x2B2D31)   // channel sidebar / member list
    static let bgSecondaryAlt = Color(hex: 0x232428)   // user panel
    static let bgTertiary     = Color(hex: 0x1E1F22)   // server rail / search field
    static let bgFloating     = Color(hex: 0x111214)   // tooltips / popouts
    static let bgModifierHover = Color(hex: 0x393C41)
    static let surfaceRaised  = Color(hex: 0x383A40)   // composer input
    static let surfaceHigher  = Color(hex: 0x404249)
    static let divider        = Color(hex: 0x3F4147)

    // Channel / message interaction states
    static let channelHover    = Color(hex: 0x35373C)
    static let channelSelected = Color(hex: 0x404249)
    static let messageHover    = Color(hex: 0x2E3035)
    static let mentionBackground = Color(hex: 0x5865F2, opacity: 0.10)
    static let mentionBackgroundHover = Color(hex: 0x5865F2, opacity: 0.16)
    static let mentionBar      = Color(hex: 0xF0B232)

    // Brand
    static let blurple        = Color(hex: 0x5865F2)
    static let blurpleHover   = Color(hex: 0x4752C4)
    static let blurplePressed = Color(hex: 0x3C45A5)
    static let linkBlue       = Color(hex: 0x00A8FC)
    static let green          = Color(hex: 0x23A55A)
    static let greenHover     = Color(hex: 0x1A6334)
    static let dangerRed      = Color(hex: 0xDA373C)
    static let dangerRedHover = Color(hex: 0xA12828)

    // Text
    static let textNormal      = Color(hex: 0xDBDEE1)
    static let textMuted       = Color(hex: 0x949BA4)
    static let textFaint       = Color(hex: 0x80848E)
    static let headerPrimary   = Color(hex: 0xF2F3F5)
    static let headerSecondary = Color(hex: 0xB5BAC1)
    static let channelDefault  = Color(hex: 0x949BA4)
    static let channelIcon     = Color(hex: 0x80848E)
    static let interactiveNormal = Color(hex: 0xB5BAC1)
    static let interactiveHover  = Color(hex: 0xDBDEE1)
    static let interactiveActive = Color(hex: 0xFFFFFF)
    static let interactiveMuted  = Color(hex: 0x4E5058)
    static let textLink          = Color(hex: 0x00A8FC)
    static let textPositive      = Color(hex: 0x2DC770)

    // Presence status
    static let statusOnline   = Color(hex: 0x23A55A)
    static let statusIdle     = Color(hex: 0xF0B232)
    static let statusDND      = Color(hex: 0xF23F43)
    static let statusOffline  = Color(hex: 0x80848E)
    static let statusStreaming = Color(hex: 0x593695)

    // Badges
    static let badgeRed       = Color(hex: 0xF23F43)
    static let mentionPill    = Color(hex: 0xF23F43)

    // Code / spoiler
    static let codeBackground = Color(hex: 0x2B2D31)
    static let codeBorder     = Color(hex: 0x1E1F22)
    static let spoiler        = Color(hex: 0x202225)
    static let blockquoteBar  = Color(hex: 0x4E5058)

    static func status(_ status: Status) -> Color {
        switch status {
        case .online: statusOnline
        case .idle: statusIdle
        case .dnd: statusDND
        case .invisible, .offline: statusOffline
        }
    }

    /// Role color, falling back to the default channel text color.
    static func role(_ role: Role?) -> Color {
        if let role, let c = Color(discordColor: role.color) { return c }
        return textNormal
    }
}
