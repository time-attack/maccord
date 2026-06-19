import SwiftUI
import MaccordCore

/// A real Discord-style emoji picker: search field, category rail, a scrolling
/// grid of unicode emoji, and the current server's custom emoji on top. Calls
/// `onPick` with a `MaccordCore.Emoji` (unicode → name is the char; custom → id+name).
struct EmojiPickerView: View {
    var onPick: (Emoji) -> Void

    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var activeCategory = "custom"

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 4), count: 9)

    private struct TaggedEmoji: Identifiable {
        let emoji: Emoji
        let guildID: Snowflake
        var id: String {
            let emojiKey = emoji.id.map(String.init(describing:)) ?? (emoji.name ?? "")
            return "\(guildID.rawValue)-\(emojiKey)"
        }
    }

    /// Custom emoji the user is allowed to use in the current channel.
    private var allowedCustomEmoji: [TaggedEmoji] {
        guard let channelID = app.selectedChannelID else { return [] }
        var seen = Set<UInt64>()
        var result: [TaggedEmoji] = []
        func add(_ store: GuildStore?, guildID: Snowflake) {
            guard let store else { return }
            for e in store.meta.emojis where e.id != nil && (e.available ?? true) {
                guard app.canUseEmoji(e, fromGuild: guildID, in: channelID) else { continue }
                if let id = e.id?.rawValue, seen.insert(id).inserted {
                    result.append(TaggedEmoji(emoji: e, guildID: guildID))
                }
            }
        }
        // Current server first, then others (external emojis when permitted).
        if let gid = app.selectedGuildID { add(app.guildStores[gid], guildID: gid) }
        for (gid, store) in app.guildStores where gid != app.selectedGuildID {
            add(store, guildID: gid)
        }
        return result
    }

    private var canUseExternal: Bool {
        guard let id = app.selectedChannelID else { return true }
        return app.canUseExternalEmojis(in: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !canUseExternal && app.selectedGuildID != nil {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 11))
                    Text("External emoji require permission in this channel.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(DiscordColor.textMuted)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            Divider().overlay(DiscordColor.divider)
            HStack(spacing: 0) {
                categoryRail
                Divider().overlay(DiscordColor.divider)
                grid
            }
        }
        .frame(width: 380, height: 400)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.7)),
                     in: .rect(cornerRadius: 12, style: .continuous))
        .onAppear {
            if allowedCustomEmoji.isEmpty { activeCategory = EmojiCatalog.categories.first?.id ?? "smileys" }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(DiscordColor.textMuted)
            TextField("Search emoji", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(DiscordColor.textNormal)
        }
        .padding(10)
    }

    private var categoryRail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                if !allowedCustomEmoji.isEmpty {
                    railButton(id: "custom", symbol: "face.smiling.inverse")
                }
                ForEach(EmojiCatalog.categories) { cat in
                    railButton(id: cat.id, symbol: cat.symbol)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 40)
    }

    private func railButton(id: String, symbol: String) -> some View {
        Button { activeCategory = id; query = "" } label: {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(activeCategory == id ? DiscordColor.interactiveActive : DiscordColor.interactiveNormal)
                .frame(width: 30, height: 30)
                .background(activeCategory == id ? DiscordColor.channelSelected : .clear,
                           in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                if !query.isEmpty {
                    ForEach(allowedCustomEmoji.filter {
                        ($0.emoji.name ?? "").lowercased().contains(query.lowercased())
                    }) { tagged in customCell(tagged.emoji, guildID: tagged.guildID) }
                    ForEach(EmojiCatalog.search(query)) { unicodeCell($0) }
                } else if activeCategory == "custom" {
                    if allowedCustomEmoji.isEmpty {
                        Text("No custom emoji available")
                            .font(.system(size: 12))
                            .foregroundStyle(DiscordColor.textMuted)
                            .gridCellColumns(9)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(allowedCustomEmoji) { tagged in customCell(tagged.emoji, guildID: tagged.guildID) }
                    }
                } else if let cat = EmojiCatalog.categories.first(where: { $0.id == activeCategory }) {
                    ForEach(cat.entries) { unicodeCell($0) }
                }
            }
            .padding(8)
        }
    }

    private func unicodeCell(_ entry: EmojiCatalog.Entry) -> some View {
        Button {
            onPick(Emoji(name: entry.char))
        } label: {
            Text(entry.char).font(.system(size: 22))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .help(entry.name)
    }

    private func customCell(_ emoji: Emoji, guildID: Snowflake) -> some View {
        Button { onPick(emoji) } label: {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: emoji.imageURL(size: 48),
                                 content: { $0.resizable().scaledToFit() },
                                 placeholder: { Color.clear })
                    .frame(width: 24, height: 24)
                    .frame(width: 34, height: 34)
                if guildID != app.selectedGuildID {
                    Image(systemName: "globe")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(DiscordColor.blurple, in: .circle)
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .help(emoji.name ?? "")
    }
}
