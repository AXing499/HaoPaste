#!/usr/bin/env bash
#
# Installs a built Release app into /Applications (or ~/Applications when the
# system folder is not writable), then launches it.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="${1:-$ROOT/.build/release/Build/Products/Release/HaoPaste.app}"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "error: app not found at: $SOURCE_APP" >&2
    echo "Run 'make release' first." >&2
    exit 1
fi

if [[ -w "/Applications" ]]; then
    TARGET_DIR="/Applications"
else
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

TARGET_APP="$TARGET_DIR/HaoPaste.app"

# Quit an existing copy before replacing it.
osascript -e 'tell application id "com.hao.HaoPaste" to quit' >/dev/null 2>&1 || true
pkill -x HaoPaste >/dev/null 2>&1 || true
sleep 0.5

rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

if ! codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1; then
    codesign --force --deep --sign - "$TARGET_APP"
fi

# Refresh Launch Services and Spotlight so exactly one installed copy is visible.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$TARGET_APP" >/dev/null 2>&1 || true
mdimport "$TARGET_APP" >/dev/null 2>&1 || true

echo "Installed: $TARGET_APP"
open "$TARGET_APP"
