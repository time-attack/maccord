import SwiftUI
import MaccordCore

/// ⌘K quick switcher: jump to any channel, DM, or server. The destination index
/// is built once when it opens and filtered live as you type; ↑/↓ move the
/// selection, Return jumps, Esc closes. Rendered on real Liquid Glass.
struct QuickSwitcherView: View {
    @Environment(AppState.self) private var app
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var selection = 0

    struct Item: Identifiable {
        enum Kind { case channel, voice, dm, guild }
        let id: String
        let kind: Kind
        let title: String
        let subtitle: String?
        let iconURL: URL?
        let monogram: String?
        let go: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider().overlay(.white.opacity(0.08))
            results
                // Explicit height — a ScrollView inside a fitting VStack otherwise
                // collapses to zero, which is why results never appeared.
                .frame(height: resultsHeight)
        }
        .frame(width: 560)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.6)),
                     in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 16)
    }

    private var resultsHeight: CGFloat {
        let count = filtered.isEmpty ? 1 : filtered.count
        return min(CGFloat(count) * 44 + 16, 380)
    }

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiscordColor.textMuted)
            QuickSwitcherField(
                text: $query,
                onUp: { move(-1) },
                onDown: { move(1) },
                onReturn: { activate() },
                onEscape: { isPresented = false }
            )
            .frame(height: 26)
            .onChange(of: query) { _, _ in selection = 0 }
        }
        .padding(18)
    }

    @ViewBuilder
    private var results: some View {
        if filtered.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(DiscordColor.textFaint)
                Text(query.isEmpty ? "Start typing to jump anywhere" : "No matches for “\(query)”")
                    .font(.system(size: 13))
                    .foregroundStyle(DiscordColor.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, item in
                            row(item, selected: i == selection)
                                .id(i)
                                .contentShape(.rect)
                                .onTapGesture { selection = i; activate() }
                                .onHover { if $0 { selection = i } }
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.never)
                .onChange(of: selection) { _, new in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 12) {
            icon(item)
                .frame(width: 28, height: 28)
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? .white : DiscordColor.headerPrimary)
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? .white.opacity(0.8) : DiscordColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(kindLabel(item.kind))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .white.opacity(0.7) : DiscordColor.textFaint)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(selected ? DiscordColor.blurple : Color.clear, in: .rect(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func icon(_ item: Item) -> some View {
        switch item.kind {
        case .guild, .dm:
            if let url = item.iconURL {
                CachedAsyncImage(url: url, content: { $0.resizable().scaledToFill() },
                                 placeholder: { monogramTile(item) })
                    .clipShape(item.kind == .dm ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 9, style: .continuous)))
            } else {
                monogramTile(item)
            }
        case .channel:
            glyph("number")
        case .voice:
            glyph("speaker.wave.2.fill")
        }
    }

    private func monogramTile(_ item: Item) -> some View {
        ZStack {
            DiscordColor.bgSecondary
            Text(item.monogram ?? String(item.title.prefix(1)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DiscordColor.headerSecondary)
        }
        .clipShape(item.kind == .dm ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 9, style: .continuous)))
    }

    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16))
            .foregroundStyle(DiscordColor.channelIcon)
    }

    private func kindLabel(_ kind: Item.Kind) -> String {
        switch kind { case .channel: "Channel"; case .voice: "Voice"; case .dm: "DM"; case .guild: "Server" }
    }

    // MARK: Index + filtering

    /// Filtered live from the reactive index (no @State / onAppear timing).
    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = buildIndex()
        guard !q.isEmpty else { return Array(all.prefix(40)) }
        return all
            .filter { $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false) }
            .prefix(40)
            .map { $0 }
    }

    private func buildIndex() -> [Item] {
        var all: [Item] = []
        for guildID in app.guildOrder {
            guard let store = app.guildStores[guildID] else { continue }
            let guildName = store.meta.name
            for channel in store.channels.values where channel.type.isTextLike || channel.type.isVoice {
                all.append(Item(
                    id: "ch-\(channel.id.rawValue)",
                    kind: channel.type.isVoice ? .voice : .channel,
                    title: channel.name ?? "channel",
                    subtitle: guildName,
                    iconURL: nil, monogram: nil,
                    go: { app.selectedGuildID = guildID; Task { await app.selectChannel(channel.id) } }
                ))
            }
        }
        for dm in app.dms {
            all.append(Item(
                id: "dm-\(dm.id.rawValue)",
                kind: .dm,
                title: dm.displayName(currentUserID: app.currentUser?.id),
                subtitle: "Direct Message",
                iconURL: dm.iconURL(currentUserID: app.currentUser?.id, size: 64)
                    ?? dm.recipients?.first?.avatarURL(size: 64),
                monogram: nil,
                go: { app.selectGuild(nil); Task { await app.selectChannel(dm.id) } }
            ))
        }
        for guild in app.orderedGuilds {
            all.append(Item(
                id: "g-\(guild.id.rawValue)",
                kind: .guild,
                title: guild.name,
                subtitle: "Server",
                iconURL: guild.iconURL(size: 64),
                monogram: guild.acronym,
                go: { app.selectGuild(guild.id) }
            ))
        }
        return all
    }

    private func move(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = (selection + delta + count) % count
    }

    private func activate() {
        let list = filtered
        guard list.indices.contains(selection) else { return }
        list[selection].go()
        isPresented = false
    }
}
