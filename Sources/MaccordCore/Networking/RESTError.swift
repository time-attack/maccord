import Foundation

/// Errors surfaced by the REST layer. All cases are value types so the error can
/// safely cross actor boundaries.
public enum RESTError: Error, Sendable, Equatable {
    /// The request could not be turned into a valid `URL`.
    case invalidURL
    /// No user token has been set; the request was not attempted.
    case notAuthenticated
    /// A non-2xx HTTP status with Discord's parsed error body (when present).
    case http(status: Int, code: Int?, message: String?)
    /// A 429 that exhausted the retry budget; `retryAfter` is in seconds.
    case rateLimited(retryAfter: Double)
    /// The response body failed to decode into the expected type.
    case decoding(String)
    /// A URLSession/transport-level failure (no HTTP response).
    case transport(String)
    /// An unclassified failure.
    case unknown
}

extension RESTError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "Not authenticated"
        case let .http(status, code, message):
            let codePart = code.map { " code=\($0)" } ?? ""
            let msgPart = message.map { ": \($0)" } ?? ""
            return "HTTP \(status)\(codePart)\(msgPart)"
        case let .rateLimited(retryAfter):
            return "Rate limited, retry after \(retryAfter)s"
        case let .decoding(detail):
            return "Decoding error: \(detail)"
        case let .transport(detail):
            return "Transport error: \(detail)"
        case .unknown:
            return "Unknown error"
        }
    }
}

/// Discord's standard JSON error envelope. `code` is Discord's internal numeric
/// error code (distinct from the HTTP status); `message` is human-readable.
/// Some errors also carry a nested `errors` tree which we don't model here.
public struct DiscordAPIError: Decodable, Sendable, Equatable {
    public let code: Int?
    public let message: String?

    public init(code: Int?, message: String?) {
        self.code = code
        self.message = message
    }
}
