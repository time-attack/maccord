import Foundation

extension RESTClient {
    /// GET /channels/{id}/pins — the channel's pinned messages (newest first).
    public func getPins(channelID: Snowflake) async throws -> [Message] {
        try await get(RESTRequest(
            method: .get,
            path: "/channels/\(channelID.rawValue)/pins",
            majorParam: channelID.description
        ))
    }

    /// PUT /channels/{id}/pins/{messageID}
    public func pinMessage(channelID: Snowflake, messageID: Snowflake) async throws {
        _ = try await send(
            RESTRequest(method: .put,
                        path: "/channels/\(channelID.rawValue)/pins/\(messageID.rawValue)",
                        majorParam: channelID.description),
            body: nil, contentType: nil
        )
    }

    /// DELETE /channels/{id}/pins/{messageID}
    public func unpinMessage(channelID: Snowflake, messageID: Snowflake) async throws {
        _ = try await send(
            RESTRequest(method: .delete,
                        path: "/channels/\(channelID.rawValue)/pins/\(messageID.rawValue)",
                        majorParam: channelID.description),
            body: nil, contentType: nil
        )
    }

    /// GET /channels/{id}/messages/{mid}/reactions/{emoji} — who reacted.
    public func getReactionUsers(
        channelID: Snowflake, messageID: Snowflake, emoji: Emoji, limit: Int = 50
    ) async throws -> [User] {
        let encoded = emoji.reactionKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? emoji.reactionKey
        return try await get(RESTRequest(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/reactions/\(encoded)",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))],
            majorParam: channelID.description
        ))
    }
}
