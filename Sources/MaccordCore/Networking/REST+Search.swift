import Foundation

/// Discord search returns groups of messages; the matched message is the hit.
struct MessageSearchResponse: Decodable {
    let totalResults: Int
    let messages: [[Message]]
    enum CodingKeys: String, CodingKey {
        case totalResults = "total_results"
        case messages
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalResults = (try? c.decode(Int.self, forKey: .totalResults)) ?? 0
        messages = (try? c.decode([[Message]].self, forKey: .messages)) ?? []
    }
    /// The hit message from each group (middle element is the match context-wise).
    var hits: [Message] {
        messages.compactMap { group in
            group.count > 1 ? group[group.count / 2] : group.first
        }
    }
}

/// Optional Discord search filters (author_id / has / pinned / channel scope).
public struct SearchFilters: Sendable {
    public var authorID: Snowflake?
    public var channelID: Snowflake?
    /// One of: link, embed, file, video, image, sound, sticker
    public var has: String?
    public var pinned: Bool?
    public var mentions: Snowflake?
    public init() {}

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let authorID { items.append(URLQueryItem(name: "author_id", value: authorID.description)) }
        if let channelID { items.append(URLQueryItem(name: "channel_id", value: channelID.description)) }
        if let has { items.append(URLQueryItem(name: "has", value: has)) }
        if let pinned { items.append(URLQueryItem(name: "pinned", value: pinned ? "true" : "false")) }
        if let mentions { items.append(URLQueryItem(name: "mentions", value: mentions.description)) }
        return items
    }
}

extension RESTClient {
    /// GET /guilds/{id}/messages/search — full-text server search with filters.
    public func searchGuildMessages(guildID: Snowflake, query: String,
                                    filters: SearchFilters = SearchFilters()) async throws -> [Message] {
        var items = filters.queryItems
        if !query.isEmpty { items.append(URLQueryItem(name: "content", value: query)) }
        let resp: MessageSearchResponse = try await get(RESTRequest(
            method: .get,
            path: "/guilds/\(guildID.rawValue)/messages/search",
            queryItems: items,
            majorParam: guildID.description
        ))
        return resp.hits
    }

    /// GET /channels/{id}/messages/search — DM/channel search with filters.
    public func searchChannelMessages(channelID: Snowflake, query: String,
                                      filters: SearchFilters = SearchFilters()) async throws -> [Message] {
        var items = filters.queryItems
        if !query.isEmpty { items.append(URLQueryItem(name: "content", value: query)) }
        let resp: MessageSearchResponse = try await get(RESTRequest(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages/search",
            queryItems: items,
            majorParam: channelID.description
        ))
        return resp.hits
    }

    /// DELETE /users/@me/guilds/{id} — leave a server.
    public func leaveGuild(_ guildID: Snowflake) async throws {
        _ = try await send(
            RESTRequest(method: .delete, path: "/users/@me/guilds/\(guildID.rawValue)",
                        majorParam: guildID.description),
            body: nil, contentType: nil
        )
    }

    /// POST /channels/{id}/invites — create an invite, returns the `discord.gg` URL.
    public func createInvite(channelID: Snowflake) async throws -> String {
        struct Body: Encodable { let max_age = 86400; let max_uses = 0 }
        struct Resp: Decodable { let code: String }
        let resp: Resp = try await post(
            RESTRequest(method: .post, path: "/channels/\(channelID.rawValue)/invites",
                        majorParam: channelID.description),
            jsonBody: Body()
        )
        return "https://discord.gg/\(resp.code)"
    }

    /// GET /guilds/{id}/roles — used as a fallback when READY didn't hydrate roles.
    public func fetchGuildRoles(_ guildID: Snowflake) async throws -> [Role] {
        try await get(RESTRequest(method: .get, path: "/guilds/\(guildID.rawValue)/roles",
                                  majorParam: guildID.description))
    }

    /// GET /users/@me/guilds/{id}/member — our own member (roles) in a guild,
    /// needed to compute channel visibility.
    public func getCurrentMember(guildID: Snowflake) async throws -> Member {
        try await get(RESTRequest(method: .get, path: "/users/@me/guilds/\(guildID.rawValue)/member",
                                  majorParam: guildID.description))
    }
}
