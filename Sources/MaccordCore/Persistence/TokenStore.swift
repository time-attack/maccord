import Foundation

/// High-level convenience layer over ``KeychainStore`` for the Discord user token.
///
/// Provides async accessors and light validation. The token is never logged.
public actor TokenStore {
    private let keychain: KeychainStore

    public init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    /// The currently stored token, or `nil` if none is persisted.
    public func currentToken() async -> String? {
        await keychain.load()
    }

    /// Persists the given token, replacing any previous value.
    public func store(_ token: String) async throws {
        try await keychain.save(token: token)
    }

    /// Removes any persisted token.
    public func clear() async throws {
        try await keychain.delete()
    }

    /// A cheap sanity check for a Discord user token: non-empty and containing
    /// at least one `.` (Discord tokens are dot-delimited). This is shape-only
    /// validation, not authentication.
    public static func looksValid(_ token: String) -> Bool {
        !token.isEmpty && token.contains(".")
    }
}
