import Foundation
import Dispatch
import MaccordCore

/// Process entry point. Normally launches the SwiftUI app, but when
/// `MACCORD_PROBE` is set it drives the real `AppState` (bootstrap → establish →
/// gateway → event pump) headlessly so the full app logic can be diagnosed
/// without a display. Requires `MACCORD_TOKEN`; logs to `MACCORD_LOG_FILE`.
@main
struct AppEntry {
    static func main() {
        FontRegistrar.registerBundledFonts()
        if ProcessInfo.processInfo.environment["MACCORD_PROBE"] != nil {
            Task { @MainActor in
                await runProbe()
                exit(0)
            }
            dispatchMain()   // service the main queue so @MainActor work runs
        }
        MaccordApp.main()
    }

    @MainActor
    private static func runProbe() async {
        func log(_ s: String) {
            MaccordLog.log("PROBE \(s)")
            FileHandle.standardError.write(Data("PROBE \(s)\n".utf8))
        }
        log("driving real AppState; bundle=\(Bundle.main.bundleIdentifier ?? "nil")")

        let app = AppState()
        await app.bootstrap()   // picks up the MACCORD_TOKEN override
        // Simulate a second restored window firing .task again — must be a no-op.
        await app.bootstrap()

        // Poll the observable connection state for 5s, exactly what the UI shows.
        for _ in 0..<10 {
            log("phase=\(app.phase) connection=\(app.connection) guilds=\(app.guildOrder.count) selected=\(app.selectedChannelID != nil)")
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        // Drive the quick-switcher index exactly as the UI does, and report what it
        // would show — so search can be verified without a display.
        app.hydrateGuildsForSearch()
        for i in 0..<14 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let base = SearchIndex(app: app).containers()
            let kinds = Dictionary(grouping: base, by: { "\($0.kind)" }).mapValues(\.count)
            log("SEARCHIDX[\(i)] guilds=\(app.guildOrder.count) channelsByID=\(app.channelsByID.count) indexable=\(app.indexableChannelCount) dms=\(app.dms.count) friends=\(app.friends.count) baseCount=\(base.count) kinds=\(kinds)")
        }
        for term in ["general", "chat", "bot", "a"] {
            let needle = term.lowercased()
            let hits = SearchIndex(app: app).containers()
                .compactMap { r in r.matchScore(needle).map { (r, $0) } }
                .sorted { $0.1 < $1.1 }
                .prefix(6)
                .map(\.0.title)
            log("SEARCHQ[\(term)] -> \(hits.count) shown, top=[\(hits.joined(separator: " | "))]")
        }
        log("probe finished")
    }
}
