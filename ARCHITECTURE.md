---

# maccord — Authoritative Architecture & Build Spec

> Single source of truth for building **maccord**: a native macOS 26 (SwiftUI, Liquid Glass) Discord *client* that logs in with a user token, looks pixel-accurate to Discord, and feels Mac-native. Build against this document.

---

## 1. Project Overview + ToS Caveat

maccord is a from-scratch, native macOS Discord client (not Electron) that authenticates with a **raw Discord user token**, talks the v10 REST + Gateway wire protocols directly, renders the 4-pane Discord UI pixel-accurately with SwiftUI + Liquid Glass, and targets a sub-100MB RAM footprint vs. Discord's 600MB+ Electron app.

> **ToS caveat:** Logging into Discord with a user token from a non-official client ("self-bot") violates Discord's Terms of Service and risks account termination — ship with this risk understood, mimic official-client headers/super-properties to reduce flag risk, and store the token only in the macOS Keychain.

---

## 2. Tech Stack & Concurrency Posture

| Concern | Choice |
|---|---|
| Language | Swift 6.3, **strict concurrency** |
| Triple | `arm64-apple-macosx26.0` |
| Min OS | **macOS 26.0** (Tahoe) — unconditional use of Liquid Glass APIs, no `#available` fallbacks |
| UI | SwiftUI + Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`), `NavigationSplitView` + `.inspector()` |
| Build | Xcode 26.5, SwiftPM for dependencies |
| Observation | `@Observable` (Observation framework) — **not** `ObservableObject`/Combine |
| Async | `async`/`await`, `actor` for I/O isolation, `AsyncStream` for event fan-out |
| Networking | `URLSession` (REST), `URLSessionWebSocketTask` (Gateway + Voice WS), `Network.framework` `NWConnection` (Voice UDP, Phase 2+) |
| Crypto (voice) | CryptoKit `AES.GCM` + libsodium (XChaCha20) — Phase 2+ |
| Codec (voice) | libopus via `alta/swift-opus` — Phase 2+ |

**Concurrency posture (the rules):**
- SwiftUI `View` bodies and all `@Observable` stores are **`@MainActor`-isolated**. Store mutation happens only on the main actor.
- `RESTClient`, `GatewaySocket`, `VoiceConnection`, `KeychainStore`, and `ImageCache` are **`actor`s**; they expose `async` APIs and own all mutable I/O state.
- All `Codable` model types are `Sendable` value types. `Message` is the one exception (a `final class` for partial-merge of `MESSAGE_UPDATE`); make it `@unchecked Sendable` with internal serialization, OR — preferred for Swift 6 cleanliness — make `Message` a `struct` and merge via a `merging(partial:)` returning a new value. **Decision: `Message` is a `struct`; merge produces a new value.** (Avoids `@unchecked` and class identity hazards under strict concurrency.)
- Gateway → store data flow: the `GatewaySocket` actor yields a `AsyncStream<GatewayEvent>`; a single long-lived `Task` owned by `AppState` (`@MainActor`) consumes it and applies deltas. The hop from socket actor to main actor is the only crossing, and `GatewayEvent` is `Sendable`.
- `glassEffectID`/`glassEffectUnion` IDs are `Hashable & Sendable` — our `Snowflake` (over `UInt64`) and `String` IDs satisfy this. `@Namespace` lives on the main-actor view.

---

## 3. Project Layout (SwiftPM workspace + app target)

Structure: a thin app target (`maccord`) plus a local SwiftPM package (`MaccordCore`) that holds everything testable/non-UI. UI lives in the app target. This lets Models/Networking/Gateway/Voice/Stores be unit-tested on CI without an app host.

```
maccord/                                    # repo root
├── Package.swift                           # local package MaccordCore
├── maccord.xcodeproj
├── README.md
├── ARCHITECTURE.md                         # this document
│
├── Sources/MaccordCore/                    # SwiftPM library target (no SwiftUI)
│   │
│   ├── Models/
│   │   ├── Snowflake.swift                 # RawRepresentable<UInt64>, string-on-wire, createdAt
│   │   ├── Codable+Helpers.swift           # NullEncodable, DecodeThrowable(s), Int+decodeFlags
│   │   ├── HashedAsset.swift               # avatar/icon hash -> CDN URL builder
│   │   ├── User.swift                      # User, CurrentUser
│   │   ├── Guild.swift                     # Guild, PreloadedGuild, GuildFeature
│   │   ├── Role.swift                      # Role, Permissions (OptionSet)
│   │   ├── Channel.swift                   # Channel, ChannelType, PermissionOverwrite
│   │   ├── Member.swift                    # Member, MemberFlags
│   │   ├── Message.swift                   # Message (struct), MessageType, MessageReference, MessageFlags
│   │   ├── Attachment.swift
│   │   ├── Embed.swift                     # Embed + EmbedFooter/Image/Thumbnail/Author/Field/Provider
│   │   ├── Reaction.swift                  # Reaction, ReactionCountDetails
│   │   ├── Emoji.swift
│   │   ├── Sticker.swift
│   │   ├── Presence.swift                  # Presence, Status, Activity, ClientStatus
│   │   ├── VoiceState.swift
│   │   ├── ReadState.swift
│   │   ├── Relationship.swift              # friends/blocked/pending
│   │   ├── UserProfile.swift              # /users/{id}/profile response
│   │   ├── AllowedMentions.swift
│   │   └── SuperProperties.swift           # the X-Super-Properties payload struct
│   │
│   ├── Networking/                         # REST
│   │   ├── RESTClient.swift                # actor: session, auth header, dispatch
│   │   ├── RESTRequest.swift               # Endpoint/Route builder, HTTPMethod
│   │   ├── RateLimiter.swift               # per-bucket token store + 429 handling
│   │   ├── RESTError.swift
│   │   ├── MultipartFormBody.swift         # file upload payload_json + files[n]
│   │   ├── REST+Users.swift                # @me, user, profile, guilds, DMs
│   │   ├── REST+Guilds.swift               # guild, channels, members, roles, search
│   │   ├── REST+Channels.swift            # get channel, typing, ack
│   │   ├── REST+Messages.swift             # history, create, edit, delete
│   │   └── REST+Reactions.swift            # add/remove/list/clear
│   │
│   ├── Gateway/
│   │   ├── GatewaySocket.swift             # actor: URLSessionWebSocketTask, recv loop, AsyncStream
│   │   ├── GatewayHeartbeat.swift          # heartbeat Task + ACK watchdog
│   │   ├── GatewayLifecycle.swift          # identify / resume / reconnect-backoff state machine
│   │   ├── GatewayOpcode.swift             # Op enum (0..14), CloseCode enum (4000..4014)
│   │   ├── GatewayPayload.swift            # GatewayFrame { op, d, s, t } envelope
│   │   ├── GatewayEvent.swift              # typed enum of dispatch events (the AsyncStream element)
│   │   ├── IdentifyPayload.swift           # user Identify (token, capabilities, properties, client_state)
│   │   ├── ResumePayload.swift
│   │   ├── GatewayCapabilities.swift       # OptionSet bitfield
│   │   ├── ClientState.swift
│   │   ├── ReadyPayload.swift              # READY + READY_SUPPLEMENTAL decode
│   │   └── MemberListSubscription.swift    # op 14 request + GUILD_MEMBER_LIST_UPDATE ops
│   │
│   ├── Voice/                              # Phase 2+ (stubbed in M1-M3)
│   │   ├── VoiceConnection.swift           # actor: orchestrates WS + UDP
│   │   ├── VoiceGatewaySocket.swift        # wss endpoint ?v=8, op 0..13
│   │   ├── VoiceOpcode.swift
│   │   ├── VoiceUDPTransport.swift         # NWConnection, IP discovery, RTP framing
│   │   ├── VoiceCrypto.swift               # AES-GCM (CryptoKit) + XChaCha20 (libsodium)
│   │   ├── OpusCodec.swift                 # swift-opus encode/decode
│   │   ├── AudioEngine.swift               # AVAudioEngine capture/playback
│   │   └── DAVE/                           # Phase 3 — E2EE (large, separate effort)
│   │       └── (placeholder; MLS via FFI)
│   │
│   └── Persistence/
│       ├── KeychainStore.swift             # actor: token save/load/delete
│       └── TokenStore.swift                # high-level token accessor
│
├── Tests/MaccordCoreTests/
│   ├── DecodingTests/                      # fixture-based Codable round-trips
│   ├── SnowflakeTests.swift
│   ├── RateLimiterTests.swift
│   ├── GatewayLifecycleTests.swift
│   └── MemberListOpsTests.swift            # op 14 SYNC/INSERT/DELETE replay
│
└── App/                                     # maccord.app target (SwiftUI)
    ├── maccordApp.swift                     # @main App, WindowGroup, scene config
    │
    ├── State/                               # @Observable stores (@MainActor)
    │   ├── AppState.swift                   # root: auth, currentUser, connection, normalized caches
    │   ├── GuildStore.swift                 # per-guild: roles, emojis, channels, member list
    │   ├── MessageStore.swift               # per-channel messages VM (LRU)
    │   ├── MemberStore.swift                # op 14 ordered rows for active channel
    │   ├── VoiceStore.swift                 # voice states + connection status
    │   ├── ReadStateStore.swift             # unread/mention badges
    │   ├── PresenceStore.swift
    │   ├── TypingStore.swift
    │   └── EventApplier.swift               # GatewayEvent -> store mutations
    │
    ├── DesignSystem/
    │   ├── Color+Discord.swift              # Color(hex:) tokens
    │   ├── Theme.swift                      # DiscordTheme (semantic token struct)
    │   ├── Layout.swift                     # Layout enum (dimensions)
    │   ├── Typography.swift                 # Font tokens
    │   ├── GlassStyles.swift               # reusable glass modifiers
    │   └── Markdown/                         # Discord markdown -> AttributedString
    │       ├── DiscordMarkdown.swift
    │       └── MentionResolver.swift
    │
    ├── Views/
    │   ├── Root/
    │   │   ├── RootView.swift                # auth gate -> LoginView | MainWindowView
    │   │   ├── MainWindowView.swift          # HStack(GuildRail + NavigationSplitView + inspector)
    │   │   └── ConnectionBanner.swift        # reconnecting/offline strip
    │   ├── Auth/
    │   │   ├── LoginView.swift               # token paste + (future) email/captcha
    │   │   └── CaptchaView.swift             # hCaptcha (later)
    │   ├── GuildRail/
    │   │   ├── GuildRailView.swift           # 72pt VStack of icons
    │   │   ├── GuildIconView.swift           # 48px squircle morph + tooltip
    │   │   ├── HomeButton.swift              # DM/home button
    │   │   ├── SelectionPill.swift           # left-edge white pill
    │   │   └── UnreadBadge.swift             # red mention pill / unread dot
    │   ├── ChannelSidebar/
    │   │   ├── ChannelSidebarView.swift      # server header + channel list + user panel
    │   │   ├── ServerHeaderView.swift        # 48px name + chevron
    │   │   ├── ChannelListView.swift         # categories + rows (List .sidebar)
    │   │   ├── CategoryHeaderView.swift      # collapsible
    │   │   ├── ChannelRowView.swift          # # / voice icon + states
    │   │   ├── VoiceChannelRowView.swift     # connected members nested
    │   │   └── UserPanelView.swift           # bottom 52px avatar+mic/deafen/gear
    │   ├── Chat/
    │   │   ├── ChatView.swift                # detail column: header + list + composer
    │   │   ├── ChannelHeaderView.swift       # 48px topbar + toolbar + search
    │   │   ├── MessageListView.swift         # ScrollView + LazyVStack, scroll anchors
    │   │   ├── MessageRowView.swift          # full vs grouped
    │   │   ├── MessageGroupHeaderView.swift  # avatar + author + timestamp
    │   │   ├── MessageContentView.swift      # markdown body
    │   │   ├── MessageHoverToolbar.swift     # react/reply/thread/more (glass)
    │   │   ├── ReplyPreviewView.swift        # reply spine
    │   │   ├── EmbedView.swift
    │   │   ├── AttachmentView.swift
    │   │   ├── ReactionBarView.swift         # pills
    │   │   ├── DateDividerView.swift
    │   │   ├── UnreadDividerView.swift       # "NEW"
    │   │   ├── TypingIndicatorView.swift
    │   │   └── Composer/
    │   │       ├── ComposerView.swift        # input pill + buttons
    │   │       ├── MentionAutocompleteView.swift
    │   │       └── EmojiPickerView.swift
    │   ├── Members/
    │   │   ├── MemberListView.swift          # inspector column, op14-driven
    │   │   ├── MemberRowView.swift
    │   │   └── MemberSectionHeaderView.swift # ONLINE — N
    │   ├── Profile/
    │   │   ├── UserProfilePopover.swift      # banner/bio/roles/mutuals
    │   │   └── PresenceDotView.swift         # mask-cut status dot
    │   ├── DMs/
    │   │   ├── DMListView.swift
    │   │   └── DMRowView.swift
    │   ├── Voice/
    │   │   └── VoicePanelView.swift          # connection HUD (stub UI in v1)
    │   └── Shared/
    │       ├── AvatarView.swift              # cached async image + presence dot
    │       ├── CachedAsyncImage.swift        # ImageCache-backed
    │       ├── TooltipModifier.swift
    │       └── EmojiText.swift               # inline custom emoji
    │
    ├── Services/
    │   ├── ImageCache.swift                  # actor: NSCache + URLCache
    │   ├── NotificationService.swift         # UNUserNotificationCenter
    │   ├── TypingThrottle.swift              # re-POST typing every ~8s
    │   └── AckService.swift                  # read-state ack (token chaining)
    │
    └── Resources/
        ├── Assets.xcassets                   # app icon, fallback avatars
        ├── Fixtures/                         # (DEBUG) sample gateway payloads
        └── Info.plist
```

---

## 4. Data Model — Codable Types to Create

All `Codable, Identifiable, Sendable, Hashable`. Snowflake-keyed dictionaries everywhere in stores. Use `DecodeThrowables` for arrays so one malformed element doesn't kill a payload (forward-compat with new Discord fields).

```swift
struct Snowflake: RawRepresentable, Codable, Hashable, Sendable, Comparable {
    let rawValue: UInt64               // decoded from JSON string
    var createdAt: Date { Date(timeIntervalSince1970: Double((rawValue >> 22) + 1_420_070_400_000) / 1000) }
    init(timestamp ms: UInt64) { rawValue = (ms - 1_420_070_400_000) << 22 } // synth for pagination
}
```

| Type | Most important fields |
|---|---|
| `User` | `id, username, global_name?, discriminator, avatar?(HashedAsset), bot?, banner?, accent_color?, public_flags?, premium_type?` |
| `CurrentUser` | embeds `User` + `email?, phone?, mfa_enabled, verified, locale, nsfw_allowed?` |
| `Guild` | `id, name, icon?, banner?, owner_id, roles:[Role], emojis:[Emoji], features:[String], approximate_member_count?, premium_tier`; (READY-hydrated) `channels?, members?, presences?, voice_states?, threads?` |
| `Role` | `id, name, color:Int, hoist, position, permissions:Permissions, managed, mentionable, icon?, unicode_emoji?, tags?` |
| `Permissions` | OptionSet over the string-bitfield |
| `Channel` | `id, type:ChannelType, guild_id?, name?, topic?, position?, parent_id?, nsfw?, last_message_id?, rate_limit_per_user?, permission_overwrites?, recipients?(DM)` |
| `ChannelType` | enum: text=0, dm=1, voice=2, groupDM=3, category=4, announcement=5, announcementThread=10, publicThread=11, privateThread=12, stageVoice=13, directory=14, forum=15, media=16 |
| `Member` | `user?, nick?, avatar?, roles:[Snowflake], joined_at:Date, premium_since?, deaf, mute, pending?, communication_disabled_until?, flags` |
| `Message` (struct) | `id, channel_id, guild_id?, author:User, member:Member?, content, timestamp:Date, edited_timestamp:Date?, tts, mention_everyone, mentions:[User], mention_roles:[Snowflake], attachments:[Attachment], embeds:[Embed], reactions:[Reaction]?, nonce?, pinned, webhook_id?, type:MessageType, message_reference?, referenced_message?(indirect), flags?, components?, sticker_items?` + `merging(partial:) -> Message` |
| `MessageType` | enum: default=0, reply=19, … (system messages: join, boost, call) |
| `MessageReference` | `type:Int(0 reply/1 forward), message_id?, channel_id?, guild_id?, fail_if_not_exists?` |
| `Attachment` | `id, filename, description?, content_type?, size, url, proxy_url, height?, width?, duration_secs?, waveform?` |
| `Embed` | `title?, type?, description?, url?, timestamp?, color?, footer?, image?, thumbnail?, video?, provider?, author?, fields?` |
| `Reaction` | `count, count_details?, me, emoji:Emoji, burst_colors?` |
| `Emoji` | `id?, name?, roles?, animated?, require_colons?, managed?` |
| `Sticker` | `id, name, format_type, ...` |
| `Presence` | `user(partial), guild_id?, status:Status, activities:[Activity], client_status` |
| `Status` | enum: online, idle, dnd, invisible, offline |
| `Activity` | `name, type, state?, details?, timestamps?, application_id?, emoji?` |
| `VoiceState` | `guild_id?, channel_id?(null=left), user_id, member?, session_id, deaf, mute, self_deaf, self_mute, self_stream?, self_video, suppress` |
| `ReadState` | `id(channel_id), last_message_id?, last_pin_timestamp?, mention_count, flags?` |
| `Relationship` | `id, type(1 friend/2 blocked/3 incoming/4 outgoing), user` |
| `UserProfile` | `user, user_profile(bio,pronouns,banner,accent), badges?, mutual_guilds?, mutual_friends?, connected_accounts?, guild_member?` |
| `AllowedMentions` | `parse:[String], roles?, users?, replied_user?` |
| `SuperProperties` | `os, browser, device, system_locale, browser_user_agent, browser_version, os_version, release_channel, client_build_number:Int, client_event_source?` |
| `HashedAsset` | wraps a hash; `url(base:, id:, size:)` → `cdn.discordapp.com/...`; `a_` prefix ⇒ `.gif` |

**Codable helpers:** `NullEncodable<T>` (distinguish `null` from absent), `DecodeThrowable`/`DecodeThrowables` (lenient single/array decode), `Int+decodeFlags` (bitfields). All shared via `RESTClient.decoder`/`encoder` and the gateway decoder, configured with `.convertFromSnakeCase` off (Discord uses snake_case keys — use explicit `CodingKeys` or a snake_case strategy; **decision: explicit `CodingKeys`** for clarity and partial-merge control).

---

## 5. Networking Layer Design

### 5.1 `actor RESTClient`

```swift
actor RESTClient {
    private let session: URLSession
    private var token: String?                  // raw user token, no prefix
    private let superProps: SuperProperties
    private let rateLimiter = RateLimiter()
    static let decoder: JSONDecoder = ...        // ISO8601 dates, explicit keys
    static let encoder: JSONEncoder = ...

    func setToken(_ t: String)

    // Core transport
    private func send(_ route: RESTRequest) async throws -> Data
    func get<T: Decodable>(_ route: RESTRequest) async throws -> T
    func post<B: Encodable, R: Decodable>(_ route: RESTRequest, body: B) async throws -> R
    func postMultipart<R: Decodable>(_ route: RESTRequest, json: Encodable, files: [FilePart]) async throws -> R
    func patch<B: Encodable, R: Decodable>(_ route: RESTRequest, body: B) async throws -> R
    func delete(_ route: RESTRequest) async throws
}
```

**Headers on every request** (set in `send`):
```swift
req.setValue(token, forHTTPHeaderField: "Authorization")          // RAW — no "Bot "/"Bearer "
req.setValue(realisticElectronUA, forHTTPHeaderField: "User-Agent")
req.setValue(superProps.base64JSON, forHTTPHeaderField: "X-Super-Properties")
req.setValue("en-US", forHTTPHeaderField: "X-Discord-Locale")
req.setValue("application/json", forHTTPHeaderField: "Content-Type") // when body present
```
Base URL: `https://discord.com/api/v10`.

**`RateLimiter` (actor-internal):** map `bucketKey -> (remaining, resetAfter)` where `bucketKey = (X-RateLimit-Bucket, majorParam)` (channel/guild id). Before sending, if `remaining == 0` and not reset, await `resetAfter`. On **429**: read body `retry_after` (float seconds), sleep, retry; if `X-RateLimit-Global`/scope==global, pause **all** requests. Back off on repeated 401/403 (invalid-request ban protection: >10k 4xx/10min → Cloudflare IP ban). Serialize per-bucket queues.

**Typed endpoints** (`REST+*.swift`), signatures:
```swift
func getCurrentUser() async throws -> CurrentUser                          // GET /users/@me
func getUser(_ id: Snowflake) async throws -> User
func getUserProfile(_ id: Snowflake, guildID: Snowflake?) async throws -> UserProfile
func getMyGuilds(after: Snowflake?, limit: Int = 200) async throws -> [Guild]   // partial
func getGuild(_ id: Snowflake) async throws -> Guild                       // ?with_counts=true
func getGuildChannels(_ id: Snowflake) async throws -> [Channel]
func getGuildRoles(_ id: Snowflake) async throws -> [Role]
func searchMembers(_ guild: Snowflake, query: String, limit: Int) async throws -> [Member]
func getChannel(_ id: Snowflake) async throws -> Channel
func getMessages(_ channel: Snowflake, before: Snowflake?, after: Snowflake?, around: Snowflake?, limit: Int = 50) async throws -> [Message]
func createMessage(_ channel: Snowflake, content: String, reference: MessageReference?, allowedMentions: AllowedMentions?, nonce: String, files: [FilePart]) async throws -> Message
func editMessage(_ channel: Snowflake, _ id: Snowflake, content: String?) async throws -> Message
func deleteMessage(_ channel: Snowflake, _ id: Snowflake) async throws
func addReaction(_ channel: Snowflake, _ msg: Snowflake, emoji: String) async throws        // emoji URL-encoded
func removeOwnReaction(_ channel: Snowflake, _ msg: Snowflake, emoji: String) async throws
func triggerTyping(_ channel: Snowflake) async throws                       // POST .../typing
func getMyDMs() async throws -> [Channel]
func openDM(recipient: Snowflake) async throws -> Channel
func ackMessage(_ channel: Snowflake, _ msg: Snowflake, token: String?) async throws -> String  // returns new ack token
```
Always send a unique `nonce` on `createMessage` to reconcile the optimistic UI with the Gateway echo.

### 5.2 `actor GatewaySocket`

```swift
actor GatewaySocket {
    private var task: URLSessionWebSocketTask?
    private var seq: Int?                      // last dispatch s
    private var sessionID: String?
    private var resumeURL: URL?
    private var heartbeat: Task<Void, Never>?
    private var lastACKed = true               // zombie detection
    private let (stream, continuation) = AsyncStream<GatewayEvent>.makeStream()

    var events: AsyncStream<GatewayEvent> { stream }

    func connect(token: String, props: SuperProperties) async
    func disconnect()
    private func receiveLoop() async           // decode frames, route by op
    private func handle(_ frame: GatewayFrame) async
}
```

**Connect:** `GET /gateway` (cache base) → open `wss://gateway.discord.gg/?v=10&encoding=json` (no compression in v1; add `zlib-stream` later).

**Lifecycle state machine** (`GatewayLifecycle.swift`):
1. RECV op 10 Hello → store `heartbeat_interval`, start heartbeat with jitter (`interval * random(0..1)` first beat).
2. SEND op 2 Identify (below) — may send in parallel with first heartbeat.
3. RECV op 0 / `READY` → cache `session_id`, `resume_gateway_url`, build stores; handle `READY_SUPPLEMENTAL`.
4. Stream dispatches → decode to `GatewayEvent` → yield.

**Heartbeat (`GatewayHeartbeat.swift`):** every interval, send `{"op":1,"d":<seq>}`. If no op 11 ACK before next beat is due (`lastACKed == false`) → zombie → close + RESUME. Honor server-sent op 1 (beat now). Respect 120 events/60s send cap.

**Resume vs re-Identify (decision matrix):**
| Trigger | Action |
|---|---|
| op 7 Reconnect | reconnect to `resume_gateway_url` + RESUME |
| op 9 `d:true` | wait 1–5s, RESUME |
| op 9 `d:false`, 4007, 4009 | base URL + re-IDENTIFY |
| silent drop / missing ACK / 4000 / 4008 | RESUME (backoff `min(2^n * 1.1 + 1.6, 60)s`) |
| **4004** (bad token) | **fatal — stop, surface "re-login required"** |
| 4010–4014 | bot-only; treat as fatal config error |

Clean-close caveat: do **not** close with 1000/1001 if you want to resume — drop TCP or use a non-standard close code.

**User Identify payload (op 2)** — `IdentifyPayload.swift`:
```json
{
  "op": 2,
  "d": {
    "token": "<raw user token>",
    "capabilities": 0,
    "properties": {
      "os": "Mac OS X", "browser": "Discord Client", "device": "",
      "system_locale": "en-US",
      "browser_user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.x Chrome/124.0.0.0 Electron/30.0.0 Safari/537.36",
      "browser_version": "30.0.0", "os_version": "23.4.0",
      "release_channel": "stable", "client_build_number": 291821,
      "client_event_source": null
    },
    "presence": { "status": "online", "since": 0, "activities": [], "afk": false },
    "compress": false,
    "client_state": {
      "guild_versions": {}, "highest_last_message_id": "0",
      "read_state_version": 0, "user_guild_settings_version": -1,
      "private_channels_version": "0", "api_code_version": 0
    }
  }
}
```
> **Decision: start with `capabilities: 0` (fully hydrated READY)** — each guild carries its own `members`/`presences`, single READY, no protobuf. This minimizes rehydration logic in M1. Opt into `DEDUPE_USER_OBJECTS (1<<4)` + `PRIORITIZED_READY_PAYLOAD (1<<5)` only after merge/rehydration code exists (M3 optimization). `client_build_number` is configurable; keep it current. The same `properties` object base64-encoded IS the `X-Super-Properties` REST header.

**Event decoding → `AsyncStream`:** `GatewayFrame` decodes `{op,d,s,t}`. For op 0, switch on `t` and decode `d` into a typed `GatewayEvent`:
```swift
enum GatewayEvent: Sendable {
    case ready(ReadyPayload)
    case readySupplemental(ReadySupplemental)
    case guildCreate(Guild), guildUpdate(Guild), guildDelete(UnavailableGuild)
    case channelCreate(Channel), channelUpdate(Channel), channelDelete(Channel)
    case messageCreate(Message), messageUpdate(PartialMessage), messageDelete(MessageDeleteEvent)
    case messageAck(MessageAckEvent)
    case reactionAdd(ReactionEvent), reactionRemove(ReactionEvent), reactionRemoveAll(...), reactionRemoveEmoji(...)
    case typingStart(TypingStartEvent)
    case presenceUpdate(Presence)
    case guildMemberListUpdate(MemberListUpdate)   // op 14 response
    case guildMembersChunk(MembersChunk)
    case guildMemberAdd(Member), guildMemberUpdate(Member), guildMemberRemove(MemberRemove)
    case voiceStateUpdate(VoiceState), voiceServerUpdate(VoiceServerUpdate)
    case relationshipAdd(Relationship), relationshipRemove(Snowflake)
    case resumed
    case unknown(t: String)                         // forward-compat: ignore gracefully
}
```

**op 14 member-list subscription** (`MemberListSubscription.swift`) — sent when a guild/channel becomes active:
```json
{ "op": 14, "d": { "guild_id": "...", "channels": { "<chan>": [[0,99]] },
                   "typing": true, "threads": false, "activities": true, "members": [] } }
```
`GUILD_MEMBER_LIST_UPDATE` carries `groups` (section counts) + `ops` (`SYNC`/`UPDATE`/`INSERT`/`DELETE`/`INVALIDATE`) addressed by **absolute index**; group headers consume index slots. Model as ordered index-addressable rows (see §6 MemberStore).

---

## 6. State / Store Layer

`@MainActor @Observable` classes. Normalize into `[Snowflake: T]` dictionaries — events arrive as ID-keyed deltas, never nested graphs.

```swift
@MainActor @Observable final class AppState {
    enum Phase { case loading, login, connected, reconnecting, fatal(String) }
    var phase: Phase = .loading
    var currentUser: CurrentUser?
    var connection: ConnectionStatus = .disconnected

    // normalized caches
    var guilds: [Snowflake: GuildStore] = [:]
    var guildOrder: [Snowflake] = []            // folder/position order
    var channels: [Snowflake: Channel] = [:]
    var users: [Snowflake: User] = [:]
    var dms: [Channel] = []                       // ordered
    var presences = PresenceStore()
    var readState = ReadStateStore()

    // selection
    var selectedGuild: Snowflake?
    var selectedChannel: Snowflake?

    // sub-stores created lazily
    private var messageStores: [Snowflake: MessageStore] = [:]   // per-channel, LRU
    var memberStore = MemberStore()                              // for active channel
    var voice = VoiceStore()

    let rest: RESTClient
    let gateway: GatewaySocket
    private var pump: Task<Void, Never>?

    func bootstrap() async              // load token -> setToken -> gateway.connect
    func startEventPump()               // for await ev in gateway.events { EventApplier.apply(ev, to: self) }
    func messageStore(for channel: Snowflake) -> MessageStore   // lazy create + LRU evict
    func selectChannel(_ id: Snowflake) async  // load history, subscribe op14, ack
}
```

```swift
@MainActor @Observable final class GuildStore {
    let id: Snowflake
    var meta: Guild
    var roles: [Snowflake: Role] = [:]
    var emojis: [Emoji] = []
    var channels: [Channel] = []            // sorted by position, grouped by parent
    var voiceStates: [Snowflake: VoiceState] = [:]   // user -> state
    func sortedChannelTree() -> [ChannelTreeNode]    // categories + children for sidebar
}

@MainActor @Observable final class MessageStore {     // per-channel
    let channelID: Snowflake
    var messages: [Message] = []            // oldest..newest
    var hasMoreBefore = true
    var oldestLoaded: Snowflake? { messages.first?.id }
    func loadInitial() async                // GET ?limit=50
    func loadOlder() async                  // GET ?before=oldestLoaded, prepend
    func append(_ m: Message)               // MESSAGE_CREATE, dedupe by id+nonce
    func update(_ p: PartialMessage)        // merge -> new Message value
    func delete(_ id: Snowflake)
    func applyReaction(_ e: ReactionEvent)
    // sliding window: cap ~400 in memory; re-fetch if scrolled into evicted range
}

@MainActor @Observable final class MemberStore {       // op 14 ordered rows
    enum Row: Identifiable { case header(MemberGroup), member(Member) }
    var rows: [Row] = []                     // index-addressable; matches op 14 indices
    var memberCount = 0; var onlineCount = 0
    func applyOps(_ update: MemberListUpdate) // SYNC/UPDATE/INSERT/DELETE/INVALIDATE in order
}

@MainActor @Observable final class VoiceStore {
    var connection: VoiceConnectionStatus = .disconnected
    var activeChannel: Snowflake?
    var statesByChannel: [Snowflake: [VoiceState]] = [:]   // who's in each voice channel
    var selfMute = false; var selfDeaf = false
}
```

**`EventApplier`** is the single switch from `GatewayEvent` to store mutations (keeps `AppState` thin and testable):
```swift
enum EventApplier {
    @MainActor static func apply(_ e: GatewayEvent, to app: AppState) {
        switch e {
        case .ready(let r):            // build guilds/channels/users/dms/readState/presences
        case .messageCreate(let m):    app.messageStore(for: m.channel_id).append(m)
                                       app.readState.bumpUnread(m.channel_id, m.id)
        case .messageUpdate(let p):    app.messageStore(for: p.channel_id).update(p)
        case .guildMemberListUpdate(let u): app.memberStore.applyOps(u)
        case .presenceUpdate(let p):   app.presences.set(p)
        case .voiceStateUpdate(let v): app.voice.apply(v); app.guilds[...]?.voiceStates[...] = v
        case .messageAck(let a):       app.readState.markRead(a.channel_id, a.message_id)  // multi-device sync
        case .typingStart(let t):      app.typing.start(t)
        ...
        case .unknown: break
        }
    }
}
```

**Data flow (end to end):**
```
GatewaySocket(actor) --AsyncStream<GatewayEvent>--> AppState.pump Task (@MainActor)
   -> EventApplier.apply -> mutate @Observable stores -> SwiftUI views re-render
RESTClient(actor) --async fetch--> store methods (loadInitial/loadOlder/getGuild) -> stores
User action (send) -> optimistic insert (nonce) -> RESTClient.createMessage -> Gateway echo reconciles
```

---

## 7. UI Architecture (4-pane) + Design Tokens

### 7.1 View tree → Discord component mapping

```
maccordApp (WindowGroup, .windowToolbarStyle(.unified), .windowResizability(.contentMinSize), minWidth 900 minHeight 600)
└─ RootView                         // auth gate
   ├─ LoginView                     // (unauthenticated)
   └─ MainWindowView                // (connected)
      └─ HStack(spacing: 0)
         ├─ GuildRailView           [Discord: SERVER RAIL]  72pt fixed, bgTertiary #1E1F22
         │   ├─ HomeButton
         │   ├─ Divider (32x8)
         │   └─ ForEach guildOrder: GuildIconView (48px squircle morph)
         │         + SelectionPill (leading) + UnreadBadge (bottom-right)
         │
         └─ NavigationSplitView(columnVisibility:)
            ├─ sidebar: ChannelSidebarView   [Discord: CHANNEL SIDEBAR] 240pt, bgSecondary #2B2D31
            │     ├─ ServerHeaderView (48px)
            │     ├─ ChannelListView          // List(.sidebar): CategoryHeaderView + ChannelRowView / VoiceChannelRowView
            │     └─ UserPanelView (52px, bgSecondaryAlt #232428)   [Discord: USER PANEL]
            │     .navigationSplitViewColumnWidth(min:200, ideal:240, max:320)
            │
            └─ detail: ChatView               [Discord: MESSAGE AREA] flex, bgPrimary #313338
                  ├─ ChannelHeaderView (48px) // # icon + name + topic + toolbar + search (glass)
                  ├─ MessageListView          // ScrollView + LazyVStack(.scrollTargetLayout)
                  │     // .defaultScrollAnchor(.bottom) + .defaultScrollAnchor(.bottom, for:.sizeChanges)
                  │     // .scrollPosition($pos) for jump-to-latest + scroll-up pause
                  │     ├─ DateDividerView / UnreadDividerView
                  │     ├─ MessageRowView      // full (MessageGroupHeaderView) vs grouped (7-min rule)
                  │     │     ├─ ReplyPreviewView
                  │     │     ├─ MessageContentView (markdown)
                  │     │     ├─ AttachmentView / EmbedView
                  │     │     ├─ ReactionBarView
                  │     │     └─ MessageHoverToolbar  [GLASS]
                  │     └─ TypingIndicatorView
                  └─ ComposerView             [Discord: COMPOSER] input pill #383A40, radius 8  [GLASS]
                        └─ MentionAutocompleteView / EmojiPickerView
            .inspector(isPresented: $showMembers) {
               MemberListView                 [Discord: MEMBER LIST] 240pt, bgSecondary
                  // MemberSectionHeaderView + MemberRowView, driven by MemberStore.rows
                  .inspectorColumnWidth(min:200, ideal:240, max:320)
            }
```

### 7.2 Where Liquid Glass is applied

| Surface | Treatment |
|---|---|
| `MessageHoverToolbar` | `GlassEffectContainer` + `.glassEffect(.regular, in: .rect(cornerRadius: 8))`; reaction picker expands via `glassEffectID` + `@Namespace` morph |
| `ComposerView` send button | `.buttonStyle(.glassProminent)`; the input pill uses `Material`/solid `#383A40` (background surface, not glass) |
| `ChannelHeaderView` toolbar | native `.toolbar { }` — adopts glass automatically; use `ToolbarSpacer(.flexible)` to push search to trailing edge; `.sharedBackgroundVisibility(.hidden)` on the members-toggle |
| Sidebar / inspector | `NavigationSplitView` sidebar + `.inspector()` get translucent glass treatment **for free** |
| `EmojiPickerView` / popovers | `.glassEffect()` floating panel; or `.sheet` (auto glass) |
| `UserProfilePopover` | glass background |
| `GuildIconView` | squircle morph via `withAnimation(.spring(response:0.2, dampingFraction:0.7))` on cornerRadius 16→24; NOT glass (uses solid icon tiles) |
| Voice HUD `VoicePanelView` | `.glassEffect(.clear)` if over media; `.regular` otherwise |

Rules: never stack glass on glass — group sibling glass in a `GlassEffectContainer`. Use `Material` (e.g. `.regularMaterial`) for purely decorative backings (code blocks, pinned-banner). `AsyncImage` has no built-in cache on macOS 26 → use `CachedAsyncImage` backed by the `ImageCache` actor for all avatars/icons/emoji.

### 7.3 Design tokens

`Color+Discord.swift` (drop-in, dark theme, current refresh):
```swift
extension Color {
    init(hex: UInt32) { /* RGB from 0xRRGGBB */ }
    // surfaces
    static let bgPrimary      = Color(hex: 0x313338)
    static let bgSecondary    = Color(hex: 0x2B2D31)
    static let bgSecondaryAlt = Color(hex: 0x232428)
    static let bgTertiary     = Color(hex: 0x1E1F22)
    static let bgFloating     = Color(hex: 0x111214)
    static let surfaceRaised  = Color(hex: 0x383A40)
    static let divider        = Color(hex: 0x3F4147)
    static let chHover        = Color(hex: 0x35373C)
    static let chSelected     = Color(hex: 0x404249)
    static let msgHover       = Color(hex: 0x2E3035)
    // brand
    static let blurple        = Color(hex: 0x5865F2)
    static let blurplePressed = Color(hex: 0x4752C4)
    static let linkBlue       = Color(hex: 0x00A8FC)
    static let dangerRed      = Color(hex: 0xED4245)
    // text
    static let textNormal      = Color(hex: 0xDBDEE1)
    static let headerPrimary   = Color(hex: 0xF2F3F5)
    static let headerSecondary = Color(hex: 0xB5BAC1)
    static let channelDefault  = Color(hex: 0x949BA4)
    static let channelIcon     = Color(hex: 0x80848E)
    static let textMuted       = Color(hex: 0x80848E)
    static let interactiveNormal = Color(hex: 0xB5BAC1)
    static let interactiveHover  = Color(hex: 0xDBDEE1)
    // status
    static let online  = Color(hex: 0x23A55A)
    static let idle    = Color(hex: 0xF0B232)
    static let dnd     = Color(hex: 0xF23F43)
    static let offline = Color(hex: 0x80848E)
    static let badgeRed = Color(hex: 0xF23F43)
}
```

`Layout.swift`:
```swift
enum Layout {
    static let guildRailWidth: CGFloat = 72
    static let serverIconSize: CGFloat = 48
    static let serverIconGap: CGFloat = 8
    static let iconRadiusIdle: CGFloat = 16
    static let iconRadiusActive: CGFloat = 24
    static let pillWidth: CGFloat = 4
    static let pillSelectedH: CGFloat = 40
    static let pillHoverH: CGFloat = 20
    static let pillUnreadH: CGFloat = 8
    static let channelSidebarWidth: CGFloat = 240
    static let memberListWidth: CGFloat = 240
    static let headerHeight: CGFloat = 48
    static let channelRowHeight: CGFloat = 34
    static let memberRowHeight: CGFloat = 44
    static let userPanelHeight: CGFloat = 52
    static let messageAvatar: CGFloat = 40
    static let listAvatar: CGFloat = 32
    static let messageLeftGutter: CGFloat = 72
    static let composerRadius: CGFloat = 8
    static let composerMinHeight: CGFloat = 44
    static let messageGroupGapMinutes: Int = 7
}
```

`Typography.swift` (SF Pro is the correct native gg-sans substitute):
```swift
enum DiscordFont {
    static let messageBody   = Font.system(size: 16, weight: .regular)   // line 22, #DBDEE1
    static let authorName    = Font.system(size: 16, weight: .medium)    // #F2F3F5 or role color
    static let timestamp     = Font.system(size: 12, weight: .regular)   // #949BA4
    static let timestampHover = Font.system(size: 11, weight: .medium)
    static let channelName   = Font.system(size: 16, weight: .medium)
    static let categoryHeader = Font.system(size: 12, weight: .semibold) // UPPERCASE +0.02 tracking
    static let serverName    = Font.system(size: 16, weight: .semibold)
    static let channelHeaderTitle = Font.system(size: 16, weight: .semibold)
    static let memberRoleHeader = Font.system(size: 12, weight: .semibold)
    static let memberName    = Font.system(size: 16, weight: .medium)
    static let panelUsername = Font.system(size: 14, weight: .semibold)
    static let panelSubtext  = Font.system(size: 12, weight: .regular)
    static let composerText  = Font.system(size: 16, weight: .regular)
    static let searchText    = Font.system(size: 14, weight: .regular)
    static let tooltip       = Font.system(size: 14, weight: .semibold)
    static let reactionCount = Font.system(size: 14, weight: .semibold)
    static let replyPreview  = Font.system(size: 14, weight: .regular)
}
```

**Interaction details to implement:** guild icon squircle morph (16→24 spring); left pill heights hidden(0)/unread(8)/hover(20)/selected(40), animate ~150ms; channel hover bg `#35373C`, selected bg `#404249` text white; unread = left white pill + bold white text; mention badge red `#F23F43` capsule bottom-right of guild icon / right edge of channel row; message hover row bg `#2E3035` + glass toolbar fade-in (~80ms); grouped messages collapse on same author within 7 min; presence dot is **mask-cut** into avatar bottom-right (transparent hole revealing surface, not a ring); mention pill bg `rgba(88,101,242,0.3)` text `#C9CDFB`; a row mentioning *you* gets left border 2px + bg tint. Custom thin scrollbars thumb `#1A1B1E`. Use `.symbolEffect(.bounce, value:)` on the mention bell, `.contentTransition(.symbolEffect(.replace))` on mic mute toggle, `.symbolEffect(.variableColor.iterative, isActive: isConnecting)` on voice connect.

---

## 8. Phased Build Plan

### M1 — Auth + Gateway + Read Messages (foundation)
**Goal:** log in with a token, connect the gateway, see guilds/channels, read message history + live `MESSAGE_CREATE`.
- `Models/`: Snowflake, Codable+Helpers, HashedAsset, User, CurrentUser, Guild, Role, Channel, Member, Message, Attachment, Embed, Reaction, Emoji, Presence, ReadState, SuperProperties.
- `Persistence/`: KeychainStore (actor, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, delete-then-add), TokenStore.
- `Networking/`: RESTClient (auth header, send/get), RESTRequest, RESTError, RateLimiter (bucket map + 429), REST+Users, REST+Guilds, REST+Channels, REST+Messages.
- `Gateway/`: GatewayOpcode, GatewayPayload, GatewayCapabilities, ClientState, IdentifyPayload, ResumePayload, GatewaySocket (connect, recv loop, AsyncStream), GatewayHeartbeat (jitter + ACK watchdog), GatewayLifecycle (identify/resume/backoff), GatewayEvent, ReadyPayload.
- `State/`: AppState (bootstrap, startEventPump, selectChannel), GuildStore, MessageStore (loadInitial/loadOlder/append/update/delete), EventApplier (ready/guildCreate/channel*/message*).
- `App/`: maccordApp scene, RootView, LoginView (token paste), minimal MainWindowView, basic ChatView + MessageListView (plain rows), ChannelSidebarView (plain list).
- `Tests/`: SnowflakeTests, DecodingTests (fixtures for READY/Message/Guild), RateLimiterTests, GatewayLifecycleTests.
- **Exit:** token → READY → guild/channel tree renders → open channel loads 50 messages → live messages append.

### M2 — Send / Interact (writes)
**Goal:** send/edit/delete, reply, react, typing, mark-read, attachments.
- `Networking/`: REST+Reactions, MultipartFormBody, createMessage/editMessage/deleteMessage/addReaction/removeOwnReaction/triggerTyping/ackMessage.
- `Models/`: AllowedMentions, MessageReference, finalize PartialMessage merge (`Message.merging(partial:)`).
- `State/`: MessageStore optimistic insert + nonce reconcile, applyReaction; ReadStateStore (bumpUnread/markRead, MESSAGE_ACK multi-device sync); EventApplier message edit/delete/reaction/typing/ack.
- `Services/`: TypingThrottle (re-POST ~8s), AckService (ack-token chaining).
- `App/Views/Chat/`: ComposerView (send, enter-to-send, slowmode awareness via `rate_limit_per_user`), MessageHoverToolbar (react/reply/edit/delete) with glass, ReactionBarView, ReplyPreviewView, AttachmentView (upload), DateDividerView, UnreadDividerView, TypingIndicatorView, MentionAutocompleteView, EmojiPickerView.
- `DesignSystem/Markdown/`: DiscordMarkdown, MentionResolver, EmojiText.
- **Exit:** send/edit/delete works; optimistic UI dedupes by nonce; reactions toggle; typing shows; channels mark read; image upload works.

### M3 — Full UI Polish + Member List + Presence (pixel parity)
**Goal:** pixel-accurate Discord, op 14 member list, presence, profiles, DMs, Liquid Glass, scroll behavior.
- `Gateway/`: MemberListSubscription (op 14 send + decode), enable `DEDUPE_USER_OBJECTS`+`PRIORITIZED_READY_PAYLOAD` capabilities + READY_SUPPLEMENTAL rehydration, ReadySupplemental decode, presenceUpdate/guildMember* handling, zlib-stream (optional optimization).
- `State/`: MemberStore (applyOps SYNC/UPDATE/INSERT/DELETE/INVALIDATE), PresenceStore, TypingStore, GuildStore.sortedChannelTree, message LRU eviction; subscribe op 14 on channel select, unsubscribe previous.
- `DesignSystem/`: Color+Discord, Layout, Typography, GlassStyles, Theme — full token set.
- `App/Views/`: full GuildRailView (GuildIconView squircle morph, SelectionPill, UnreadBadge, HomeButton, tooltips), ServerHeaderView, ChannelListView (CategoryHeaderView collapse, ChannelRowView states, VoiceChannelRowView), UserPanelView, ChannelHeaderView (toolbar glass + search), MessageRowView grouping (7-min), MessageGroupHeaderView, MessageContentView, EmbedView (full), MemberListView + MemberRowView + MemberSectionHeaderView, AvatarView/PresenceDotView (mask-cut), CachedAsyncImage + ImageCache actor, DMListView/DMRowView, UserProfilePopover, ConnectionBanner, TooltipModifier.
- `Services/`: NotificationService (UNUserNotificationCenter, per-channel mute).
- MessageListView scroll anchors (`.defaultScrollAnchor(.bottom, for:.sizeChanges)`, `.scrollPosition` jump-to-latest + scroll-up pause).
- **Exit:** indistinguishable from Discord dark theme; member sidebar live with presence; profiles/DMs work; glass everywhere specified; <100MB RAM with avatar cache.

### M4 — Voice (dedicated later milestone, stub UI shipped earlier)
**Goal:** voice transport spike, then DAVE. Ship a **stub** "Join Voice" affordance in M3 that indicates voice is not yet supported (DAVE is enforced since ~March 2026; transport-only cannot carry audio in standard channels).
- **M4a transport spike (internal, flagged):** VoiceConnection (actor), VoiceGatewaySocket (`?v=8`, op 0 identify w/ `max_dave_protocol_version`, op 8 hello, op 2 ready, op 1 select protocol, op 4 session description, op 5 speaking, heartbeat seq_ack), VoiceUDPTransport (NWConnection, 74-byte IP discovery, RTP 12-byte header, 4-byte trailing nonce → 12-byte expansion, AAD=RTP header), VoiceCrypto (CryptoKit AES-GCM for `aead_aes256_gcm_rtpsize` + libsodium XChaCha20 for required `aead_xchacha20_poly1305_rtpsize`), OpusCodec (swift-opus, 48kHz stereo 20ms), AudioEngine (AVAudioEngine capture/playback, 5 silence frames on stop). Main-gateway op 4 join handshake (wait for BOTH VOICE_STATE_UPDATE + VOICE_SERVER_UPDATE). VoiceStore + VoicePanelView (real).
- **M4b DAVE/E2EE (months, high-risk):** MLS state machine via FFI (OpenMLS Rust C-ABI or libdave C++), AES-128-GCM frame transform (8-byte tag, ULEB128 nonce, `0xFAFA` marker), per-sender ratchet, epoch transition choreography (op 21–31). Gate behind feasibility/licensing review.
- **Exit (realistic):** M4a = self-loopback + speaking indicators (internal). M4b = genuinely usable voice in current Discord. Do **not** promise functional audio before M4b lands.

---

## 9. Parity Checklist (by milestone)

**Auth & account**
- [M1] User-token login (raw token paste)
- [M1] Keychain token storage; [M2] logout clears it
- [M3] hCaptcha challenge handling
- [M3+] MFA/TOTP prompt
- [M3+] Multiple accounts / switcher

**Connectivity (gateway)**
- [M1] Identify with super-properties/UA; heartbeat + zombie detection; resume + exponential backoff
- [M3] zlib-stream decompression; DEDUPE/PRIORITIZED capabilities + READY_SUPPLEMENTAL
- [M2] Presence/status set; [M3] custom status

**Servers & channels**
- [M1] Guild list sidebar; channel list (categories, text/voice/announcement/forum/stage); permission-hidden channels
- [M3] Folders/ordering; category collapse; channel topic, slowmode, NSFW gating
- [M3] op 14 lazy member sidebar (role groups, online/offline, presence)
- [M1] Unread; [M2] mention indicators (read-state) per-channel & per-guild
- [M3+] Threads (list/view/reply/archive)

**Messages**
- [M1] Paginated history (before/after/around); live MESSAGE_CREATE
- [M2] Send (markdown), edit, delete, reply, optimistic send w/ nonce
- [M2] Attachments upload (multipart); reactions (unicode + custom); typing send+display; mark-as-read
- [M2] Mention autocomplete; emoji picker
- [M3] Embeds/link previews; system messages; spoilers; code blocks; mention pills; role colors
- [M3] Jump-to-message; [M3+] pinned messages, message search; stickers; GIF picker; burst reactions
- [M3] Date/unread dividers; 7-min grouping

**DMs & social**
- [M3] DMs + group DMs (create/leave); friends list (add/remove/block)
- [M3] User profile popovers (banner/bio/roles/mutuals)

**Voice/video**
- [M3] Stub "Join Voice" UI; voice-state display (who's in channel)
- [M4a] Join voice (transport), speaking indicators, Opus, mute/deafen — internal/flagged
- [M4b] DAVE E2EE (genuinely usable audio); [stretch] screen share/video

**Moderation / management**
- [M3+] Kick/ban/timeout; role assign; invite/emoji management; audit log

**Platform/UX**
- [M3] Native macOS notifications (per-channel mute); Liquid Glass; dark theme
- [M3+] Cmd-K quick switcher; keyboard shortcuts; settings (appearance/notifications)
- [M3] Animated avatars/emoji (toggleable); low RAM footprint

---

## 10. Key Risks & Decisions

1. **Voice complexity / DAVE (highest risk).** DAVE E2EE is mandatory (enforced ~March 2026) with **no Swift library** — it's a 3–6 month MLS/crypto project requiring C++ (`libdave`) or Rust (OpenMLS) FFI. **Decision:** ship a stubbed "Join Voice" UI in v1; treat transport voice (M4a) as an internal-only spike; gate DAVE (M4b) behind a separate feasibility/licensing review. Do not block v1 on voice.

2. **Lazy member list (op 14).** The trickiest undocumented subsystem. **Decision:** model `MemberStore` as an **ordered, index-addressable list of rows** (header OR member), since `ops` address by absolute index and group headers consume slots. Replay SYNC/UPDATE/INSERT/DELETE strictly in order; on INVALIDATE, re-request the range. Subscribe `[0,99]` on channel select, extend ranges on scroll, unsubscribe the previous guild. Unit-test op replay (`MemberListOpsTests`).

3. **Token storage.** **Decision:** macOS Keychain only (`kSecClassGenericPassword`, service = bundle id, account = `"discord-user-token"`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — never iCloud-synced). Wrap in `actor KeychainStore`; read once at launch into RESTClient/GatewaySocket; **never log it**; send only over TLS.

4. **Rate limits.** Reference clients (DiscordKit/Accord) handle this weakly — **we must do better.** **Decision:** `RateLimiter` actor keyed by `(X-RateLimit-Bucket, majorParam)`; pre-flight wait when `remaining==0`; honor 429 `retry_after` float; global 429 pauses all requests; serialize per-bucket queues; surface `rate_limit_per_user` (slowmode) in the composer. Back off on repeated 401/403 (>10k 4xx/10min ⇒ Cloudflare IP ban).

5. **Forward-compat decoding.** Discord adds fields constantly. **Decision:** lenient array decode (`DecodeThrowables`) so one bad element never drops a whole READY/message batch; `GatewayEvent.unknown(t:)` ignores unrecognized dispatches gracefully; explicit `CodingKeys` everywhere.

6. **Capabilities sequencing.** **Decision:** M1 uses `capabilities: 0` (hydrated READY) to avoid rehydration logic early; opt into `DEDUPE_USER_OBJECTS`+`PRIORITIZED_READY_PAYLOAD` in M3 only after merge logic exists. Keep `client_build_number` configurable and current (gates experiments/features).

7. **AsyncImage has no cache on macOS 26.** **Decision:** never use bare `AsyncImage` in the message/member lists; route all avatars/icons/emoji through `CachedAsyncImage` backed by an `actor ImageCache` (NSCache + URLCache), fetching pre-sized CDN assets via `?size=`. This is the linchpin of the <100MB RAM goal.

8. **Licensing.** **Decision:** reimplement from scratch. DiscordKit is unlicensed (all rights reserved), Swiftcord is GPLv3, Accord is BSD-4-Clause (advertising clause). Wire-protocol facts (opcodes, JSON keys) are not copyrightable and free to use; **copy no source.** Borrow architecture/design only.

---

**File:** This document should be saved as `/Users/sinabina/conductor/workspaces/maccord/indianapolis/ARCHITECTURE.md` — it is the single source of truth for the build.