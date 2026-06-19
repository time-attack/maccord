import SwiftUI
import AppKit

/// Drop-in replacement for `AsyncImage` backed by `ImageCache`. macOS 26's
/// `AsyncImage` has no cache, so every avatar/icon/emoji routes through here.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var nsImage: NSImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let nsImage {
                content(Image(nsImage: nsImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            nsImage = nil
            guard let url else { return }
            if let data = await ImageCache.shared.data(for: url), let image = NSImage(data: data) {
                nsImage = image
            }
        }
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    /// Convenience: fill the frame, with a faint placeholder.
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { DiscordColor.bgTertiary }
        )
    }
}
