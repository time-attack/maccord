# maccord — Discord parity review & feature work

A grounded review of features the real Discord client has that **maccord** was
missing, plus the set implemented in this branch.

## How the review was done

Ten parallel reviewers each audited one domain against the **actual Swift
source** (not the architecture checklist), producing 138 concrete gaps with
`file:line` evidence, user-impact, and effort. Several "gaps" turned out to be
already implemented (member role colors, presence/activity text, `Mark As Read`
on channels and the server header, category collapse animation, NSFW gate) and
were dropped. The rest were ranked; the 40+ highest-value, tractable items were
implemented here.

A handful of genuinely large items remain deliberately **out of scope** (see the
bottom of this file) because they are multi-week efforts on their own.

## Implemented in this branch

### Pinned messages & jump-to-message (the original complaint)
1. **Pinned rows are tappable** → jump to the message in chat, then dismiss.
2. **Rich pin previews** — image thumbnails, file chips (name + size), embed and
   sticker indicators instead of the bare `(attachment)` placeholder.
3. **Jump loads a window around the target** (`MessageStore.loadAround`, `GET
   ?around=`) when it isn't already on screen.
4. **Highlight flash** — the jumped-to row pulses blurple for ~2s.
5. **Pin/unpin from the message hover toolbar** (not just the context menu).

### Rich content & messages
6. Honor `MessageFlags.suppressEmbeds` when rendering.
7. Resolve `<#channel>` mentions to channel names (was always "channel").
8. **Message forwarding** — context-menu → composer forward bar → `type:1` ref.
9. **Silent reply** toggle ("@ ON/OFF") → `AllowedMentions.silentReply`.
10. **Cmd+B / I / U** wrap the composer selection in markdown markers.
11. **Per-channel composer drafts** (restored on return; persisted to disk).
12. Markdown **headers** (`#`/`##`/`###`).
13. Markdown **masked links** `[label](url)`.
14. Markdown **subtext** (`-#`) and **ordered/unordered lists**.
15. **Deleted-message tombstones** (grayed row until reload).

### Reactions & emoji
16. **Reaction details** — right-click a pill → "View Reactions" popover of who
    reacted (`GET .../reactions/{emoji}`), with a richer hover tooltip.
17. Emoji picker **"Recently Used"** tab.

### Channels, threads, navigation
18. Channel right-click adds **Notification Settings** + **Invite People**;
    channel topic shown as a row tooltip.
19. **Thread breadcrumb / back button** when viewing a thread.
20. Quick switcher surfaces **recent channels** first; **Alt+↑/↓** cycle channels.

### Members, presence, moderation
21. Member context menu: **Message**, **Block/Unblock**, and permission-gated
    **Kick / Ban / Timeout** (with durations) — new REST + permission checks +
    the `moderateMembers` permission bit.
22. Member **Roles** submenu (assign/remove) → `modifyMemberRoles`.

### DMs & social
23. Friends **Blocked** tab (with unblock).
24. DM right-click menu (Mark Read, Block, Close DM / Leave Group, Copy ID) and a
    hover **close (×)**.
25. DM list **search** field.
26. **Group DM creation** — friend-picker sheet (`createGroupDM` + recipient
    add/remove + `closeChannel`).

### Platform & settings
27. **Settings persistence** — prefs, mutes, per-guild notification levels,
    status, and drafts saved to `UserDefaults` (load on launch + autosave).
28. **Dock badge** unread-mention count.
29. Notifications: **suppressed when focused on that channel**, carry the
    sender's **avatar** + ids, and **click-to-jump** to the message.
30. **Cmd-/** Keyboard Shortcuts reference sheet.
31. Composer **drag-drop**, **paste-image**, and **"+" file-picker** uploads
    (with a drop-target highlight); spellcheck follows the pref.

### Server management
32. **Join a server** by invite link/code (guild-rail "+" → sheet → `POST
    /invites/{code}`).
33. Server Settings **Invites** tab — create with expiry / max-uses, copy, revoke.
34. Server Settings **Bans** tab — list with reason + **Unban**.

(Several entries above bundle multiple sub-fixes, e.g. moderation = kick + ban +
timeout + unban + REST + perms; the working tree contains 40+ discrete changes.)

## Deliberately out of scope (large, separate efforts)

- **Voice/video transport + DAVE E2EE** (months; see `ARCHITECTURE.md §10`).
- **Forum channel browsing** (post grid, tags) and **stage channel** controls.
- **Link unfurling** (server-side OG scraping) and inline **video/audio players**.
- **GIF picker** (Tenor/Giphy) and **Lottie sticker** animation.
- **Edit history**, **slash commands**, **audit log**, **multi-account switcher**,
  drag-to-reorder channels, full role/emoji **editors**.

These are tracked but were not attempted here to keep every change compiling and
reviewable.
