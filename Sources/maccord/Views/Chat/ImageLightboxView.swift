import SwiftUI
import MaccordCore

/// Full-size image viewer (Discord's click-to-enlarge). Scroll/pinch to zoom,
/// Escape or the close button to dismiss, plus open-in-browser.
struct ImageLightboxView: View {
    let url: URL?
    var filename: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.85).ignoresSafeArea()

            ScrollView([.horizontal, .vertical]) {
                CachedAsyncImage(
                    url: url,
                    content: { $0.resizable().scaledToFit() },
                    placeholder: { ProgressView().controlSize(.large) }
                )
                .scaleEffect(zoom)
                .frame(minWidth: 400, minHeight: 300)
            }
            .scrollIndicators(.never)

            HStack(spacing: 8) {
                lightboxButton("minus.magnifyingglass") { zoom = max(0.5, zoom - 0.25) }
                lightboxButton("plus.magnifyingglass") { zoom = min(4, zoom + 0.25) }
                if let url {
                    lightboxButton("arrow.up.right.square") { NSWorkspace.shared.open(url) }
                }
                lightboxButton("xmark") { dismiss() }
            }
            .padding(12)
        }
        .frame(minWidth: 600, minHeight: 480)
        .onExitCommand { dismiss() }
    }

    private func lightboxButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: .circle)
    }
}
