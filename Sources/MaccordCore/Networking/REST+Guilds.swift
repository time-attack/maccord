import Foundation

extension RESTClient {
    /// `GET /guilds/{id}?with_counts=true` — a full guild object.
    public func getGuild(_ id: Snowflake) async throws -> Guild {
        let req = RESTRequest(
            method: .get,
            path: "/guilds/\(id.rawValue)",
            queryItems: [URLQueryItem(name: "with_counts", value: "true")],
            majorParam: String(id.rawValue)
        )
        return try await get(req)
    }

    /// `GET /guilds/{id}/channels` — the guild's channels (excludes threads).
    public func getGuildChannels(_ id: Snowflake) async throws -> [Channel] {
        let req = RESTRequest(
            method: .get,
            path: "/guilds/\(id.rawValue)/channels",
            majorParam: String(id.rawValue)
        )
        return try await get(req)
    }

    /// `GET /guilds/{id}/roles` — the guild's roles.
    public func getGuildRoles(_ id: Snowflake) async throws -> [Role] {
        let req = RESTRequest(
            method: .get,
            path: "/guilds/\(id.rawValue)/roles",
            majorParam: String(id.rawValue)
        )
        return try await get(req)
    }

    // MARK: Moderation

    /// `DELETE /guilds/{id}/members/{uid}` — kick a member.
    public func kickMember(guildID: Snowflake, userID: Snowflake) async throws {
        try await delete(RESTRequest(
            method: .delete,
            path: "/guilds/\(guildID.rawValue)/members/\(userID.rawValue)",
            majorParam: String(guildID.rawValue)))
    }

    /// `PUT /guilds/{id}/bans/{uid}` — ban a member, optionally purging recent messages.
    public func banMember(guildID: Snowflake, userID: Snowflake, deleteMessageSeconds: Int = 0) async throws {
        struct Body: Encodable {
            let deleteMessageSeconds: Int
            enum CodingKeys: String, CodingKey { case deleteMessageSeconds = "delete_message_seconds" }
        }
        try await putNoContent(RESTRequest(
            method: .put,
            path: "/guilds/\(guildID.rawValue)/bans/\(userID.rawValue)",
            majorParam: String(guildID.rawValue)),
            jsonBody: Body(deleteMessageSeconds: deleteMessageSeconds))
    }

    /// `DELETE /guilds/{id}/bans/{uid}` — unban a user.
    public func unbanMember(guildID: Snowflake, userID: Snowflake) async throws {
        try await delete(RESTRequest(
            method: .delete,
            path: "/guilds/\(guildID.rawValue)/bans/\(userID.rawValue)",
            majorParam: String(guildID.rawValue)))
    }

    /// `GET /guilds/{id}/bans?limit=` — the guild's ban list.
    public func getBans(guildID: Snowflake, limit: Int = 100) async throws -> [GuildBan] {
        try await get(RESTRequest(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/bans",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))],
            majorParam: String(guildID.rawValue)))
    }

    /// `PATCH /guilds/{id}/members/{uid}` `{communication_disabled_until}` — timeout
    /// a member until the given instant (nil clears the timeout).
    public func timeoutMember(guildID: Snowflake, userID: Snowflake, until: Date?) async throws {
        struct Body: Encodable {
            let communicationDisabledUntil: String?
            enum CodingKeys: String, CodingKey { case communicationDisabledUntil = "communication_disabled_until" }
        }
        let iso = until.map { ISO8601DateFormatter().string(from: $0) }
        try await patchNoContent(RESTRequest(
            method: .patch,
            path: "/guilds/\(guildID.rawValue)/members/\(userID.rawValue)",
            majorParam: String(guildID.rawValue)),
            jsonBody: Body(communicationDisabledUntil: iso))
    }

    /// `PATCH /guilds/{id}/members/{uid}` `{roles}` — set a member's role set.
    public func modifyMemberRoles(guildID: Snowflake, userID: Snowflake, roles: [Snowflake]) async throws {
        struct Body: Encodable { let roles: [Snowflake] }
        try await patchNoContent(RESTRequest(
            method: .patch,
            path: "/guilds/\(guildID.rawValue)/members/\(userID.rawValue)",
            majorParam: String(guildID.rawValue)),
            jsonBody: Body(roles: roles))
    }

    // MARK: Members

    /// `GET /guilds/{id}/members/search?query=&limit=` — prefix search members.
    public func searchMembers(guildID: Snowflake, query: String, limit: Int = 25) async throws -> [Member] {
        let req = RESTRequest(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/members/search",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
            ],
            majorParam: String(guildID.rawValue)
        )
        return try await get(req)
    }
}
