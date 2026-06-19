import Foundation

public enum StickerFormat: Int, Codable, Sendable, Hashable {
    case png = 1
    case apng = 2
    case lottie = 3
    case gif = 4

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = StickerFormat(rawValue: raw) ?? .png
    }
}

/// The compact sticker reference embedded in messages.
/// https://discord.com/developers/docs/resources/sticker#sticker-item-object
public struct StickerItem: Codable, Hashable, Sendable, Identifiable {
    public let id: Snowflake
    public let name: String
    public let formatType: StickerFormat

    enum CodingKeys: String, CodingKey {
        case id, name
        case formatType = "format_type"
    }

    public var imageURL: URL? {
        DiscordCDN.sticker(id: id, lottie: formatType == .lottie)
    }
}
