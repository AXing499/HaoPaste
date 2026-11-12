#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${HAOPASTE_SKIP_BUILD:-0}" != "1" ]]; then
    xcodebuild \
        -project HaoPaste.xcodeproj \
        -scheme HaoPaste \
        -configuration Debug \
        -derivedDataPath .build \
        build -quiet
fi

APP=".build/Build/Products/Debug/HaoPaste.app/Contents/MacOS/HaoPaste"
OUTPUT_DIR="${HAOPASTE_SCREENSHOT_OUTPUT:-Docs}"
mkdir -p "$OUTPUT_DIR"
export HAOPASTE_RENDER_FIXED_NOW="${HAOPASTE_RENDER_FIXED_NOW:-1794326400}"
export HAOPASTE_RENDER_DISABLE_ANIMATIONS=1
if [[ ! -x "$APP" ]]; then
    echo "Debug app not found at $APP; run make build first." >&2
    exit 1
fi

EN_STORE="$(mktemp -d "${TMPDIR:-/tmp}/haopaste-shots-en.XXXXXX")"
ZH_STORE="$(mktemp -d "${TMPDIR:-/tmp}/haopaste-shots-zh.XXXXXX")"

# Keep documentation screenshots on the default-off state regardless of the
# developer's current app preferences.
DEFAULTS_DOMAIN="com.hao.HaoPaste"
SELECTION_SETTING_KEY="settings.selectionTranslationEnabled"
ORIGINAL_SELECTION_SETTING="$(
    defaults read "$DEFAULTS_DOMAIN" "$SELECTION_SETTING_KEY" 2>/dev/null || true
)"
defaults write "$DEFAULTS_DOMAIN" "$SELECTION_SETTING_KEY" -bool false

cleanup() {
    rm -rf "$EN_STORE" "$ZH_STORE"
    if [[ "$ORIGINAL_SELECTION_SETTING" == "1" ]]; then
        defaults write "$DEFAULTS_DOMAIN" "$SELECTION_SETTING_KEY" -bool true
    else
        defaults delete "$DEFAULTS_DOMAIN" "$SELECTION_SETTING_KEY" 2>/dev/null || true
    fi
}
trap cleanup EXIT

render_en() {
    "$APP" --storage "$EN_STORE" --language en -AppleLanguages '(en)' "$@"
}

render_zh() {
    "$APP" --storage "$ZH_STORE" --language zh-Hans -AppleLanguages '(zh-Hans)' "$@"
}

# Main panel
render_en --render "$OUTPUT_DIR/screenshot-light-en.png"
HAOPASTE_RENDER_APPEARANCE=dark render_en --render "$OUTPUT_DIR/screenshot-dark-en.png"
render_zh --render "$OUTPUT_DIR/screenshot-light.png"
HAOPASTE_RENDER_APPEARANCE=dark render_zh --render "$OUTPUT_DIR/screenshot-dark.png"

# Clipboard shelf
render_en --render-shelf "$OUTPUT_DIR/screenshot-shelf-en.png"
render_zh --render-shelf "$OUTPUT_DIR/screenshot-shelf.png"
HAOPASTE_RENDER_APPEARANCE=dark render_en --render-shelf "$OUTPUT_DIR/screenshot-shelf-dark-en.png"
HAOPASTE_RENDER_APPEARANCE=dark render_zh --render-shelf "$OUTPUT_DIR/screenshot-shelf-dark.png"
HAOPASTE_RENDER_SHELF_EDGE=left render_en --render-shelf "$OUTPUT_DIR/screenshot-shelf-side-en.png"
HAOPASTE_RENDER_SHELF_EDGE=left render_zh --render-shelf "$OUTPUT_DIR/screenshot-shelf-side.png"
HAOPASTE_RENDER_SHELF_HOVER=1 render_en --render-shelf "$OUTPUT_DIR/screenshot-shelf-actions-en.png"
HAOPASTE_RENDER_SHELF_HOVER=1 render_zh --render-shelf "$OUTPUT_DIR/screenshot-shelf-actions.png"

# Snippets
HAOPASTE_RENDER_SNIPPETS=1 render_en --render "$OUTPUT_DIR/screenshot-snippets-en.png"
HAOPASTE_RENDER_SNIPPETS=1 render_zh --render "$OUTPUT_DIR/screenshot-snippets.png"

# Preview
HAOPASTE_RENDER_PREVIEW=image render_en --render "$OUTPUT_DIR/screenshot-preview-en.png"
HAOPASTE_RENDER_PREVIEW=image render_zh --render "$OUTPUT_DIR/screenshot-preview.png"
HAOPASTE_RENDER_PREVIEW=text render_en --render "$OUTPUT_DIR/screenshot-preview-text-en.png"
HAOPASTE_RENDER_PREVIEW=text render_zh --render "$OUTPUT_DIR/screenshot-preview-text.png"

# Multi-select
HAOPASTE_RENDER_MULTI=3 render_en --render "$OUTPUT_DIR/screenshot-multi-select-en.png"
HAOPASTE_RENDER_MULTI=3 render_zh --render "$OUTPUT_DIR/screenshot-multi-select.png"

# Quick translation
render_en --render-quick "$OUTPUT_DIR/screenshot-quick-translation-en.png"
render_zh --render-quick "$OUTPUT_DIR/screenshot-quick-translation.png"

# Translation pane
HAOPASTE_RENDER_TRANSLATION=success render_en --render "$OUTPUT_DIR/screenshot-translation-en.png"
HAOPASTE_RENDER_TRANSLATION=success render_zh --render "$OUTPUT_DIR/screenshot-translation.png"
HAOPASTE_RENDER_TRANSLATION=consent render_en --render "$OUTPUT_DIR/screenshot-translation-consent-en.png"
HAOPASTE_RENDER_TRANSLATION=consent render_zh --render "$OUTPUT_DIR/screenshot-translation-consent.png"

# OCR
HAOPASTE_RENDER_OCR=success render_en --render "$OUTPUT_DIR/screenshot-ocr-en.png"
HAOPASTE_RENDER_OCR=success render_zh --render "$OUTPUT_DIR/screenshot-ocr.png"
HAOPASTE_RENDER_OCR=batch render_en --render "$OUTPUT_DIR/screenshot-ocr-batch-en.png"
HAOPASTE_RENDER_OCR=batch render_zh --render "$OUTPUT_DIR/screenshot-ocr-batch.png"

# Selection translation
render_en --render-selection "$OUTPUT_DIR/screenshot-selection-translation-en.png"
render_zh --render-selection "$OUTPUT_DIR/screenshot-selection-translation.png"

# Settings
render_en --render-settings "$OUTPUT_DIR/screenshot-settings-en.png"
render_zh --render-settings "$OUTPUT_DIR/screenshot-settings.png"
HAOPASTE_RENDER_SETTINGS_TAB=shortcuts render_en --render-settings "$OUTPUT_DIR/screenshot-settings-shortcuts-en.png"
HAOPASTE_RENDER_SETTINGS_TAB=shortcuts render_zh --render-settings "$OUTPUT_DIR/screenshot-settings-shortcuts.png"
HAOPASTE_RENDER_SETTINGS_TAB=intelligence render_en --render-settings "$OUTPUT_DIR/screenshot-settings-intelligence-en.png"
HAOPASTE_RENDER_SETTINGS_TAB=intelligence render_zh --render-settings "$OUTPUT_DIR/screenshot-settings-intelligence.png"

echo "Screenshots written to $OUTPUT_DIR/."
