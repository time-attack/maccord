import Foundation

/// A rich embed. https://discord.com/developers/docs/resources/channel#embed-object
public struct Embed: Codable, Hashable, Sendable, Identifiable {
    public let title: String?
    public let type: String?
    public let description: String?
    public let url: String?
    public let timestamp: Date?
    public let color: Int?
    public let footer: EmbedFooter?
    public let image: EmbedMedia?
    public let thumbnail: EmbedMedia?
    public let video: EmbedMedia?
    public let provider: EmbedProvider?
    public let author: EmbedAuthor?
    public let fields: [EmbedField]?

    // Embeds have no stable id; synthesize a hash-based one for ForEach.
    public var id: Int { hashValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        timestamp = try? c.decodeIfPresent(Date.self, forKey: .timestamp)
        color = try? c.decodeIfPresent(Int.self, forKey: .color)
        footer = try? c.decodeIfPresent(EmbedFooter.self, forKey: .footer)
        image = try? c.decodeIfPresent(EmbedMedia.self, forKey: .image)
        thumbnail = try? c.decodeIfPresent(EmbedMedia.self, forKey: .thumbnail)
        video = try? c.decodeIfPresent(EmbedMedia.self, forKey: .video)
        provider = try? c.decodeIfPresent(EmbedProvider.self, forKey: .provider)
        author = try? c.decodeIfPresent(EmbedAuthor.self, forKey: .author)
        fields = try? c.decodeIfPresent([EmbedField].self, forKey: .fields)
    }

    enum CodingKeys: String, CodingKey {
        case title, type, description, url, timestamp, color
        case footer, image, thumbnail, video, provider, author, fields
    }
}

public struct EmbedFooter: Codable, Hashable, Sendable {
    public let text: String
    public let iconURL: String?
    enum CodingKeys: String, CodingKey { case text; case iconURL = "icon_url" }
}

public struct EmbedMedia: Codable, Hashable, Sendable {
    public let url: String?
    public let proxyURL: String?
    public let height: Int?
    public let width: Int?
    enum CodingKeys: String, CodingKey { case url, height, width; case proxyURL = "proxy_url" }
    public var bestURL: URL? {
        if let proxyURL, let u = URL(string: proxyURL) { return u }
        return url.flatMap(URL.init(string:))
    }
}

public struct EmbedProvider: Codable, Hashable, Sendable {
    public let name: String?
    public let url: String?
}

public struct EmbedAuthor: Codable, Hashable, Sendable {
    public let name: String
    public let url: String?
    public let iconURL: String?
    enum CodingKeys: String, CodingKey { case name, url; case iconURL = "icon_url" }
}

public struct EmbedField: Codable, Hashable, Sendable, Identifiable {
    public let name: String
    public let value: String
    public let inline: Bool?
    public var id: Int { hashValue }
}
