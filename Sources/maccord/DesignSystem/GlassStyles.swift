import SwiftUI

/// Reusable Liquid Glass treatments (macOS 26). Glass is used for *floating
/// chrome* — the message hover toolbar, the composer's send affordance, popovers,
/// the connection banner — while flat Discord surfaces use solid fills.
extension View {
    /// A rounded glass panel for floating chrome (toolbars, HUDs, popovers).
    func glassPanel(cornerRadius: CGFloat = 8, tint: Color? = nil, interactive: Bool = false) -> some View {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return self.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    /// A capsule glass pill (e.g. reaction picker buttons, jump-to-present).
    func glassPill(tint: Color? = nil, interactive: Bool = true) -> some View {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return self.glassEffect(glass, in: .capsule)
    }

    /// Discord-style flat surface fill with an optional hairline border.
    func discordSurface(_ color: Color, cornerRadius: CGFloat = 0, border: Color? = nil) -> some View {
        self
            .background(color)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
    }
}
