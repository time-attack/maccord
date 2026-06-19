import Testing
import Foundation
@testable import MaccordCore

/// Opt-in live integration test. Skipped unless `MACCORD_TEST_TOKEN` is set, so
/// normal `swift test` / CI never needs a token or the network.
@Suite("GatewayLive")
struct GatewayLiveTests {

    /// Collects results race-free across the consumer task and the waiter.
    actor Probe {
        var reachedReady = false
        var readyUser: String?
        var guildCount = 0
        var states: [String] = []
        var lastFatal: String?

        func note(state: GatewayConnectionState) {
            states.append("\(state)")
            if case .fatal(let m) = state { lastFatal = m }
        }
        func markReady(user: String, guilds: Int) {
            reachedReady = true; readyUser = user; guildCount = guilds
        }
        func bumpGuild() { guildCount += 1 }
    }

    @Test func botOrUserConnectsAndReachesReady() async throws {
        guard let token = ProcessInfo.processInfo.environment["MACCORD_TEST_TOKEN"],
              !token.isEmpty else {
            print("[live] MACCORD_TEST_TOKEN not set — skipping live gateway test")
            return
        }

        let rest = RESTClient()
        let auth = try await rest.authenticate(token: token)
        print("[live] authenticated as \(auth.user.username) (mode: \(auth.mode.rawValue))")

        let intents: Int? = auth.mode == .bot ? await rest.recommendedBotIntents() : nil
        if let intents { print("[live] requesting intents bitfield: \(intents)") }

        let probe = Probe()
        let gateway = GatewaySocket()

        let consumer = Task {
            for await event in gateway.events {
                switch event {
                case .connectionState(let s):
                    await probe.note(state: s)
                    print("[live] state → \(s)")
                case .ready(let r):
                    await probe.markReady(user: r.user.username, guilds: r.guilds.count)
                    print("[live] READY ✅ user=\(r.user.username) guilds(in payload)=\(r.guilds.count)")
                case .guildCreate(let g):
                    await probe.bumpGuild()
                    print("[live] GUILD_CREATE: \(g.name) (#channels=\(g.channels.count))")
                case .messageCreate(let m):
                    print("[live] MESSAGE_CREATE in \(m.channelID): \(m.content.prefix(60))")
                default:
                    break
                }
            }
        }

        await gateway.connect(
            token: token,
            superProperties: SuperProperties(),
            capabilities: 0,
            botIntents: intents
        )

        // Watch for ~70s — long enough to cross at least one heartbeat interval
        // (~41s) so a post-READY zombie/reconnect loop would surface here.
        let deadline = Date().addingTimeInterval(70)
        var readyAt: Date?
        while Date() < deadline {
            if readyAt == nil, await probe.reachedReady {
                readyAt = Date()
                print("[live] reached READY — now watching \(Int(deadline.timeIntervalSinceNow))s for any reconnect…")
            }
            if let fatal = await probe.lastFatal {
                Issue.record("Gateway fatal: \(fatal)")
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        let ready = await probe.reachedReady
        // Did the connection drop back into reconnecting/resuming AFTER it was ready?
        let states = await probe.states
        if let firstReadyIdx = states.firstIndex(of: "ready") {
            let after = states[(firstReadyIdx + 1)...]
            let reconnectedAfterReady = after.contains { $0.contains("reconnect") || $0.contains("resum") }
            print("[live] post-READY states: \(after.isEmpty ? "(none — stayed connected ✅)" : after.joined(separator: " → "))")
            #expect(!reconnectedAfterReady, "Gateway dropped/reconnected after READY (heartbeat zombie?)")
        }

        // Prove we can actually READ guild data + message history over REST.
        if ready {
            if let guilds = try? await rest.getMyGuilds() {
                print("[live] REST guilds: \(guilds.map(\.name))")
                if let g = guilds.first, let channels = try? await rest.getGuildChannels(g.id) {
                    let textChannels = channels.filter { $0.type == .text }
                    print("[live] \(g.name): \(channels.count) channels (\(textChannels.count) text)")
                    for ch in textChannels.prefix(5) {
                        if let msgs = try? await rest.getMessages(channelID: ch.id, limit: 3), !msgs.isEmpty {
                            print("[live] #\(ch.name ?? "?") — last \(msgs.count) messages:")
                            for m in msgs.prefix(3) {
                                let body = m.content.isEmpty ? "(no text / embed or attachment)" : m.content
                                print("   • \(m.author.username): \(body.prefix(80))")
                            }
                            break
                        }
                    }
                }
            }
        }

        consumer.cancel()
        await gateway.disconnect()

        print("[live] full connection-state trace: \(states.joined(separator: " → "))")
        #expect(ready, "Gateway should reach READY for a valid token")
    }
}
