import Foundation

/// The op 6 RESUME `d` payload. Sent on a fresh socket to `resume_gateway_url`
/// to replay missed dispatches. See `.context/research-gateway.md` §6.
public struct ResumePayload: Encodable, Sendable {
    public let token: String
    public let sessionID: String
    public let seq: Int

    public init(token: String, sessionID: String, seq: Int) {
        self.token = token
        self.sessionID = sessionID
        self.seq = seq
    }

    enum CodingKeys: String, CodingKey {
        case token, seq
        case sessionID = "session_id"
    }
}
