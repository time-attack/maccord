import SwiftUI
import Combine

/// A thin animated "X is typing…" indicator that sits just above the composer.
struct TypingIndicatorView: View {
    let names: [String]

    @State private var phase = 0

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            dots
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DiscordColor.textMuted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.composerHPadding + 4)
        .frame(height: 24)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DiscordColor.textMuted)
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.0 : 0.6)
                    .opacity(phase == i ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.25), value: phase)
            }
        }
    }

    private var message: String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return "\(names[0]) is typing…"
        case 2:
            return "\(names[0]) and \(names[1]) are typing…"
        case 3:
            return "\(names[0]), \(names[1]), and \(names[2]) are typing…"
        default:
            return "Several people are typing…"
        }
    }
}
