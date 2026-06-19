import SwiftUI
import MaccordCore

/// Live @ / # / : autocomplete above the composer.
struct ComposerAutocompleteView: View {
    @Environment(AppState.self) private var app

    let kind: Kind
    let query: String
    var onPick: (String) -> Void

    enum Kind { case mention, channel, emoji }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entries, id: \.key) { entry in
                    Button { onPick(entry.insert) } label: {
                        HStack(spacing: 8) {
                            if let url = entry.iconURL {
                                CachedAsyncImage(url: url, content: { $0.resizable().scaledToFill() },
                                                 placeholder: { Color.clear })
                                    .frame(width: 24, height: 24).clipShape(.circle)
                            } else if let symbol = entry.symbol {
                                Image(systemName: symbol).frame(width: 24)
                            }
                            Text(entry.label).font(.system(size: 14)).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10).frame(height: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 280, height: min(220, CGFloat(entries.count) * 34 + 8))
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.85)),
                     in: .rect(cornerRadius: 8, style: .continuous))
    }

    private struct Entry {
        let key: String
        let label: String
        let insert: String
        let iconURL: URL?
        let symbol: String?
    }

    private var entries: [Entry] {
        let q = query.lowercased()
        switch kind {
        case .mention:
            return app.members.rows.compactMap { row -> Entry? in
                guard case .member(let entry) = row, let user = entry.member.user else { return nil }
                let name = entry.member.displayName
                guard q.isEmpty || name.lowercased().contains(q) else { return nil }
                return Entry(key: user.id.description, label: name,
                             insert: "<@\(user.id.rawValue)>", iconURL: user.avatarURL(size: 64), symbol: nil)
            }.prefix(8).map { $0 }
        case .channel:
            guard let store = app.selectedGuildStore else { return [] }
            return store.channels.values
                .filter { $0.type.isTextLike && (q.isEmpty || ($0.name ?? "").lowercased().contains(q)) }
                .prefix(8)
                .map { ch in
                    Entry(key: ch.id.description, label: "#\(ch.name ?? "channel")",
                          insert: "<#\(ch.id.rawValue)>", iconURL: nil, symbol: "number")
                }
        case .emoji:
            var list: [Entry] = []
            if let gid = app.selectedGuildID, let store = app.guildStores[gid] {
                for e in store.meta.emojis where (e.name ?? "").lowercased().contains(q) {
                    guard let id = e.id else { continue }
                    list.append(Entry(key: id.description, label: ":\(e.name ?? ""):",
                                      insert: "<\(e.isAnimated ? "a" : ""):\(e.name ?? ""):\(id.rawValue)>",
                                      iconURL: e.imageURL(size: 48), symbol: nil))
                }
            }
            for cat in EmojiCatalog.categories {
                for e in cat.entries where q.isEmpty || e.name.lowercased().contains(q) {
                    list.append(Entry(key: e.char, label: e.name, insert: e.char, iconURL: nil, symbol: nil))
                }
            }
            return Array(list.prefix(8))
        }
    }
}
