import Foundation

extension RESTClient {
    /// `GET /channels/{id}/messages` — channel history, newest → oldest.
    /// `before`/`after`/`around` are mutually exclusive (Discord enforces this).
    public func getMessages(
        channelID: Snowflake,
        before: Snowflake? = nil,
        after: Snowflake? = nil,
        around: Snowflake? = nil,
        limit: Int = 50
    ) async throws -> [Message] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before { items.append(URLQueryItem(name: "before", value: String(before.rawValue))) }
        if let after { items.append(URLQueryItem(name: "after", value: String(after.rawValue))) }
        if let around { items.append(URLQueryItem(name: "around", value: String(around.rawValue))) }
        let req = RESTRequest(
            method: .get,
            path: "/channels/\(channelID.rawValue)/messages",
            queryItems: items,
            majorParam: String(channelID.rawValue)
        )
        return try await get(req)
    }

    /// `POST /channels/{id}/messages` — send a message. Uses multipart when
    /// `files` is non-empty (Discord's attachment upload), else a JSON body.
    public func createMessage(
        channelID: Snowflake,
        content: String,
        messageReference: MessageReference? = nil,
        allowedMentions: AllowedMentions? = .default,
        nonce: String? = nil,
        files: [FilePart] = []
    ) async throws -> Message {
        let req = RESTRequest(
            method: .post,
            path: "/channels/\(channelID.rawValue)/messages",
            majorParam: String(channelID.rawValue)
        )

        if files.isEmpty {
            let body = CreateMessageBody(
                content: content,
                messageReference: messageReference,
                allowedMentions: allowedMentions,
                nonce: nonce,
                attachments: nil
            )
            return try await post(req, jsonBody: body)
        }

        // Multipart: declare attachments[n] so Discord pairs files[n] with metadata.
        let attachments = files.enumerated().map { index, file in
            AttachmentDescriptor(id: index, filename: file.filename)
        }
        let body = CreateMessageBody(
            content: content,
            messageReference: messageReference,
            allowedMentions: allowedMentions,
            nonce: nonce,
            attachments: attachments
        )
        let payloadJSON = try encodeJSON(body)
        return try await postMultipart(req, payloadJSON: payloadJSON, files: files)
    }

    /// `PATCH /channels/{id}/messages/{mid}` — edit a message's content.
    public func editMessage(
        channelID: Snowflake,
        messageID: Snowflake,
        content: String
    ) async throws -> Message {
        struct Body: Encodable { let content: String }
        let req = RESTRequest(
            method: .patch,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)",
            majorParam: String(channelID.rawValue)
        )
        return try await patch(req, jsonBody: Body(content: content))
    }

    /// `DELETE /channels/{id}/messages/{mid}` — delete a message.
    public func deleteMessage(channelID: Snowflake, messageID: Snowflake) async throws {
        let req = RESTRequest(
            method: .delete,
            path: "/channels/\(channelID.rawValue)/messages/\(messageID.rawValue)",
            majorParam: String(channelID.rawValue)
        )
        try await delete(req)
    }
}

/// JSON body for `POST /channels/{id}/messages`.
struct CreateMessageBody: Encodable {
    let content: String
    let messageReference: MessageReference?
    let allowedMentions: AllowedMentions?
    let nonce: String?
    let attachments: [AttachmentDescriptor]?

    enum CodingKeys: String, CodingKey {
        case content, nonce, attachments
        case messageReference = "message_reference"
        case allowedMentions = "allowed_mentions"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(messageReference, forKey: .messageReference)
        try c.encodeIfPresent(allowedMentions, forKey: .allowedMentions)
        try c.encodeIfPresent(nonce, forKey: .nonce)
        try c.encodeIfPresent(attachments, forKey: .attachments)
    }
}

/// One entry in `attachments[]`, pairing a `files[n]` index with its filename.
struct AttachmentDescriptor: Encodable {
    let id: Int
    let filename: String
}
