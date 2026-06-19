import SwiftUI
import MaccordCore

/// An uppercase, letter-tracked section header that groups members by role or by
/// online/offline status (e.g. "ADMIN — 3", "ONLINE — 12").
struct MemberSectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .categoryHeaderStyle()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Layout.memberSectionHeaderHeight, alignment: .bottom)
            .padding(.top, 16)
            .padding(.horizontal, Layout.channelRowInset)
            .padding(.bottom, 4)
    }
}
