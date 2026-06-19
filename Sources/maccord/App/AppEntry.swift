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

        // Poll the observable connection state for 30s, exactly what the UI shows.
        for _ in 0..<20 {
            log("phase=\(app.phase) connection=\(app.connection) guilds=\(app.guildOrder.count) selected=\(app.selectedChannelID != nil)")
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        log("probe finished")
    }
}
