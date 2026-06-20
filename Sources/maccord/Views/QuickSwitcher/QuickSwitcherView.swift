import SwiftUI
import MaccordCore

/// ⌘K quick switcher: search every server, channel, DM and friend. Type to
/// filter, ↑/↓ to move, Return to open, Esc to close. Clicking a row opens it.
///
/// `filtered` is computed straight from `query` while the view renders, so the
/// list ALWAYS reflects what you typed (no event handler to misfire). The match
/// is a cheap substring test over an index built once when the switcher opens.
struct QuickSwitcherView: View {
    @Environment(AppState.self) private var app
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var selection = 0
    @State private var index: [SearchResult] = []   // full index, built on open
    @State private var builtSignature = -1
    @State private var focusTick = 0                 // nudges focus retries on open

    var body: some View {
        let _ = focusTick   // re-render when ticked → the field re-attempts focus
        let shown = filtered
        return VStack(spacing: 0) {
            field(shown)
            Divider().overlay(.white.opacity(0.08))
            list(shown)
        }
        .frame(width: 560)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 16)
        .onAppear {
            app.hydrateGuildsForSearch()
            rebuild()
            // Force a few re-renders over the first ~0.7s so the search field grabs
            // focus once the sheet window becomes key (otherwise typing goes nowhere).
            Task { @MainActor in
                for _ in 0..<12 {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    focusTick &+= 1
                }
            }
        }
        .onChange(of: query) { _, _ in selection = 0 }
        .onChange(of: indexSignature) { _, _ in rebuild() }
    }

    // MARK: Field

    private func field(_ shown: [SearchResult]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiscordColor.textMuted)
            QuickSwitcherField(
                text: $query,
                onUp: { move(-1, shown.count) },
                onDown: { move(1, shown.count) },
                onReturn: { if shown.indices.contains(selection) { open(shown[selection]) } },
                onEscape: { isPresented = false }
            )
            .frame(height: 26)
        }
        .padding(16)
    }

    // MARK: List

    @ViewBuilder
    private func list(_ shown: [SearchResult]) -> some View {
        if shown.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(DiscordColor.textFaint)
                Text(query.isEmpty ? "Search servers, channels, DMs and friends" : "No matches")
                    .font(.system(size: 13))
                    .foregroundStyle(DiscordColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, item in
                            row(item, selected: i == selection)
                                .id(i)
                                .contentShape(.rect)
                                .onTapGesture { open(item) }
                        }
                    }
                    .padding(8)
                }
                .frame(height: min(CGFloat(shown.count) * 52 + 16, 400))
                .scrollIndicators(.never)
                // Only keyboard navigation scrolls — hovering never moves selection.
                .onChange(of: selection) { _, s in
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(s, anchor: .center) }
                }
            }
        }
    }

    private func row(_ item: SearchResult, selected: Bool) -> some View {
        HStack(spacing: 12) {
            icon(item).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? .white : DiscordColor.headerPrimary)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(selected ? .white.opacity(0.85) : DiscordColor.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(item.kindLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(selected ? .white.opacity(0.7) : DiscordColor.textFaint)
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(selected ? DiscordColor.blurple : .clear, in: .rect(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func icon(_ item: SearchResult) -> some View {
        switch item.icon {
        case let .image(url, monogram, shape):
            let clip: AnyShape = shape == .circle
                ? AnyShape(Circle())
                : AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            CachedAsyncImage(
                url: url,
                content: { $0.resizable().scaledToFill() },
                placeholder: {
                    ZStack {
                        DiscordColor.bgSecondary
                        Text(monogram)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DiscordColor.headerSecondary)
                    }
                }
            )
            .frame(width: 30, height: 30)
            .clipShape(clip)
            .overlay(alignment: .bottomTrailing) {
                if let status = item.status {
                    PresenceDotView(status: status, size: 10, borderColor: DiscordColor.bgFloating)
                        .offset(x: 2, y: 2)
                }
            }
        case let .glyph(symbol, tint):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DiscordColor.bgSecondary.opacity(0.5))
                Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)
        }
    }

    // MARK: Data

    /// Fingerprint of the index inputs; when it changes the index is rebuilt
    /// (channels hydrate, member roles load → hidden channels drop out).
    private var indexSignature: Int {
        var h = Hasher()
        h.combine(app.guildOrder.count)
        h.combine(app.channelsByID.count)
        h.combine(app.dms.count)
        h.combine(app.relationships.count)
        h.combine(app.myMembers.count)
        return h.finalize()
    }

    private func rebuild() {
        guard indexSignature != builtSignature else { return }
        builtSignature = indexSignature
        index = SearchIndex(app: app).containers()
    }

    /// Computed every render from the live `query` — cheap substring match over the
    /// already-built index. Empty query → recents first, then everything else.
    private var filtered: [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else {
            let recents = index.filter { $0.recencyRank != .max }
                .sorted { $0.recencyRank < $1.recencyRank }
            let recentIDs = Set(recents.map(\.id))
            let rest = index.filter { !recentIDs.contains($0.id) }
            return Array((recents + rest).prefix(50))
        }
        var scored: [(item: SearchResult, score: Int)] = []
        for r in index {
            if let s = r.matchScore(q) { scored.append((r, s)) }
        }
        scored.sort { $0.score != $1.score ? $0.score < $1.score : $0.item.title.count < $1.item.title.count }
        return scored.prefix(50).map(\.item)
    }

    // MARK: Navigation

    private func move(_ delta: Int, _ count: Int) {
        guard count > 0 else { return }
        selection = (min(max(0, selection), count - 1) + delta + count) % count
    }

    private func open(_ item: SearchResult) {
        item.navigate()
        isPresented = false
    }
}
