import Foundation

/// A message attachment. https://discord.com/developers/docs/resources/channel#attachment-object
public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    public let id: Snowflake
    public let filename: String
    public let title: String?
    public let description: String?
    public let contentType: String?
    public let size: Int
    public let url: String
    public let proxyURL: String
    public let height: Int?
    public let width: Int?
    public let ephemeral: Bool?
    public let durationSecs: Double?
    public let waveform: String?

    enum CodingKeys: String, CodingKey {
        case id, filename, title, description, size, url, height, width, ephemeral, waveform
        case contentType = "content_type"
        case proxyURL = "proxy_url"
        case durationSecs = "duration_secs"
    }

    public var isImage: Bool {
        if let contentType { return contentType.hasPrefix("image/") }
        return ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(filename.lowercased().split(separator: ".").last.map(String.init) ?? "")
    }

    public var isVideo: Bool { contentType?.hasPrefix("video/") ?? false }
    public var isAudio: Bool { contentType?.hasPrefix("audio/") ?? false }
    public var isVoiceMessage: Bool { durationSecs != nil && waveform != nil }

    public var bestURL: URL? { URL(string: proxyURL) ?? URL(string: url) }

    /// Human-readable size, e.g. "1.4 MB".
    public var humanSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
