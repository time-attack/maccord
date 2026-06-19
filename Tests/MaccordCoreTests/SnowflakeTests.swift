import Testing
import Foundation
@testable import MaccordCore

@Suite("Snowflake")
struct SnowflakeTests {
    @Test func decodesFromJSONString() throws {
        let json = #"{"id":"175928847299117063"}"#.data(using: .utf8)!
        struct Box: Decodable { let id: Snowflake }
        let box = try JSONDecoder().decode(Box.self, from: json)
        #expect(box.id.rawValue == 175928847299117063)
    }

    @Test func encodesAsString() throws {
        struct Box: Encodable { let id: Snowflake }
        let data = try JSONEncoder().encode(Box(id: Snowflake(123)))
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("\"123\""))
    }

    @Test func extractsCreationTimestamp() {
        // 175928847299117063 → 2016-04-30T11:18:25.796Z (Discord's documented example)
        let flake = Snowflake(175928847299117063)
        let expected = Date(timeIntervalSince1970: 1462015105.796)
        #expect(abs(flake.createdAt.timeIntervalSince1970 - expected.timeIntervalSince1970) < 1.0)
    }

    @Test func synthesizesFromTimestampForPagination() {
        let now: UInt64 = 1_600_000_000_000
        let flake = Snowflake(timestampMS: now)
        #expect(abs(flake.createdAt.timeIntervalSince1970 - 1_600_000_000) < 1.0)
    }

    @Test func comparableOrdersByTime() {
        #expect(Snowflake(100) < Snowflake(200))
    }
}
