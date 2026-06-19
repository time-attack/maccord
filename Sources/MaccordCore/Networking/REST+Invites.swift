import Foundation

extension RESTClient {
    /// `POST /channels/{id}/invites` — create an invite with explicit options.
    public func createInvite(channelID: Snowflake, maxAgeSeconds: Int, maxUses: Int,
                             temporary: Bool) async throws -> GuildInvite {
        struct Body: Encodable {
            let maxAge: Int
            let maxUses: Int
            let temporary: Bool
            enum CodingKeys: String, CodingKey {
                case maxAge = "max_age"
                case maxUses = "max_uses"
                case temporary
            }
        }
        return try await post(
            RESTRequest(method: .post, path: "/channels/\(channelID.rawValue)/invites",
                        majorParam: channelID.description),
            jsonBody: Body(maxAge: maxAgeSeconds, maxUses: maxUses, temporary: temporary))
    }

    /// `GET /guilds/{id}/invites` — the guild's active invites.
    public func getGuildInvites(_ guildID: Snowflake) async throws -> [GuildInvite] {
        try await get(RESTRequest(method: .get, path: "/guilds/\(guildID.rawValue)/invites",
                                  majorParam: guildID.description))
    }

    /// `DELETE /invites/{code}` — revoke an invite.
    public func deleteInvite(code: String) async throws {
        try await delete(RESTRequest(method: .delete, path: "/invites/\(code)"))
    }

    /// `GET /invites/{code}?with_counts=true` — preview an invite without joining.
    public func getInvite(code: String) async throws -> GuildInvite {
        try await get(RESTRequest(method: .get, path: "/invites/\(code)",
                                  queryItems: [URLQueryItem(name: "with_counts", value: "true")]))
    }

    /// `POST /invites/{code}` — accept (join) an invite.
    @discardableResult
    public func acceptInvite(code: String) async throws -> GuildInvite {
        try await post(RESTRequest(method: .post, path: "/invites/\(code)"), jsonBody: nil)
    }
}
