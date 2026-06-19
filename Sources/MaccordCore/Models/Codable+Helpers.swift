import Foundation

// MARK: - Lenient array decoding

/// Decodes an array element-by-element, dropping any element that fails to decode
/// rather than failing the whole container. Discord constantly adds fields and
/// occasionally ships malformed objects; one bad element should never sink an
/// entire READY payload or message batch.
@propertyWrapper
public struct LenientArray<Element: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element]) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        if let count = container.count {
            elements.reserveCapacity(count)
        }
        while !container.isAtEnd {
            // Decode into a throwaway wrapper so a failed element still advances the cursor.
            if let decoded = try? container.decode(Throwable<Element>.self) {
                if let value = decoded.value {
                    elements.append(value)
                }
            } else {
                // Could not even skip; bail to avoid an infinite loop.
                _ = try? container.decode(AnyDecodableSkip.self)
            }
        }
        self.wrappedValue = elements
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension LenientArray: Equatable where Element: Equatable {}
extension LenientArray: Hashable where Element: Hashable {}

/// Wraps a decode attempt so failures become `nil` instead of throwing.
private struct Throwable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
}

/// Consumes one arbitrary value to advance an unkeyed container's cursor.
private struct AnyDecodableSkip: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if (try? container.decode(Bool.self)) != nil { return }
        if (try? container.decode(Double.self)) != nil { return }
        if (try? container.decode(String.self)) != nil { return }
        if (try? container.decode([String: AnyDecodableSkip].self)) != nil { return }
        if (try? container.decode([AnyDecodableSkip].self)) != nil { return }
    }
}

// MARK: - Default convenience

extension LenientArray {
    public static var empty: LenientArray<Element> { LenientArray(wrappedValue: []) }
}

// MARK: - Shared coders

public enum DiscordCoding {
    /// Discord timestamps are ISO8601 with fractional seconds; some fields omit
    /// fractional seconds, so we accept both. `ISO8601DateFormatter`'s
    /// `date(from:)`/`string(from:)` are thread-safe, so sharing read-only
    /// instances across actors is sound.
    nonisolated(unsafe) public static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) public static let dateFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Robust parse: Discord sends up to 6 fractional digits and a `+00:00`
    /// offset; `ISO8601DateFormatter` only accepts 3 fractional digits, so we
    /// normalize the fractional component before parsing.
    public static func parseDate(_ string: String) -> Date? {
        if let d = dateFormatter.date(from: string) { return d }
        if let d = dateFormatterNoFraction.date(from: string) { return d }
        let normalized = normalizeFraction(string)
        return dateFormatter.date(from: normalized) ?? dateFormatterNoFraction.date(from: normalized)
    }

    /// Truncate or pad the `.ssssss` fraction to exactly 3 digits.
    private static func normalizeFraction(_ s: String) -> String {
        guard let dot = s.firstIndex(of: ".") else { return s }
        let afterDot = s.index(after: dot)
        var i = afterDot
        while i < s.endIndex, s[i].isNumber { i = s.index(after: i) }
        let digits = s[afterDot..<i]
        let trimmed = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return s[s.startIndex..<afterDot] + trimmed + s[i...]
    }

    /// A freshly-configured decoder. Each actor should own its own instance —
    /// `JSONDecoder` is not guaranteed safe for concurrent mutation.
    public static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parseDate(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date: \(string)"
                )
            }
            return date
        }
        return d
    }

    public static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter.string(from: date))
        }
        return e
    }
}
