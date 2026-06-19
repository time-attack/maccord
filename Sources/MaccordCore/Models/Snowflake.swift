import Foundation

/// A Discord snowflake ID — a 64-bit integer transported as a JSON **string**.
///
/// The high 42 bits encode a millisecond timestamp relative to the Discord epoch
/// (2015-01-01), which lets us derive `createdAt` and synthesize IDs for time-based
/// pagination without an extra round-trip.
public struct Snowflake: RawRepresentable, Hashable, Sendable, Comparable, Identifiable {
    public let rawValue: UInt64

    public var id: UInt64 { rawValue }

    /// 2015-01-01T00:00:00Z in milliseconds.
    public static let discordEpochMS: UInt64 = 1_420_070_400_000

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Synthesize a snowflake whose timestamp is `ms` since the Unix epoch — used
    /// to build `before`/`after` pagination cursors from a `Date`.
    public init(timestampMS ms: UInt64) {
        let clamped = ms > Self.discordEpochMS ? ms : Self.discordEpochMS
        self.rawValue = (clamped - Self.discordEpochMS) << 22
    }

    public init?(string: String) {
        guard let value = UInt64(string) else { return nil }
        self.rawValue = value
    }

    /// The creation timestamp embedded in the ID.
    public var createdAt: Date {
        let ms = (rawValue >> 22) + Self.discordEpochMS
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    public static func < (lhs: Snowflake, rhs: Snowflake) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension Snowflake: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Discord almost always sends strings, but be lenient for ints too.
        if let string = try? container.decode(String.self) {
            guard let value = UInt64(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Snowflake string '\(string)' is not a valid UInt64"
                )
            }
            self.rawValue = value
        } else {
            self.rawValue = try container.decode(UInt64.self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(rawValue))
    }
}

extension Snowflake: CustomStringConvertible {
    public var description: String { String(rawValue) }
}

extension Snowflake: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = UInt64(value) ?? 0
    }
}

extension Snowflake: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.rawValue = value
    }
}
