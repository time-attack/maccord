Drop Discord's font files here to make maccord use the real Discord typeface.

Discord's UI font is "gg sans" (proprietary — not redistributable, so it isn't
bundled). Options:

1. If you have the gg sans .ttf/.otf files, copy them into THIS folder and
   rebuild (scripts/build-app.sh). They are auto-registered at launch and the UI
   will pick them up (family name must be "gg sans").

2. Free alternative: install Inter (https://rsms.me/inter/) and rename the
   constant `DiscordFont.family` in Sources/maccord/DesignSystem/Typography.swift
   to "Inter" (or drop Inter-*.ttf here).

Until a font is present, maccord falls back to the system font (SF Pro).
Recognized extensions: .ttf, .otf
