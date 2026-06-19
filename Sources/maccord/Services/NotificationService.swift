import Foundation
import UserNotifications
import MaccordCore

/// Native macOS notifications for mentions and DMs (UNUserNotificationCenter).
/// Carries the sender's avatar, encodes the target channel/message in `userInfo`,
/// and routes clicks back to the app via `onOpen`.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    /// Invoked when the user clicks a notification: (channelID, messageID?).
    var onOpen: ((Snowflake, Snowflake?) -> Void)?

    private override init() { super.init() }

    func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, subtitle: String? = nil, body: String,
                channelID: Snowflake? = nil, messageID: Snowflake? = nil,
                avatarURL: URL? = nil, playSound: Bool = true) {
        Task {
            await deliver(title: title, subtitle: subtitle, body: body,
                          channelID: channelID, messageID: messageID,
                          avatarURL: avatarURL, playSound: playSound)
        }
    }

    private func deliver(title: String, subtitle: String?, body: String,
                         channelID: Snowflake?, messageID: Snowflake?,
                         avatarURL: URL?, playSound: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        content.body = body
        if playSound { content.sound = .default }
        if let channelID { content.userInfo["channelID"] = String(channelID.rawValue) }
        if let messageID { content.userInfo["messageID"] = String(messageID.rawValue) }
        if let avatarURL, let attachment = await avatarAttachment(avatarURL) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Download (cached) the sender's avatar and wrap it as a notification image.
    private func avatarAttachment(_ url: URL) async -> UNNotificationAttachment? {
        guard let data = await ImageCache.shared.data(for: url) else { return nil }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("maccord-avatar-\(UUID().uuidString).png")
        do {
            try data.write(to: file)
            return try UNNotificationAttachment(identifier: "avatar", url: file)
        } catch {
            return nil
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["channelID"] as? String, let cid = UInt64(raw) else { return }
        let channel = Snowflake(cid)
        let message = (info["messageID"] as? String).flatMap { UInt64($0) }.map { Snowflake($0) }
        await MainActor.run { self.onOpen?(channel, message) }
    }
}
