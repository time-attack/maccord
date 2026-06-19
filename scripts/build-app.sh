#!/usr/bin/env bash
#
# Assemble a runnable maccord.app bundle from the SwiftPM build.
#
# Usage:  scripts/build-app.sh [debug|release]
#
# Produces ./dist/maccord.app  (ad-hoc signed with the Keychain entitlement).
# Open it with:  open dist/maccord.app
#
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="maccord"
BUNDLE_ID="com.maccord.app"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "▸ Building $APP_NAME ($CONFIG) with SwiftPM…"
swift build -c "$CONFIG" --product "$APP_NAME"

BIN_PATH="$(swift build -c "$CONFIG" --product "$APP_NAME" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "✗ Built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "▸ Assembling bundle at ${APP} ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"

# Copy SwiftPM resource bundles (fonts, etc.) so Bundle.module resolves at runtime.
# Place them BOTH next to the binary and in Resources to cover Bundle.module lookup.
BIN_DIR="$(dirname "$BIN_PATH")"
for b in "$BIN_DIR"/*.bundle; do
  [[ -e "$b" ]] || continue
  cp -R "$b" "$APP/Contents/Resources/"
  echo "▸ Bundled resources: $(basename "$b")"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>maccord</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key> <string>0.1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>26.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key> <true/>
</dict>
</plist>
PLIST

# Entitlements: a non-sandboxed app needs none for outgoing network or for
# generic-password Keychain access (it uses its own default access group). We
# keep an empty/sandbox-off entitlements file for clarity; ad-hoc signatures
# reject app-specific keychain-access-groups, so we deliberately omit those.
ENTITLEMENTS="$DIST/maccord.entitlements"
cat > "$ENTITLEMENTS" <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key> <false/>
</dict>
</plist>
ENT

echo "▸ Ad-hoc code signing…"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP" >/dev/null 2>&1 || \
  codesign --force --deep --sign - "$APP"

# macOS keys running apps by bundle id, so `open` would re-activate a stale
# pre-build instance instead of launching this fresh binary. Quit any running
# copy so the next launch is guaranteed to be THIS build.
if pkill -x "$APP_NAME" 2>/dev/null; then
  echo "▸ Quit a running ${APP_NAME} instance so the new build launches fresh."
fi

echo "✓ Built $APP"
echo "  Run it with:  open \"$APP\""
