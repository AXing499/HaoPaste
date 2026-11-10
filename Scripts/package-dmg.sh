#!/usr/bin/env bash
#
# Builds a distributable HaoPaste DMG containing the .app and an Applications
# shortcut, with a Finder window that explains how to install it. Run `make dmg`
# from the repository root, or invoke this script after a Release build.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/.build/release/Build/Products/Release/HaoPaste.app}"
DIST="$ROOT/dist"
BACKGROUND="$ROOT/Scripts/dmg-background.png"

if [[ ! -d "$APP" ]]; then
    echo "error: Release app not found at: $APP" >&2
    echo "Run 'make release' first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
VOLUME_NAME="HaoPaste $VERSION"
DMG="$DIST/HaoPaste-$VERSION.dmg"
RW_DMG="$(mktemp "${TMPDIR:-/tmp}/haopaste-rw.XXXXXX.dmg")"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/haopaste-dmg.XXXXXX")"
MOUNT="/Volumes/$VOLUME_NAME"

cleanup() {
    hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
    rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

mkdir -p "$DIST"
rm -f "$DMG" "$DMG.sha256"

# Stage the classic drag-to-install DMG layout.
ditto "$APP" "$STAGE/HaoPaste.app"
ln -s /Applications "$STAGE/Applications"

# Finder window background with the install steps and the ad-hoc signing note.
if [[ -f "$BACKGROUND" ]]; then
    mkdir -p "$STAGE/.background"
    cp "$BACKGROUND" "$STAGE/.background/background.png"
    chflags hidden "$STAGE/.background" 2>/dev/null || true
    SetFile -a V "$STAGE/.background" 2>/dev/null || true
fi

# Strip development attributes and make sure the copy is validly signed.
xattr -cr "$STAGE/HaoPaste.app" 2>/dev/null || true
if ! codesign --verify --deep --strict "$STAGE/HaoPaste.app" >/dev/null 2>&1; then
    codesign --force --deep --sign - "$STAGE/HaoPaste.app"
fi

# Build a read-write image first so Finder can store the window layout.
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$RW_DMG" >/dev/null

hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
hdiutil attach "$RW_DMG" -nobrowse -readwrite >/dev/null
open "$MOUNT"
sleep 0.5

# Best effort: Finder may refuse Apple events in a headless build. The DMG is
# still usable if the layout cannot be applied.
if [[ -f "$BACKGROUND" ]]; then
    osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {140, 140, 870, 600}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        try
            set position of item ".background" of container window to {2000, 2000}
        end try
        set position of item "HaoPaste.app" of container window to {185, 195}
        set position of item "Applications" of container window to {545, 195}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT
fi

sync
hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

(
    cd "$DIST"
    shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)

echo "Created: $DMG"
echo "SHA-256: $DIST/$(basename "$DMG").sha256"
