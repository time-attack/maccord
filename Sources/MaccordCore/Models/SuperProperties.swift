import Foundation

/// The client-identity payload Discord expects in the gateway IDENTIFY
/// `properties` field and, base64-encoded, in the `X-Super-Properties` REST
/// header. Values mimic the official desktop (Electron) client to blend in.
public struct SuperProperties: Codable, Sendable, Hashable {
    public var os: String
    public var browser: String
    public var device: String
    public var systemLocale: String
    public var browserUserAgent: String
    public var browserVersion: String
    public var osVersion: String
    public var releaseChannel: String
    public var clientBuildNumber: Int
    public var clientEventSource: String?

    enum CodingKeys: String, CodingKey {
        case os, browser, device
        case systemLocale = "system_locale"
        case browserUserAgent = "browser_user_agent"
        case browserVersion = "browser_version"
        case osVersion = "os_version"
        case releaseChannel = "release_channel"
        case clientBuildNumber = "client_build_number"
        case clientEventSource = "client_event_source"
    }

    public init(
        os: String = "Mac OS X",
        browser: String = "Discord Client",
        device: String = "",
        systemLocale: String = "en-US",
        browserUserAgent: String = SuperProperties.defaultUserAgent,
        browserVersion: String = "0.0.360",
        osVersion: String = "26.4.0",
        releaseChannel: String = "stable",
        clientBuildNumber: Int = 354823,
        clientEventSource: String? = nil
    ) {
        self.os = os
        self.browser = browser
        self.device = device
        self.systemLocale = systemLocale
        self.browserUserAgent = browserUserAgent
        self.browserVersion = browserVersion
        self.osVersion = osVersion
        self.releaseChannel = releaseChannel
        self.clientBuildNumber = clientBuildNumber
        self.clientEventSource = clientEventSource
    }

    public static let defaultUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.360 Chrome/124.0.6367.243 Electron/30.2.0 Safari/537.36"

    /// The same value used for the REST `User-Agent` header.
    public static let restUserAgent = defaultUserAgent

    /// Base64-encoded JSON, the form required by the `X-Super-Properties` header.
    public var base64Encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }
}
