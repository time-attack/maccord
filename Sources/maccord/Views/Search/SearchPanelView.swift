import SwiftUI
import MaccordCore

/// The Discord-style search panel (sheet): a focused search field, filter chips
/// (has / pinned), and results you can click to jump to.
struct SearchPanelView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query: String
    @State private var has: String? = nil
    @State private var pinnedOnly = false
    @State private var results: [Message] = []
    @State private var loading = false
    @State private var searched = false

    init(seed: String) { _query = State(initialValue: seed) }

    private let hasOptions: [(String, String?)] = [
        ("Any", nil), ("Links", "link"), ("Images", "image"),
        ("Files", "file"), ("Embeds", "embed"), ("Videos", "video"),
    ]

    private var filters: SearchFilters {
        var f = SearchFilters()
        f.has = has
        f.pinned = pinnedOnly ? true : nil
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DiscordColor.divider)
            filterBar
            Divider().overlay(DiscordColor.divider)
            resultsArea
        }
        .frame(width: 620, height: 560)
        .glassEffect(.regular.tint(DiscordColor.bgFloating.opacity(0.65)),
                     in: .rect(cornerRadius: 14, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(DiscordColor.textMuted)
            QuickSwitcherField(text: $query, onReturn: runSearch, onEscape: { dismiss() })
                .frame(height: 24)
            Button("Search", action: runSearch)
                .buttonStyle(.borderedProminent).tint(DiscordColor.blurple)
            Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
        }
        .padding(14)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(hasOptions, id: \.0) { opt in
                    Button { has = opt.1; runSearch() } label: {
                        if has == opt.1 { Label(opt.0, systemImage: "checkmark") } else { Text(opt.0) }
                    }
                }
            } label: {
                Label("Has: \(hasOptions.first { $0.1 == has }?.0 ?? "Any")", systemImage: "paperclip")
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Toggle(isOn: $pinnedOnly) { Label("Pinned", systemImage: "pin.fill").font(.system(size: 12)) }
                .toggleStyle(.button)
                .tint(DiscordColor.blurple)
                .onChange(of: pinnedOnly) { _, _ in runSearch() }

            Spacer()
            Text(app.selectedGuildStore?.meta.name ?? "This channel")
                .font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    @ViewBuilder
    private var resultsArea: some View {
        if loading {
            centered { ProgressView().controlSize(.small) }
        } else if !searched {
            centered {
                Text("Search messages — type a query and press Return.")
                    .font(.system(size: 13)).foregroundStyle(DiscordColor.textMuted)
            }
        } else if results.isEmpty {
            centered {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 30)).foregroundStyle(DiscordColor.textFaint)
                    Text("No results found").font(.system(size: 14, weight: .semibold)).foregroundStyle(DiscordColor.headerSecondary)
                    Text("Try different keywords or filters.").font(.system(size: 12)).foregroundStyle(DiscordColor.textMuted)
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    Text("\(results.count) RESULTS").font(.system(size: 11, weight: .bold)).tracking(0.4)
                        .foregroundStyle(DiscordColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(results) { resultRow($0) }
                }
                .padding(14)
            }
        }
    }

    private func resultRow(_ msg: Message) -> some View {
        Button {
            if let gid = msg.guildID { app.selectedGuildID = gid }
            Task { await app.selectChannel(msg.channelID) }
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(url: msg.author.avatarURL(size: 48), fallbackText: msg.author.displayName, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(msg.author.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(DiscordColor.headerPrimary)
                        if let n = app.channelsByID[msg.channelID]?.name { Text("#\(n)").font(.system(size: 11)).foregroundStyle(DiscordColor.textMuted) }
                        Spacer(minLength: 0)
                        Text(msg.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(DiscordColor.textFaint)
                    }
                    Text(msg.content.isEmpty ? "(attachment)" : msg.content).font(.system(size: 14)).foregroundStyle(DiscordColor.textNormal).lineLimit(3).multilineTextAlignment(.leading)
                }
            }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(DiscordColor.bgSecondary, in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        searched = true
        loading = true
        Task {
            let r = await app.search(query, filters: filters)
            results = r
            loading = false
        }
    }

    private func centered<V: View>(@ViewBuilder _ c: () -> V) -> some View {
        VStack { Spacer(); c(); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
