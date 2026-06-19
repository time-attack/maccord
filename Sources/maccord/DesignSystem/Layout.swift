import SwiftUI

/// Pixel dimensions mirroring the Discord desktop layout.
enum Layout {
    // Server rail
    static let guildRailWidth: CGFloat = 72
    static let serverIconSize: CGFloat = 48
    static let serverIconGap: CGFloat = 8
    static let iconRadiusIdle: CGFloat = 16     // squircle (rounded square)
    static let iconRadiusActive: CGFloat = 16   // morph target uses Circle-ish via continuous
    static let iconCornerActive: CGFloat = 24

    // Selection pill (left edge)
    static let pillWidth: CGFloat = 4
    static let pillSelectedHeight: CGFloat = 40
    static let pillHoverHeight: CGFloat = 20
    static let pillUnreadHeight: CGFloat = 8

    // Sidebars
    static let channelSidebarWidth: CGFloat = 240
    static let channelSidebarMin: CGFloat = 200
    static let channelSidebarMax: CGFloat = 360
    static let memberListWidth: CGFloat = 240
    static let memberListMin: CGFloat = 200
    static let memberListMax: CGFloat = 340

    // Headers / bars
    static let headerHeight: CGFloat = 48
    static let userPanelHeight: CGFloat = 52

    // Channel list rows
    static let channelRowHeight: CGFloat = 32
    static let categoryHeaderHeight: CGFloat = 28
    static let channelRowInset: CGFloat = 8

    // Member list
    static let memberRowHeight: CGFloat = 42
    static let memberSectionHeaderHeight: CGFloat = 26

    // Messages
    static let messageAvatar: CGFloat = 40
    static let listAvatar: CGFloat = 32
    static let messageLeftGutter: CGFloat = 72   // 16 pad + 40 avatar + 16 gap → text at 72
    static let messageHGutter: CGFloat = 16
    static let messageVPadding: CGFloat = 2
    static let messageGroupTopPadding: CGFloat = 17
    static let messageGroupGapMinutes: Int = 7
    static let reactionPillHeight: CGFloat = 24

    // Composer
    static let composerRadius: CGFloat = 8
    static let composerMinHeight: CGFloat = 44
    static let composerHPadding: CGFloat = 16
    static let composerVPadding: CGFloat = 10

    // Avatars / dots
    static let presenceDotSize: CGFloat = 12
    static let presenceDotBorder: CGFloat = 3

    // Window
    static let windowMinWidth: CGFloat = 940
    static let windowMinHeight: CGFloat = 600
}
