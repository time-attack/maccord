import Foundation

/// High-level convenience layer over ``KeychainStore`` for the Discord user token.
///
/// Provides async accessors and light validation. The token is never logged.
///
/// Persistence is layered: the **Keychain** is authoritative, with a file-based
/// fallback ([`FileTokenStore`]) that survives the per-build signature changes of
/// ad-hoc-signed builds — so you stay logged in across rebuilds instead of
/// re-pasting your token every run.
public actor TokenStore {
    private let keychain: KeychainStore
    private let file: FileTokenStore

    public init(keychain: KeychainStore = KeychainStore(),
                file: FileTokenStore = FileTokenStore()) {
        self.keychain = keychain
        self.file = file
    }

    /// The currently stored token, or `nil` if none is persisted. Prefers the
    /// Keychain, falling back to the on-disk copy (and re-seeding the Keychain
    /// from it so the canonical store heals itself).
    public func currentToken() async -> String? {
        if let token = await keychain.load() { return token }
        if let token = file.load() {
            try? await keychain.save(token: token)   // best-effort re-seed
            return token
        }
        return nil
    }

    /// Persists the given token to both stores, replacing any previous value.
    public func store(_ token: String) async throws {
        try? await keychain.save(token: token)   // best-effort; some signing setups reject it
        file.save(token)                          // reliable across rebuilds
    }

    /// Removes any persisted token from both stores.
    public func clear() async throws {
        try? await keychain.delete()
        file.delete()
    }

    /// A cheap sanity check for a Discord user token: non-empty and containing
    /// at least one `.` (Discord tokens are dot-delimited). This is shape-only
    /// validation, not authentication.
    public static func looksValid(_ token: String) -> Bool {
        !token.isEmpty && token.contains(".")
    }
}
