import Foundation

/// HTTP verbs the REST client uses.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

/// A single REST call, independent of the client that executes it.
///
/// `majorParam` is the channel/guild/webhook id that Discord uses to scope
/// rate-limit buckets; it is folded into the bucket key so two channels with the
/// same route don't share a remaining-request counter.
public struct RESTRequest: Sendable {
    public var method: HTTPMethod
    /// Path relative to the API base, with a leading slash, e.g. `/users/@me`.
    public var path: String
    public var queryItems: [URLQueryItem]?
    /// The channel/guild/webhook id for rate-limit bucketing (nil when none applies).
    public var majorParam: String?

    public init(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        majorParam: String? = nil
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.majorParam = majorParam
    }

    /// Builds the absolute URL against `base` (e.g. `https://discord.com/api/v10`).
    public func url(base: String) -> URL? {
        guard var components = URLComponents(string: base + path) else { return nil }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    /// The rate-limit bucket key: major parameter combined with the route.
    /// Until a real `X-RateLimit-Bucket` is learned from a response, we key on
    /// `majorParam + method + path` so per-channel limits stay isolated.
    public var fallbackBucket: String {
        let major = majorParam ?? "-"
        return "\(major):\(method.rawValue):\(path)"
    }
}
