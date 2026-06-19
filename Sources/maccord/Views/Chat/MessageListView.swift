import SwiftUI
import MaccordCore

/// The scrolling message list. Applies Discord's grouping rules (same-author
/// collapse within 7 minutes), inserts date dividers between calendar days,
/// loads older pages when the user scrolls to the top, and stays pinned to the
/// newest message as content grows.
struct MessageListView: View {
    @Environment(AppState.self) private var app
    let store: MessageStore
    var onReply: (Message) -> Void = { _ in }

    @State private var scrolledUp = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    topLoadingArea

                    ForEach(rows) { row in
                        rowView(row)
                            .id(row.id)
                    }

                    Color.clear
                        .frame(height: 24)
                        .id(Self.bottomAnchor)
                }
                .scrollTargetLayout()
            }
            .defaultScrollAnchor(.bottom)
            .scrollContentBackground(.hidden)
            .background(DiscordColor.panelChat)
            // Track whether we're scrolled away from the bottom (for jump-to-present).
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y < geo.contentSize.height - geo.containerSize.height - 240
            } action: { _, up in
                scrolledUp = up
            }
            .overlay(alignment: .bottom) {
                if scrolledUp { jumpToPresent(proxy) }
            }
            .task(id: store.channelID) {
                await store.loadInitialIfNeeded()
            }
            .onChange(of: store.messages.last?.id) { _, _ in
                // Keep pinned to newest as fresh messages arrive (unless reading up).
                if !scrolledUp { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            }
            .onChange(of: scrolledUp) { _, up in
                if !up { app.acknowledgeVisibleRead(in: store.channelID) }
            }
            .onAppear {
                app.acknowledgeVisibleRead(in: store.channelID)
            }
            .onChange(of: app.scrollToMessageID) { _, target in
                guard let target else { return }
                Task { await scrollToTarget(target, proxy: proxy) }
            }
        }
    }

    /// Scroll a jumped-to message into view, waiting for it to be loaded/laid out
    /// first (a pin/search jump may still be merging a fetched `around` window).
    @MainActor
    private func scrollToTarget(_ target: Snowflake, proxy: ScrollViewProxy) async {
        for _ in 0..<12 {
            if store.messages.contains(where: { $0.id == target }) { break }
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
        try? await Task.sleep(nanoseconds: 60_000_000)  // let the LazyVStack lay out
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo("msg-\(target.rawValue)", anchor: .center)
        }
        app.scrollToMessageID = nil
    }

    private func jumpToPresent(_ proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        } label: {
            HStack(spacing: 6) {
                Text("Jump to Present")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(DiscordColor.blurple).interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .padding(.trailing, Layout.messageHGutter)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: Top area (spinner / error / load-older trigger)

    @ViewBuilder
    private var topLoadingArea: some View {
        if let error = store.loadError {
            HStack {
                Spacer()
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(DiscordColor.dangerRed)
                Spacer()
            }
            .padding(.vertical, 12)
        } else if store.isLoadingOlder {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            }
            .padding(.vertical, 12)
        } else if store.hasMoreBefore {
            // Invisible sentinel; loading older history when it scrolls into view.
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task { await store.loadOlder() }
                }
        } else {
            channelStart
        }
    }

    /// The "beginning of the channel" header shown once all history is loaded.
    private var channelStart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(DiscordColor.headerPrimary)
                .padding(12)
                .background(DiscordColor.bgModifierHover)
                .clipShape(.circle)
            Text("Welcome to the beginning of this channel.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DiscordColor.textMuted)
        }
        .padding(.horizontal, Layout.messageHGutter)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Row model

    private static let bottomAnchor = "bottom-anchor"

    private enum Row: Identifiable {
        case dateDivider(Date)
        case unreadDivider
        case message(Message, grouped: Bool)

        var id: String {
            switch self {
            case .dateDivider(let date): return "date-\(date.timeIntervalSince1970)"
            case .unreadDivider: return "unread-divider"
            case .message(let m, _): return "msg-\(m.id.rawValue)"
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .dateDivider(let date):
            DateDividerView(date: date)
        case .unreadDivider:
            UnreadDividerView()
        case .message(let message, let grouped):
            MessageRowView(message: message, isGrouped: grouped, onReply: onReply)
        }
    }

    /// Compute grouping + date dividers in a single pass over the messages.
    private var rows: [Row] {
        let messages = store.messages
        var rows: [Row] = []
        let cal = Calendar.current
        let gap = TimeInterval(Layout.messageGroupGapMinutes * 60)
        let unreadBoundary = app.unreadBoundaries[store.channelID]
        var insertedUnread = false

        var previous: Message?
        for message in messages {
            var startsNewDay = false
            if let previous {
                if !cal.isDate(previous.timestamp, inSameDayAs: message.timestamp) {
                    startsNewDay = true
                }
            }
            if startsNewDay {
                rows.append(.dateDivider(message.timestamp))
            }

            // The NEW divider sits before the first message newer than where we left off.
            if !insertedUnread, let boundary = unreadBoundary, message.id > boundary {
                rows.append(.unreadDivider)
                insertedUnread = true
            }

            let grouped: Bool
            if let previous, !startsNewDay, !(rows.last.map { if case .unreadDivider = $0 { return true } else { return false } } ?? false) {
                grouped = previous.author.id == message.author.id
                    && !message.isReply
                    && !message.type.isSystem
                    && !previous.type.isSystem
                    && message.timestamp.timeIntervalSince(previous.timestamp) < gap
            } else {
                grouped = false
            }

            rows.append(.message(message, grouped: grouped))
            previous = message
        }
        return rows
    }
}
