import Foundation

extension RESTClient {
    /// `GET /users/@me` — the authenticated account.
    public func getCurrentUser() async throws -> CurrentUser {
        try await get(RESTRequest(method: .get, path: "/users/@me"))
    }

    /// `GET /users/{id}` — another user.
    public func getUser(_ id: Snowflake) async throws -> User {
        try await get(RESTRequest(method: .get, path: "/users/\(id.rawValue)"))
    }

    /// `GET /users/{id}/profile?with_mutual_guilds=true[&guild_id=]` — rich profile.
    public func getUserProfile(_ id: Snowflake, guildID: Snowflake? = nil) async throws -> UserProfile {
        var items = [URLQueryItem(name: "with_mutual_guilds", value: "true")]
        if let guildID {
            items.append(URLQueryItem(name: "guild_id", value: String(guildID.rawValue)))
        }
        let req = RESTRequest(method: .get, path: "/users/\(id.rawValue)/profile", queryItems: items)
        return try await get(req)
    }

    /// `GET /users/@me/guilds` — the guilds the user belongs to (lightweight).
    public func getMyGuilds() async throws -> [Guild] {
        let req = RESTRequest(
            method: .get,
            path: "/users/@me/guilds",
            queryItems: [URLQueryItem(name: "limit", value: "200")]
        )
        return try await get(req)
    }

    /// `GET /users/@me/channels` — the user's DM and group-DM channels.
    public func getMyDMs() async throws -> [Channel] {
        try await get(RESTRequest(method: .get, path: "/users/@me/channels"))
    }

    /// `POST /users/@me/channels` `{recipient_id}` — open (or fetch) a 1:1 DM.
    public func openDM(recipientID: Snowflake) async throws -> Channel {
        struct Body: Encodable {
            let recipientID: Snowflake
            enum CodingKeys: String, CodingKey { case recipientID = "recipient_id" }
        }
        let req = RESTRequest(method: .post, path: "/users/@me/channels")
        return try await post(req, jsonBody: Body(recipientID: recipientID))
    }

    /// `GET /users/@me/relationships` — friends, pending, blocked.
    public func getRelationships() async throws -> [Relationship] {
        try await get(RESTRequest(method: .get, path: "/users/@me/relationships"))
    }

    /// `POST /users/@me/relationships` — send a friend request by username.
    public func sendFriendRequest(username: String) async throws -> Relationship {
        struct Body: Encodable { let username: String }
        let req = RESTRequest(method: .post, path: "/users/@me/relationships")
        return try await post(req, jsonBody: Body(username: username))
    }

    /// `PUT /users/@me/relationships/{id}` — accept a friend request.
    public func acceptFriendRequest(userID: Snowflake) async throws -> Relationship {
        struct Body: Encodable { let type = 1 }
        let req = RESTRequest(method: .put, path: "/users/@me/relationships/\(userID.rawValue)")
        return try await put(req, jsonBody: Body())
    }

    /// `DELETE /users/@me/relationships/{id}` — remove friend / cancel request / decline.
    public func removeRelationship(userID: Snowflake) async throws {
        try await delete(RESTRequest(method: .delete, path: "/users/@me/relationships/\(userID.rawValue)"))
    }

    /// `PUT /users/@me/relationships/{id}` `{type:2}` — block a user.
    public func blockUser(_ userID: Snowflake) async throws -> Relationship {
        struct Body: Encodable { let type = 2 }
        let req = RESTRequest(method: .put, path: "/users/@me/relationships/\(userID.rawValue)")
        return try await put(req, jsonBody: Body())
    }
}
