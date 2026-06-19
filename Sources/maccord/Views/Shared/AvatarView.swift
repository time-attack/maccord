import SwiftUI
import MaccordCore

/// A circular avatar with an optional presence dot, backed by the image cache.
struct AvatarView: View {
    let url: URL?
    var fallbackText: String = ""
    var size: CGFloat = 40
    var status: Status? = nil
    var dotBorderColor: Color = DiscordColor.bgPrimary

    var body: some View {
        CachedAsyncImage(
            url: url,
            content: { image in
                image.resizable().scaledToFill()
            },
            placeholder: {
                ZStack {
                    DiscordColor.blurple
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        )
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(alignment: .bottomTrailing) {
            if let status {
                PresenceDotView(
                    status: status,
                    size: size * 0.32,
                    borderColor: dotBorderColor
                )
                .offset(x: size * 0.06, y: size * 0.06)
            }
        }
    }

    private var initials: String {
        let parts = fallbackText.split(separator: " ")
        if let first = parts.first?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}
