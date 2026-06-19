import SwiftUI
import MaccordCore

/// Maps Discord user public-flags + Nitro into renderable badges. We don't ship
/// Discord's badge art, so each maps to a representative SF Symbol + tint.
enum ProfileBadgeKind: CaseIterable {
    case staff, partner, hypesquadEvents, bravery, brilliance, balance
    case bugHunter1, bugHunter2, earlySupporter, activeDeveloper
    case verifiedDev, moderator, nitro, booster

    var bit: Int? {
        switch self {
        case .staff: 1 << 0
        case .partner: 1 << 1
        case .hypesquadEvents: 1 << 2
        case .bugHunter1: 1 << 3
        case .bravery: 1 << 6
        case .brilliance: 1 << 7
        case .balance: 1 << 8
        case .earlySupporter: 1 << 9
        case .bugHunter2: 1 << 14
        case .verifiedDev: 1 << 17
        case .moderator: 1 << 18
        case .activeDeveloper: 1 << 22
        case .nitro, .booster: nil   // derived separately
        }
    }

    var symbol: String {
        switch self {
        case .staff: "shield.lefthalf.filled"
        case .partner: "checkmark.seal.fill"
        case .hypesquadEvents: "sparkles"
        case .bravery: "house.fill"
        case .brilliance: "house.fill"
        case .balance: "house.fill"
        case .bugHunter1: "ladybug.fill"
        case .bugHunter2: "ladybug.fill"
        case .earlySupporter: "medal.fill"
        case .activeDeveloper: "chevron.left.forwardslash.chevron.right"
        case .verifiedDev: "cpu.fill"
        case .moderator: "shield.checkerboard"
        case .nitro: "sparkle"
        case .booster: "diamond.fill"
        }
    }

    var tint: Color {
        switch self {
        case .staff, .partner, .verifiedDev: Color(hex: 0x5865F2)
        case .hypesquadEvents: Color(hex: 0xF47B68)
        case .bravery: Color(hex: 0x9C84EF)
        case .brilliance: Color(hex: 0xF47B68)
        case .balance: Color(hex: 0x45DDC0)
        case .bugHunter1: Color(hex: 0x3BA55C)
        case .bugHunter2: Color(hex: 0xF0B232)
        case .earlySupporter: Color(hex: 0xFF73FA)
        case .activeDeveloper: Color(hex: 0x3BA55C)
        case .moderator: Color(hex: 0x4D7CFE)
        case .nitro, .booster: Color(hex: 0xFF73FA)
        }
    }

    var label: String {
        switch self {
        case .staff: "Discord Staff"
        case .partner: "Partnered Server Owner"
        case .hypesquadEvents: "HypeSquad Events"
        case .bravery: "HypeSquad Bravery"
        case .brilliance: "HypeSquad Brilliance"
        case .balance: "HypeSquad Balance"
        case .bugHunter1: "Discord Bug Hunter"
        case .bugHunter2: "Golden Bug Hunter"
        case .earlySupporter: "Early Supporter"
        case .activeDeveloper: "Active Developer"
        case .verifiedDev: "Early Verified Bot Developer"
        case .moderator: "Moderator Programs Alumni"
        case .nitro: "Discord Nitro"
        case .booster: "Server Booster"
        }
    }

    static func badges(publicFlags: Int?, premiumType: Int?, premiumSince: Date?) -> [ProfileBadgeKind] {
        var result: [ProfileBadgeKind] = []
        let flags = publicFlags ?? 0
        for kind in ProfileBadgeKind.allCases {
            if let bit = kind.bit, flags & bit != 0 { result.append(kind) }
        }
        if let premiumType, premiumType > 0 { result.append(.nitro) }
        if premiumSince != nil { result.append(.booster) }
        return result
    }
}

/// A row of badge chips.
struct ProfileBadgesRow: View {
    let badges: [ProfileBadgeKind]

    var body: some View {
        if !badges.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(badges, id: \.self) { badge in
                    Image(systemName: badge.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(badge.tint)
                        .frame(width: 26, height: 26)
                        .background(DiscordColor.bgSecondaryAlt, in: .rect(cornerRadius: 7, style: .continuous))
                        .help(badge.label)
                }
            }
        }
    }
}
