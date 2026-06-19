import SwiftUI
import AppKit
import MaccordCore

/// Renders a single message attachment: a constrained inline image, or a
/// flat file card for non-image attachments.
struct AttachmentView: View {
    let attachment: Attachment

    private let maxWidth: CGFloat = 400
    private let maxHeight: CGFloat = 300

    @State private var showLightbox = false

    var body: some View {
        if attachment.isImage {
            imageBody
        } else {
            fileCard
        }
    }

    // MARK: Image

    private var imageBody: some View {
        Button { showLightbox = true } label: {
            CachedAsyncImage(
                url: attachment.bestURL,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: {
                    DiscordColor.bgSecondary
                }
            )
            .frame(width: displaySize.width, height: displaySize.height)
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(attachment.filename)
        .sheet(isPresented: $showLightbox) {
            ImageLightboxView(url: attachment.bestURL, filename: attachment.filename)
        }
    }

    /// Scale the image down to fit the max box while preserving aspect ratio.
    private var displaySize: CGSize {
        let w = CGFloat(attachment.width ?? Int(maxWidth))
        let h = CGFloat(attachment.height ?? Int(maxHeight))
        guard w > 0, h > 0 else { return CGSize(width: maxWidth, height: maxHeight) }
        let scale = min(maxWidth / w, maxHeight / h, 1)
        return CGSize(width: w * scale, height: h * scale)
    }

    // MARK: File card

    private var fileCard: some View {
        Button {
            if let url = attachment.bestURL { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 26))
                    .foregroundStyle(DiscordColor.interactiveNormal)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DiscordColor.linkBlue)
                        .lineLimit(1)
                    Text(attachment.humanSize)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DiscordColor.textMuted)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(DiscordColor.interactiveNormal)
            }
            .padding(12)
            .frame(maxWidth: 432, alignment: .leading)
            .background(DiscordColor.bgSecondary)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(DiscordColor.divider, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url = attachment.bestURL {
                Button { NSWorkspace.shared.open(url) } label: { Label("Open in Browser", systemImage: "safari") }
                Button { Clipboard.copy(url.absoluteString) } label: { Label("Copy Link", systemImage: "link") }
            }
        }
    }

    private var iconName: String {
        if attachment.isVideo { return "play.rectangle.fill" }
        if attachment.isAudio { return "waveform" }
        return "doc.fill"
    }
}
