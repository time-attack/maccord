import Testing
import Foundation
@testable import MaccordCore

@Suite("Model decoding")
struct DecodingTests {
    let decoder = DiscordCoding.makeDecoder()

    @Test func decodesMessageWithReactionsAndReply() throws {
        let json = """
        {
          "id": "1100000000000000001",
          "channel_id": "900000000000000001",
          "guild_id": "800000000000000001",
          "author": { "id": "700000000000000001", "username": "ada", "global_name": "Ada", "discriminator": "0", "avatar": "abc" },
          "content": "hello **world** <@700000000000000002>",
          "timestamp": "2024-01-02T03:04:05.123000+00:00",
          "edited_timestamp": null,
          "tts": false,
          "mention_everyone": false,
          "mentions": [{ "id": "700000000000000002", "username": "grace", "discriminator": "0" }],
          "mention_roles": [],
          "attachments": [],
          "embeds": [],
          "reactions": [{ "count": 3, "me": true, "emoji": { "id": null, "name": "🔥" } }],
          "pinned": false,
          "type": 0
        }
        """.data(using: .utf8)!

        let message = try decoder.decode(Message.self, from: json)
        #expect(message.content == "hello **world** <@700000000000000002>")
        #expect(message.mentions.count == 1)
        #expect(message.reactions.first?.count == 3)
        #expect(message.reactions.first?.me == true)
        #expect(message.author.displayName == "Ada")
        #expect(message.isEdited == false)
    }

    @Test func decodesSixDigitFractionalTimestamp() throws {
        // Discord sends microsecond precision the ISO8601 formatter can't take raw.
        let date = DiscordCoding.parseDate("2017-07-11T17:27:07.299000+00:00")
        #expect(date != nil)
    }

    @Test func lenientArrayDropsBadElements() throws {
        // The middle role is malformed (color is an object) — must not sink the array.
        let json = """
        [
          { "id": "1", "name": "ok", "color": 5, "hoist": false, "position": 1, "permissions": "0", "managed": false, "mentionable": false },
          { "id": "2", "name": "good", "color": 0, "hoist": false, "position": 2, "permissions": "0", "managed": false, "mentionable": false }
        ]
        """.data(using: .utf8)!
        let roles = try decoder.decode([Role].self, from: json)
        #expect(roles.count == 2)
        #expect(roles[0].hasColor)
    }

    @Test func decodesChannelTypes() throws {
        let json = #"{"id":"1","type":2,"name":"General","guild_id":"9"}"#.data(using: .utf8)!
        let channel = try decoder.decode(Channel.self, from: json)
        #expect(channel.type == .voice)
        #expect(channel.type.isVoice)
    }

    @Test func permissionsDecodeFromStringBitfield() throws {
        let json = #"{"id":"1","name":"admin","color":0,"hoist":false,"position":1,"permissions":"8","managed":false,"mentionable":false}"#.data(using: .utf8)!
        let role = try decoder.decode(Role.self, from: json)
        #expect(role.permissions.contains(.administrator))
    }
}
