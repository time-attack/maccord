import Foundation

/// The gateway frame envelope: `{"op": Int, "d": <raw>, "s": Int?, "t": String?}`.
///
/// Because `d` is heterogeneous (its shape depends on `op` and `t`), we decode
/// `op`/`s`/`t` eagerly and keep `d` as raw `Data` for a later, typed decode via
/// ``decodeData(_:using:)``. We parse with `JSONSerialization` so we can re-extract
/// the `d` sub-object back into self-contained `Data` for the per-actor decoder.
public struct GatewayFrame: Sendable {
    public let op: Int
    public let sequence: Int?
    public let type: String?
    /// The re-serialized `d` payload, ready for a typed `JSONDecoder` pass. `nil`
    /// when `d` was absent or JSON `null`.
    public let data: Data?

    /// Initialize from the raw bytes of a websocket message.
    public init(rawData: Data) throws {
        let object = try JSONSerialization.jsonObject(with: rawData, options: [])
        guard let dict = object as? [String: Any] else {
            throw GatewayFrameError.notAnObject
        }

        // `op` may arrive as an Int or a numeric NSNumber; coerce defensively.
        if let opInt = dict["op"] as? Int {
            self.op = opInt
        } else if let opNum = dict["op"] as? NSNumber {
            self.op = opNum.intValue
        } else {
            throw GatewayFrameError.missingOpcode
        }

        if let s = dict["s"] as? Int {
            self.sequence = s
        } else if let sNum = dict["s"] as? NSNumber {
            self.sequence = sNum.intValue
        } else {
            self.sequence = nil
        }

        self.type = dict["t"] as? String

        // Re-serialize the `d` sub-object back into standalone Data. JSONSerialization
        // rejects top-level fragments by default, so wrap fragments and unwrap.
        if let raw = dict["d"], !(raw is NSNull) {
            if JSONSerialization.isValidJSONObject(raw) {
                self.data = try JSONSerialization.data(withJSONObject: raw, options: [])
            } else {
                // Fragment (Bool/Int/String) — wrap, serialize, then strip the wrapper.
                let wrapped = try JSONSerialization.data(
                    withJSONObject: ["v": raw], options: []
                )
                self.data = GatewayFrame.unwrapFragment(wrapped)
            }
        } else {
            self.data = nil
        }
    }

    /// Decode the stored `d` payload into a concrete `Decodable` type using the
    /// caller's (per-actor) decoder.
    public func decodeData<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder) throws -> T {
        guard let data else {
            throw GatewayFrameError.missingPayload
        }
        return try decoder.decode(T.self, from: data)
    }

    /// Strip the `{"v": ...}` wrapper around a serialized JSON fragment, returning
    /// just the inner value's bytes.
    private static func unwrapFragment(_ wrapped: Data) -> Data? {
        guard let string = String(data: wrapped, encoding: .utf8) else { return nil }
        // Wrapped form is exactly `{"v":<value>}`. Drop the leading `{"v":` and
        // the trailing `}`.
        let prefix = "{\"v\":"
        guard string.hasPrefix(prefix), string.hasSuffix("}") else { return nil }
        let inner = string.dropFirst(prefix.count).dropLast()
        return String(inner).data(using: .utf8)
    }
}

public enum GatewayFrameError: Error, Sendable {
    case notAnObject
    case missingOpcode
    case missingPayload
}

/// op 10 Hello payload — carries the heartbeat interval (milliseconds).
public struct HelloPayload: Decodable, Sendable {
    public let heartbeatInterval: Int
    enum CodingKeys: String, CodingKey {
        case heartbeatInterval = "heartbeat_interval"
    }
}
