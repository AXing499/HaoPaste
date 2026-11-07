#!/usr/bin/env bash
#
# Builds a distributable HaoPaste DMG containing the .app and an Applications
# shortcut. Run `make dmg` from the repository root, or invoke this script after
# a Release build.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/.build/release/Build/Products/Release/HaoPaste.app}"
DIST="$ROOT/dist"

if [[ ! -d "$APP" ]]; then
    echo "error: Release app not found at: $APP" >&2
    echo "Run 'make release' first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
VOLUME_NAME="HaoPaste $VERSION"
DMG="$DIST/HaoPaste-$VERSION.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/haopaste-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$DIST"
rm -f "$DMG" "$DMG.sha256"

# Stage the classic drag-to-install DMG layout.
ditto "$APP" "$STAGE/HaoPaste.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/安装说明.txt" <<'EOF'
HaoPaste 安装说明

1. 将左侧的 HaoPaste 拖入右侧的“Applications / 应用程序”文件夹。
2. 从“应用程序”或 Spotlight 启动 HaoPaste。
3. HaoPaste 是菜单栏应用，启动后不会显示 Dock 图标。
   首次启动会自动展示一次面板，之后：
     · 按 ⌥⌘V 随时呼出悬浮面板
     · 点击菜单栏中的剪贴板图标也可打开
     · 右键菜单栏图标可暂停监听、清空未置顶记录或退出

系统要求：macOS 14 或更高版本。

如果 macOS 提示“无法验证开发者”：
  在 Finder 中右键 HaoPaste → 打开，或在“系统设置 → 隐私与安全性”
  中允许打开。本安装包使用本地 ad-hoc 签名，未做 Apple 公证。
EOF

# Strip development attributes and make sure the copy is validly signed.
xattr -cr "$STAGE/HaoPaste.app" 2>/dev/null || true
if ! codesign --verify --deep --strict "$STAGE/HaoPaste.app" >/dev/null 2>&1; then
    codesign --force --deep --sign - "$STAGE/HaoPaste.app"
fi

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

(
    cd "$DIST"
    shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)

echo "Created: $DMG"
echo "SHA-256: $DIST/$(basename "$DMG").sha256"
