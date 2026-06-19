import Foundation

extension RESTClient {
    /// `PUT /channels/{id}/messages/{mid}/reactions/{emoji}/@me` — add own reaction.
    /// The emoji path component (`name:id` for custom, raw char for unicode) is
    /// percent-encoded.
    public func addReaction(
        channelID: Snowflake,
        messageID: Snowflake,
        emoji: Emoji
    ) async throws {
        let req = reactionRequest(method: .put, channelID: channelID, messageID: messageID, emoji: emoji)
        _ = try await send(req, body: nil, contentType: nil)
    }

    /// `DELETE /channels/{id}/messages/{mid}/reactions/{emoji}/@me` — remove own reaction.
    public func removeOwnReaction(
        channelID: Snowflake,
        messageID: Snowflake,
        emoji: Emoji
    ) async throws {
        let req = reactionRequest(method: .delete, channelID: channelID, messageID: messageID, emoji: emoji)
        try await delete(req)
    }

    // MARK: - Helpers

    private func reactionRequest(
        method: HTTPMethod,
        channelID: Snowflake,
        messageID: Snowflake,
        emoji: Emoji
    ) -> RESTRequest {
        let encoded = Self.percentEncodeEmoji(emoji.reactionKey)
        let path = "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/reactions/\(encoded)/@me"
        return RESTRequest(method: method, path: path, majorParam: String(channelID.rawValue))
    }

    /// Percent-encode a reaction key so it is safe as a single URL path segment.
    /// We escape everything outside an unreserved set, which covers both the
    /// `name:id` form (the `:` is encoded) and multi-byte unicode emoji.
    static func percentEncodeEmoji(_ key: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
    }
}
