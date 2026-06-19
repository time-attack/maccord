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
}
