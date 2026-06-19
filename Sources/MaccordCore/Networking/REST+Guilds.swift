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
