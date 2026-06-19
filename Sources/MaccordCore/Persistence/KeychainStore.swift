import Foundation
import Security

/// Errors surfaced by ``KeychainStore`` when a Security framework call fails.
public enum KeychainError: Error, Sendable {
    /// An unexpected, non-success `OSStatus` was returned by a `SecItem*` call.
    case unexpectedStatus(OSStatus)
}

/// Persists the single Discord user token in the macOS Keychain as a generic
/// password item.
///
/// The item is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
/// so it is available after the first unlock following a reboot and is **never**
/// synced to iCloud. The actor serializes the (synchronous) C Keychain calls.
public actor KeychainStore {
    /// The keychain service identifier (the app's bundle id).
    private let service: String

    /// The fixed account name under which the token is stored.
    private let account = "discord-user-token"

    public init(service: String = "com.maccord.app") {
        self.service = service
    }

    /// The query that uniquely identifies our generic-password item.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Stores the token, replacing any existing value.
    ///
    /// Uses a delete-then-add strategy so a pre-existing item never causes an
    /// `errSecDuplicateItem` failure.
    public func save(token: String) throws {
        // Best-effort removal of any existing item; a missing item is fine.
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(deleteStatus)
        }

        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    /// Returns the stored token decoded as UTF-8, or `nil` if absent or unreadable.
    public func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return token
    }

    /// Removes the stored token. A missing item is not treated as an error.
    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
