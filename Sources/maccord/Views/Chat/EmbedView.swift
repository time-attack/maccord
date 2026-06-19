import SwiftUI
import MaccordCore

/// A rich embed card: a left color bar, a flat secondary-surface body holding
/// author / title / description / fields / thumbnail / image / footer.
struct EmbedView: View {
    let embed: Embed

    private var accent: Color {
        if let c = embed.color, let color = Color(discordColor: c) { return color }
        return DiscordColor.blurple
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                topSection
                if let image = embed.image, let url = image.bestURL {
                    CachedAsyncImage(
                        url: url,
                        content: { $0.resizable().scaledToFit() },
                        placeholder: { DiscordColor.bgTertiary }
                    )
                    .frame(maxWidth: 400, maxHeight: 300, alignment: .leading)
                    .clipShape(.rect(cornerRadius: 4, style: .continuous))
                }
                if let footer = embed.footer {
                    footerView(footer)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: 432, alignment: .leading)
        .background(DiscordColor.bgSecondary)
        .clipShape(.rect(cornerRadius: 4, style: .continuous))
    }

    // MARK: Sections

    private var topSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let author = embed.author {
                    Text(author.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                        .lineLimit(1)
                }
                if let title = embed.title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(embed.url == nil ? DiscordColor.headerPrimary : DiscordColor.linkBlue)
                        .lineLimit(2)
                }
                if let description = embed.description {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DiscordColor.textNormal)
                        .lineLimit(12)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let fields = embed.fields, !fields.isEmpty {
                    fieldsGrid(fields)
                }
            }

            if let thumb = embed.thumbnail, let url = thumb.bestURL {
                CachedAsyncImage(
                    url: url,
                    content: { $0.resizable().scaledToFill() },
                    placeholder: { DiscordColor.bgTertiary }
                )
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private func fieldsGrid(_ fields: [EmbedField]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DiscordColor.headerPrimary)
                    Text(field.value)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DiscordColor.textNormal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }

    private func footerView(_ footer: EmbedFooter) -> some View {
        HStack(spacing: 6) {
            if let icon = footer.iconURL, let url = URL(string: icon) {
                CachedAsyncImage(
                    url: url,
                    content: { $0.resizable().scaledToFill() },
                    placeholder: { DiscordColor.bgTertiary }
                )
                .frame(width: 18, height: 18)
                .clipShape(.circle)
            }
            Text(footer.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DiscordColor.textMuted)
                .lineLimit(1)
        }
    }
}
