import SwiftUI
import MaccordCore

/// The 240pt right-hand member list. Renders the flat, op14-driven rows from
/// `app.members`: section headers (role names or ONLINE/OFFLINE) interleaved with
/// member rows. Shown only when a guild text channel is selected.
public struct MemberListView: View {
    @Environment(AppState.self) private var app

    public init() {}

    public var body: some View {
        let rows = app.members.rows

        let counts = liveCounts(rows)

        return Group {
            if rows.isEmpty {
                emptyPlaceholder
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            switch row {
                            case .header(_, let group):
                                MemberSectionHeaderView(
                                    title: "\(headerName(for: group)) — \(counts[index] ?? group.count)"
                                )
                            case .member(let entry):
                                MemberRowView(entry: entry)
                            }
                        }
                        // Load the next member window when scrolled to the bottom.
                        Color.clear.frame(height: 1)
                            .onAppear { Task { await app.extendMemberList() } }
                    }
                    .padding(.bottom, 8)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: Layout.memberListWidth)
        .frame(maxHeight: .infinity)
        .background(DiscordColor.panelMembers)
    }

    /// Live count of members under each header (header row index → member count),
    /// computed from the actual rows so it always matches what's shown.
    private func liveCounts(_ rows: [MemberStore.Row]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        var currentHeader: Int?
        for (index, row) in rows.enumerated() {
            switch row {
            case .header:
                currentHeader = index
                counts[index] = 0
            case .member:
                if let h = currentHeader { counts[h, default: 0] += 1 }
            }
        }
        return counts
    }

    private var emptyPlaceholder: some View {
        VStack {
            Spacer()
            Text("No members")
                .font(DiscordFont.memberName)
                .foregroundStyle(DiscordColor.textFaint)
                .opacity(0.5)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// Resolve a group's label: literal ONLINE/OFFLINE, otherwise the role name
    /// looked up by snowflake id (group ids may be non-numeric).
    private func headerName(for group: MemberListGroup) -> String {
        switch group.id {
        case "online": return "Online"
        case "offline": return "Offline"
        default:
            if let snowflake = Snowflake(string: group.id),
               let role = app.selectedGuildStore?.role(snowflake) {
                return role.name
            }
            return group.id
        }
    }
}
