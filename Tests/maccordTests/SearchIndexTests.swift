import Testing
import Foundation
@testable import maccord
@testable import MaccordCore

/// Proves the ⌘K search index: that loaded channels are findable, that channels
/// the viewer can't see are filtered out (the "showing hidden channels" bug), and
/// that the fuzzy ranker orders matches sensibly.
@MainActor
@Suite("Quick switcher search index")
struct SearchIndexTests {

    // MARK: Fixtures

    private static let guildID = Snowflake(800)
    private static let meID = Snowflake(700)
    private static let viewChannel = Permissions(rawValue: 1 << 10)

    /// An AppState with one server: a public "#general" and a "#secret-admin"
    /// channel hidden from @everyone. `memberLoaded` controls whether our member
    /// roles are known (the visibility filter fails open until they are).
    private func makeApp(memberLoaded: Bool) -> AppState {
        let app = AppState()
        app.currentUser = try! DiscordCoding.makeDecoder()
            .decode(CurrentUser.self, from: Data(#"{"id":"700","username":"me","discriminator":"0"}"#.utf8))

        let everyone = Role(id: Self.guildID, name: "@everyone", permissions: Self.viewChannel)
        let general = Channel(id: Snowflake(901), type: .text, guildID: Self.guildID, name: "general")
        let secret = Channel(
            id: Snowflake(902), type: .text, guildID: Self.guildID, name: "secret-admin",
            permissionOverwrites: [PermissionOverwrite(
                id: Self.guildID, type: 0,
                allow: Permissions(rawValue: 0), deny: Self.viewChannel
            )]
        )
        let guild = Guild(id: Self.guildID, name: "Game Dev", roles: [everyone],
                          channels: [general, secret])
        app.guildStores[Self.guildID] = GuildStore(guild: guild)
        app.guildOrder = [Self.guildID]
        app.channelsByID[general.id] = general
        app.channelsByID[secret.id] = secret
        if memberLoaded {
            app.myMembers[Self.guildID] = Member(user: User(id: Self.meID, username: "me"), roles: [])
        }
        return app
    }

    // MARK: Index

    @Test func indexesLoadedChannels() {
        let app = makeApp(memberLoaded: true)
        let titles = SearchIndex(app: app).containers().map(\.title)
        #expect(titles.contains("general"))
        #expect(titles.contains("Game Dev"))   // the server itself is searchable
    }

    @Test func hidesChannelsTheViewerCannotSee() {
        let app = makeApp(memberLoaded: true)
        let titles = SearchIndex(app: app).containers().map(\.title)
        #expect(!titles.contains("secret-admin"))   // denied VIEW_CHANNEL → filtered
    }

    @Test func failsOpenBeforeMemberRolesLoad() {
        // Until we know the viewer's roles, nothing is hidden on a guess.
        let app = makeApp(memberLoaded: false)
        let titles = SearchIndex(app: app).containers().map(\.title)
        #expect(titles.contains("secret-admin"))
    }

    @Test func findsChannelByTypedQuery() {
        let app = makeApp(memberLoaded: true)
        let hits = SearchIndex(app: app).containers()
            .filter { $0.matchScore("gen") != nil }
            .map(\.title)
        #expect(hits.contains("general"))
    }

    @Test func findsChannelByServerName() {
        // A channel is findable by its server name (server is in `keywords`).
        let app = makeApp(memberLoaded: true)
        let general = SearchIndex(app: app).containers().first { $0.title == "general" }!
        #expect(general.matchScore("game dev") != nil)
    }

    @Test func serverMatchesIgnoringSpaces() {
        // "gamedev" (no space) must find a server named "Game Dev".
        let app = makeApp(memberLoaded: true)
        let server = SearchIndex(app: app).containers().first { $0.kind == .server }!
        #expect(server.title == "Game Dev")
        #expect(server.matchScore("gamedev") != nil)   // space-insensitive tier
        #expect(server.matchScore("game") == 1)            // prefix
    }

    // MARK: Match scoring (simple: exact < prefix < substring < keyword)

    @Test func matchScoreTiers() {
        let app = makeApp(memberLoaded: true)
        let general = SearchIndex(app: app).containers().first { $0.title == "general" }!
        #expect(general.matchScore("general") == 0)   // exact title
        #expect(general.matchScore("gen") == 1)        // title prefix
        #expect(general.matchScore("ral") == 2)        // title substring
        #expect(general.matchScore("zzz") == nil)      // no match
    }

    // MARK: Navigation (each result opens its OWN target — no cross-wiring)

    @Test func channelResultTargetsItsOwnGuild() {
        let app = makeApp(memberLoaded: true)
        let general = SearchIndex(app: app).containers().first { $0.title == "general" }!
        general.navigate()
        #expect(app.selectedGuildID == Self.guildID)
    }

    @Test func serverResultSelectsThatServer() {
        let app = makeApp(memberLoaded: true)
        app.selectedGuildID = nil
        let server = SearchIndex(app: app).containers().first { $0.kind == .server }!
        server.navigate()
        #expect(app.selectedGuildID == Self.guildID)
    }
}
