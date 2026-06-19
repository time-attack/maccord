import SwiftUI
import MaccordCore

/// The author name + timestamp line that heads a "full" (non-grouped) message.
struct MessageGroupHeaderView: View {
    let message: Message
    let authorName: String
    let authorColor: Color
    var isOwner: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(authorName)
                .font(DiscordFont.authorName)
                .foregroundStyle(authorColor)
            if isOwner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DiscordColor.statusIdle)
            }
            if message.author.isBot {
                BotTag()
            }
            Text(Self.format(message.timestamp))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DiscordColor.textMuted)
        }
    }

    /// "Today at 4:32 PM" / "Yesterday at …" / "MM/dd/yyyy h:mm a".
    static func format(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today at \(timeFormatter.string(from: date))"
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday at \(timeFormatter.string(from: date))"
        }
        return dateFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy h:mm a"; return f
    }()
}

/// Small "APP"/"BOT" tag shown next to bot author names.
struct BotTag: View {
    var body: some View {
        Text("APP")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(DiscordColor.blurple)
            .clipShape(.rect(cornerRadius: 3, style: .continuous))
    }
}
