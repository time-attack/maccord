import Foundation

/// An on-disk fallback for the session token, kept in Application Support with
/// `0600` permissions.
///
/// The Keychain is still the preferred store, but **ad-hoc-signed builds get a
/// fresh code signature on every rebuild**, and macOS scopes a generic-password
/// item to the signature that created it — so a freshly built binary can't read
/// the token the previous build saved, forcing a re-login every run. This file
/// is keyed only by path, so it survives rebuilds and you stay logged in.
///
/// It is lightly obfuscated (base64), **not encrypted** — it is protected by your
/// user account's file permissions, like a CLI credential. Don't ship it.
public struct FileTokenStore: Sendable {
    private let fileURL: URL

    public init(appName: String = "Maccord") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        self.fileURL = dir.appendingPathComponent("session.token")
    }

    public func load() -> String? {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = Data(base64Encoded: raw),
              let token = String(data: decoded, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    public func save(_ token: String) {
        let data = Data(Data(token.utf8).base64EncodedData())
        guard (try? data.write(to: fileURL, options: .atomic)) != nil else { return }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
    }

    public func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
