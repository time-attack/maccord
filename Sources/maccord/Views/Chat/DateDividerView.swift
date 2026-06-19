import SwiftUI

/// A centered date label sitting on a thin horizontal rule, dividing messages
/// from different calendar days (e.g. "June 18, 2026").
struct DateDividerView: View {
    let date: Date

    var body: some View {
        HStack(spacing: 0) {
            line
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DiscordColor.textMuted)
                .fixedSize()
                .padding(.horizontal, 8)
            line
        }
        .padding(.horizontal, Layout.messageHGutter)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var line: some View {
        Rectangle()
            .fill(DiscordColor.divider)
            .frame(height: 1)
    }

    private var label: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
}
