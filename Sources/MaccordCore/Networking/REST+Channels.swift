import Foundation

extension RESTClient {
    /// `GET /channels/{id}` — a single channel.
    public func getChannel(_ id: Snowflake) async throws -> Channel {
        let req = RESTRequest(
            method: .get,
            path: "/channels/\(id.rawValue)",
            majorParam: String(id.rawValue)
        )
        return try await get(req)
    }

    /// `POST /channels/{id}/typing` — fire a typing indicator (empty body, 204).
    public func triggerTyping(channelID: Snowflake) async throws {
        let req = RESTRequest(
            method: .post,
            path: "/channels/\(channelID.rawValue)/typing",
            majorParam: String(channelID.rawValue)
        )
        _ = try await send(req, body: nil, contentType: nil)
    }

    /// `POST /channels/{id}/messages/{mid}/ack` — mark the channel read up to a
    /// message. The body carries a (null on first call) ack `token`.
    public func ackMessage(channelID: Snowflake, messageID: Snowflake) async throws {
        struct Body: Encodable {
            let token: String?
            let manual: Bool
        }
        let req = RESTRequest(
            method: .post,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)/ack",
            majorParam: String(channelID.rawValue)
        )
        try await postNoContent(req, jsonBody: Body(token: nil, manual: true))
    }

    // MARK: DMs / group DMs

    /// `POST /users/@me/channels` `{recipients:[ids]}` — create a group DM.
    public func createGroupDM(recipientIDs: [Snowflake]) async throws -> Channel {
        struct Body: Encodable {
            let recipients: [Snowflake]
        }
        let req = RESTRequest(method: .post, path: "/users/@me/channels")
        return try await post(req, jsonBody: Body(recipients: recipientIDs))
    }

    /// `DELETE /channels/{id}` — close a DM / leave a group DM.
    public func closeChannel(_ id: Snowflake) async throws {
        try await delete(RESTRequest(
            method: .delete, path: "/channels/\(id.rawValue)", majorParam: String(id.rawValue)))
    }

    /// `PUT /channels/{id}/recipients/{uid}` — add a recipient to a group DM.
    public func addGroupRecipient(channelID: Snowflake, userID: Snowflake) async throws {
        try await putNoContent(RESTRequest(
            method: .put,
            path: "/channels/\(channelID.rawValue)/recipients/\(userID.rawValue)",
            majorParam: String(channelID.rawValue)), jsonBody: nil)
    }

    /// `DELETE /channels/{id}/recipients/{uid}` — remove a recipient from a group DM.
    public func removeGroupRecipient(channelID: Snowflake, userID: Snowflake) async throws {
        try await delete(RESTRequest(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/recipients/\(userID.rawValue)",
            majorParam: String(channelID.rawValue)))
    }
}
