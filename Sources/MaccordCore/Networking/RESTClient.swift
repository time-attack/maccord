import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The Discord HTTP REST client (user-token auth, v10).
///
/// All mutable state (token, rate limiter, coders) lives behind this actor.
/// Each instance owns its own `JSONDecoder`/`JSONEncoder`; never share them.
/// The token is held in memory only and is never logged.
public actor RESTClient {
    /// Versioned API base.
    public static let apiBase = "https://discord.com/api/v10"
    /// Fallback gateway URL when `/gateway` cannot be reached.
    public static let defaultGatewayURL = "wss://gateway.discord.gg"

    private let session: URLSession
    private let superProperties: SuperProperties
    private let rateLimiter = RateLimiter()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var token: String?
    private var authMode: DiscordAuthMode = .user

    /// Max attempts for a single request when 429s are encountered.
    private let maxAttempts = 3

    public init(superProperties: SuperProperties = SuperProperties()) {
        self.superProperties = superProperties
        self.decoder = DiscordCoding.makeDecoder()
        self.encoder = DiscordCoding.makeEncoder()

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [:]
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Token management

    public func setToken(_ token: String, mode: DiscordAuthMode = .user) {
        self.token = token
        self.authMode = mode
    }

    public func clearToken() {
        self.token = nil
        self.authMode = .user
    }

    public var hasToken: Bool { token != nil }
    public var currentAuthMode: DiscordAuthMode { authMode }

    /// The exact `Authorization` header value: bots are prefixed with `Bot `.
    private func authorizationHeader(for token: String) -> String {
        authMode == .bot ? "Bot \(token)" : token
    }

    /// Detect whether `token` is a bot or user token (and validate it) by trying
    /// `GET /users/@me` as a bot first, then as a user. Sets the client's token +
    /// mode on success. Throws if neither works.
    public func authenticate(token: String) async throws -> (mode: DiscordAuthMode, user: CurrentUser) {
        setToken(token, mode: .bot)
        if let user = try? await getCurrentUser() {
            return (.bot, user)
        }
        setToken(token, mode: .user)
        let user = try await getCurrentUser()   // rethrows on a genuinely bad token
        return (.user, user)
    }

    /// Recommended gateway intents for the current bot, derived from its
    /// application flags so we never request a privileged intent it lacks.
    public func recommendedBotIntents() async -> Int {
        struct AppInfo: Decodable { let flags: Int? }
        let flags: Int
        if let info: AppInfo = try? await get(RESTRequest(method: .get, path: "/applications/@me")) {
            flags = info.flags ?? 0
        } else {
            flags = 0
        }
        let messageContent = (flags & (1 << 18)) != 0 || (flags & (1 << 19)) != 0
        let members        = (flags & (1 << 14)) != 0 || (flags & (1 << 15)) != 0
        let presences      = (flags & (1 << 12)) != 0 || (flags & (1 << 13)) != 0
        return GatewayIntents.recommended(
            messageContent: messageContent, members: members, presences: presences
        ).rawValue
    }

    // MARK: - Core transport

    /// Sends a request and returns the raw response body. Applies auth headers,
    /// rate-limit gating, and 429 retry with backoff. Throws `RESTError`.
    func send(_ req: RESTRequest, body: Data?, contentType: String?) async throws -> Data {
        guard let token else { throw RESTError.notAuthenticated }
        guard let url = req.url(base: Self.apiBase) else { throw RESTError.invalidURL }

        let bucket = req.fallbackBucket

        var attempt = 0
        while true {
            attempt += 1

            await rateLimiter.willSend(bucket: bucket)

            var request = URLRequest(url: url)
            request.httpMethod = req.method.rawValue
            request.setValue(authorizationHeader(for: token), forHTTPHeaderField: "Authorization")
            if authMode == .bot {
                // Bots must NOT send the browser super-properties / Electron UA —
                // Discord rejects those on bot requests (403 40333). Use a plain
                // bot User-Agent instead.
                request.setValue("DiscordBot (https://github.com/maccord, 0.1)",
                                 forHTTPHeaderField: "User-Agent")
            } else {
                request.setValue(SuperProperties.restUserAgent, forHTTPHeaderField: "User-Agent")
                request.setValue(superProperties.base64Encoded, forHTTPHeaderField: "X-Super-Properties")
                request.setValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
            }
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = body

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw RESTError.transport(error.localizedDescription)
            }

            guard let http = response as? HTTPURLResponse else {
                throw RESTError.transport("Non-HTTP response")
            }

            let headers = http.allHeaderFields

            // Success.
            if (200...299).contains(http.statusCode) {
                await rateLimiter.didReceive(headers: headers, bucket: bucket)
                return data
            }

            // Rate limited.
            if http.statusCode == 429 {
                let parsed = parse429(data: data)
                let retryAfter = parsed.retryAfter ?? doubleHeader(headers, "Retry-After") ?? 1.0
                if parsed.global {
                    await rateLimiter.globalPause(retryAfter: retryAfter)
                } else {
                    await rateLimiter.penalize(bucket: bucket, retryAfter: retryAfter)
                }
                if attempt >= maxAttempts {
                    throw RESTError.rateLimited(retryAfter: retryAfter)
                }
                try? await Task.sleep(nanoseconds: UInt64(max(0, retryAfter) * 1_000_000_000))
                continue
            }

            // Other error — update buckets then decode Discord's error envelope.
            await rateLimiter.didReceive(headers: headers, bucket: bucket)
            let apiError = try? decoder.decode(DiscordAPIError.self, from: data)
            throw RESTError.http(
                status: http.statusCode,
                code: apiError?.code,
                message: apiError?.message
            )
        }
    }

    // MARK: - Generic helpers

    func get<T: Decodable>(_ req: RESTRequest) async throws -> T {
        let data = try await send(req, body: nil, contentType: nil)
        return try decode(T.self, from: data)
    }

    func post<R: Decodable>(_ req: RESTRequest, jsonBody: Encodable?) async throws -> R {
        let body = try encodeBody(jsonBody)
        let data = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
        return try decode(R.self, from: data)
    }

    /// POST that ignores the response body (e.g. 204 routes).
    func postNoContent(_ req: RESTRequest, jsonBody: Encodable?) async throws {
        let body = try encodeBody(jsonBody)
        _ = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
    }

    func patch<R: Decodable>(_ req: RESTRequest, jsonBody: Encodable?) async throws -> R {
        let body = try encodeBody(jsonBody)
        let data = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
        return try decode(R.self, from: data)
    }

    func delete(_ req: RESTRequest) async throws {
        _ = try await send(req, body: nil, contentType: nil)
    }

    func put<R: Decodable>(_ req: RESTRequest, jsonBody: Encodable?) async throws -> R {
        let body = try encodeBody(jsonBody)
        let data = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
        return try decode(R.self, from: data)
    }

    /// PUT that ignores the response body (e.g. 204 routes like bans / recipients).
    func putNoContent(_ req: RESTRequest, jsonBody: Encodable?) async throws {
        let body = try encodeBody(jsonBody)
        _ = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
    }

    /// PATCH that ignores the response body.
    func patchNoContent(_ req: RESTRequest, jsonBody: Encodable?) async throws {
        let body = try encodeBody(jsonBody)
        _ = try await send(req, body: body, contentType: body == nil ? nil : "application/json")
    }

    func postMultipart<R: Decodable>(
        _ req: RESTRequest,
        payloadJSON: Data,
        files: [FilePart]
    ) async throws -> R {
        let form = MultipartFormBody()
        let (body, _) = form.encode(payloadJSON: payloadJSON, files: files)
        let data = try await send(req, body: body, contentType: form.contentTypeHeader)
        return try decode(R.self, from: data)
    }

    // MARK: - Gateway URL

    /// `GET /gateway` → `{"url": "..."}`. Falls back to the well-known URL on any error.
    public func getGatewayURL() async throws -> String {
        struct GatewayResponse: Decodable { let url: String }
        do {
            let req = RESTRequest(method: .get, path: "/gateway")
            let resp: GatewayResponse = try await get(req)
            return resp.url
        } catch {
            return Self.defaultGatewayURL
        }
    }

    // MARK: - Encoding / decoding plumbing

    /// Exposed to REST extensions that need to hand-build a `payload_json` body.
    func encodeJSON(_ value: Encodable) throws -> Data {
        do {
            return try encoder.encode(AnyEncodable(value))
        } catch {
            throw RESTError.decoding("Encode failed: \(error)")
        }
    }

    private func encodeBody(_ value: Encodable?) throws -> Data? {
        guard let value else { return nil }
        return try encodeJSON(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RESTError.decoding("Failed to decode \(T.self): \(error)")
        }
    }

    private func parse429(data: Data) -> (retryAfter: Double?, global: Bool) {
        struct Body: Decodable {
            let retryAfter: Double?
            let global: Bool?
            enum CodingKeys: String, CodingKey {
                case retryAfter = "retry_after"
                case global
            }
        }
        guard let body = try? decoder.decode(Body.self, from: data) else {
            return (nil, false)
        }
        return (body.retryAfter, body.global ?? false)
    }

    private func doubleHeader(_ headers: [AnyHashable: Any], _ key: String) -> Double? {
        for (k, v) in headers {
            if let ks = k as? String, ks.caseInsensitiveCompare(key) == .orderedSame {
                if let s = v as? String { return Double(s) }
            }
        }
        return nil
    }
}

/// A type-erased `Encodable` so `Encodable?` parameters can be encoded directly
/// (Swift can't call `encode` on an existential without this shim).
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
