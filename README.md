# maccord

A **native macOS Discord client** — not a clone, a real *client* you log into with
your own Discord token. Written from scratch in **Swift 6 + SwiftUI** with
**Liquid Glass** (macOS 26 Tahoe). It speaks the Discord v10 REST + Gateway wire
protocols directly, renders the familiar 4-pane Discord dark-theme UI
pixel-for-pixel, and feels Mac-native (no Electron, low RAM).

> [!WARNING]
> Logging into Discord with a **user token** from a non-official client
> ("self-botting") violates Discord's Terms of Service and can get your account
> terminated. maccord stores your token only in the macOS **Keychain** and sends
> it only to Discord over TLS. Use at your own risk. The same networking layer
> works with a **bot token** too if you prefer to stay within ToS.

## Requirements

- macOS **26.0+** (Tahoe) — Liquid Glass APIs are used unconditionally
- Xcode **26.x** / Swift **6.x**

## Build & run

```bash
# Compile + test the core
swift build
swift test

# Assemble a runnable .app bundle (ad-hoc signed, Keychain entitlement)
scripts/build-app.sh release
open dist/maccord.app
```

You can also open `Package.swift` in Xcode and run the `maccord` scheme.

On first launch, paste your Discord token into the login screen. It is saved to
the Keychain so subsequent launches connect automatically.

## Architecture

A thin SwiftUI app target (`maccord`) over a Foundation-only core library
(`MaccordCore`). Full design notes live in [`ARCHITECTURE.md`](ARCHITECTURE.md).

```
Sources/
  MaccordCore/            # Foundation only — unit-testable, no UI
    Models/               # Codable Discord types (Snowflake, Guild, Message, …)
    Networking/           # actor RESTClient + typed v10 endpoints + rate limiter
    Gateway/              # actor GatewaySocket — WebSocket, heartbeat, resume,
                          #   typed AsyncStream<GatewayEvent>
    Persistence/          # actor KeychainStore + TokenStore
  maccord/                # SwiftUI app
    State/                # @MainActor @Observable stores + EventApplier
    DesignSystem/         # Discord color/layout/type tokens, Liquid Glass, markdown
    Views/                # GuildRail · ChannelSidebar · Chat · Members · …
    Services/             # ImageCache, …
```

**Data flow:** `GatewaySocket` (actor) yields a `Sendable` `AsyncStream<GatewayEvent>`
→ a single `@MainActor` pump in `AppState` → `EventApplier` mutates the
`@Observable` stores → SwiftUI re-renders. REST calls flow into the same stores.

## Status

- **M1 — Foundation + connectivity:** ✅ models, REST, gateway (identify /
  heartbeat / resume / backoff), Keychain, read message history + live messages.
- **M2 — Interactions:** send / edit / delete / reply, reactions, typing,
  mark-read, attachments. *(in progress)*
- **M3 — Full UI parity:** server rail, channel tree, member list (op 14),
  presence, profiles, DMs, Liquid Glass chrome. *(in progress)*
- **M4 — Voice:** stubbed UI; real audio transport + DAVE E2EE is a later
  milestone (see `ARCHITECTURE.md §8/§10`).

See the parity checklist in `ARCHITECTURE.md §9`.
